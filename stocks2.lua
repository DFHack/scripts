-- a v50 script remake of the older stocks plugin
-- chawkzero, Aug 2023

local gui = require("gui")
local widgets = require("gui.widgets")
local utils = require("utils")

local item_desc_width = 38
local item_table = {}

local current_search_query = ""
local filter_states = {
    in_job = true,
    rotten = true,
    owned = true,
    forbidden = true,
    dump = true,
    on_fire = true,
    melt = true,
    in_inv = true,
    caged = true,
    trade = true,
    no_flags = true,
}

local min_qual = 0
local max_qual = 6
local min_wear = 0

-- 0 = listed, 1 = selected
local apply_to_mode = 0
local apply_to_labels = {"Listed", "Selected"}

local stocks_window_width = 106
local stocks_window_height = 50

StocksWindow = defclass(StocksWindow, widgets.Window)
StocksWindow.ATTRS({
    frame = {w = stocks_window_width, h = stocks_window_height},
    frame_title = "Stocks",
    autoarrange_subviews = false,
    autoarrange_gap = 0,
})

function StocksWindow:init()
    self:addviews({
        widgets.Panel({
            view_id = "left_panel",
            frame = {t = 0, b = 0, l = 0, r = stocks_window_width - 76},
            frame_style = gui.INTERIOR_FRAME,
            subviews = {
                widgets.EditField({
                    view_id = "search_box",
                    frame = {t = 1, l = 0},
                    label_text = "Search: ",
                    on_char = function(ch) return ch:match("[%l%s]") end,
                    on_change = function(new_text, old_text)
                        current_search_query = new_text
                        self:filter_list(current_search_query)
                    end,
                }),
                widgets.Label({
                    text = {{text = "Items: ", pen = COLOR_LIGHTGREEN}},
                    frame = {t = 3, l = 0},
                    view_id = "item_count_label"
                }),
                widgets.List({
                    view_id = "item_list",
                    frame = {t = 4, b = 1, l = 1, r = 1},
                    text_pen = {fg = COLOR_GREY, bg = COLOR_BLACK},
                    text_hpen = {fg = COLOR_BLACK, bg = COLOR_GREY},
                    cursor_pen = {fg = COLOR_LIGHTGREEN, bg = COLOR_DARKGREY},
                }),
            },
        }),
        widgets.Panel({
            view_id = "right_panel",
            frame = {t = 0, b = 0, r = 0, l = 72},
            frame_style = gui.INTERIOR_FRAME,
            subviews = {
                widgets.Label({
                    text = "Filters (Alt+Key toggles)",
                    frame = {t = 0, l = 0},
                    view_id = "filters_header_label",
                }),
                widgets.Label({
                    text = "to be filled in...",
                    frame = {t = 1, l = 0},
                    view_id = "filters_label",
                }),
                widgets.Label({
                    text = {
                        {text = "Shift-C", pen = COLOR_LIGHTGREEN}, {text = ": Clear All", pen = COLOR_WHITE}, NEWLINE,
                        {text = "Shift-E", pen = COLOR_LIGHTGREEN}, {text = ": Enable All", pen = COLOR_WHITE}, NEWLINE,
                        {text = "Shift-G", pen = COLOR_LIGHTGREEN}, {text = ": Toggle Grouping", pen = COLOR_WHITE}
                    },
                    frame = {t = 8, l = 0},
                    view_id = "filters_label2",
                }),
                widgets.Label({
                    text = {
                        {text = "-+", pen = COLOR_LIGHTGREEN}, {text = ": Min Qual: ", pen = COLOR_WHITE}, {text = "tbd", pen = COLOR_BROWN}, NEWLINE,
                        {text = "/*", pen = COLOR_LIGHTGREEN}, {text = ": Max Qual: ", pen = COLOR_WHITE}, {text = "tbd", pen = COLOR_BROWN}, NEWLINE,
                        {text = "Shift-W", pen = COLOR_LIGHTGREEN}, {text = ": Min Wear: ", pen = COLOR_WHITE}, {text = "tbd", pen = COLOR_BROWN}
                    },
                    frame = {t = 12, l = 0},
                    view_id = "filters_qual_wear",
                }),
                widgets.Label({
                    text = {
                        {text = "Actions (", pen = COLOR_BROWN}, {text = "...", pen = COLOR_LIGHTGREEN}, {text = " Items)", pen = COLOR_BROWN}
                    },
                    frame = {t = 16, l = 0},
                    view_id = "actions_item_count_label",
                }),
                widgets.Label({
                    text = {
                        {text = "Shift-Z", pen = COLOR_LIGHTGREEN}, {text = ": Zoom    ", pen = COLOR_WHITE},
                        {text = "-D", pen = COLOR_LIGHTGREEN}, {text = ": Dump", pen = COLOR_WHITE}, NEWLINE,
                        {text = "Shift-F", pen = COLOR_LIGHTGREEN}, {text = ": Forbid  ", pen = COLOR_WHITE},
                        {text = "-M", pen = COLOR_LIGHTGREEN}, {text = ": Melt", pen = COLOR_WHITE}, NEWLINE,
                        {text = "Shift-T", pen = COLOR_LIGHTGREEN}, {text = ": Mark for Trade", pen = COLOR_GREY},
                    },
                    frame = {t = 17, l = 0},
                    view_id = "actions_label",
                }),
                widgets.Label({
                    text = {
                        {text = "Shift-A", pen = COLOR_LIGHTGREEN}, {text = ": Apply to: ", pen = COLOR_WHITE},
                        {text = apply_to_labels[apply_to_mode + 1], pen = COLOR_BROWN},
                    },
                    frame = {t = 20, l = 0},
                    view_id = "apply_to_label",
                }),
            }
        }),
    })

    self:populate_item_table()
    self:filter_list(current_search_query)
    self:show_filters()
    self:show_qual_and_wear()
end

function StocksWindow:populate_item_table()
    -- retrieve all in-play items
    local temp_table = {}
    for i,v in ipairs(df.global.world.items.other[df.items_other_id.IN_PLAY]) do
        local item_desc = dfhack.items.getDescription(v, v:getType())

        -- store item description and an item ref
        table.insert(temp_table, { desc = item_desc, ref = v })
    end

    -- sort alphabetically
    local spec = { key = function(v) return v.desc end }
    local order = utils.make_sort_order(temp_table, { spec })
    for i = 1, #order do item_table[i] = temp_table[order[i]] end
end

function toggle_melt(item)
    item.flags.melt = not item.flags.melt

    if item.flags.melt then
        utils.insert_sorted(df.global.world.items.other.ANY_MELT_DESIGNATED, item, "id")
    else
        utils.erase_sorted(df.global.world.items.other.ANY_MELT_DESIGNATED, item, "id")
    end
end

function is_valid_melt_item(item)
    local mat_info = dfhack.matinfo.decode(item)
    if not mat_info then
        return false
    end

    -- must be a metal thing
    if mat_info:getCraftClass() ~= df.craft_material_class.Metal then
        return false
    end

    -- must not be a metal bar
    if item:getType() == df.item_type.BAR then
        return false
    end

    for i,g in ipairs(item.general_refs) do
        local t = g:getType()

        -- don't be a holder of things
        if t == df.general_ref_type.CONTAINS_ITEM or
           t == df.general_ref_type.UNIT_HOLDER or
           t == df.general_ref_type.CONTAINS_UNIT then
           return false
        end

        -- or be in something like a quiver, backpack, flask etc?
        if t == df.general_ref_type.CONTAINED_IN_ITEM then
            for i2, g2 in ipairs(g:getItem().general_refs) do
                if g2:getType() == df.general_ref_type.UNIT_HOLDER then
                    return false
                end
            end
        end
    end

    -- lastly, don't melt masterworks
    if item:getQuality() >= 5 then
        return false
    end

    return true
end

function StocksWindow:onInput(keys)
    -- FILTERS -------------------
    local refresh_list = false

    if keys["CUSTOM_ALT_J"] then filter_states.in_job = not filter_states.in_job; refresh_list = true end
    if keys["CUSTOM_ALT_X"] then filter_states.rotten = not filter_states.rotten; refresh_list = true end
    if keys["CUSTOM_ALT_O"] then filter_states.owned = not filter_states.owned; refresh_list = true end
    if keys["CUSTOM_ALT_F"] then filter_states.forbidden = not filter_states.forbidden; refresh_list = true end
    if keys["CUSTOM_ALT_D"] then filter_states.dump = not filter_states.dump; refresh_list = true end
    if keys["CUSTOM_ALT_E"] then filter_states.on_fire = not filter_states.on_fire; refresh_list = true end
    if keys["CUSTOM_ALT_M"] then filter_states.melt = not filter_states.melt; refresh_list = true end
    if keys["CUSTOM_ALT_I"] then filter_states.in_inv = not filter_states.in_inv; refresh_list = true end
    if keys["CUSTOM_ALT_C"] then filter_states.caged = not filter_states.caged; refresh_list = true end
    if keys["CUSTOM_ALT_T"] then filter_states.trade = not filter_states.trade; refresh_list = true end
    if keys["CUSTOM_ALT_N"] then filter_states.no_flags = not filter_states.no_flags; refresh_list = true end

    if keys["CUSTOM_SHIFT_C"] then
        for k,v in pairs(filter_states) do
            filter_states[k] = false
        end
        refresh_list = true
    end

    if keys["CUSTOM_SHIFT_E"] then
        for k,v in pairs(filter_states) do
            filter_states[k] = true
        end
        refresh_list = true
    end

    -- QUALITY AND WEAR -------------------
    -- keypad minus?
    if keys["STRING_A045"] then
        local new_min_qual = min_qual - 1
        if new_min_qual < 0 then new_min_qual = 0 end
        if new_min_qual ~= min_qual then
            min_qual = new_min_qual
            refresh_list = true
        end
    end

    -- keypad plus?
    if keys["STRING_A043"] then
        local new_min_qual = min_qual + 1
        if new_min_qual > max_qual then new_min_qual = max_qual end
        if new_min_qual ~= min_qual then
            min_qual = new_min_qual
            refresh_list = true
        end
    end

    -- keypad forward slash?
    if keys["STRING_A047"] then
        local new_max_qual = max_qual - 1
        if new_max_qual < min_qual then new_max_qual = min_qual end
        if new_max_qual ~= max_qual then
            max_qual = new_max_qual
            refresh_list = true
        end
    end

    -- keypad asterisk?
    if keys["STRING_A042"] then
        local new_max_qual = max_qual + 1
        if new_max_qual > 6 then new_max_qual = 6 end
        if new_max_qual ~= max_qual then
            max_qual = new_max_qual
            refresh_list = true
        end
    end

    if keys["CUSTOM_SHIFT_W"] then
        min_wear = (min_wear + 1) % 4
        refresh_list = true
    end

    -- ACTIONS --------------------
    if keys["CUSTOM_SHIFT_D"] then
        if apply_to_mode == 1 then --selected
            _, choice = self.subviews.item_list:getSelected()
            choice.ref.flags.dump = not choice.ref.flags.dump
        else
            for i,v in ipairs(self.subviews.item_list:getChoices()) do
                v.ref.flags.dump = not v.ref.flags.dump
            end
        end

        refresh_list = true
    end

    if keys["CUSTOM_SHIFT_F"] then
        if apply_to_mode == 1 then --selected
            _, choice = self.subviews.item_list:getSelected()
            choice.ref.flags.forbid = not choice.ref.flags.forbid
        else
            for i,v in ipairs(self.subviews.item_list:getChoices()) do
                v.ref.flags.forbid = not v.ref.flags.forbid
            end
        end

        refresh_list = true
    end

    if keys["CUSTOM_SHIFT_M"] then
        if apply_to_mode == 1 then --selected
            _, choice = self.subviews.item_list:getSelected()
            if is_valid_melt_item(choice.ref) then
                toggle_melt(choice.ref)
            end
        else
            for i,v in ipairs(self.subviews.item_list:getChoices()) do
                toggle_melt(v.ref)
            end
        end

        refresh_list = true
    end


    if refresh_list then
        self:filter_list(current_search_query)
    end

    if keys["CUSTOM_SHIFT_A"] then
        apply_to_mode = (apply_to_mode + 1) % 2
        self.subviews.apply_to_label:setText(
            {{text = "Shift-A", pen = COLOR_LIGHTGREEN}, {text = ": Apply to: ", pen = COLOR_WHITE}, {text = apply_to_labels[apply_to_mode + 1], pen = COLOR_BROWN},
        })
    end

    self:show_filters()
    self:show_qual_and_wear()

    return StocksWindow.super.onInput(self, keys)
end

function StocksWindow:show_qual_and_wear()
    local quality_labels = {"Ordinary", "WellCrafted", "FinelyCrafted", "Superior", "Exceptional", "Masterful", "Artifact"}
    self.subviews.filters_qual_wear:setText(
        {
            { text = "-+", pen = COLOR_LIGHTGREEN}, { text = ": Min Qual: ", pen = COLOR_WHITE }, { text = quality_labels[min_qual + 1], pen = COLOR_BROWN }, NEWLINE,
            { text = "/*", pen = COLOR_LIGHTGREEN}, { text = ": Max Qual: ", pen = COLOR_WHITE }, { text = quality_labels[max_qual + 1], pen = COLOR_BROWN }, NEWLINE,
            { text = "Shift-W", pen = COLOR_LIGHTGREEN}, { text = ": Min Wear: ", pen = COLOR_WHITE }, { text = tostring(min_wear), pen = COLOR_BROWN }
        }
    )
end

function StocksWindow:show_filters()

    local function get_pen(state)
        if state then
            return COLOR_WHITE
        else
            return COLOR_GREY
        end
    end

    self.subviews.filters_label:setText(
        {
            { text = "J", pen = COLOR_LIGHTBLUE},  { text = ": In Job  ", pen = get_pen(filter_states.in_job) },
            { text = "X", pen = COLOR_CYAN },      { text = ": Rotten", pen = get_pen(filter_states.rotten) }, NEWLINE,
            { text = "O", pen = COLOR_GREEN},      { text = ": Owned   ", pen = get_pen(filter_states.owned) },
            { text = "F", pen = COLOR_RED},        { text = ": Forbidden", pen = get_pen(filter_states.forbidden) }, NEWLINE,
            { text = "D", pen = COLOR_MAGENTA},    { text = ": Dump    ", pen = get_pen(filter_states.dump) },
            { text = "E", pen = COLOR_LIGHTRED},   { text = ": On Fire", pen = get_pen(filter_states.on_fire) }, NEWLINE,
            { text = "M", pen = COLOR_BLUE},       { text = ": Melt    ", pen = get_pen(filter_states.melt) },
            { text = "I", pen = COLOR_WHITE},      { text = ": In Inventory", pen = get_pen(filter_states.in_inv) }, NEWLINE,
            { text = "C", pen = COLOR_LIGHTRED},   { text = ": Caged   ", pen = get_pen(filter_states.caged) },
            { text = "T", pen = COLOR_LIGHTGREEN}, { text = ": Trade", pen = get_pen(filter_states.trade) }, NEWLINE,
            { text = "N", pen = COLOR_GREY},       { text = ": No Flags", pen = get_pen(filter_states.no_flags) },
        }
    )
end

function StocksWindow:filter_list(filter)
    dfhack.printerr(string.format("filter_list() called with \"%s\"", filter))
    local list_contents = {}
    local item_string

    local quality_labels = {"", "WellCrafted", "FinelyCrafted", "Superior", "Exceptional", "Masterful", "Artifact"}
    local quality_pens = {COLOR_BLACK, COLOR_BROWN, COLOR_CYAN, COLOR_LIGHTBLUE, COLOR_GREEN, COLOR_LIGHTGREEN, COLOR_BLUE}

    for i,v in ipairs(item_table) do
        local item = v.ref
        local has_flags = false

        -- see if item is in job
        local job_char
        local ref = dfhack.items.getSpecificRef(item, df.specific_ref_type.JOB)
        if ref and ref.data.job then
            job_char = 'J'
            has_flags = true
        else
            job_char = ' '
        end
        if not filter_states.in_job and job_char == 'J' then goto continue end

        -- check various flags
        local rotten_char
        if item.flags.rotten then
            rotten_char = 'X'
            has_flags = true
        else
            rotten_char = ' '
        end
        if not filter_states.rotten and item.flags.rotten then goto continue end

        local owned_char
        if item.flags.owned then
            owned_char = 'O'
            has_flags = true
        else
            owned_char = ' '
        end
        if not filter_states.owned and item.flags.owned then goto continue end

        local forbidden_char
        if item.flags.forbid then
            forbidden_char = 'F'
            has_flags = true
        else
            forbidden_char = ' '
        end
        if not filter_states.forbidden and item.flags.forbid then goto continue end

        local dump_char
        if item.flags.dump then
            dump_char = 'D'
            has_flags = true
        else
            dump_char = ' '
        end
        if not filter_states.dump and item.flags.dump then goto continue end

        local on_fire_char
        if item.flags.on_fire then
            on_fire_char = 'E'
            has_flags = true
        else
            on_fire_char = ' '
        end
        if not filter_states.on_fire and item.flags.on_fire then goto continue end

        local melt_char
        if item.flags.melt then
            melt_char = 'M'
            has_flags = true
        else
            melt_char = ' '
        end
        if not filter_states.melt and item.flags.melt then goto continue end

        local in_inv_char
        if item.flags.in_inventory then
            in_inv_char = 'I'
            has_flags = true
        else
            in_inv_char = ' '
        end
        if not filter_states.in_inv and item.flags.in_inventory then goto continue end

        -- skip if item has no flags and that filter is off!
        if not filter_states.no_flags and has_flags == false then goto continue end

        -- check quality
        local quality_label, quality_pen
        quality_label = quality_labels[item:getQuality() + 1]
        quality_pen = quality_pens[item:getQuality() + 1]

        -- skip by quality or wear
        if item:getQuality() < min_qual or item:getQuality() > max_qual then goto continue end
        if item:getWear() < min_wear then goto continue end

        local wear_tags = {"", "x", "X", "XX"}

        if not filter or #filter < 1 or string.match(string.lower(v.desc), filter) then
            local full_item_desc
            if item:getWear() > 0 then
                local wear_tag = wear_tags[item:getWear() + 1]
                full_item_desc = wear_tag .. v.desc .. wear_tag
            else
                full_item_desc = v.desc
            end

            table.insert(list_contents, {
                text = {
                    {text = full_item_desc, width = item_desc_width, rjustify = false, pad_char = ' '}, ' ',
                    {text = job_char, width = 1, pen = COLOR_LIGHTBLUE},
                    {text = rotten_char, width = 1, pen = COLOR_CYAN},
                    {text = owned_char, width = 1, pen = COLOR_GREEN},
                    {text = forbidden_char, width = 1, pen = COLOR_RED},
                    {text = dump_char, width = 1, pen = COLOR_LIGHTMAGENTA},
                    {text = on_fire_char, width = 1, pen = COLOR_LIGHTRED},
                    {text = melt_char, width = 1, pen = COLOR_BLUE},
                    {text = in_inv_char, width = 1, pen = COLOR_WHITE}, "   ",
                    {text = quality_label, width = 13, rjustify = false, pad_char = ' ', pen = quality_pen},
                },
                ref = v.ref,
            })
        end

        ::continue::
    end

    self.subviews.item_list:setChoices(list_contents)
    self.subviews.item_count_label:setText(string.format("Items: %d", #list_contents))
    self.subviews.actions_item_count_label:setText({
            {text = "Actions (", pen = COLOR_BROWN}, {text = tostring(#list_contents), pen = COLOR_LIGHTGREEN}, {text = " Items)", pen = COLOR_BROWN}
    })
    dfhack.printerr("done.")
end

StocksScreen = defclass(StocksScreen, gui.ZScreen)
StocksScreen.ATTRS({
    focus_path = "stocks2"
})

function StocksScreen:init()
    self:addviews({StocksWindow{}})
end

function StocksScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then
    return
end

view = view and view:raise() or StocksScreen{}:show()
