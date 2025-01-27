--@module=true

local options = {}

local argparse = require('argparse')
local commands = argparse.processArgsGetopt({ ... }, {
    { 'd', 'dead', handler = function() options.dead = true end }
})

local dialogs = require('gui.dialogs')

--luacheck: in=df.viewscreen_setupadventurest,df.nemesis_record
local function addNemesisToUnretireList(advSetUpScreen, nemesis, index)
    local unretireOption = false
    for i = #advSetUpScreen.valid_race - 1, 0, -1 do
        if advSetUpScreen.valid_race[i] == -2 then -- this is the "Specific Person" option on the menu
            unretireOption = true
            break
        end
    end

    if not unretireOption then
        advSetUpScreen.valid_race:insert('#', -2)
    end

    -- Revive the historical figure
    local histFig = nemesis.figure
    if histFig.died_year >= -1 then
        histFig.died_year = -1
        histFig.died_seconds = -1
    end

    nemesis.flags.ADVENTURER = true
    -- nemesis.id and df.global.world.nemesis.all index should *usually* align but there may be bugged scenarios where they don't.
    -- This is a workaround for the issue by using the vector index rather than nemesis.id
    advSetUpScreen.nemesis_index:insert('#', index)
end

function getHistfigShortSummary(histFig)
    local race = df.creature_raw.find(histFig.race)
    local name = 'Unknown Creature'
    local sym = nil
    if race then
        local creature = race.caste[histFig.caste]
        name = creature.caste_name[0]
        sym = df.pronoun_type.attrs[creature.sex].symbol
    end
    if histFig.info and histFig.info.curse then
        local curse = histFig.info.curse
        if curse.name ~= '' then
            name = name .. ' ' .. curse.name
        end
        if curse.undead_name ~= '' then
            name = curse.undead_name .. " - reanimated " .. name
        end
    end
    if histFig.flags.ghost then
        name = name .. " ghost"
    end
    if sym then
        name = name .. ' (' .. sym .. ')'
    end
    name = name ..
            '\n' .. dfhack.units.getReadableName(histFig)
    if histFig.name.has_name then
        name = name ..
                '\n"' .. dfhack.translation.translateName(histFig.name, true) .. '"'
    else
        name = name ..
            '\nUnnamed'
    end
    return name
end

--luacheck: in=table
local function showNemesisPrompt(advSetUpScreen)
    local choices = {}
    for i, nemesis in ipairs(df.global.world.nemesis.all) do
        if nemesis.figure then
            local histFig = nemesis.figure
            if (histFig.died_year == -1 or histFig.flags.ghost or options.dead) and
                not histFig.flags.deity and
                not histFig.flags.force
            then
                if histFig.died_year == -1 and nemesis.flags.ADVENTURER then
                    -- already available for unretiring
                    goto continue
                end
                local name = getHistfigShortSummary(histFig)
                table.insert(choices, { text = name, nemesis = nemesis, search_key = name:lower(), idx = i })
            end
        end
        ::continue::
    end

    dialogs.ListBox{
        frame_title = 'unretire-anyone',
        text = 'Select someone to add to the "Specific Person" list (' .. #choices .. ' entries)',
        text_pen = COLOR_WHITE,
        choices = choices,
        on_select = function(id, choice) addNemesisToUnretireList(advSetUpScreen, choice.nemesis, choice.idx) end,
        with_filter = true,
        row_height = 3,
    }:show()
end

if dfhack_flags.module then
    return
end

local viewscreen = dfhack.gui.getDFViewscreen(true)
if viewscreen._type ~= df.viewscreen_setupadventurest then
    qerror("This script can only be used during adventure mode setup!")
end

showNemesisPrompt(viewscreen)
