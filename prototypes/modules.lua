
productivity1 = util.table.deepcopy(data.raw.module["productivity-module"])
productivity2 = util.table.deepcopy(data.raw.module["productivity-module-2"])
productivity3 = util.table.deepcopy(data.raw.module["productivity-module-3"])
speed1 = util.table.deepcopy(data.raw.module["speed-module"])
speed2 = util.table.deepcopy(data.raw.module["speed-module-2"])
speed3 = util.table.deepcopy(data.raw.module["speed-module-3"])
efficiency1 = util.table.deepcopy(data.raw.module["efficiency-module"])
efficiency2 = util.table.deepcopy(data.raw.module["efficiency-module-2"])
efficiency3 = util.table.deepcopy(data.raw.module["efficiency-module-3"])
minScaling = settings.startup["sr-mom-ramping-min-scaling"].value
maxScaling = settings.startup["sr-mom-ramping-max-scaling"].value
thresholdScaling = settings.startup["sr-mom-ramping-threshold-scaling"].value
coldScaling = settings.startup["sr-mom-ramping-cold-scaling"].value
hotScaling = settings.startup["sr-mom-ramping-hot-scaling"].value

local maxRamp = 10
local graphicsPath = "__sir-rolins-momentum-modules__/graphics/icons/"

-- Normalizes any icon input into an array of icon-layer-arrays.
-- Accepts: string, {icon=...} object, layer array, or an array of any of those.
local function normalizeIconStates(icons)
	if type(icons) ~= "table" then icons = { icons } end
	if icons[1] == nil then icons = { icons } end
	for i, ico in ipairs(icons) do
		if type(ico) == "string" then
			icons[i] = { { icon = ico, icon_size = 64 } }
		elseif ico.icon ~= nil then
			icons[i] = { ico }
		end
	end
	return icons
end

-- Returns a new module-like object whose effect table is base.effect with every
-- value multiplied by multiplier (e.g. -1 to invert an efficiency module's
-- consumption bonus into a consumption penalty).
local function scaleModuleEffect(base, multiplier)
	local scaled = { effect = {} }
	for k, v in pairs(base.effect) do
		scaled.effect[k] = v * multiplier
	end
	return scaled
end

-- Returns a new module-like object whose effect table is base.effect with the
-- given key dropped entirely (e.g. removing a speed module's quality malus).
local function withoutEffect(base, key)
	local stripped = { effect = {} }
	for k, v in pairs(base.effect) do
		if k ~= key then
			stripped.effect[k] = v
		end
	end
	return stripped
end

-- Returns a new module-like object whose effect table is base.effect with value
-- added onto the given key (e.g. adding a pollution effect a module didn't have).
local function withAddedEffect(base, key, value)
	local merged = { effect = {} }
	for k, v in pairs(base.effect) do
		merged.effect[k] = v
	end
	merged.effect[key] = (merged.effect[key] or 0) + value
	return merged
end

-- Averages the effect tables of one or more base modules into a single table.
local function averageModuleEffects(baseModules)
	local _mods = baseModules[1] ~= nil and baseModules or { baseModules }
	local effect = {}
	for _, base in pairs(_mods) do
		for k, v in pairs(base.effect) do
			effect[k] = (effect[k] or 0) + v / #_mods
		end
	end
	return effect
end

local function newModuleShell(name, cat, tier, i, icon)
	return {
		type = "module",
		name = string.format("sr-mom-%s-%s-%s", name, tier, i),
		order = string.format("sr-mom[%s]-a[%s]-a[%d]", cat, name, tier),
		localised_name = { "item-name." .. name .. "-module-" .. tier .. "-mom" },
		localised_description = { "item-description." .. name .. "-module-" .. tier .. "-mom", tostring(i) },
		icons = icon,
		subgroup = i == 0 and "module" or "",
		category = cat or "productivity",
		tier = tier,
		hidden = i > 0,
		hidden_in_factoriopedia = i > 0,
		stack_size = 50,
		effect = {}
	}
end

local function buildMod(name, cat, baseModules, tier, i, icon, effectScale)
	local mod = newModuleShell(name, cat, tier, i, icon)
	for k, v in pairs(averageModuleEffects(baseModules)) do
		mod.effect[k] = v * effectScale
	end
	return mod
end

-- Blends from coldProfile (i = 0) to hotProfile (i = maxRamp), unlike buildMod
-- which blends baseModules together at a fixed ratio and only scales magnitude.
-- coldScale and hotScale are independent so each end of the transition can be
-- tuned (or disabled, via coldScale = 0) without affecting the other.
local function buildTransitionMod(name, cat, coldProfile, hotProfile, tier, i, icon, coldScale, hotScale)
	local mod = newModuleShell(name, cat, tier, i, icon)
	local weight = i / maxRamp
	for k, v in pairs(averageModuleEffects(coldProfile)) do
		mod.effect[k] = (mod.effect[k] or 0) + v * (1 - weight) * coldScale
	end
	for k, v in pairs(averageModuleEffects(hotProfile)) do
		mod.effect[k] = (mod.effect[k] or 0) + v * weight * hotScale
	end
	return mod
end

-- Effects that recipes can selectively disallow (recipe.allowed_effects). A series
-- (all 11 stack tiers of one named module) must be uniformly accepted or rejected by
-- a given recipe -- if some tiers carry the effect and others don't, control.lua's
-- ramping can try to swap in a tier the current recipe disallows, silently failing
-- or ejecting the module. Forcing the key to exist (min the value) on every tier once any
-- tier has it keeps the whole series consistent.
local restrictedEffects = { productivity = 0.01, quality = 0.01 }

local function enforceEffectConsistency(package, startIndex)
	for key, value in pairs(restrictedEffects) do
		local sign = nil
		for i = startIndex, #package do
			local current = package[i].effect[key]
			if current and math.abs(current) >= value then
				sign = current < 0 and -1 or 1
				break
			end
		end
		if sign then
			local floor = value * sign
			for i = startIndex, #package do
				local current = package[i].effect[key]
				if current == nil then
					package[i].effect[key] = floor
				elseif math.abs(current) < value then
					package[i].effect[key] = current < 0 and -value or value
				end
			end
		end
	end
end

local function getTechnology(name, tier, tech, icons)
	return {
		type = "technology",
		name = string.format("sr-mom-%s-%s", name, tier),
		icons = icons,
		localised_name = { "technology-name." .. name .. "-module-" .. tier .. "-mom" },
		localised_description = { "technology-description." .. name .. "-module-" .. tier .. "-mom" },
		effects = {{ type = "unlock-recipe", recipe = string.format("sr-mom-%s-%s-0", name, tier) }},
		prerequisites = tech.prerequisites,
		unit = tech.unit,
		upgrade = true
	}
end

local function getRecipe(product, overrides, extras)
	local name = string.format("sr-mom-%s-%s-0", product.name, product.tier or 1)
	local settingPrefix = string.format("sr-mom-%s-%s-sr-", product.name, product.tier or 1)
	local recipe = {
		type = "recipe",
		name = name,
		main_product = name,
		category = mods["space-age"] and "electronics" or "crafting",
		order = string.format("sr-mom[%s]-a[%s]-a[%d]", product.category or "a", product.name, product.tier or 1),
		enabled = false,
		energy_required = 15 * 2 ^ ((product.tier or 1) - 1),
		icons = product.icons or { { icon = "__base__/graphics/icons/speed-module.png", icon_size = 32 } },
		allow_decomposition = true,
		auto_recycle = false,
		results = {{ 
			type = product.type or "item",
			name = name,
			amount = tonumber(settings.startup[settingPrefix .. "produces"] and settings.startup[settingPrefix .. "produces"].value or 1),
		}},
		ingredients = {}
	}
	for i = 1, 5 do
		local ingredient = ""
		if false == pcall(function()
			ingredient = settings.startup[settingPrefix .. i].value
		end) then
			error(settingPrefix .. i .. " doesn't exist in settings.lua", 3)
		end
		local amount = settings.startup[settingPrefix .. "amount-" .. i]
		if ingredient ~= nil and ingredient ~= "" then
			table.insert(recipe.ingredients, { type = "item", name = ingredient, amount = amount and amount.value or 1 })
		end
	end
	for i = 1, 3 do
		local ingredient = ""
		if false == pcall(function()
			ingredient = settings.startup[settingPrefix .. "fluid-" .. i].value
		end) then
			error(settingPrefix .. "fluid-" .. i .. " doesn't exist in settings.lua", 3)
		end
		local amount = settings.startup[settingPrefix .. "fluid-amount-" .. i]
		if ingredient ~= nil and ingredient ~= "" then
			table.insert(recipe.ingredients, { type = "fluid", name = ingredient, amount = amount and amount.value or 1 })
		end
	end
	if overrides then
		for k, v in pairs(overrides) do recipe[k] = v end
	end
	if extras then
		for k, v in pairs(extras) do table.insert(recipe[k], v) end
	end
	return recipe
end

local function SetupRampMod(package, baseName, cat, baseModules, tier, icons, tech)
	icons = normalizeIconStates(icons)
	local startIndex = #package + 1
	for i = 0, maxRamp do
		local icon = icons[math.min(math.floor(i / maxRamp * #icons) + 1, #icons)]
		table.insert(package, buildMod(baseName, cat, baseModules, tier, i, icon,
			(minScaling + (i / maxRamp) * (1 - minScaling)) * maxScaling))
	end
	enforceEffectConsistency(package, startIndex)
	table.insert(package, getRecipe({ name = baseName, tier = tier, icons = icons[1], category = cat }))
	if tech then table.insert(package, getTechnology(baseName, tier, tech, icons[1])) end
end

local function SetupThresholdMod(package, baseName, cat, baseModules, tier, icons, tech)
	icons = normalizeIconStates(icons)
	local startIndex = #package + 1
	for i = 0, maxRamp do
		local fullyStacked = i == maxRamp
		local icon = icons[fullyStacked and math.min(2, #icons) or 1]
		table.insert(package, buildMod(baseName, cat, fullyStacked and baseModules[2] or baseModules[1], tier, i, icon, thresholdScaling))
	end
	enforceEffectConsistency(package, startIndex)
	table.insert(package, getRecipe({ name = baseName, tier = tier, icons = icons[1], category = cat }))
	if tech then table.insert(package, getTechnology(baseName, tier, tech, icons[1])) end
end

local function SetupTransitionMod(package, baseName, cat, coldProfile, hotProfile, tier, icons, tech)
	icons = normalizeIconStates(icons)
	local startIndex = #package + 1
	for i = 0, maxRamp do
		local icon = icons[math.min(math.floor(i / maxRamp * #icons) + 1, #icons)]
		table.insert(package, buildTransitionMod(baseName, cat, coldProfile, hotProfile, tier, i, icon, coldScaling, hotScaling))
	end
	enforceEffectConsistency(package, startIndex)
	table.insert(package, getRecipe({ name = baseName, tier = tier, icons = icons[1], category = cat }))
	if tech then table.insert(package, getTechnology(baseName, tier, tech, icons[1])) end
end

local function getTintedIcons(tier, r, g, b, r2, g2, b2)
	assigned = (r2 or g2 or b2 or -1) >= 0
	r2 = r2 or r
	g2 = g2 or g
	b2 = b2 or b
	local function lights(r, g, b)
		if(assigned) then
			return { r = r, g = g, b = b, a = 1 }
		end
		local highlight = math.max(r, g, b)
		if(highlight == 0) then
			return { r = 1, g = 1, b = 1, a = 1}
		else
			return { r = math.min(r * 1.5 / highlight, 1.0), g = math.min(g * 1.5 / highlight, 1.0), b = math.min(b * 1.5 / highlight, 1.0), a = 1 }
		end
	end
	return {
		{
			{ icon = graphicsPath .. "tint-module-base.png",                   icon_size = 64, tint = { r = r, g = g, b = b, a = 1 } },
			{ icon = graphicsPath .. "tint-module-lights-" .. tier .. ".png",  icon_size = 64, tint = lights(r2, g2, b2) },
			{ icon = graphicsPath .. "tint-module-lights-" .. tier .. "-highlights.png",  icon_size = 64, tint = { r = 1, g = 1, b = 1, a = 0.75 } },
			{ icon = graphicsPath .. "tint-module-wires.png",                  icon_size = 64},
		}
	}
end


local package = {}

local unit1 = { count = 50,  ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}},                                                               time = 30 }
local unit2 = { count = 75,  ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}},                                 time = 30 }
local unit3 = { count = 300, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}}, time = 60 }

SetupRampMod(package, "turbo",   "speed", speed1, 1, getTintedIcons(1, 0.1, 0.7, 0.7, 0, 1, 1), { prerequisites = {"speed-module"},                     unit = unit1 })
SetupRampMod(package, "turbo",   "speed", speed2, 2, getTintedIcons(2, 0.1, 0.7, 0.7, 0, 1, 1), { prerequisites = {"sr-mom-turbo-1", "speed-module-2"}, unit = unit2 })
SetupRampMod(package, "turbo",   "speed", speed3, 3, getTintedIcons(3, 0.1, 0.7, 0.7, 0, 1, 1), { prerequisites = {"sr-mom-turbo-2", "speed-module-3"}, unit = unit3 })

local clean1 = withAddedEffect(scaleModuleEffect(withoutEffect(speed1, "quality"), 0.65), "pollution", -0.05)
local clean2 = withAddedEffect(scaleModuleEffect(withoutEffect(speed2, "quality"), 0.65), "pollution", -0.05)
local clean3 = withAddedEffect(scaleModuleEffect(withoutEffect(speed3, "quality"), 0.65), "pollution", -0.05)

SetupRampMod(package, "clean",   "speed", clean1, 1, getTintedIcons(1, 0.3, 0.75, 0.45, 0.6, 1.0, 0.75), { prerequisites = {"speed-module"},                    unit = unit1 })
SetupRampMod(package, "clean",   "speed", clean2, 2, getTintedIcons(2, 0.3, 0.75, 0.45, 0.6, 1.0, 0.75), { prerequisites = {"sr-mom-clean-1", "speed-module-2"}, unit = unit2 })
SetupRampMod(package, "clean",   "speed", clean3, 3, getTintedIcons(3, 0.3, 0.75, 0.45, 0.6, 1.0, 0.75), { prerequisites = {"sr-mom-clean-2", "speed-module-3"}, unit = unit3 })

SetupRampMod(package, "heat-up", "speed", { productivity1, speed1, efficiency1 }, 1, getTintedIcons(1, 0.7, 0.22, 0.05, 1.0, 1.0, 0.15), { prerequisites = {"speed-module", "productivity-module", "efficiency-module"},                            unit = { count = 50,  ingredients = {}, time = 30 } }) -- This one is special, no research costs
SetupRampMod(package, "heat-up", "speed", { productivity2, speed2, efficiency2 }, 2, getTintedIcons(2, 0.7, 0.22, 0.05, 1.0, 1.0, 0.15), { prerequisites = {"sr-mom-heat-up-1", "speed-module-2", "productivity-module-2", "efficiency-module-2"},  unit = { count = 75,  ingredients = {}, time = 30 } }) -- This one is special, no research costs
SetupRampMod(package, "heat-up", "speed", { productivity3, speed3, efficiency3 }, 3, getTintedIcons(3, 0.7, 0.22, 0.05, 1.0, 1.0, 0.15), { prerequisites = {"sr-mom-heat-up-2", "speed-module-3", "productivity-module-3", "efficiency-module-3"},  unit = { count = 300, ingredients = {}, time = 60 } }) -- This one is special, no research costs

SetupThresholdMod(package, "productivity-speed", "productivity", { productivity1, speed1 }, 1, { graphicsPath .. "productivity-speed.png",   "__base__/graphics/icons/speed-module.png"   }, { prerequisites = {"productivity-module"},                                  unit = unit1 })
SetupThresholdMod(package, "productivity-speed", "productivity", { productivity2, speed2 }, 2, { graphicsPath .. "productivity-speed-2.png", "__base__/graphics/icons/speed-module-2.png" }, { prerequisites = {"sr-mom-productivity-speed-1", "productivity-module-2"}, unit = unit2 })
SetupThresholdMod(package, "productivity-speed", "productivity", { productivity3, speed3 }, 3, { graphicsPath .. "productivity-speed-3.png", "__base__/graphics/icons/speed-module-3.png" }, { prerequisites = {"sr-mom-productivity-speed-2", "productivity-module-3"}, unit = unit3 })

SetupThresholdMod(package, "efficiency-speed", "efficiency", { efficiency1, speed1 }, 1, { graphicsPath .. "efficiency-speed.png",   "__base__/graphics/icons/speed-module.png"   }, { prerequisites = {"efficiency-module"},                                   unit = unit1 })
SetupThresholdMod(package, "efficiency-speed", "efficiency", { efficiency2, speed2 }, 2, { graphicsPath .. "efficiency-speed-2.png", "__base__/graphics/icons/speed-module-2.png" }, { prerequisites = {"sr-mom-efficiency-speed-1", "efficiency-module-2"},   unit = unit2 })
SetupThresholdMod(package, "efficiency-speed", "efficiency", { efficiency3, speed3 }, 3, { graphicsPath .. "efficiency-speed-3.png", "__base__/graphics/icons/speed-module-3.png" }, { prerequisites = {"sr-mom-efficiency-speed-2", "efficiency-module-3"},   unit = unit3 })

SetupTransitionMod(package, "catalyst", "efficiency", scaleModuleEffect(efficiency1, -1), { efficiency1, productivity1 }, 1, getTintedIcons(1, 0.15, 0.55, 0.65, 0.9, 0.5, 0.15), { prerequisites = {"efficiency-module", "productivity-module"},                          unit = unit1 })
SetupTransitionMod(package, "catalyst", "efficiency", scaleModuleEffect(efficiency2, -1), { efficiency2, productivity2 }, 2, getTintedIcons(2, 0.15, 0.55, 0.65, 0.9, 0.5, 0.15), { prerequisites = {"sr-mom-catalyst-1", "efficiency-module-2", "productivity-module-2"}, unit = unit2 })
SetupTransitionMod(package, "catalyst", "efficiency", scaleModuleEffect(efficiency3, -1), { efficiency3, productivity3 }, 3, getTintedIcons(3, 0.15, 0.55, 0.65, 0.9, 0.5, 0.15), { prerequisites = {"sr-mom-catalyst-2", "efficiency-module-3", "productivity-module-3"}, unit = unit3 })

if mods["quality"] then
	quality1 = util.table.deepcopy(data.raw.module["quality-module"])
	quality2 = util.table.deepcopy(data.raw.module["quality-module-2"])
	quality3 = util.table.deepcopy(data.raw.module["quality-module-3"])

	SetupThresholdMod(package, "quality-speed", "quality", { quality1, speed1 }, 1, { graphicsPath .. "quality-speed.png",   "__base__/graphics/icons/speed-module.png"   }, { icon = "__quality__/graphics/technology/quality-module-1.png", prerequisites = {"quality-module"},                                                    unit = unit1 })
	SetupThresholdMod(package, "quality-speed", "quality", { quality2, speed2 }, 2, { graphicsPath .. "quality-speed-2.png", "__base__/graphics/icons/speed-module-2.png" }, { icon = "__quality__/graphics/technology/quality-module-2.png", prerequisites = {"sr-mom-quality-speed-1", "quality-module-2"},                        unit = unit2 })
	SetupThresholdMod(package, "quality-speed", "quality", { quality3, speed3 }, 3, { graphicsPath .. "quality-speed-3.png", "__base__/graphics/icons/speed-module-3.png" }, { icon = "__quality__/graphics/technology/quality-module-3.png", prerequisites = {"sr-mom-quality-speed-2", "quality-module-3"},                        unit = unit3 })

	SetupThresholdMod(package, "quality-productivity", "quality", { quality1, productivity1 }, 1, { graphicsPath .. "quality-productivity.png"   }, { icon = "__quality__/graphics/technology/quality-module-1.png", prerequisites = {"quality-module", "productivity-module"},                             unit = unit1 })
	SetupThresholdMod(package, "quality-productivity", "quality", { quality2, productivity2 }, 2, { graphicsPath .. "quality-productivity-2.png" }, { icon = "__quality__/graphics/technology/quality-module-2.png", prerequisites = {"sr-mom-quality-productivity-1", "quality-module-2", "productivity-module-2"}, unit = unit2 })
	SetupThresholdMod(package, "quality-productivity", "quality", { quality3, productivity3 }, 3, { graphicsPath .. "quality-productivity-3.png" }, { icon = "__quality__/graphics/technology/quality-module-3.png", prerequisites = {"sr-mom-quality-productivity-2", "quality-module-3", "productivity-module-3"}, unit = unit3 })
end

data:extend(package)
