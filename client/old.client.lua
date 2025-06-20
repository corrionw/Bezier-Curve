local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- //
local Shared = ReplicatedStorage:WaitForChild("Shared")
-- //

local Bezier = require(Shared:WaitForChild("Bezier"))

local ControlPoints = workspace:WaitForChild("ControlPoints")

local INCREMENTS = 32

-- //

local function GetControlPoints(): {[number]: Vector3}
    local controlParts = ControlPoints:GetChildren()
    table.sort(controlParts, function(A, B)
        return tonumber(A.Name) < tonumber(B.Name)
    end)
    local points = {}
    for _, part in ipairs(controlParts) do
        table.insert(points, part.Position)
    end
    return points
end


-- //
local LUT, Length = Bezier.GetLUTAndLength(GetControlPoints(), INCREMENTS)

local sampledParts = {}

for i = 0, 1, 1/INCREMENTS do
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Shape = Enum.PartType.Ball
    part.Size = Vector3.one
    part.Parent = workspace.Terrain
    sampledParts[#sampledParts + 1] = part

    local a = Instance.new("Attachment")
    a.Parent = part

end


local previousAlpha = 0
RunService.Heartbeat:Connect(function()
    local controlPoints = GetControlPoints()

    LUT, Length = Bezier.GetLUTAndLength(controlPoints)

    for _, part in ipairs(sampledParts) do
        local alpha = Bezier.ConvertAlpha(LUT, Length, previousAlpha)
        local point = Bezier.deCasteljau(controlPoints, alpha)
       
        part.Position = point

        local dir = Bezier.SecondDerivative(controlPoints, alpha)
        part.Attachment.Position = dir

        previousAlpha += 1/INCREMENTS
    end
    previousAlpha = 0
end)


UserInputService.InputBegan:Connect(function(Input, GPE)
    if (GPE) then return; end
    if (Input.KeyCode == Enum.KeyCode.G) then
    end
end)

local c = #ControlPoints:GetChildren() - 1
ControlPoints.ChildAdded:Connect(function(Obj)
    c += 1
    Obj.Name = c
end)