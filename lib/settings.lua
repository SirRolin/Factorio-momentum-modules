-- Shared settings-stage library for momentum module addons.
-- Usage from another mod's settings.lua:
--   local momentumSettings = require("__sir-rolins-momentum-modules__/lib/settings")

local momentumSettings = {}

-- Adds a sub mod's shared recipe settings: 2 extra items and 1 fluid (each with an
-- amount), used by every module of that sub mod on top of its base module(s).
-- defaults (optional) = { items = { { item =, amount = }, { item =, amount = } }, fluid = { fluid =, amount = } }
function momentumSettings.addRecipeSettings(package, subMod, displayName, defaults)
    defaults = defaults or {}
    local items = defaults.items or {}
    local fluid = defaults.fluid or {}
    local prefix = "sr-mom-" .. subMod .. "-recipe-"

    for i = 1, 2 do
        table.insert(package, {
            type = "string-setting",
            name = prefix .. "item-" .. i,
            setting_type = "startup",
            allow_blank = true,
            order = string.format("a-recipe-%d-a", i),
            default_value = items[i] and items[i].item or "",
            localised_name = { "mod-setting-name.sr-mom-recipe-item", displayName, tostring(i) },
            localised_description = { "mod-setting-description.sr-mom-recipe-item", displayName },
        })
        table.insert(package, {
            type = "int-setting",
            name = prefix .. "amount-" .. i,
            setting_type = "startup",
            order = string.format("a-recipe-%d-b", i),
            default_value = items[i] and items[i].amount or 1,
            minimum_value = 1,
            localised_name = { "mod-setting-name.sr-mom-recipe-amount", displayName, tostring(i) },
        })
    end

    table.insert(package, {
        type = "string-setting",
        name = prefix .. "fluid",
        setting_type = "startup",
        allow_blank = true,
        order = "a-recipe-3-a",
        default_value = fluid.fluid or "",
        localised_name = { "mod-setting-name.sr-mom-recipe-fluid", displayName },
        localised_description = { "mod-setting-description.sr-mom-recipe-fluid", displayName },
    })
    table.insert(package, {
        type = "int-setting",
        name = prefix .. "fluid-amount",
        setting_type = "startup",
        order = "a-recipe-3-b",
        default_value = fluid.amount or 25,
        minimum_value = 1,
        localised_name = { "mod-setting-name.sr-mom-recipe-fluid-amount", displayName },
    })
end

return momentumSettings
