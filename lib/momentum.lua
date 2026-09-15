-- Shared data-stage library for momentum module addons.
-- Usage from another mod's data.lua:
--   local momentum = require("__sir-rolins-momentum-modules__/lib/momentum")

local momentum = {}

local maxRamp = 10
momentum.maxRamp = maxRamp
momentum.graphicsPath = "__sir-rolins-momentum-modules__/graphics/icons/"

momentum.unit1 = { count = 10,  ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}},                                                               time = 30 }
momentum.unit2 = { count = 25,  ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}},                                 time = 30 }
momentum.unit3 = { count = 50, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}}, time = 60 }

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
function momentum.scaleModuleEffect(base, multiplier)
	local scaled = { effect = {} }
	for k, v in pairs(base.effect) do
		scaled.effect[k] = v * multiplier
	end
	return scaled
end

-- Returns a new module-like object whose effect table is base.effect with the
-- given key dropped entirely (e.g. removing a speed module's quality malus).
function momentum.withoutEffect(base, key)
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
function momentum.withAddedEffect(base, key, value)
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

-- Every module series (all tiers of e.g. speed-turbo) gets its own row in the core mod's
-- "sr-mom-modules" crafting tab. Adds the subgroup to package the first time it's needed.
local function addSubgroup(package, name, cat)
	local subgroupName = "sr-mom-" .. name
	if data.raw["item-subgroup"][subgroupName] then return end
	for _, prototype in pairs(package) do
		if prototype.type == "item-subgroup" and prototype.name == subgroupName then return end
	end
	table.insert(package, {
		type = "item-subgroup",
		name = subgroupName,
		group = "sr-mom-modules",
		order = string.format("%s-%s", cat or "a", name),
	})
end

-- names (optional) = { name = <localised string>, description = function(i) return <localised string> end }
-- Without it, the per-module locale keys item-name.<name>-module-<tier>-mom are used.
local function newModuleShell(name, cat, tier, i, icon, names, subgroup)
	return {
		type = "module",
		name = string.format("sr-mom-%s-%s-%s", name, tier, i),
		order = string.format("sr-mom[%s]-a[%s]-a[%d]", cat, name, tier),
		localised_name = names and names.name or { "item-name." .. name .. "-module-" .. tier .. "-mom" },
		localised_description = names and names.description(i) or { "item-description." .. name .. "-module-" .. tier .. "-mom", tostring(i) },
		icons = icon,
		subgroup = "sr-mom-" .. (subgroup or name),
		category = cat or "productivity",
		tier = tier,
		hidden = i > 0,
		hidden_in_factoriopedia = i > 0,
		stack_size = 50,
		effect = {}
	}
end

local function buildMod(name, cat, baseModules, tier, i, icon, effectScale, names, subgroup)
	local mod = newModuleShell(name, cat, tier, i, icon, names, subgroup)
	for k, v in pairs(averageModuleEffects(baseModules)) do
		mod.effect[k] = v * effectScale
	end
	return mod
end

-- Positive consumption/pollution and negative everything else are maluses.
function momentum.isMalus(key, value)
	if key == "consumption" or key == "pollution" then
		return value > 0
	end
	return value < 0
end

-- See SetupCatalyticMod: positives go from reduction to full strength, maluses from full
-- strength to reduction, as momentum i goes from 0 to maxRamp.
local function buildCatalyticMod(name, cat, baseModule, tier, i, icon, reduction, names, subgroup)
	local mod = newModuleShell(name, cat, tier, i, icon, names, subgroup)
	local weight = i / maxRamp
	for k, v in pairs(baseModule.effect) do
		if momentum.isMalus(k, v) then
			mod.effect[k] = v * (1 - (1 - reduction) * weight)
		else
			mod.effect[k] = v * (reduction + (1 - reduction) * weight)
		end
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

-- Order the effects are listed in, matching the vanilla module tooltip.
local effectOrder = { "consumption", "speed", "productivity", "pollution", "quality" }

-- Percent shown per 1.0 of an effect value: effects are fractions (0.2 = +20%), but the game
-- multiplies quality by the current quality's next_probability (0.1 for normal quality, so
-- quality module 1's quality = 0.1 shows +1%). Read from the normal quality prototype so a mod
-- changing it is followed; read when used, since other mods may change it after this file loads.
local function effectPercentScale(key)
	if key == "quality" then
		local normal = data.raw.quality and data.raw.quality.normal
		return 100 * (normal and normal.next_probability or 0.1)
	end
	return 100
end

-- Adds the effects of the fully ramped module (momentum 10) to the momentum 0 module's
-- description, since its tooltip only shows its own (weakest) effects.
-- Rounded to one decimal, dropping ".0" (e.g. +54%, +2.5%).
local function describeMaxEffects(package, startIndex)
	local zero = package[startIndex]
	local full = package[startIndex + maxRamp]
	local lines = { "", { "sr-mom-effect.max-momentum", tostring(maxRamp) } }
	for _, key in ipairs(effectOrder) do
		local value = full.effect[key]
		if value then
			local tenths = value * effectPercentScale(key) * 10
			tenths = tenths >= 0 and math.floor(tenths + 0.5) or -math.floor(-tenths + 0.5)
			if tenths ~= 0 then
				local text = tenths % 10 == 0
					and string.format("%+d%%", tenths / 10)
					or  string.format("%+.1f%%", tenths / 10)
				table.insert(lines, { "", "\n", { "sr-mom-effect." .. key, text } })
			end
		end
	end
	zero.localised_description = { "", zero.localised_description, "\n", lines }
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

local unlockWithModules -- defined further down, next to findUnlockTechnologies

-- A list of ingredients/products where adding the same name twice adds up the amounts
-- (Factorio doesn't allow duplicate ingredients).
local function newItemList()
	local list, byName = {}, {}
	local function add(type, name, amount)
		if byName[name] then
			byName[name].amount = byName[name].amount + amount
		else
			byName[name] = { type = type, name = name, amount = amount }
			table.insert(list, byName[name])
		end
	end
	return list, add
end

local function hasFluid(list)
	for _, entry in pairs(list) do
		if entry.type == "fluid" then return true end
	end
	return false
end

-- Normal recipe category; fluid ingredients need a machine with a fluid input.
local function recipeCategory(withFluid)
	if mods["space-age"] then
		return withFluid and "electronics-with-fluid" or "electronics"
	end
	return withFluid and "crafting-with-fluid" or "crafting"
end

-- The sub mod's extra ingredients from its shared recipe settings, as { type, name, amount } entries.
local function getRecipeExtras(subMod)
	local prefix = "sr-mom-" .. subMod .. "-recipe-"
	local extras = {}
	for i = 1, 2 do
		local item = settings.startup[prefix .. "item-" .. i].value
		if item ~= "" then
			table.insert(extras, { type = "item", name = item, amount = settings.startup[prefix .. "amount-" .. i].value })
		end
	end
	local fluid = settings.startup[prefix .. "fluid"].value
	if fluid ~= "" then
		table.insert(extras, { type = "fluid", name = fluid, amount = settings.startup[prefix .. "fluid-amount"].value })
	end
	return extras
end

-- Recipe for modules built from real base modules, using a sub mod's shared recipe
-- settings (see addRecipeSettings in lib/settings.lua).
-- Ingredients: one of each base module + the sub mod's extra items and fluid.
-- Produces one module per base module used.
local function getGeneralRecipe(name, cat, tier, icons, baseModules, subMod)
	local recipeName = string.format("sr-mom-%s-%s-0", name, tier)
	local ingredients, addIngredient = newItemList()
	for _, base in pairs(baseModules) do
		addIngredient("item", base.name, 1)
	end
	for _, extra in pairs(getRecipeExtras(subMod)) do
		addIngredient(extra.type, extra.name, extra.amount)
	end

	return {
		type = "recipe",
		name = recipeName,
		main_product = recipeName,
		category = recipeCategory(hasFluid(ingredients)),
		order = string.format("sr-mom[%s]-a[%s]-a[%d]", cat, name, tier),
		enabled = false,
		energy_required = 15 * 2 ^ (tier - 1),
		icons = icons,
		allow_decomposition = true,
		auto_recycle = false,
		results = {{ type = "item", name = recipeName, amount = #baseModules }},
		ingredients = ingredients,
	}
end

-- Finds the recipe that upgrades module from the previous tier (e.g. speed-module-2 from
-- 4 speed-module). Returns recipe, previous tier module, how many of it the recipe uses.
local function findUpgradeRecipe(module)
	local function check(recipe)
		if not recipe or recipe.category == "recycling" then return end
		local produces = false
		for _, result in pairs(recipe.results or {}) do
			if result.name == module.name and result.amount == 1 then produces = true end
		end
		if not produces then return end
		for _, ingredient in pairs(recipe.ingredients or {}) do
			local previous = data.raw.module[ingredient.name]
			if previous and previous.category == module.category and previous.tier == module.tier - 1 then
				return recipe, previous, ingredient.amount
			end
		end
	end
	local recipe, previous, count = check(data.raw.recipe[module.name])
	if recipe then return recipe, previous, count end
	for _, candidate in pairs(data.raw.recipe) do
		recipe, previous, count = check(candidate)
		if recipe then return recipe, previous, count end
	end
end

local function findInPackage(package, name)
	for _, prototype in pairs(package) do
		if prototype.name == name and prototype.type == "module" then return prototype end
	end
end

-- Tier up recipe (setting sr-mom-tier-up-recipe): upgrades previous tier momentum modules
-- the same way the base modules upgrade, e.g. speed-turbo-2 from 4 speed-turbo-1 + the rest
-- of the speed-module-2 recipe (advanced circuits and processing units).
-- Modules made from several base modules pay the upgrade cost of every one of them, and like
-- their normal recipe make #modules at a time, e.g. heat-up-2: 12 heat-up-1 + the productivity,
-- speed and efficiency module 2 upgrade costs = 3 heat-up-2.
-- The previous tier modules already contain extras, so "refund" returns the ones that
-- aren't needed for the new modules (fluids included).
-- Returns nil when there's nothing to upgrade from (tier 1, or unknown upgrade recipes).
local function getTierUpRecipe(package, name, cat, tier, icons, modules, subMod)
	local mode = settings.startup["sr-mom-tier-up-recipe"].value
	if mode == "disabled" or tier < 2 then return end
	local previousName = string.format("sr-mom-%s-%s-0", name, tier - 1)
	if not findInPackage(package, previousName) then return end

	-- For every base module: the rest of its upgrade recipe, and how many of the previous tier it uses.
	local ingredients, addIngredient = newItemList()
	local count = 0
	for _, module in pairs(modules) do
		local recipe, previous, previousCount = findUpgradeRecipe(module)
		if not recipe then return end
		count = math.max(count, previousCount)
		for _, ingredient in pairs(recipe.ingredients) do
			if ingredient.name ~= previous.name then
				addIngredient(ingredient.type or "item", ingredient.name, ingredient.amount)
			end
		end
	end

	-- #modules * count previous modules hold count sets of extras (one set makes #modules
	-- modules), and the #modules new modules need 1 set, so count - 1 sets are refunded.
	-- Everything stays whole numbers.
	local moduleName = string.format("sr-mom-%s-%s-0", name, tier)
	local results = {{ type = "item", name = moduleName, amount = #modules }}
	if mode == "refund" then
		for _, extra in pairs(getRecipeExtras(subMod)) do
			if count > 1 then
				table.insert(results, { type = extra.type, name = extra.name, amount = extra.amount * (count - 1) })
			end
		end
	end

	local allIngredients = {{ type = "item", name = previousName, amount = #modules * count }}
	for _, ingredient in pairs(ingredients) do table.insert(allIngredients, ingredient) end

	-- Fluid products need a machine with a fluid output: assembling machine 2 and up.
	local category = hasFluid(results) and "crafting-with-fluid" or recipeCategory(hasFluid(allIngredients))
	local module = findInPackage(package, moduleName)

	return {
		type = "recipe",
		name = string.format("sr-mom-%s-%s-tier-up", name, tier),
		localised_name = { "sr-mom-name.tier-up-recipe", module.localised_name },
		main_product = moduleName,
		category = category,
		order = string.format("sr-mom[%s]-a[%s]-a[%d]-b", cat, name, tier),
		enabled = false,
		energy_required = 15 * 2 ^ (tier - 1),
		icons = icons,
		allow_decomposition = false,
		auto_recycle = false,
		results = results,
		ingredients = allIngredients,
	}
end

-- Adds the recipe (and technology, if tech is given) for a module series, using the
-- options.recipeSettings sub mod's shared recipe settings, made from recipeModules
-- (real module prototypes). Without tech, the recipe is unlocked by the research of
-- those modules instead.
local function addRecipe(package, baseName, cat, tier, icon, recipeModules, tech, options)
	if options.recipe == false then return end
	if not options.recipeSettings then
		error("sr-mom-" .. baseName .. "-" .. tier .. ": options.recipeSettings (the sub mod's recipe settings name) is required, or recipe = false", 3)
	end

	local modules = options.recipeModules or recipeModules
	modules = modules[1] ~= nil and modules or { modules }
	local recipe = getGeneralRecipe(baseName, cat, tier, icon, modules, options.recipeSettings)
	local tierUp = getTierUpRecipe(package, baseName, cat, tier, icon, modules, options.recipeSettings)
	if tech then
		local technology = getTechnology(baseName, tier, tech, icon)
		if tierUp then
			table.insert(technology.effects, { type = "unlock-recipe", recipe = tierUp.name })
		end
		table.insert(package, technology)
	else
		local moduleNames = {}
		for _, module in pairs(modules) do table.insert(moduleNames, module.name) end
		unlockWithModules(recipe, moduleNames)
		if tierUp then unlockWithModules(tierUp, moduleNames) end
	end
	table.insert(package, recipe)
	if tierUp then table.insert(package, tierUp) end
end

-- scaling = { min = <strength at 0 momentum>, max = <strength at full momentum> }
-- options (optional):
--   names          = see newModuleShell
--   recipe         = false to only create the modules (no recipe or technology)
--   recipeSettings = sub mod name; uses its shared recipe settings (see addRecipe)
--   subgroup       = share a crafting tab row with other series (e.g. both directions of a
--                    threshold pair), instead of one row per series name
--   recipeModules  = modules the recipe is made from, when baseModules aren't real
--                    modules (e.g. clean's modified speed effects). Defaults to baseModules.
function momentum.SetupRampMod(package, baseName, cat, baseModules, tier, icons, tech, scaling, options)
	options = options or {}
	icons = normalizeIconStates(icons)
	addSubgroup(package, options.subgroup or baseName, cat)
	local startIndex = #package + 1
	for i = 0, maxRamp do
		local icon = icons[math.min(math.floor(i / maxRamp * #icons) + 1, #icons)]
		table.insert(package, buildMod(baseName, cat, baseModules, tier, i, icon,
			(scaling.min + (i / maxRamp) * (1 - scaling.min)) * scaling.max, options.names, options.subgroup))
	end
	enforceEffectConsistency(package, startIndex)
	describeMaxEffects(package, startIndex)
	addRecipe(package, baseName, cat, tier, icons[1], baseModules, tech, options)
end

-- Localised name of a module category, e.g. "Speed". Categories from other mods
-- without an sr-mom-category entry fall back to the raw category name.
function momentum.categoryName(category)
	return { "?", { "sr-mom-category." .. category }, category }
end

-- Returns the names of every technology that unlocks a recipe producing itemName.
local function findUnlockTechnologies(itemName)
	local recipes = {}
	for recipeName, recipe in pairs(data.raw.recipe) do
		if recipe.category ~= "recycling" then
			for _, result in pairs(recipe.results or {}) do
				if result.name == itemName then
					recipes[recipeName] = true
				end
			end
		end
	end
	local technologies = {}
	for techName, tech in pairs(data.raw.technology) do
		for _, effect in pairs(tech.effects or {}) do
			if effect.type == "unlock-recipe" and recipes[effect.recipe] then
				table.insert(technologies, techName)
				break
			end
		end
	end
	return technologies
end

-- Adds recipe's unlock to every technology that unlocks one of the given modules,
-- so researching any of them unlocks it. If none of the modules need research
-- (they're available from the start), the recipe is enabled from the start too.
function unlockWithModules(recipe, moduleNames)
	local added = {}
	for _, moduleName in pairs(moduleNames) do
		for _, techName in pairs(findUnlockTechnologies(moduleName)) do
			if not added[techName] then
				added[techName] = true
				local tech = data.raw.technology[techName]
				tech.effects = tech.effects or {}
				table.insert(tech.effects, { type = "unlock-recipe", recipe = recipe.name })
			end
		end
	end
	if next(added) == nil then
		recipe.enabled = true
	end
end

-- scaling = number, the strength of both the before and after threshold effects
-- Unlocked by the research of either base module rather than a technology of its own.
-- options: same as SetupRampMod. Without options.names, the two base modules' categories name it.
function momentum.SetupThresholdMod(package, baseName, cat, baseModules, tier, icons, scaling, options)
	options = options or {}
	icons = normalizeIconStates(icons)
	local names = options.names
	if not names then
		local before = momentum.categoryName(baseModules[1].category)
		local after = momentum.categoryName(baseModules[2].category)
		names = {
			name = tier == 1
				and { "sr-mom-name.threshold", before, after }
				or  { "sr-mom-name.threshold-tier", before, after, tostring(tier) },
			description = function(i) return { "sr-mom-description.threshold", before, after, tostring(i) } end,
		}
	end
	addSubgroup(package, options.subgroup or baseName, cat)
	local startIndex = #package + 1
	for i = 0, maxRamp do
		local fullyStacked = i == maxRamp
		local icon = icons[fullyStacked and math.min(2, #icons) or 1]
		table.insert(package, buildMod(baseName, cat, fullyStacked and baseModules[2] or baseModules[1], tier, i, icon, scaling, names, options.subgroup))
	end
	enforceEffectConsistency(package, startIndex)
	addRecipe(package, baseName, cat, tier, icons[1], baseModules, nil, options)
end

-- Catalytic module: the base module's own effects, but at momentum 0 its positive effects
-- are multiplied by reduction, and by momentum 10 its negative effects are instead.
-- In between, positives grow from reduction to full strength while negatives shrink from
-- full strength to reduction.
-- reduction = number (e.g. 0.5); options: same as SetupRampMod.
function momentum.SetupCatalyticMod(package, baseName, cat, baseModule, tier, icons, tech, reduction, options)
	options = options or {}
	icons = normalizeIconStates(icons)
	addSubgroup(package, options.subgroup or baseName, cat)
	local startIndex = #package + 1
	for i = 0, maxRamp do
		local icon = icons[math.min(math.floor(i / maxRamp * #icons) + 1, #icons)]
		table.insert(package, buildCatalyticMod(baseName, cat, baseModule, tier, i, icon, reduction, options.names, options.subgroup))
	end
	enforceEffectConsistency(package, startIndex)
	describeMaxEffects(package, startIndex)
	addRecipe(package, baseName, cat, tier, icons[1], baseModule, tech, options)
end

function momentum.getTintedIcons(tier, r, g, b, r2, g2, b2)
	local assigned = (r2 or g2 or b2 or -1) >= 0
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
	local graphicsPath = momentum.graphicsPath
	return {
		{
			{ icon = graphicsPath .. "tint-module-base.png",                   icon_size = 64, tint = { r = r, g = g, b = b, a = 1 } },
			{ icon = graphicsPath .. "tint-module-lights-" .. tier .. ".png",  icon_size = 64, tint = lights(r2, g2, b2) },
			{ icon = graphicsPath .. "tint-module-lights-" .. tier .. "-highlights.png",  icon_size = 64, tint = { r = 1, g = 1, b = 1, a = 0.75 } },
			{ icon = graphicsPath .. "tint-module-wires.png",                  icon_size = 64},
		}
	}
end

-- Two-colour icon for modules combining two effects: the left half tinted with
-- leftColour and the right half with rightColour ({ r =, g =, b = } tables).
-- Returns two icon states whose lights glow in leftLight and rightLight, so a threshold
-- module's lights switch colour when it reaches full momentum. Without light colours,
-- brightened versions of leftColour and rightColour are used.
function momentum.getSplitTintedIcons(tier, leftColour, rightColour, leftLight, rightLight)
	local function tint(c) return { r = c.r, g = c.g, b = c.b, a = 1 } end
	local function lights(c, given)
		if given then return tint(given) end
		local highlight = math.max(c.r, c.g, c.b)
		if highlight == 0 then
			return { r = 1, g = 1, b = 1, a = 1 }
		end
		return { r = math.min(c.r * 1.5 / highlight, 1.0), g = math.min(c.g * 1.5 / highlight, 1.0), b = math.min(c.b * 1.5 / highlight, 1.0), a = 1 }
	end
	local average = { r = (leftColour.r + rightColour.r) / 2, g = (leftColour.g + rightColour.g) / 2, b = (leftColour.b + rightColour.b) / 2 }
	local graphicsPath = momentum.graphicsPath
	local function state(lightTint)
		return {
			-- base underneath covers the outer rim the two halves leave out
			{ icon = graphicsPath .. "tint-module-base.png",                              icon_size = 64, tint = tint(average) },
			{ icon = graphicsPath .. "tint-bi-left.png",                                  icon_size = 64, tint = tint(leftColour) },
			{ icon = graphicsPath .. "tint-bi-right.png",                                 icon_size = 64, tint = tint(rightColour) },
			{ icon = graphicsPath .. "tint-module-lights-" .. tier .. ".png",             icon_size = 64, tint = lightTint },
			{ icon = graphicsPath .. "tint-module-lights-" .. tier .. "-highlights.png",  icon_size = 64, tint = { r = 1, g = 1, b = 1, a = 0.75 } },
			{ icon = graphicsPath .. "tint-module-wires.png",                             icon_size = 64 },
		}
	end
	return { state(lights(leftColour, leftLight)), state(lights(rightColour, rightLight)) }
end

return momentum
