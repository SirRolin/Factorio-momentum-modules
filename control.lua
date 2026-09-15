rampMode = nil
rampSpeed = 1

function on_tick(event)
    momentum_check(event)
end

function update_settings()
    script.on_nth_tick(
        60 * rampSpeed,
        nil
    )
    rampMode  = settings.global["sr-mom-ramping-mode"].value
    rampSpeed = settings.global["sr-mom-ramping-speed"].value
    script.on_nth_tick(
        60 * rampSpeed,
        on_tick
    )
end
update_settings()

-- machine.energy is the energy buffer, which only electric machines fill, and it's always 0
-- for machines without one (burner, heat or fluid powered). Those are counted as running
-- whenever they're crafting. energy_usage lives on the prototype, not the entity, and reading
-- an undefined property off an entity is an error rather than nil.
function is_running(machine)
    if not machine.is_crafting() then return false end
    local electric = machine.prototype.electric_energy_source_prototype
    return electric == nil or machine.energy > 0
end

function momentum_check(event)
    for _, surface in pairs(game.surfaces) do
        for _, machine in pairs(surface.find_entities_filtered({type = "assembling-machine"})) do
            if is_running(machine) then
                change_momentum_modules(machine, 1)
            else
                change_momentum_modules(machine, -1)
            end
        end -- for entities

        for _, furnace in pairs(surface.find_entities_filtered({type = "furnace"})) do
            if is_running(furnace) then
                change_momentum_modules(furnace, 1)
            else
                change_momentum_modules(furnace, -1)
            end
        end -- for furnaces and recyclers

        for _, beacon in pairs(surface.find_entities_filtered({type = "beacon"})) do
            if beacon.energy > 0 then
                change_momentum_modules(beacon, 1)
            else
                change_momentum_modules(beacon, -1)
            end
        end -- for beacons
    end -- for surfaces
end -- function

function change_momentum_modules(machine, momentum)
	local inv = machine.get_module_inventory()
	if inv then
        if rampMode == "all" then
            for i = 1, #inv do
                if inv[i].valid_for_read then
                    local basename, momvalue = inv[i].name:match("(sr%-mom%-.+%-)(%d+)$")
                    if basename and momvalue then
                        local stacks = tonumber(momvalue)
                        local before = stacks
                        if momentum > 0 then
                            stacks = math.min(10, stacks + 1)
                        else
                            stacks = math.max(0, stacks - 1)
                        end
                        if before - stacks ~= 0 then
                            inv[i].set_stack({name = basename .. stacks, count = inv[i].count, quality = inv[i].quality})
                        end
                    end
                end
            end
        elseif rampMode == "sequential" then
            local startInt = 1
            local endInt = #inv
            if momentum < 0 then
                startInt = #inv
                endInt = 1
            end
            for i = startInt, endInt do
                if inv[i].valid_for_read then
                    local basename, momvalue = inv[i].name:match("(sr%-mom%-.+%-)(%d+)$")
                    if basename and momvalue then
                        local stacks = tonumber(momvalue)
                        local before = stacks
                        local restCount = inv[i].count - 1
                        if momentum > 0 then
                            stacks = math.min(10, stacks + 1)
                        else
                            stacks = math.max(0, stacks - 1)
                        end
                        if before - stacks ~= 0 then
                            inv[i].set_stack({name = basename .. stacks, count = 1, quality = inv[i].quality})
                            if restCount > 0 then
                                inv.insert({name = basename .. before, count = restCount, quality = inv[i].quality})
                            end
                            break
                        end
                    end
                end
            end
        elseif rampMode == "balanced" or true then -- fallback
            local i = nil
            local basename = nil
            local momvalue = momentum > 0 and 10 or 0
            for finder = 1, #inv do
                if inv[finder].valid_for_read then
                    local _basename, _momvalue = inv[finder].name:match("(sr%-mom%-.+%-)(%d+)$")
                    if _momvalue and (
                            (momentum > 0 
                                and tonumber(_momvalue) < momvalue 
                                and tonumber(_momvalue) < 10
                            ) or (momentum < 0 
                                and tonumber(_momvalue) >= momvalue 
                                and tonumber(_momvalue) > 0
                            )
                        ) then
                        i = finder
                        basename = _basename
                        momvalue = tonumber(_momvalue)
                        --game.print(finder .. basename .. momvalue)
                    end
                end
            end
            if i and basename and momvalue then
                local stacks = tonumber(momvalue)
                local before = stacks
                local restCount = inv[i].count - 1
                if momentum > 0 then
                    stacks = math.min(10, stacks + 1)
                else
                    stacks = math.max(0, stacks - 1)
                end
                if before - stacks ~= 0 then
                    inv[i].set_stack({name = basename .. stacks, count = 1, quality = inv[i].quality})
                    if restCount > 0 then
                        inv.insert({name = basename .. before, count = restCount, quality = inv[i].quality})
                    end
                end
            end
        end -- rampmode
	end --if inv
end -- function

function get_momentum_of_item(machine)
    if machine == nil then return nil , 0 end
    if machine.type ~= "module" then return nil, 0 end
    local basename, momvalue = machine.name:match("(sr%-mom%-.+%-)(%d+)$")
    if basename and momvalue then
        return basename, tonumber(momvalue)
    end
    return nil, 0
end

-- making sure it plays nice with inventories and blueprints
function remove_momentum_inv(inventory)
	if inventory then
		for i = 1, #inventory do
            remove_momentum(inventory[i])
		end
	end
end

function remove_momentum(machine)
    if machine.valid_for_read then
        local basename, momvalue = get_momentum_of_item(machine);
        if basename and momvalue > 0 then
            machine.set_stack({name = basename .. "0", count = machine.count, quality = machine.quality})
        end
    end
end

script.on_event(defines.events.on_player_main_inventory_changed, function(event)
    local inventory = game.get_player(event.player_index).get_main_inventory()
    remove_momentum_inv(inventory)
end)

script.on_event(defines.events.on_player_mined_item, function(event)
    local machine = event.item_stack
    local basename, momvalue = get_momentum_of_item(machine)
    if basename and momvalue > 0 then
        local player = game.get_player(event.player_index)
        local count = machine.count
        local quality = machine.quality
        player.remove_item({name = machine.name, count = count, quality = quality})
        player.insert({name = basename .. "0", count = count, quality = quality})
    end
end)

script.on_event(defines.events.on_robot_pre_mined, function(event)
    local inventory = event.entity.get_module_inventory()
    remove_momentum_inv(inventory)
end)

script.on_event(defines.events.on_player_pipette, function(event)
    local basename, momvalue = get_momentum_of_item(event.machine)
    if basename and momvalue > 0 then
        local player = game.get_player(event.player_index)
        if player then
            local proto = prototypes.machine[basename .. "0"]
            player.pipette(proto, event.quality, true)
        end
    end
end)

script.on_event(defines.events.on_player_setup_blueprint, function(event)
    local blueprint = event.stack
    -- Retrieve the entities
    local entities = blueprint.get_blueprint_entities()
    local has_updated = false
    if entities then
        -- Iterate through all entities in the blueprint
        for _, machine in pairs(entities) do
            if machine and machine.items then
                for i, machine in pairs(machine.items) do
                    local basename, momvalue = get_momentum_of_item(machine.id)
                    if momvalue > 0 then
                        machine.id.name = basename .. "0"
                        has_updated = true
                    end
                end
            end
        end
        if has_updated then
            -- Update the machine's items with the modified items
            blueprint.set_blueprint_entities(entities)
        end
    end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
    if event.setting == "sr-mom-ramping-mode" or event.setting == "sr-mom-ramping-speed" then
        update_settings()
    end
end)

-- Warn players when the core is running without any addon that adds modules.
local addonMods = { "sir-rolins-momentum-turbo", "sir-rolins-momentum-threshold", "sir-rolins-momentum-catalytic" }
local warningColour = { r = 1, g = 0.8, b = 0.2 }

local function has_addon()
    for _, name in pairs(addonMods) do
        if script.active_mods[name] then return true end
    end
    return false
end

-- Printing straight from on_init/on_configuration_changed gets lost (no players yet,
-- or the game is still loading), so the warning is printed a couple of seconds later.
local function addon_warning_tick(event)
    if event.tick < storage.sr_mom_warn_at then return end
    storage.sr_mom_warn_at = nil
    script.on_event(defines.events.on_tick, nil)
    game.print({ "sr-mom-message.no-addons" }, { color = warningColour })
end

local function schedule_addon_warning()
    if has_addon() then return end
    storage.sr_mom_warn_at = game.tick + 120
    script.on_event(defines.events.on_tick, addon_warning_tick)
end

-- Factorio doesn't re-apply a technology's unlocks when a mod adds new ones to it,
-- so recipes added to already researched technologies (e.g. threshold modules added
-- to speed-module) have to be enabled by hand.
local function unlock_researched_recipes()
    for _, force in pairs(game.forces) do
        for _, tech in pairs(force.technologies) do
            if tech.researched then
                for _, effect in pairs(tech.prototype.effects) do
                    if effect.type == "unlock-recipe" and effect.recipe:find("^sr%-mom%-") then
                        force.recipes[effect.recipe].enabled = true
                    end
                end
            end
        end
    end
end

script.on_init(function()
    unlock_researched_recipes()
    schedule_addon_warning()
end)
script.on_configuration_changed(function()
    unlock_researched_recipes()
    schedule_addon_warning()
end)
script.on_load(function()
    if storage.sr_mom_warn_at then
        script.on_event(defines.events.on_tick, addon_warning_tick)
    end
end)

-- Players joining a multiplayer game later wouldn't have seen the message above.
script.on_event(defines.events.on_player_joined_game, function(event)
    if has_addon() or not game.is_multiplayer() then return end
    local player = game.get_player(event.player_index)
    if player then
        player.print({ "sr-mom-message.no-addons" }, { color = warningColour })
    end
end)


function test(obj, label)
    label = label or "object"
    game.print("Inspecting " .. label .. ":")

    local inspect_metatable
    local function inspect(o, depth, visited)
        depth = depth or 0
        visited = visited or {}
        local indent = string.rep("  ", depth)
        local t = type(o)

        if depth > 5 then
            game.print(indent .. "[depth limit reached]")
            return
        end

        if (t == "table" or t == "userdata") and visited[o] then
            game.print(indent .. "[circular reference]")
            return
        end
        if t == "table" or t == "userdata" then
            visited[o] = true
        end

        if t == "table" then
            game.print(indent .. "table {")
            for k, v in pairs(o) do
                game.print(indent .. "  " .. tostring(k) .. " = " .. type(v))
                inspect(v, depth + 1, visited)
            end
            local mt = getmetatable(o)
            if mt then
                inspect_metatable(mt, depth + 1, visited, "metatable")
            end
            game.print(indent .. "}")

        elseif t == "userdata" then
            game.print(indent .. "userdata: " .. tostring(o))
            local mt = getmetatable(o)
            if mt then
                inspect_metatable(mt, depth + 1, visited, "metatable")
            end

        elseif t == "function" then
            game.print(indent .. "function")
        elseif t == "string" then
            game.print(indent .. '"' .. o .. '"')
        elseif t == "number" then
            game.print(indent .. tostring(o))
        elseif t == "boolean" then
            game.print(indent .. tostring(o))
        elseif t == "nil" then
            game.print(indent .. "nil")
        else
            game.print(indent .. t .. ": " .. tostring(o))
        end
    end

    inspect_metatable = function(mt, depth, visited, label)
        local indent = string.rep("  ", depth)
        if not mt then
            return
        end
        if visited[mt] then
            game.print(indent .. label .. " [circular reference]")
            return
        end
        if type(mt) ~= "table" then
            game.print(indent .. label .. " = " .. type(mt) .. ": " .. tostring(mt))
            return
        end
        visited[mt] = true
        game.print(indent .. label .. " {")
        for k, v in pairs(mt) do
            if k == "__index" or k == "__newindex" then
                game.print(indent .. "  " .. tostring(k) .. " = " .. type(v))
                if type(v) == "table" then
                    inspect(v, depth + 2, visited)
                end
            else
                game.print(indent .. "  " .. tostring(k) .. " = " .. type(v))
            end
        end
        local index = mt.__index
        if type(index) == "table" and next(index) then
            game.print(indent .. "  __index table {")
            inspect(index, depth + 2, visited)
            game.print(indent .. "  }")
        elseif type(index) == "function" then
            game.print(indent .. "  __index = function")
        end
        game.print(indent .. "}")
    end

    inspect(obj, 0, {})
end

