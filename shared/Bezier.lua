
--[=[
    Primarily sourced from: https://pomax.github.io/bezierinfo/
]=]


local Bezier = {}

local BinomialLUT = {
    {1};
    {1, 1};
    {1, 2, 1};
    {1, 3, 3, 1};
    {1, 4, 6, 4, 1};
    {1, 5, 10, 10, 5, 1};
    {1, 6, 15, 20, 15, 6, 1};
}

type ControlPoints = {[number]: Vector3}

-- //

local function Factorial(X: number): number
    if (X == 0) then
        return 1;
    end
    return X * Factorial(X - 1)
end



local function Binomial(N: number, K: number): number
    while (N >= #BinomialLUT) do
        local s = #BinomialLUT
        local nextRow = {[1] = 1}
        local previousRow = BinomialLUT[s - 1]
        for i = 2, s do
            nextRow[i] = previousRow[i - 1] + previousRow[i]
        end
        nextRow[s] = 1
        BinomialLUT[s + 1] = nextRow
    end
    return BinomialLUT[N][K]
end


-- //


--[=[
    @param Points -- The control points of the curve
    @param Steps? -- How many segments the curve should get broken up into, defaults to 32

    Creates a Distance Lookup Table
]=]

function Bezier.GetLUTAndLength(Points: ControlPoints, Steps: number?): ({[number]: number}, number)
    local steps = Steps or 32
    local len = 0
    local lut = {}
    
    local previous
    for i = 0, steps do
        local alpha = i/steps
        local point = Bezier.deCasteljau(Points, alpha)

        len = (previous and len + (previous - point).Magnitude) or len
        lut[i] = len

        previous = point
    end
    return lut, len
end

--[=[

    @param LUT -- Cumulative Distance Lookup Table
    @param Length -- Arc length of the curve. Essentially the sum of the LUT, but parameterized here for efficiency
    @param Alpha -- Number between [0, 1]

    Returns an equidistant point on a curve given the provided LUT
]=]



function Bezier.ConvertAlpha(LUT: {[number]: number}, Length: number, Alpha: number): number
    local target = Length * Alpha

    if (Alpha == 1) then
        return 1;--LUT[#LUT]
    elseif (Alpha == 0) then
        return 0; --LUT[1]
    end

    local largestIndex = 1;
    local largestDistance = LUT[largestIndex]
    for i, distance in ipairs(LUT) do
        if ((target >= distance) and (distance > largestDistance)) then
            largestIndex, largestDistance = i, distance
        end
    end

    if (largestDistance == target) then
        return largestIndex/#LUT
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
    @param Points -- The control points of the curve
    @param Alpha -- A number between [0, 1] 

    Using a numerical solution (de Casteljau algorithm), it calculates a point on a Bezier curve at the given Alpha value
]=]

function Bezier.deCasteljau(Points: ControlPoints, Alpha: number): Vector3
    local copy, n = {unpack(Points)}, #Points
    for j = 1, n - 1 do
        for k = 1, n - j do
            copy[k] = (1 - Alpha) * copy[k] + copy[k + 1] * Alpha
        end
    end
    return copy[1]
end


--[=[
    @param Points -- The control points of the curve
    @param Alpha -- A number between [0, 1]

    Gets the first derivative of a curve at a given point.
]=]

function Bezier.FirstDerivative(Points: ControlPoints, Alpha: number): Vector3
    local sum = Vector3.zero

    local n = #Points
    local k = n - 1

    for i = 0, k - 1 do -- subtracting 1 here to account for lua arrays begin with an index of 1 and not 0.
        local binomialCoefficient = Binomial(k + 1, i + 1) --Factorial(k) / (Factorial(i) * Factorial(k - i) )
        sum += binomialCoefficient * math.pow(1 - Alpha, k - i) * math.pow(Alpha, i) * n * (Points[i + 2] - Points[i + 1])
    end
    return sum;
end

--[=[
    @param Points -- The control points of the curve
    @param Alpha -- A number between [0, 1]

    Gets the second derivative of a curve at a given point
]=]

function Bezier.SecondDerivative(Points: ControlPoints, Alpha: number): Vector3
    local sum = Vector3.zero

    local n = #Points
    local k = n - 2

    for i = 0, k - 1 do -- same reason as before, lua arrays begin indexing at 1.
        local binomialCoefficient =  Binomial(k + 1, i + 1) --Factorial(k) / (Factorial(i) * Factorial(k - i))
        sum += binomialCoefficient * math.pow(1 - Alpha, k - i) * math.pow(Alpha, i) * n * (Points[i + 2] - Points[i + 1])
    end
    return sum
end


--[=[
]=]

function Bezier.Derivative(Points: ControlPoints, Alpha: number, Order: number?): Vector3
    local sum = Vector3.zero

    local n = #Points
    local k = n - (Order or 1)

    for i = 0, k - 1 do
        local binomialCoefficient = Factorial(k) / (Factorial(i) * Factorial(k - i))
    end
end



return Bezier