--[=[
    Bezier curve library.
    Resources used in creating this:  
        https://pomax.github.io/bezierinfo/;
        https://pages.mtu.edu/~shene/COURSES/cs3621/NOTES/spline/Bezier/de-casteljau.html
]=]


local Bezier = {}

-- //

local EPS = 0.0001;

local BinomialLUT = { --Not much memory usage by writing some steps of Pascal's Triangle by hand
    {1};
    {1, 1};
    {1, 2, 1};
    {1, 3, 3, 1};
    {1, 4, 6, 4, 1};
    {1, 5, 10, 10, 5, 1};
    {1, 6, 15, 20, 15, 6, 1};
}

-- //
type Points = {[number]: Vector3}
type RotationMinimisedFrames = {[number]: {
    O: Vector3; -- Origin
    T: Vector3; -- Tangent (Direction of the curve)
    R: Vector3; -- Axis of rotation
    N: Vector3 -- Normal
}}
-- //


local function Binomial(N: number, K: number) -- The Factorial is EXTREMELY expensive, using Pascal's Triangle in a LUT is drastically more efficient.
    while (N >= #BinomialLUT) do
        local s = #BinomialLUT
        local nextEntry = {[1] = 1; [s + 1] = 1}

        local previousEntry = BinomialLUT[s - 1]
        for i = 2, s do
            nextEntry[i] = previousEntry[i - 1] + previousEntry[i]
        end
        BinomialLUT[s + 1] = nextEntry
    end
    return BinomialLUT[N + 1][K + 1]  
end

-- //

--[=[

    @param ControlPoints -- Control points of the curve
    @param T -- Number between [0, 1]

    Calculates a position that lies on the curve at the given T value using de CastelJau's algorithm
]=]

function Bezier.deCastelJau(ControlPoints: Points, T: number): Vector3
    local q, n = {table.unpack(ControlPoints)}, #ControlPoints
    for j = 1, n do
        for i = 1, n - j do
            q[i] =  q[i] * (1 - T) + T * q[i + 1]
        end 
    end
    return q[1];
end
--[=[

    @param ControlPoints -- Control points of the curve
    @param T -- Number between [0, 1]

    Calculates a position that lies on the curve at the given T value using explicit definition of Bernstein polynomials. NOT as numerically stable as de CastelJau's algorithm for higher orders.
]=]

function Bezier.ExplicitDefinition(ControlPoints: Points, T: number): Vector3
    local n = #ControlPoints
    local k = n - 1

    local sum = Vector3.zero
    for i = 0, k do
        local coefficient = Binomial(k, i)
        sum += (coefficient * math.pow(1 - T, k - i) * math.pow(T, i)) * ControlPoints[i + 1]
    end
    return sum;
end


--[=[

    @param ControlPoints -- Control points of the curve
    @param Segments? -- How many approximation the algorithm takes, default 32

    Returns a Cumulative Distance Lookup Table & the length of the curve.

]=]

function Bezier.GetLUT(ControlPoints: Points, Segments: number?): ({[number]: number}, number)
    local steps = Segments or 32
    local lut, len = {}, 0

    lut[0] = 0
    local previous = Bezier.deCastelJau(ControlPoints, 0)
    for i = 1, steps do
        local t = i/steps
        local point = Bezier.deCastelJau(ControlPoints, t)

        len += (previous - point).Magnitude
        lut[i] = len
        previous = point
    end

    return lut, len;
end

--[=[

    @param LUT -- Cumulative Distance Lookup Table
    @param T -- Number between [0, 1]
    @param ArcLength? -- Arc length of the curve. Automatically calculates it using the LUT if not provided.

    Returns a remapped value of T to be equidistant on the curve given its cumulative distance LUT
]=]

function Bezier.RemapT(LUT: {[number]: number}, T: number, ArcLength: number?): number

    local curveLength = ArcLength
    if (curveLength == nil) then
        curveLength = 0
        for _, distance in ipairs(LUT) do
            curveLength += distance
        end
    end

    local target = curveLength * T
    local largestIndex = 0
    local largestDistance = 0

    for i, distance in ipairs(LUT) do
        if ((target >= distance) and (target > largestDistance)) then
            largestIndex, largestDistance = i, distance
        end
    end

    if (largestDistance >= target) then
        return largestIndex/#LUT;
    else
        local nextDistance, previousDistance = LUT[largestIndex + 1], LUT[largestIndex - 1]
        if (nextDistance) then
            return (largestIndex + (target - largestDistance)/(nextDistance - largestDistance))/#LUT;
        else
            return (largestIndex + (target - largestDistance)/(previousDistance - largestDistance))/#LUT;
        end
    end
end


--[=[
    @param ControlPoints -- Control points of the curve
    @param T -- Number between [0, 1]

    Gets the first derivative of the curve at the given T value.
]=]

function Bezier.Derivative(ControlPoints: Points, T: number): Vector3
    local n = #ControlPoints
    local k = n - 2
    
    local sum = Vector3.zero
    for i = 0, k do
        local coefficient = Binomial(k, i)
        sum += coefficient * math.pow(T, i) * math.pow(1 - T, k - i) * n * (ControlPoints[i + 2] - ControlPoints[i + 1])
    end
    return sum;
end

--[=[
    @param ControlPoints
    @param T

    -- Gets the second derivative of the curve at the given T value.
]=]

function Bezier.DDerivative(ControlPoints: Points, T: number): Vector3
    local n = #ControlPoints
    local k = n - 3
    local sum = Vector3.zero

    for i = 0, k do
        local coefficient = Binomial(k, i)
        sum += coefficient * math.pow(T, i) * math.pow(1 - T, k - i) * n * (ControlPoints[i + 2] - ControlPoints[i + 1])
    end
    return sum;
end

--[=[
    @param ControlPoints -- The control points of the curve
    @param T -- A number between [0, 1]

    Returns the Frenet Normal of the curve at the given T value.

]=]

function Bezier.FrenetNormal(ControlPoints: Points, T: number): Vector3
    local a = Bezier.Derivative(ControlPoints, T).Unit
    local b = (a + Bezier.DDerivative(ControlPoints, T)).Unit
    local r = b:Cross(a).Unit
    local normal = r:Cross(a).Unit
    return normal;
end

--[=[
rewrite this later
]=]

function Bezier.NormalFromMinimisedFrames(Frames: RotationMinimisedFrames, T: number): Vector3
    local n = #Frames
    local f = T * n
    local i = math.floor(f)
     
    if (f == i) then
        return Frames[i].N
    end

    local j = i + 1
    return Frames[j].N;
end



--[=[
    @param ControlPoints
    @param LUT

    Returns a LUT of minimised rotations of the curve using its Cumulative Distance LUT.
]=]


function Bezier.GetRotationMinimisedFrames(ControlPoints: Points, LUT: {[number]: number}): RotationMinimisedFrames
    local step = 1/#LUT

    local a = Bezier.Derivative(ControlPoints, 0 + EPS)
    local b = a + Bezier.DDerivative(ControlPoints, 0 + EPS)
    local r = b:Cross(a).Unit
    local normal = r:Cross(a).Unit

    local frames = {
        [0] = {
            O = Bezier.deCastelJau(ControlPoints, 0);
            T = a;
            R = r;
            N = normal;
        };

    }
    for i = step, 1, step do
        local i1 = i + step
        local x0 = frames[#frames]

        local x1 = {
            O = Bezier.deCastelJau(ControlPoints, i1);
            T = Bezier.Derivative(ControlPoints, i1);
        }

        local v1 = x1.O - x0.O
        local c1 = v1:Dot(v1)
        local riL = x0.R - v1 * 2/c1 * v1:Dot(x0.R)
        local tiL = x0.T - v1 * 2/c1 * v1:Dot(x0.T)

        local v2 = x1.T - tiL
        local c2 = v2:Dot(v2)
    
        x1.R = riL - v2 * 2/c2 * v2:Dot(riL)
        x1.N = x1.R:Cross(x1.T).Unit

        frames[#frames + 1] = x1
    end
    return frames;
end


return Bezier