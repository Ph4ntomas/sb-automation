sfutil = {}

--------------------------------------------------------------------------------
--- Yields until a promise is finished, or immediately if running on the main
-- thread
-- @param promise RpcMessage - the promise to await
-- @returns Return the promise when finished
function sfutil.safe_await(promise)
    if not coroutine.running() == nil then
        while not promise:finished() do
            coroutine.yield()
        end
    end
  return promise
end
--------------------------------------------------------------------------------
local function fmax(val)
    if val ~= nil then
        max = val[1]
        for _,v in ipairs(val) do
            if max < v then
                max = v
            end
        end
        return max
    end

    return nil
end

local function fmin(val)
    if val ~= nil then
        min = val[1]
        for _, v in ipairs(val) do
            if min > v then
                min = v
            end
        end
        return min
    end

    return nil
end

function sfutil.rgb2hsv(rgb)
    local r = rgb[1] / 255
    local g = rgb[2] / 255
    local b = rgb[3] / 255
    local maxColor = fmax({r, g, b})
    local minColor = fmin({r, g, b})
    local delta = maxColor - minColor

    local hue = 0
    if delta == 0 then
    elseif maxColor == r then
        hue = 60 * (((g - b) / delta) % 6)
    elseif maxColor == g then
        hue = 60 * (((b - r) / delta) + 2)
    elseif maxColor == b then
        hue = 60 * (((r - g) / delta) + 4)
    end

    local sat = 0
    if maxColor ~= 0 then
        sat = delta / maxColor
    end

    local val = (maxColor + minColor) / 2

    return {hue = hue, sat = sat, val = val}
end

function sfutil.compare(ref, oth, ign)
    local tableType = type({})

    if type(ref) ~= tableType or type(oth) ~= tableType then
        return ref == oth
    end

    local seen = {}
    ign = ign or {}

    for k, v in pairs(ref) do
        seen[k] = true
        if ign[k] ~= true then
            if not sfutil.compare(v, oth[k], ign[k]) then 
                return false 
            end
        end
    end

    for k, v in pairs(oth) do
        if not seen[k] then
            return false
        end
    end

    return true
end
