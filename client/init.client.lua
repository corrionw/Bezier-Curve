local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- //

local Shared = ReplicatedStorage:WaitForChild("Shared")


-- //
local Bezier = require(Shared:WaitForChild("Bezier2"))

local Camera = workspace.CurrentCamera

local ControlParts = workspace:WaitForChild("ControlPoints")
local SampledParts = workspace:WaitForChild("SampledPoints")

local SampledPoints = {}

local NumControlParts = #ControlParts:GetChildren() - 1
local PreviousT = 0

local TANGENT_PART_SIZE = Vector3.new(0.25, 0.25, 1.5)

local INCREMENTS = 32;

-- //

local ControlPoints
local LUT
local ArcLength
local RotationMinimisedFrames
-- //

local function GetControlPoints(): {[number]: Vector3}
    local parts = ControlParts:GetChildren()
    table.sort(parts, function(A, B)
        return tonumber(A.Name) < tonumber(B.Name)
    end)

    local points = {}
    for _, part in ipairs(parts) do
        points[#points + 1] = part.Position
    end
    return points;
end

-- //

for i = 0, 1, 1/INCREMENTS do
    local part = Instance.new("Part")
    part.Shape = Enum.PartType.Ball
    part.Size = Vector3.one
    part.CanCollide = false
    part.Anchored = true
    part.Parent = SampledParts

    local example = Instance.new("Part")
    example.CanCollide = false
    example.Anchored = false
    example.Shape = Enum.PartType.Block
    example.Size = TANGENT_PART_SIZE

    local direction, normal, extra, extra2 = example:Clone(), example:Clone(), example:Clone(), example:Clone()

    extra.Shape, extra2.Shape = Enum.PartType.Ball, Enum.PartType.Ball

    direction.BrickColor, normal.BrickColor, extra.BrickColor, extra2.BrickColor = BrickColor.new("Navy blue"), BrickColor.new("Really red"), BrickColor.new("Black"), BrickColor.new("Black")
    direction.Name, normal.Name, extra.Name, extra2.Name = "Direction", "Normal", "Extra", "Extra2"
    direction.Parent, normal.Parent, extra.Parent, extra2.Parent = part, part, part, part

    SampledPoints[#SampledPoints + 1] = part
end

-- //

RunService.Heartbeat:Connect(function(DeltaTime)
    ControlPoints = GetControlPoints()

    LUT, ArcLength = Bezier.GetLUT(ControlPoints, INCREMENTS)
    RotationMinimisedFrames = Bezier.GetRotationMinimisedFrames(ControlPoints, LUT)

    for _, part in ipairs(SampledPoints) do
        local t = Bezier.RemapT(LUT, PreviousT, ArcLength)
        local point = Bezier.deCastelJau(ControlPoints, t)
        part.Position = point

        local tangent = Bezier.Derivative(ControlPoints, t).Unit
        local normal =  Bezier.NormalFromMinimisedFrames(RotationMinimisedFrames, t) --Bezier.FrenetNormal(controlPoints, t)


        part.Direction.CFrame = CFrame.lookAt(point, point + tangent)
        part.Normal.CFrame = CFrame.lookAt(point, point + normal)

        part.Extra.Position = point + (normal * 2)

        PreviousT += 1/INCREMENTS
    end
    PreviousT = 0
end)


ControlParts.ChildAdded:Connect(function(Object)
    NumControlParts += 1
    Object.Name = NumControlParts
end)

local maxTime = 10;
UserInputService.InputBegan:Connect(function(Input, GPE)
    if (Input.KeyCode == Enum.KeyCode.G) then
    
        local timeHeld = 0;
        local deltaTime = 0;

        while (UserInputService:IsKeyDown(Enum.KeyCode.G)) do
          --  SampledParts.Parent = nil

            timeHeld += deltaTime
            Camera.CameraType = Enum.CameraType.Scriptable


            local i = timeHeld/maxTime
            
            local point = Bezier.deCastelJau(ControlPoints, i)
            local direction = Bezier.Derivative(ControlPoints, i)

            Camera.CFrame = CFrame.lookAt(point, point + direction.Unit)

            deltaTime = task.wait()
        end
        SampledParts.Parent = workspace
        Camera.CameraType = Enum.CameraType.Custom
    end

end)