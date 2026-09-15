function getModuleList() 
  local modules = {}

  -- family groups modules that belong together (vanilla, clean, ...). Mods that combine two
  -- modules (e.g. threshold) only combine modules of the same family, which also keeps the
  -- number of combinations down. Defaults to "base".
  local function add(module, family)
    -- Skips modules from mods that aren't installed (e.g. quality modules without the quality mod).
    if module.tier1 then
      module.family = family or "base"
      table.insert(modules, module)
    end
  end

  add(_get_module("speed",        "speed-module",        { r = 0.45, g = 0.65, b = 1.0 },  { r = 0.45, g = 0.65, b = 1.0 }))
  add(_get_module("productivity", "productivity-module", { r = 1.0,  g = 0.45, b = 0.1 },  { r = 1.0, g = 0.6,  b = 0.2 }))
  add(_get_module("efficiency",   "efficiency-module",   { r = 0.3,  g = 0.85, b = 0.3 },  { r = 0.3, g = 0.85,  b = 0.3 }))
  add(_get_module("quality",      "quality-module",      { r = 0.9, g = 0.9, b = 0.9 }, { r = 1.0, g = 0.0, b = 0.0 }))

  -- Clean Modules (optional mod): sr-clean-<name>-module, -2, -3.
  if mods["sir-rolins-clean-modules"] then
    add(_get_module("clean-speed",        "sr-clean-speed-module",        { r = 0.6,  g = 0.75, b = 1.0 },  { r = 0.8, g = 0.9,  b = 1.0 }),  "clean")
    add(_get_module("clean-productivity", "sr-clean-productivity-module", { r = 1.0,  g = 0.6,  b = 0.35 }, { r = 1.0, g = 0.8,  b = 0.5 }),  "clean")
    add(_get_module("clean-efficiency",   "sr-clean-efficiency-module",   { r = 0.5,  g = 0.9,  b = 0.5 },  { r = 0.7, g = 1.0,  b = 0.7 }),  "clean")
    add(_get_module("clean-quality",      "sr-clean-quality-module",      { r = 1.0,  g = 1.0,  b = 1.0 },  { r = 1.0, g = 0.4,  b = 0.4 }),  "clean")
  end

  return modules
end

-- effectName is the name that's going to be used.
-- baseName is the name the game knows it as.
-- baseColour is the tint that it is approximated.
-- lightColour is the tint for the lights colour.
-- tier2 (optional) is if the tier2 module doesn't have the same naming scheme as vanilla. Probably never gonna be used. Set to 0 to skip.
-- tier3 (optional) same as tier 2.
function _get_module(effectName, baseName, baseColour, lightColour, tier2, tier3)
  return {
    name = effectName,
    tier1 = util.table.deepcopy(data.raw.module[baseName]),
    tier2 = tier2 ~= 0 and util.table.deepcopy(data.raw.module[tier2 or baseName .. "-2"]) or nil,
    tier3 = tier3 ~= 0 and util.table.deepcopy(data.raw.module[tier3 or baseName .. "-3"]) or nil,
    baseColour = baseColour,
    lightColour = lightColour,
  }
end