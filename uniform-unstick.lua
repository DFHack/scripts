--@ module=true

local gui = require('gui')
local overlay = require('plugins.overlay')
local utils = require('utils')
local widgets = require('gui.widgets')

local validArgs = utils.invert({
    'all',
    'drop',
    'free',
    'multi',
    'help'
})

-- Functions

-- @param item df.item
-- @return string
local function item_description(item)
    return "item #" .. item.id .. " '" .. dfhack.df2console(dfhack.items.getDescription(item, 0, true)) .. "'"
end

-- @param item df.item
-- @return df.coord|nil
local function get_visible_item_pos(item)
    local x, y, z = dfhack.items.getPosition(item)
    if not x or not y or not z then
        return
    end

    if dfhack.maps.isTileVisible(x, y, z) then
        return xyz2pos(x, y, z)
    end
end

-- @param unit df.unit
-- @return df.squad_position|nil
local function get_squad_position(unit)
    local squad = df.squad.find(unit.military.squad_id)
    if not squad then
        return
    end

    if squad.entity_id ~= df.global.plotinfo.group_id then
        print("WARNING: Unit " .. dfhack.df2console(dfhack.units.getReadableName(unit)) .. " is a member of a squad from another site!" ..
            " This may be preventing them from doing any useful work." ..
            " You can fix this by assigning them to a local squad and then unassigning them.")
        print()
        return
    end

    if #squad.positions > unit.military.squad_position then
        return squad.positions[unit.military.squad_position]
    end
end

-- @param unit df.unit
-- @param item df.item
-- @return number[] list of body part ids
local function bodyparts_that_can_wear(unit, item)
    local bodyparts = {}
    local unitparts = dfhack.units.getCasteRaw(unit).body_info.body_parts

    for bodypart_flag, item_type in pairs({
        HEAD       = df.item_helmst,
        UPPERBODY  = df.item_armorst,
        GRASP      = df.item_glovesst,
        LOWERBODY  = df.item_pantsst,
        STANCE     = df.item_shoesst,
    }) do
        if item._type == item_type then
            for index, part in ipairs(unitparts) do
                if part.flags[bodypart_flag] then
                    table.insert(bodyparts, index)
                end
            end
        end
    end

    return bodyparts
end

-- @param unit_name string
-- @param labor_name string
local function print_bad_labor(unit_name, labor_name)
    return print("WARNING: Unit " .. unit_name .. " has the " .. labor_name ..
        " labor enabled, which conflicts with military uniforms.")
end

-- @param squad_position df.squad_position
-- @param item_id number
local function remove_item_from_position(squad_position, item_id)
    utils.erase_sorted(squad_position.equipment.assigned_items, item_id)
    for _, uniform_slot_specs in ipairs(squad_position.equipment.uniform) do
        for _, uniform_spec in ipairs(uniform_slot_specs) do
            for idx, assigned_item_id in ipairs(uniform_spec.assigned) do
                if assigned_item_id == item_id then
                    uniform_spec.assigned:erase(idx)
                    return
                end
            end
        end
    end
    for _, special_case in ipairs({"quiver", "backpack", "flask"}) do
        if squad_position.equipment[special_case] == item_id then
            squad_position.equipment[special_case] = -1
            return
        end
    end
end

-- Will figure out which items need to be moved to the floor, returns an item_id:item map
--   and a flag that indicates whether a separator line needs to be printed
local function process(unit, args)
    local silent = args.all -- Don't print details if we're iterating through all dwarves
    local unit_name = dfhack.df2console(dfhack.units.getReadableName(unit))
    local printed = false

    if not silent then
        print("Processing unit " .. unit_name)
        printed = true
    end

    -- The return value
    local to_drop = {} -- item id to item object

    -- First get squad position for an early-out for non-military dwarves
    local squad_position = get_squad_position(unit)
    if not squad_position then
        if not silent then
            print(unit_name .. " does not have a military uniform.")
            print()
        end
        return
    end

    if unit.status.labors.MINE then
        print_bad_labor(unit_name, "mining")
        printed = true
    elseif unit.status.labors.CUTWOOD then
        print_bad_labor(unit_name, "woodcutting")
        printed = true
    elseif unit.status.labors.HUNT then
        print_bad_labor(unit_name, "hunting")
        printed = true
    end

    -- Find all worn items which may be at issue.
    local worn_items = {} -- map of item ids to item objects
    local worn_parts = {} -- map of item ids to body part ids
    for _, inv_item in ipairs(unit.inventory) do
        local item = inv_item.item
        -- Include weapons so we can check we have them later
        if inv_item.mode == df.inv_item_role_type.Worn or
            inv_item.mode == df.inv_item_role_type.Weapon or
            inv_item.mode == df.inv_item_role_type.Strapped or
            inv_item.mode == df.inv_item_role_type.Flask
        then
            worn_items[item.id] = item
            worn_parts[item.id] = inv_item.body_part_id
        end
    end

    -- Now get info about which items have been assigned as part of the uniform
    local uniform_assigned_items = {} -- assigned item ids mapped to item objects
    for _, uniform_slot_specs in ipairs(squad_position.equipment.uniform) do
        for _, uniform_spec in ipairs(uniform_slot_specs) do
            for _, assigned_item_id in ipairs(uniform_spec.assigned) do
                -- Include weapon and shield so we can avoid dropping them, or pull them out of container/inventory later
                uniform_assigned_items[assigned_item_id] = df.item.find(assigned_item_id)
            end
        end
    end
    for _, special_case in ipairs({"quiver", "backpack", "flask"}) do
        local assigned_item_id = squad_position.equipment[special_case]
        if assigned_item_id ~= -1 then
            uniform_assigned_items[assigned_item_id] = df.item.find(assigned_item_id)
        end
    end

    -- Figure out which assigned items are currently not being worn
    -- and if some other unit is carrying the item, unassign it from this unit's uniform

    local present_ids = {} -- map of item ID to item object
    local missing_ids = {} -- map of item ID to item object
    for item_id, item in pairs(uniform_assigned_items) do
        if not worn_items[item_id] then
            if not silent then
                print(unit_name .. " is missing an assigned item, " .. item_description(item))
                printed = true
            end
            if dfhack.items.getGeneralRef(item, df.general_ref_type.UNIT_HOLDER) then
                print(unit_name .. " cannot equip item: another unit has a claim on " .. item_description(item))
                printed = true
                if args.free then
                    print("  Removing from uniform")
                    uniform_assigned_items[item_id] = nil
                    remove_item_from_position(squad_position, item_id)
                end
            else
                missing_ids[item_id] = item
                if args.free then
                    to_drop[item_id] = item
                end
            end
        else
            present_ids[item_id] = item
        end
    end

    -- Make the equipment.assigned_items list consistent with what is present in equipment.uniform
    for i=#(squad_position.equipment.assigned_items)-1,0,-1 do
        local assigned_item_id = squad_position.equipment.assigned_items[i]
        if uniform_assigned_items[assigned_item_id] == nil then
            local item = df.item.find(assigned_item_id)
            if item ~= nil then
                print(unit_name .. " has an improperly assigned item, " .. item_description(item) .. "; removing it")
            else
                print(unit_name .. " has a nonexistent item assigned, item # " .. assigned_item_id .. "; removing it")
            end
            printed = true
            squad_position.equipment.assigned_items:erase(i)
        end
    end

    -- Figure out which worn items should be dropped

    -- First, figure out which body parts are covered by the uniform pieces we have.
    -- unless --multi is specified, in which we don't care
    local covered = {} -- map of body part id to true/nil
    if not args.multi then
        for item_id, item in pairs(present_ids) do
            -- only the five clothing types can block armor for the bodypart they're worn on.
            if utils.linear_index({ df.item_helmst, df.item_armorst, df.item_glovesst,
                df.item_pantsst, df.item_shoesst }, item._type)
            then
                covered[worn_parts[item_id]] = true
            end
        end
    end

    -- Figure out body parts which should be covered but aren't
    local uncovered = {}
    for _, item in pairs(missing_ids) do
        for _, bp in ipairs(bodyparts_that_can_wear(unit, item)) do
            if not covered[bp] then
                uncovered[bp] = true
            end
        end
    end

    -- Drop clothing (except uniform pieces) from body parts which should be covered but aren't
    for worn_item_id, item in pairs(worn_items) do
        if uniform_assigned_items[worn_item_id] == nil  -- don't drop uniform pieces
            -- only the five clothing types can block armor for the bodypart they're worn on.
            and utils.linear_index({ df.item_helmst, df.item_armorst, df.item_glovesst,
                df.item_pantsst, df.item_shoesst }, item._type)
        then
            if uncovered[worn_parts[worn_item_id]] then
                print(unit_name .. " potentially has " .. item_description(item) .. " blocking a missing uniform item.")
                printed = true
                if args.drop then
                    to_drop[worn_item_id] = item
                end
            end
        end
    end

    return to_drop, printed
end

local function do_drop(item_list, printed)
    if not item_list then
        return
    end

    for _, item in pairs(item_list) do
        local pos = get_visible_item_pos(item)

        -- only drop if the item is on the map and is being held by a unit.
        if not pos then
            dfhack.printerr("Could not find drop location for " .. item_description(item))
        elseif dfhack.items.getHolderUnit(item) == nil then
            -- dfhack.printerr("Not in inventory: " .. item_description(item))
        else
            if dfhack.items.moveToGround(item, pos) then
                print("Dropped " .. item_description(item))
            else
                dfhack.printerr("Could not drop " .. item_description(item))
            end
        end
    end

    -- add a spacing line if there was any output
    if printed then
        print()
    end
end

local function main(args)
    args = utils.processArgs(args, validArgs)

    if args.help then
        print(dfhack.script_help())
        return
    end

    if args.all then
        for _, unit in ipairs(dfhack.units.getCitizens(true)) do
            do_drop(process(unit, args))
        end
    else
        local unit = dfhack.gui.getSelectedUnit()
        if unit then
            do_drop(process(unit, args))
        else
            qerror("Please select a unit if not running with --all")
        end
    end
end

ReportWindow = defclass(ReportWindow, widgets.Window)
ReportWindow.ATTRS {
    frame_title='Equipment conflict report',
    frame={w=100, h=35},
    resizable=true,
    resize_min={w=60, h=20},
    report=DEFAULT_NIL,
}

function ReportWindow:init()
    self:addviews{
        widgets.Label{
            frame={t=0, l=0},
            text_pen=COLOR_YELLOW,
            text='Equipment conflict report:',
        },
        widgets.Panel{
            frame={t=2, b=7},
            subviews={
                widgets.WrappedLabel{
                    frame={t=0},
                    text_to_wrap=self.report,
                },
            },
        },
        widgets.WrappedLabel{
            frame={b=4, h=2, l=0},
            text_pen=COLOR_LIGHTRED,
            text_to_wrap='After resolving conflicts, be sure to click the "Update equipment" button to reassign new equipment!',
            auto_height=false,
        },
        widgets.Panel{
            frame={b=0, w=34, h=3},
            frame_style=gui.FRAME_THIN,
            subviews={
                widgets.HotkeyLabel{
                    label='Try to resolve conflicts',
                    key='CUSTOM_CTRL_T',
                    on_activate=function()
                        dfhack.run_script('uniform-unstick', '--all', '--drop', '--free')
                        self.parent_view:dismiss()
                    end,
                },
            },
        },
    }
end

ReportScreen = defclass(ReportScreen, gui.ZScreenModal)
ReportScreen.ATTRS {
    focus_path='equipreport',
    report=DEFAULT_NIL,
}

function ReportScreen:init()
    self:addviews{ReportWindow{report=self.report}}
end

local MIN_WIDTH = 26

EquipOverlay = defclass(EquipOverlay, overlay.OverlayWidget)
EquipOverlay.ATTRS{
    desc='Adds a link to the equip screen to fix equipment conflicts.',
    default_pos={x=7,y=23},
    default_enabled=true,
    viewscreens='dwarfmode/Squads/Equipment/Default',
    frame={w=MIN_WIDTH, h=1},
    version=1
}

function EquipOverlay:init()
    self:addviews{
        widgets.TextButton{
            view_id='button',
            frame={t=0, w=MIN_WIDTH, r=0, h=1},
            label='Detect conflicts',
            key='CUSTOM_CTRL_T',
            on_activate=self:callback('run_report'),
        },
        widgets.TextButton{
            view_id='button_good',
            frame={t=0, w=MIN_WIDTH, r=0, h=1},
            label='  No conflicts  ',
            text_pen=COLOR_GREEN,
            key='CUSTOM_CTRL_T',
            visible=false,
        },
    }
end

function EquipOverlay:run_report()
    local output = dfhack.run_command_silent({'uniform-unstick', '--all'})
    if #output == 0 then
        self.subviews.button.visible = false
        self.subviews.button_good.visible = true
        local end_ms = dfhack.getTickCount() + 5000
        local function label_reset()
            if dfhack.getTickCount() < end_ms then
                dfhack.timeout(10, 'frames', label_reset)
            else
                self.subviews.button_good.visible = false
                self.subviews.button.visible = true
            end
        end
        label_reset()
    else
        ReportScreen{report=output}:show()
    end
end

function EquipOverlay:preUpdateLayout(parent_rect)
    self.frame.w = math.max(0, parent_rect.width - 133) + MIN_WIDTH
end

OVERLAY_WIDGETS = {overlay=EquipOverlay}

if dfhack_flags.module then
    return
end

main({...})
