---@diagnostic disable: missing-fields

local gui = require('gui')
local widgets = require('gui.widgets')

local autotraining = reqscript('autotraining')

local training_squads  = autotraining.state.training_squads
local ignored_units = autotraining.state.ignored
local ignored_nobles = autotraining.state.ignored_nobles

AutoTrain = defclass(AutoTrain, widgets.Window)
AutoTrain.ATTRS {
    frame_title='Training Setup',
    frame={w=55, h=45},
    resizable=true, -- if resizing makes sense for your dialog
    resize_min={w=55, h=20}, -- try to allow users to shrink your windows
}

local SELECTED_ICON = dfhack.pen.parse{ch=string.char(251), fg=COLOR_LIGHTGREEN}
function AutoTrain:getSquadIcon(squad_id)
    if training_squads[squad_id] then
        return SELECTED_ICON
    end
    return nil
end

function AutoTrain:getSquads()
    local squads = {}
    for _, squad in ipairs(df.global.world.squads.all) do
        if not (squad.entity_id == df.global.plotinfo.group_id) then
            goto continue
        end
        table.insert(squads, {
            text = dfhack.translation.translateName(squad.name, true)..(squad.alias ~= '' and ' ('..squad.alias..')' or ''),
            icon = self:callback("getSquadIcon", squad.id ),
            id   = squad.id
        })

        ::continue::
    end
    return squads
end

function AutoTrain:toggleSquad(_, choice)
    training_squads[choice.id] = not training_squads[choice.id]
    autotraining.persist_state()
    self:updateLayout()
end

local IGNORED_ICON = dfhack.pen.parse{ch='x', fg=COLOR_RED}
function AutoTrain:getUnitIcon(unit_id)
    if ignored_units[unit_id] then
        return IGNORED_ICON
    end
    return nil
end

function AutoTrain:getNobleIcon(noble_code)
    if ignored_nobles[noble_code] then
        return IGNORED_ICON
    end
    return nil
end

function AutoTrain:getUnits()
    local unit_choices = {}
    for _, unit in ipairs(dfhack.units.getCitizens(true,false)) do
        if not dfhack.units.isAdult(unit) then
            goto continue
        end

        table.insert(unit_choices, {
            text = dfhack.units.getReadableName(unit),
            icon = self:callback("getUnitIcon", unit.id ),
            id   = unit.id
        })
        ::continue::
    end
    return unit_choices
end

function AutoTrain:toggleUnit(_, choice)
    ignored_units[choice.id] = not ignored_units[choice.id]
    autotraining.persist_state()
    self:updateLayout()
end

local function to_title_case(str)
    return dfhack.capitalizeStringWords(dfhack.lowerCp437(str:gsub('_', ' ')))
end

function toSet(list)
    local set = {}
    for _, v in ipairs(list) do
        set[v] = true
    end
    return set
end

local function add_positions(positions, entity)
    if not entity then return end
    for _,position in pairs(entity.positions.own) do
        positions[position.id] = {
            id=position.id+1,
            code=position.code,
        }
    end
end

function AutoTrain:getPositions()
    local positions = {}
    local excludedPositions = toSet({
        'MILITIA_CAPTAIN',
        'MILITIA_COMMANDER',
        'OUTPOST_LIAISON',
        'CAPTAIN_OF_THE_GUARD',
    })

    add_positions(positions, df.historical_entity.find(df.global.plotinfo.civ_id))
    add_positions(positions, df.historical_entity.find(df.global.plotinfo.group_id))

    -- Step 1: Extract values into a sortable array
    local sortedPositions = {}
    for _, val in pairs(positions) do
        if val and not excludedPositions[val.code] then
            table.insert(sortedPositions, val)
        end
    end

    -- Step 2: Sort the positions (optional, adjust sorting criteria)
    table.sort(sortedPositions, function(a, b)
        return a.id < b.id  -- Sort alphabetically by code
    end)

    -- Step 3: Rebuild the table without gaps
    positions = {}  -- Reset positions table
    for i, val in ipairs(sortedPositions) do
        positions[i] = {
            text = to_title_case(val.code),
            value = val.code,
            pen = COLOR_LIGHTCYAN,
            icon = self:callback("getNobleIcon", val.code),
            id = val.id
        }
    end

    return positions
end



function AutoTrain:toggleNoble(_, choice)
    ignored_nobles[choice.value] = not ignored_nobles[choice.value]
    autotraining.persist_state()
    self:updateLayout()
end

function AutoTrain:init()
    self:addviews{
        widgets.Label{
            frame={ t = 0 , h = 1 },
            text = "Select squads for automatic training:",
        },
        widgets.List{
            view_id = "squad_list",
            icon_width = 2,
            frame = { t = 1, h = 5 },
            choices = self:getSquads(),
            on_submit=self:callback("toggleSquad")
        },
        widgets.Divider{ frame={t=6, h=1}, frame_style_l = false, frame_style_r = false},
        widgets.Label{
            frame={ t = 7 , h = 1 },
            text = "General options:",
        },
        widgets.EditField {
            view_id = "threshold",
            frame={ t = 8 , h = 1 },
            key = "CUSTOM_T",
            label_text = "Need threshold for training: ",
            text = tostring(-autotraining.state.threshold),
            on_char = function (char, _)
                return tonumber(char,10)
            end,
            on_submit = function (text)
                -- still necessary, because on_char does not check pasted text
                local entered_number = tonumber(text,10) or 5000
                autotraining.state.threshold = -entered_number
                autotraining.persist_state()
                -- make sure that the auto correction is reflected in the EditField
                self.subviews.threshold:setText(tostring(entered_number))
            end
        },
        widgets.ToggleHotkeyLabel {
            view_id = 'enable_toggle',
            frame = { t = 9, h = 1 },
            label = 'Autotraining is',
            key = 'CUSTOM_E',
            options = { { value = true, label = 'Enabled', pen = COLOR_GREEN },
                        { value = false, label = 'Disabled', pen = COLOR_RED } },
            on_change = function(val)
                if val then
                    autotraining.enable()
                else
                    autotraining.disable()
                end
            end,
        },
        widgets.Divider{ frame={t=10, h=1}, frame_style_l = false, frame_style_r = false},
        widgets.Label{
            frame={ t = 11 , h = 1 },
            text = "Ignored noble positions:",
        },
        widgets.List{
            frame = { t = 12 , h = 11},
            view_id = "nobles_list",
            icon_width = 2,
            choices = self:getPositions(),
            on_submit=self:callback("toggleNoble")
        },
        widgets.Divider{ frame={t=23, h=1}, frame_style_l = false, frame_style_r = false},
        widgets.Label{
            frame={ t = 24 , h = 1 },
            text = "Select units to exclude from automatic training:"
        },
        widgets.FilteredList{
            frame = { t = 25 },
            view_id = "unit_list",
            edit_key = "CUSTOM_CTRL_F",
            icon_width = 2,
            choices = self:getUnits(),
            on_submit=self:callback("toggleUnit")
        }
    }
    --self.subviews.unit_list:setChoices(unit_choices)
end

function AutoTrain:onRenderBody(painter)
    self.subviews.enable_toggle:setOption(autotraining.state.enabled)
end

function AutoTrain:onDismiss()
    view = nil
end

AutoTrainScreen = defclass(AutoTrainScreen, gui.ZScreen)
AutoTrainScreen.ATTRS {
    focus_path='autotrain',
}

function AutoTrainScreen:init()
    self:addviews{AutoTrain{}}
end

function AutoTrainScreen:onDismiss()
    view = nil
end

if not dfhack.world.isFortressMode() or not dfhack.isMapLoaded() then
    qerror('gui/autotraining requires a fortress map to be loaded')
end

view = view and view:raise() or AutoTrainScreen{}:show()
