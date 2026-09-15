-- Recipe settings for each module family live in the addon mods
-- (sir-rolins-momentum-turbo, sir-rolins-momentum-threshold), built with lib/settings.lua.

data:extend({
    {
        type = "string-setting",
        name = "sr-mom-ramping-mode",
        setting_type = "runtime-global",
        default_value = "sequential",
        allowed_values = {"all", "sequential", "balanced"}
    },
    {
        type = "int-setting",
        name = "sr-mom-ramping-speed",
        setting_type = "runtime-global",
        default_value = 3,
        minimum_value = 1,
        maximum_value = 60
    },
    {
        type = "string-setting",
        name = "sr-mom-tier-up-recipe",
        setting_type = "startup",
        default_value = "refund",
        allowed_values = {"refund", "no-refund", "disabled"},
    }
})
