-- Workaround for the v50.x bug where Dwarf Fortress occasionally erase Dwarf's nicknames.
-- It happen when killing certain figures, such as forgotten beasts.
--@ enable = true
--@ module = true

local json = require('json')
local persist = require('persist-table')

local GLOBAL_KEY = 'fix-restore-nicks'

enabled = enabled or false

local function persist_state()
    persist.GlobalTable[GLOBAL_KEY] = json.encode({enabled=enabled})
end

local function nil_or_empty(s)
    return s == nil or s == ''
end

-- Store all the assigned nicknames in a persistent place
local function save_nicks()
    for _,unit in pairs(df.global.world.units.active) do
        local nickname = unit.name.nickname
        local hfid = unit.id
        if not nil_or_empty(nickname) then
            dfhack.persistent.save{key="nicknames/" .. hfid, value=nickname, ints = {hfid}}
        end
    end
end

-- Restore all the assigned nicknames from a persistent place
local function restore_nicks()
    for _,entry in pairs(dfhack.persistent.get_all("nicknames", true)) do
        local nickname = entry.value
        local hfid = entry.ints[1]

        local unit = df.unit.find(hfid)
        if nil_or_empty(unit.name.nickname) then
            print("fix/restore-nicks: Restoring removed nickname for " .. nickname)
            unit.name.nickname = nickname
        end
    end
end

-- Return the number of saved nicknames
local function count_stored_nicks()
    return #(dfhack.persistent.get_all("nicknames", true) or {})
end

-- Save all the assigned nicknames, and restore any that was removed
local function save_and_restore_nicks()
    save_nicks()
    restore_nicks()
end

-- Forget the saved nicknames
local function forget()
    for _,entry in pairs(dfhack.persistent.get_all("nicknames", true)) do
        dfhack.persistent.delete(entry.key)
    end
end

local function event_loop()
    if enabled then
        save_and_restore_nicks()
        dfhack.timeout(1, 'days', event_loop)
    end
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        enabled = false
        return
    end

    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end

    local persisted_data = json.decode(persist.GlobalTable[GLOBAL_KEY] or '')
    enabled = (persisted_data or {enabled=false})['enabled']
    event_loop()
end

if dfhack_flags.module then
    return
end

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    -- Possibly to review with adventure mode
    dfhack.printerr('fix/restore-nicks only works in fortress mode')
    return
end

local args = {...}
if dfhack_flags and dfhack_flags.enable then
    args = {dfhack_flags.enable_state and 'enable' or 'disable'}
end

if args[1] == "enable" then
    enabled = true
elseif args[1] == "disable" then
    enabled = false
elseif args[1] == "now" then
    print("Restoring and saving nicknames")
    save_and_restore_nicks()
    return
elseif args[1] == "forget" then
    print("Clearing all the saved nicknames")
    forget()
    return
else
    local enabled_str = enabled and "enabled" or "disabled"
    print("fix/restore-nicks is currently " .. enabled_str)
    print("There is " .. count_stored_nicks() .. " saved nickname(s).")
    return
end

event_loop()
persist_state()
