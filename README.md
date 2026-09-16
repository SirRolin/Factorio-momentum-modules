# Momentum Modules

The core library for the Momentum Modules family of [Factorio](https://factorio.com) mods. It ramps
any `sr-mom` module up while its machine is running and back down while it sits idle, and provides
the shared module generation, recipe, technology and icon-tinting helpers the add-on mods build on.

**This mod adds no modules by itself.** Install one or more of the add-ons below to get something to
put in a machine — without them the mod logs a message saying so and does nothing else.

## Add-on mods

| Mod | What it adds |
| --- | --- |
| [Momentum Modules - Turbo](https://github.com/SirRolin/Factorio-momentum-turbo) | A Turbo version of every module type, plus Clean and Heat Up. Effects ramp from a minimum at 0 momentum to a maximum at 10. |
| [Momentum Modules - Catalytic](https://github.com/SirRolin/Factorio-momentum-catalytic) | Modules that start with weakened bonuses and end with weakened penalties as momentum builds. |
| [Momentum Modules - Threshold](https://github.com/SirRolin/Factorio-momentum-threshold) | Modules that switch from one effect to another at full momentum, e.g. Prod→Speed. |
| [Clean Modules](https://github.com/SirRolin/Factorio-clean-modules) | Standalone: vanilla modules without their maluses. Optional here — when present, its modules become available as bases for the momentum add-ons. |

## How momentum works

Every momentum module tracks a momentum value from 0 to 10. While its machine is working the value
climbs; while the machine is idle it falls. Each add-on interprets that value differently — Turbo
scales effects with it, Catalytic shifts the balance between bonus and penalty, Threshold flips
between two modules once it hits the top.

## Startup settings

| Setting | Description |
| --- | --- |
| Ramping Mode | **All** — every module ramps at once. **Sequential** — the leftmost module ramps up first and the rightmost ramps down first. **Balanced** — ramping and deramping are spread across the modules. |
| Ramping Rate | How many seconds between each update to modules. |
| Tier up recipe | Adds a second recipe for tier 2 and 3 momentum modules, made from the previous tier plus the rest of the normal upgrade cost, the way vanilla modules upgrade. **Refund** returns the extra ingredients that are no longer needed (fluid refunds need assembling machine 2 or better), **No refund** returns nothing, **Disabled** adds no such recipe. |

## Dependencies

- Factorio 2.0+
- Optional: Space Age, Quality, [Clean Modules](https://github.com/SirRolin/Factorio-clean-modules)

## For add-on authors

`lib/momentum.lua` is the public surface. The main entry points:

| Function | Purpose |
| --- | --- |
| `SetupRampMod(package, name, cat, baseModules, tier, icons, tech, scaling, options)` | Builds a module whose effects scale with momentum, plus its recipe and technology. |
| `SetupCatalyticMod(package, name, cat, baseModule, tier, icons, tech, reduction, options)` | Builds a module whose bonuses and penalties trade places as momentum builds. |
| `SetupThresholdMod(package, name, cat, baseModules, tier, icons, scaling, options)` | Builds a module that switches between two base modules at full momentum. |
| `getTintedIcons(tier, r, g, b, r2, g2, b2)` | Generates a tinted module icon set. |
| `getSplitTintedIcons(tier, left, right, leftLight, rightLight)` | Generates a two-tone icon, used for threshold modules. |
| `categoryName(category)` | The localised name for a module category. |
| `scaleModuleEffect` / `withoutEffect` / `withAddedEffect` / `isMalus` | Helpers for manipulating module effect tables. |

`lib/module_list.lua` exposes `getModuleList()`, the list of module families to generate from, which
skips any whose source mod isn't installed. `lib/settings.lua` exposes `addRecipeSettings(package,
key, label, defaults)` so each add-on gets a consistent set of per-mod recipe ingredient settings.

## Installation

Clone or copy this folder into your Factorio `mods` directory as
`sir-rolins-momentum-modules_<version>`, or install it from the in-game mod portal.
