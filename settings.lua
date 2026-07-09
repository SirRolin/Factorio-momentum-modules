-- @return nil
-- @param package table to insert the settings into
-- @comment Adds 16 settings for recipe settings
local srDisplayNames = {
    ["turbo"] = "Turbo",
    ["clean"] = "Clean",
    ["heat-up"] = "Heat up",
    ["productivity-speed"] = "Productivity/Speed",
    ["efficiency-speed"] = "Efficiency/Speed",
    ["quality-speed"] = "Quality/Speed",
    ["quality-productivity"] = "Quality/Productivity",
    ["catalyst"] = "Catalyst"
}

function addSRSettings(package, moduleName, tier, count, defaults, defaultFluids)
    if defaults ~= nil and defaults[item] ~= nil and defaults[amount] ~= nil then
        defaults = { [1] = defaults }
    elseif defaults == nil then
        defaults = {}
    end
    if defaultFluids ~= nil and defaultFluids[item] ~= nil and defaultFluids[amount] ~= nil then
        defaultFluids = { [1] = defaultFluids }
    elseif defaultFluids == nil then
        defaultFluids = {}
    end
    local displayName = srDisplayNames[moduleName] or moduleName

    -- Count
    table.insert(
        package,
        {
            type = "int-setting",
            name = string.format("sr-mom-%s-%s-sr-produces", moduleName, tier),
            setting_type = "startup",
            order = string.format("%s-%d-a", moduleName, tier),
            default_value = count or 1,
            minimum_value = 1,
            localised_name = { "mod-setting-name.sr-mom-sr-produces", displayName, tostring(tier) }
        }
    )

    -- Items
    for i = 1, 5 do
        table.insert(
            package,
            {
                type = "string-setting",
                name = string.format("sr-mom-%s-%s-sr-%s", moduleName, tier, i),
                setting_type = "startup",
                allow_blank = true,
                order = string.format("%s-%d-b-%d", moduleName, tier, i),
                default_value = defaults[i] and defaults[i].item or "",
                localised_name = { "mod-setting-name.sr-mom-sr-item", displayName, tostring(tier), tostring(i) }
            }
        )
        table.insert(
            package,
            {
                type = "int-setting",
                name = string.format("sr-mom-%s-%s-sr-amount-%s", moduleName, tier, i),
                setting_type = "startup",
                order = string.format("%s-%d-c-%d", moduleName, tier, i),
                default_value = defaults[i] and defaults[i].amount or 1,
                localised_name = { "mod-setting-name.sr-mom-sr-amount", displayName, tostring(tier), tostring(i) }
            }
        )
    end -- for i = 1 to 5 -- Items

    -- Fluids
    for i = 1, 3 do
        table.insert(
            package,
            {
                type = "string-setting",
                name = string.format("sr-mom-%s-%s-sr-fluid-%s", moduleName, tier, i),
                setting_type = "startup",
                allow_blank = true,
                order = string.format("%s-%d-d-%d", moduleName, tier, i),
                default_value = defaultFluids[i] and defaultFluids[i].fluid or "",
                localised_name = { "mod-setting-name.sr-mom-sr-fluid", displayName, tostring(tier), tostring(i) }
            }
        )
        table.insert(
            package,
            {
                type = "int-setting",
                name = string.format("sr-mom-%s-%s-sr-fluid-amount-%s", moduleName, tier, i),
                setting_type = "startup",
                order = string.format("%s-%d-e-%d", moduleName, tier, i),
                default_value = defaultFluids[i] and defaultFluids[i].amount or 25,
                localised_name = { "mod-setting-name.sr-mom-sr-fluid-amount", displayName, tostring(tier), tostring(i) }
            }
        )
    end -- for i = 1 to 3 -- Fluids

end -- function

function concatItem(base, items)
    for _, item in pairs(items) do
        base[#base+1] = item
    end
    return base
end

local settingsPackage = {
    {
        type = "string-setting",
        name = "sr-mom-ramping-mode",
        setting_type = "runtime-global",
        default_value = "balanced",
        allowed_values = {"all", "sequential", "balanced"}
    },
    {
        type = "int-setting",
        name = "sr-mom-ramping-speed",
        setting_type = "runtime-global",
        default_value = 5,
        minimum_value = 1,
        maximum_value = 60
    },
    {
        type = "double-setting",
        name = "sr-mom-ramping-max-scaling",
        setting_type = "startup",
        default_value = 1.5,
        minimum_value = 0.0,
        maximum_value = 3.0
    },
    {
        type = "double-setting",
        name = "sr-mom-ramping-min-scaling",
        setting_type = "startup",
        default_value = 0.5,
        minimum_value = 0.0,
        maximum_value = 3.0
    },
    {
        type = "double-setting",
        name = "sr-mom-ramping-threshold-scaling",
        setting_type = "startup",
        default_value = 1.0,
        minimum_value = 0.8,
        maximum_value = 3.0
    },
    {
        type = "double-setting",
        name = "sr-mom-ramping-cold-scaling",
        setting_type = "startup",
        default_value = 1.0,
        minimum_value = 0.0,
        maximum_value = 3.0
    },
    {
        type = "double-setting",
        name = "sr-mom-ramping-hot-scaling",
        setting_type = "startup",
        default_value = 2.0,
        minimum_value = 1.0,
        maximum_value = 3.0
    }
}
local defaultsOn1 = function() 
    return {
        [1] = {item = "electronic-circuit", amount = 5},
        [2] = {item = "advanced-circuit",   amount = 5},
    }
end
local defaultsOn2 = function() 
    return {
        [1] = {item = "advanced-circuit", amount = 5},
        [2] = {item = "processing-unit",  amount = 5},
    }
end

addSRSettings(settingsPackage, "turbo", 1, 1, defaultsOn1())
addSRSettings(settingsPackage, "turbo", 2, 1, concatItem(defaultsOn2(), {{ item = "sr-mom-turbo-1-0", amount = 4 }}))
addSRSettings(settingsPackage, "turbo", 3, 1, concatItem(defaultsOn2(), {{ item = "sr-mom-turbo-2-0", amount = 4 }, { item = "tungsten-carbide", amount = 1 }}))

addSRSettings(settingsPackage, "clean", 1, 1, defaultsOn1())
addSRSettings(settingsPackage, "clean", 2, 1, concatItem(defaultsOn2(), {{ item = "sr-mom-clean-1-0", amount = 4 }}))
addSRSettings(settingsPackage, "clean", 3, 1, concatItem(defaultsOn2(), {{ item = "sr-mom-clean-2-0", amount = 4 }, { item = "sulfur", amount = 5 }}))

addSRSettings(settingsPackage, "heat-up", 1, 1, defaultsOn1())
addSRSettings(settingsPackage, "heat-up", 2, 1, defaultsOn2(), {{ item = "sr-mom-heat-up-1-0", amount = 4 }})
addSRSettings(settingsPackage, "heat-up", 3, 1, concatItem(defaultsOn2(), {{ item = "sr-mom-heat-up-2-0", amount = 4 }, { item = "spoilage", amount = 5 }, { item = "biter-egg", amount = 1 }}))

addSRSettings(settingsPackage, "productivity-speed", 1, 1, defaultsOn1())
addSRSettings(settingsPackage, "productivity-speed", 2, 1, defaultsOn2(), {{ item = "sr-mom-productivity-speed-1-0", amount = 4 }})
addSRSettings(settingsPackage, "productivity-speed", 3, 2, concatItem(defaultsOn2(), {{ item = "sr-mom-productivity-speed-2-0", amount = 4 }, { item = "biter-egg", amount = 1 }, { item = "spoilage", amount = 5 }}))

addSRSettings(settingsPackage, "efficiency-speed", 1, 1, defaultsOn1())
addSRSettings(settingsPackage, "efficiency-speed", 2, 1, defaultsOn2(), {{ item = "sr-mom-efficiency-speed-1-0", amount = 4 }})
addSRSettings(settingsPackage, "efficiency-speed", 3, 2, concatItem(defaultsOn2(), {{ item = "sr-mom-efficiency-speed-2-0", amount = 4 }, { item = "spoilage", amount = 5 }, { item = "tungsten-carbide", amount = 1 }}))

addSRSettings(settingsPackage, "quality-speed", 1, 1, defaultsOn1())
addSRSettings(settingsPackage, "quality-speed", 2, 1, defaultsOn2(), {{ item = "sr-mom-quality-speed-1-0", amount = 4 }})
addSRSettings(settingsPackage, "quality-speed", 3, 2, concatItem(defaultsOn2(), {{ item = "sr-mom-quality-speed-2-0", amount = 4 }, { item = "superconductor", amount = 1 }, { item = "tungsten-carbide", amount = 1 }}))

addSRSettings(settingsPackage, "quality-productivity", 1, 1, defaultsOn1())
addSRSettings(settingsPackage, "quality-productivity", 2, 1, defaultsOn2(), {{ item = "sr-mom-quality-productivity-1-0", amount = 4 }})
addSRSettings(settingsPackage, "quality-productivity", 3, 2, concatItem(defaultsOn2(), {{ item = "sr-mom-quality-productivity-2-0", amount = 4 }, { item = "superconductor", amount = 1 }, { item = "biter-egg", amount = 1 }}))

addSRSettings(settingsPackage, "catalyst", 1, 1, defaultsOn1())
addSRSettings(settingsPackage, "catalyst", 2, 1, concatItem(defaultsOn2(), {{ item = "sr-mom-catalyst-1-0", amount = 4 }}))
addSRSettings(settingsPackage, "catalyst", 3, 1, concatItem(defaultsOn2(), {{ item = "sr-mom-catalyst-2-0", amount = 4 }, { item = "coal", amount = 10 }}), {{ fluid = "lubricant", amount = 25 }})

data:extend(settingsPackage)