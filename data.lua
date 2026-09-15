-- Modules are defined by the addon mods using lib/momentum.lua.

-- Crafting menu tab for all momentum modules; lib/momentum.lua adds a row (subgroup) per module series.
-- Clean Modules creates the same tab when it's installed without this mod.
if not data.raw["item-group"]["sr-mom-modules"] then
    data:extend({
        {
            type = "item-group",
            name = "sr-mom-modules",
            order = "ca",
            icon = "__base__/graphics/icons/speed-module.png",
            icon_size = 64,
        },
    })
end

-- Move the modules from the module list (speed, productivity, ...) into the same tab, one row
-- per module list entry. The row order "<category>-" sorts before that category's momentum module
-- rows ("<category>-<series>"), so e.g. speed modules sit right above the speed momentum modules.
-- Clean Modules already made its own rows ("sr-mom-base-clean-<name>"), which are kept.
require("lib.module_list")
for _, module in pairs(getModuleList()) do
    local category = module.tier1.category
    local subgroupName = "sr-mom-base-" .. module.name
    if not data.raw["item-subgroup"][subgroupName] then
        data:extend({
            {
                type = "item-subgroup",
                name = subgroupName,
                group = "sr-mom-modules",
                order = category .. "-",
            },
        })
    end
    for tier = 1, 3 do
        local copy = module["tier" .. tier]
        if copy and data.raw.module[copy.name] then
            data.raw.module[copy.name].subgroup = subgroupName
        end
    end
end

--ass = data.raw["assembling-machine"]["assembling-machine-3"]
--ass.crafting_speed = ass.crafting_speed * 2
--data.extend({ass})
