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

local function item_description(item)
    return dfhack.df2console(dfhack.items.getDescription(item, 0, true))
end

local function get_item_pos(item)
    local x, y, z = dfhack.items.getPosition(item)
    if not x or not y or not z then
        return
    end

    if dfhack.maps.isTileVisible(x, y, z) then
        return xyz2pos(x, y, z)
    end
end

local function get_squad_position(unit, unit_name)
    local squad = df.squad.find(unit.military.squad_id)
    if squad then
        if squad.entity_id ~= df.global.plotinfo.group_id then
            print("WARNING: Unit " .. unit_name .. " is a member of a squad from another site!" ..
                " This may be preventing them from doing any useful work." ..
                " You can fix this by assigning them to a local squad and then unassigning them.")
            print()
            return
        end
    else
        return
    end
    if #squad.positions > unit.military.squad_position then
        return squad.positions[unit.military.squad_position]
    end
end

local function bodyparts_that_can_wear(unit, item)
    local bodyparts = {}
    local unitparts = dfhack.units.getCasteRaw(unit).body_info.body_parts

    if item._type == df.item_helmst then
        for index, part in ipairs(unitparts) do
            if part.flags.HEAD then
                table.insert(bodyparts, index)
            end
        end
    elseif item._type == df.item_armorst then
        for index, part in ipairs(unitparts) do
            if part.flags.UPPERBODY then
                table.insert(bodyparts, index)
            end
        end
    elseif item._type == df.item_glovesst then
        for index, part in ipairs(unitparts) do
            if part.flags.GRASP then
                table.insert(bodyparts, index)
            end
        end
    elseif item._type == df.item_pantsst then
        for index, part in ipairs(unitparts) do
            if part.flags.LOWERBODY then
                table.insert(bodyparts, index)
            end
        end
    elseif item._type == df.item_shoesst then
        for index, part in ipairs(unitparts) do
            if part.flags.STANCE then
                table.insert(bodyparts, index)
            end
        end
    else
        -- print("Ignoring item type for "..item_description(item) )
    end

    return bodyparts
end

-- returns new value of need_newline
local function print_line(text, need_newline)
    if need_newline then
        print()
    end
    print(text)
    return false
end

local function print_bad_labor(unit_name, labor_name, need_newline)
    return print_line("WARNING: Unit " .. unit_name .. " has the " .. labor_name ..
        " labor enabled, which conflicts with military uniforms.", need_newline)
end

-- Will figure out which items need to be moved to the floor, returns an item_id:item map
local function process(unit, args, need_newline)
    local silent = args.all -- Don't print details if we're iterating through all dwarves
    local unit_name = dfhack.df2console(dfhack.units.getReadableName(unit))

    if not silent then
        need_newline = print_line("Processing unit " .. unit_name, need_newline)
    end

    -- The return value
    local to_drop = {} -- item id to item object

    -- First get squad position for an early-out for non-military dwarves
    local squad_position = get_squad_position(unit, unit_name)
    if not squad_position then
        if not silent then
            need_newline = print_line(unit_name .. " does not have a military uniform.", need_newline)
        end
        return
    end

    if unit.status.labors.MINE then
        need_newline = print_bad_labor(unit_name, "mining", need_newline)
    elseif unit.status.labors.CUTWOOD then
        need_newline = print_bad_labor(unit_name, "woodcutting", need_newline)
    elseif unit.status.labors.HUNT then
        need_newline = print_bad_labor(unit_name, "hunting", need_newline)
    end

    -- Find all worn items which may be at issue.
    local worn_items = {} -- map of item ids to item objects
    local worn_parts = {} -- map of item ids to body part ids
    for _, inv_item in ipairs(unit.inventory) do
        local item = inv_item.item
        -- Include weapons so we can check we have them later
        if inv_item.mode == df.inv_item_role_type.Worn or
            inv_item.mode == df.inv_item_role_type.Weapon or
            inv_item.mode == df.inv_item_role_type.Strapped
        then
            worn_items[item.id] = item
            worn_parts[item.id] = inv_item.body_part_id
        end
    end

    -- Now get info about which items have been assigned as part of the uniform
    local assigned_items = {} -- assigned item ids mapped to item objects
    for _, specs in ipairs(squad_position.equipment.uniform) do
        for _, spec in ipairs(specs) do
            for _, assigned in ipairs(spec.assigned) do
                -- Include weapon and shield so we can avoid dropping them, or pull them out of container/inventory later
                assigned_items[assigned] = df.item.find(assigned)
            end
        end
    end

    -- Figure out which assigned items are currently not being worn
    -- and if some other unit is carrying the item, unassign it from this unit's uniform

    local present_ids = {} -- map of item ID to item object
    local missing_ids = {} -- map of item ID to item object
    for u_id, item in pairs(assigned_items) do
        if not worn_items[u_id] then
            if not silent then
                need_newline = print_line(unit_name .. " is missing an assigned item, object #" .. u_id .. " '" ..
                    item_description(item) .. "'", need_newline)
            end
            if dfhack.items.getGeneralRef(item, df.general_ref_type.UNIT_HOLDER) then
                need_newline = print_line(unit_name .. " cannot equip item: another unit has a claim on object #" .. u_id .. " '" .. item_description(item) .. "'", need_newline)
                if args.free then
                    print("  Removing from uniform")
                    assigned_items[u_id] = nil
                    for _, specs in ipairs(squad_position.equipment.uniform) do
                        for _, spec in ipairs(specs) do
                            for idx, assigned in ipairs(spec.assigned) do
                                if assigned == u_id then
                                    spec.assigned:erase(idx)
                                    break
                                end
                            end
                        end
                    end
                end
            else
                missing_ids[u_id] = item
                if args.free then
                    to_drop[u_id] = item
                end
            end
        else
            present_ids[u_id] = item
        end
    end

    -- Figure out which worn items should be dropped

    -- First, figure out which body parts are covered by the uniform pieces we have.
    -- unless --multi is specified, in which we don't care
    local covered = {} -- map of body part id to true/nil
    if not args.multi then
        for id, item in pairs(present_ids) do
            -- weapons and shields don't "cover" the bodypart they're assigned to. (Needed to figure out if we're missing gloves.)
            if item._type ~= df.item_weaponst and item._type ~= df.item_shieldst then
                covered[worn_parts[id]] = true
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

    -- Drop everything (except uniform pieces) from body parts which should be covered but aren't
    for w_id, item in pairs(worn_items) do
        if assigned_items[w_id] == nil then -- don't drop uniform pieces (including shields, weapons for hands)
            if uncovered[worn_parts[w_id]] then
                need_newline = print_line(unit_name ..
                    " potentially has object #" ..
                    w_id .. " '" .. item_description(item) .. "' blocking a missing uniform item.", need_newline)
                if args.drop then
                    to_drop[w_id] = item
                end
            end
        end
    end

    return to_drop
end

local function do_drop(item_list)
    if not item_list then
        return
    end

    for id, item in pairs(item_list) do
        local pos = get_item_pos(item)
        if not pos then
            dfhack.printerr("Could not find drop location for item #" .. id .. "  " .. item_description(item))
        else
            if dfhack.items.moveToGround(item, pos) then
                print("Dropped item #" .. id .. " '" .. item_description(item) .. "'")
            else
                dfhack.printerr("Could not drop object #" .. id .. "  " .. item_description(item))
            end
        end
    end
end

local function main(args)
    args = utils.processArgs(args, validArgs)

    if args.help then
        print(dfhack.script_help())
        return
    end

    if args.all then
        local need_newline = false
        for _, unit in ipairs(dfhack.units.getCitizens(true)) do
            do_drop(process(unit, args, need_newline))
            need_newline = true
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
    default_pos={x=7,y=21},
    default_enabled=true,
    viewscreens='dwarfmode/Squads/Equipment/Default',
    frame={w=MIN_WIDTH, h=1},
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
