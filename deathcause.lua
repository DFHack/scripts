-- show death cause of a creature
local guidm = require('gui.dwarfmode')

local DEATH_TYPES = reqscript('gui/unit-info-viewer').DEATH_TYPES

-- Gets the first corpse item at the given location
function getItemAtPosition(pos)
    for _, item in ipairs(df.global.world.items.other.ANY_CORPSE) do
        if item.pos.x == pos.x and item.pos.y == pos.y and item.pos.z == pos.z then
            print("Automatically chose first corpse at the selected location.")
            return item
        end
    end
end

function getRaceNameSingular(race_id)
    return df.creature_raw.find(race_id).name[0]
end

function getDeathStringFromCause(cause)
    if cause == -1 then
        return "died"
    else
        return DEATH_TYPES[cause]:trim()
    end
end

function displayDeathUnit(unit)
    local str = ("The %s"):format(getRaceNameSingular(unit.race))
    if unit.name.has_name then
        str = str .. (" %s"):format(dfhack.TranslateName(unit.name))
    end

    if not dfhack.units.isDead(unit) then
        print(str .. " is not dead yet!")
        return
    end

    str = str .. (" %s"):format(getDeathStringFromCause(unit.counters.death_cause))

    local incident = df.incident.find(unit.counters.death_id)
    if incident then
        str = str .. (" in year %d"):format(incident.event_year)

        if incident.criminal then
            local killer = df.unit.find(incident.criminal)
            if killer then
                str = str .. (", killed by the %s"):format(getRaceNameSingular(killer.race))
                if killer.name.has_name then
                    str = str .. (" %s"):format(dfhack.TranslateName(killer.name))
                end
            end
        end
    end

    print(str .. '.')
end

-- returns the item description if the item still exists; otherwise
-- returns the weapon name
function getWeaponName(item_id, subtype)
    local item = df.item.find(item_id)
    if not item then
        return df.global.world.raws.itemdefs.weapons[subtype].name
    end
    return dfhack.items.getDescription(item, 0, false)
end

function displayDeathEventHistFigUnit(histfig_unit, event)
    local str = ("The %s %s %s in year %d"):format(
            getRaceNameSingular(histfig_unit.race),
            dfhack.TranslateName(histfig_unit.name),
            getDeathStringFromCause(event.death_cause),
            event.year
    )

    local slayer_histfig = df.historical_figure.find(event.slayer_hf)
    if slayer_histfig then
        str = str .. (", killed by the %s %s"):format(
                getRaceNameSingular(slayer_histfig.race),
                dfhack.TranslateName(slayer_histfig.name)
        )
    end

    if event.weapon then
        if event.weapon.item_type == df.item_type.WEAPON then
            str = str .. (", using a %s"):format(getWeaponName(event.weapon.item, event.weapon.item_subtype))
        elseif event.weapon.shooter_item_type == df.item_type.WEAPON then
            str = str .. (", shot by a %s"):format(getWeaponName(event.weapon.shooter_item, event.weapon.shooter_item_subtype))
        end
    end

    print(str .. '.')
end

-- Returns the death event for the given histfig or nil if not found
function getDeathEventForHistFig(histfig_id)
    for i = #df.global.world.history.events - 1, 0, -1 do
        local event = df.global.world.history.events[i]
        if event:getType() == df.history_event_type.HIST_FIGURE_DIED then
            if event.victim_hf == histfig_id then
                return event
            end
        end
    end

    return nil
end

function displayDeathHistFig(histfig)
    local histfig_unit = df.unit.find(histfig.unit_id)
    if not histfig_unit then
        qerror("Cause of death not available")
    end

    if not dfhack.units.isDead(histfig_unit) then
        print(("%s is not dead yet!"):format(dfhack.TranslateName(histfig_unit.name)))
    else
        local death_event = getDeathEventForHistFig(histfig.id)
        displayDeathEventHistFigUnit(histfig_unit, death_event)
    end
end

local function is_corpse_item(item)
    if not item then return false end
    local itype = item:getType()
    return itype == df.item_type.CORPSE or itype == df.item_type.CORPSEPIECE
end

local view_sheets = df.global.game.main_interface.view_sheets

local function get_target()
    local selected_unit = dfhack.gui.getSelectedUnit(true)
    if selected_unit then
        return selected_unit.hist_figure_id, selected_unit
    end
    local selected_item = dfhack.gui.getSelectedItem(true)
    if not selected_item and
        dfhack.gui.matchFocusString('dwarfmode/ViewSheets/ITEM_LIST', dfhack.gui.getDFViewscreen(true)) and
        #view_sheets.viewing_itid > 0
    then
        local pos = xyz2pos(dfhack.items.getPosition(df.item.find(view_sheets.viewing_itid[0])))
        selected_item = getItemAtPosition(pos)
    end
    if not is_corpse_item(selected_item) then
        if df.item_remainsst:is_instance(selected_item) then
            print(("The %s died."):format(getRaceNameSingular(selected_item.race)))
            return
        end
        qerror("Please select a unit, a corpse, or a body part")
    end
    return selected_item.hist_figure_id, df.unit.find(selected_item.unit_id)
end

local hist_figure_id, selected_unit = get_target()

if not hist_figure_id then
    qerror("Cause of death not available")
elseif hist_figure_id == -1 then
    if not selected_unit then
        qerror("Cause of death not available")
    end
    displayDeathUnit(selected_unit)
else
    displayDeathHistFig(df.historical_figure.find(hist_figure_id))
end
