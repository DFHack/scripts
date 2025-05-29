-- Adjusts dwarves' skills when embarking

function err(msg)
    qerror(msg)
end

function adjust(dwarves, callback)
    for _, dwf in pairs(dwarves) do
        callback(dwf)
    end
end

local scr = dfhack.gui.getCurViewscreen() --as:df.viewscreen_setupdwarfgamest
if not dfhack.gui.matchFocusString('setupdwarfgame/Dwarves', scr) then
    qerror('Must be called on the "Prepare carefully" screen, "Dwarves" tab')
end

local dwarf_info = scr.dwarf_info
local dwarves = dwarf_info
local selected_dwarf = {[0] = scr.dwarf_info[scr.selected_u]} --as:df.startup_charactersheetst[]

local args = {...}
if args[1] == 'points' then
    local points = tonumber(args[2])
    if points == nil then
        err('Invalid points')
    end
    if args[3] ~= 'all' then dwarves = selected_dwarf end
    adjust(dwarves, function(dwf)
        dwf.skill_picks_left = points
    end)
elseif args[1] == 'max' then
    if args[2] ~= 'all' then dwarves = selected_dwarf end
    adjust(dwarves, function(dwf)
        for skill, level in pairs(dwf.skilllevel) do
            dwf.skilllevel[skill] = df.skill_rating.Proficient
        end
    end)
elseif args[1] == 'legendary' then
    if args[2] ~= 'all' then dwarves = selected_dwarf end
    adjust(dwarves, function(dwf)
        for skill, level in pairs(dwf.skilllevel) do
            dwf.skilllevel[skill] = df.skill_rating.Legendary5
        end
    end)
else
    print(dfhack.script_help())
end
