sfliquidutil = {}

function sfliquidutil.init(liquidName)
    self.waterConfig = sfliquidutil.getLiquidConfig("water")

    sfliquidutil.setLiquid(liquidName)
end

--- Set current stored liquid. This is useful to prevent reloading the liquid configuration everytime.
-- @param liquidName - Name of the liquid to load.
-- @return True if state was preoperly updated, or if liquid was already loaded. False on error (state is guaranteed not to be modified).
function sfliquidutil.setLiquid(liquidName)
    local ret = false

    if liquidName and liquidName == self.liquidName and self.liquidConfig then
        ret = true
    elseif liquidName then
        local config = root.liquidConfig(liquidName)

        if config then
            self.liquidName = liquidName
            self.liquidConfig = config["config"]
            ret = true
        end
    end

    return ret
end

function sfliquidutil.getLiquidConfig(liquidName)
    local ret = nil

    if not liquidName or liquidName == self.liquidName then
        if self.liquidConfig then
            ret = self.liquidConfig
            liquidName = nil
        elseif self.liquidName then
            liquidName = self.liquidName
        end
    end

    if liquidName then
        local config = root.liquidConfig(liquidName)

        if config then
            ret = config["config"]
        end
    end

    return ret
end

function sfliquidutil.getColorShift(name, ref)
    local config = sfliquidutil.getLiquidConfig(name)
    local ret = nil
    local refConfig = nil

    if not ref or ref == "water" then
        refConfig = self.waterConfig
    else
        refConfig = sfliquidutil.getLiquidConfig(ref)
    end

    if config and refConfig then
        local refRgb = refConfig["color"]
        local rgb = config["color"]
        local lrgb = config["radiantLight"]
        local brgb = config["bottomLightMix"]

        if refRgb and rgb then
            local refHsv = sfutil.rgb2hsv(refRgb)
            local liquidHsv = sfutil.rgb2hsv(rgb)

            if lrgb then
                local lHsv = sfutil.rgb2hsv(lrgb)

                if brgb then
                    local bHsv = sfutil.rgb2hsv(lrgb)

                    liquidHsv.hue = (liquidHsv.hue + lHsv.hue + bHsv.hue) / 3
                    liquidHsv.sat = (liquidHsv.sat + lHsv.sat + bHsv.sat) / 3
                    liquidHsv.val = (liquidHsv.val + lHsv.val + bHsv.val) / 3
                else
                    liquidHsv.hue = (liquidHsv.hue + lHsv.hue) / 2
                    liquidHsv.sat = (liquidHsv.sat + lHsv.sat) / 2
                    liquidHsv.val = (liquidHsv.val + lHsv.val) / 2
                end
            end

            ret = {
                hue = liquidHsv.hue - refHsv.hue,
                sat = liquidHsv.sat - refHsv.sat,
                val = liquidHsv.val - refHsv.val,
                rgb[4]
            }
        end
    end

    return ret
end

function sfliquidutil.getLiquidItemConfig(name)
    local ret = nil
    local config = self.liquidConfig

    if not name or name == self.liquidName then
        name = self.liquidName
    elseif name then
        config = sfliquidutil.getLiquidConfig(name)
    end

    if config then
        local itemName = config["itemDrop"]
        local itemConfig = root.itemConfig({name=item, count=1})

        if itemConfig then
            ret = itemConfig["config"]
        end
    end

    return ret
end




