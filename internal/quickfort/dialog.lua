-- gui logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local argparse = require('argparse')
local dialogs = require('gui.dialogs')
local guidm = require('gui.dwarfmode')
local quickfort_command = reqscript('internal/quickfort/command')
local quickfort_list = reqscript('internal/quickfort/list')
local quickfort_parse = reqscript('internal/quickfort/parse')

-- must be at least enough to display all help text on the main dialog
local min_dialog_width = 73

-- persist these between dialog invocations
blueprint_dialog = blueprint_dialog or nil
show_library = show_library or false
show_hidden = show_hidden or false
filter_text = filter_text or nil
selected_id = selected_id or nil

local BlueprintDetails = defclass(BlueprintDetails, dialogs.MessageBox)

function BlueprintDetails:onRenderFrame(dc, rect)
    BlueprintDetails.super.onRenderFrame(self, dc, rect)
    dc:seek(rect.x1+2, rect.y2):string('Left arrow', dc.cur_key_pen):
            string(': Back', COLOR_GREY)
end

function BlueprintDetails:onInput(keys)
    if keys.STANDARDSCROLL_LEFT or keys.SELECT or keys.LEAVESCREEN then
        self:dismiss()
    else
        self:inputToSubviews(keys)
    end
end

local BlueprintDialog = defclass(BlueprintDialog, dialogs.ListBox)

BlueprintDialog.ATTRS{
    on_orders = DEFAULT_NIL,
}

function BlueprintDialog:onDismiss()
    BlueprintDialog.super.onDismiss()
    blueprint_dialog = nil
end

function BlueprintDialog:onRenderFrame(dc, rect)
    BlueprintDialog.super.onRenderFrame(self, dc, rect)

    -- render settings help in top row
    local filters_caption = "Filters:"
    local library_caption = "Library: Off"
    local hidden_caption = "Hidden: Off"
    if show_library then library_caption = "Library: On " end
    if show_hidden then hidden_caption = "Hidden: On " end
    local filters_offset = rect.x1 + 2
    local library_offset = filters_offset + #filters_caption + 2
    local hidden_offset = library_offset + #library_caption + 9
    dc:seek(filters_offset, rect.y1+1):string(filters_caption, COLOR_GREY)
    dc:seek(library_offset, rect.y1+1):
            key_string('CUSTOM_ALT_L', library_caption)
    dc:seek(hidden_offset, rect.y1+1):
            key_string('CUSTOM_ALT_H', hidden_caption)

    -- render command help on bottom frame
    local orders_caption = "Queue orders"
    local details_key = "Right arrow"
    local details_caption = ": Show details"
    local orders_offset = rect.x1 + 21
    local details_offset = orders_offset + #orders_caption + 9
    dc:seek(orders_offset, rect.y2):key_string('CUSTOM_ALT_O', orders_caption)
    dc:seek(details_offset, rect.y2):string(details_key, dc.cur_key_pen):
            string(details_caption, COLOR_GREY)
end

local function truncate(text, width, max_lines)
    local truncated_text = {}
    for line in text:gmatch('[^\n]*') do
        if #line > width then
            line = line:sub(1, width-5) .. '...->'
        end
        table.insert(truncated_text, line)
        if #truncated_text >= max_lines then break end
    end
    return table.concat(truncated_text, '\n')
end

local function get_id(text)
    local _, _, id = text:find('^(%d+)')
    return tonumber(id)
end

function BlueprintDialog:refresh()
    local choices = {}
    for _,v in ipairs(
            quickfort_list.do_list_internal(show_library, show_hidden)) do
        local start_comment = ''
        if v.start_comment then
            start_comment = string.format(' cursor start: %s', v.start_comment)
        end
        local sheet_spec = ''
        if v.section_name then
            sheet_spec = string.format(
                    ' -n %s',
                    quickfort_parse.quote_if_has_spaces(v.section_name))
        end
        local text = string.format('%d) %s%s (%s)%s\n    %s',
                v.id, quickfort_parse.quote_if_has_spaces(v.path), sheet_spec,
                v.mode, start_comment, v.comment or '')
        local truncated_text =
                truncate(text, self.frame_body.width, self.row_height)
        table.insert(choices,
                     {text=truncated_text,
                      full_text=text,
                      search_key=v.search_key})
    end
    self.subviews.list:setChoices(choices)
    self:updateLayout()
    if selected_id then
        for idx,v in ipairs(choices) do
            local cur_id = get_id(v.text)
            if selected_id >= cur_id then selected_idx = idx end
            if selected_id <= cur_id then break end
        end
    end
    self.subviews.list:setFilter(filter_text, selected_idx)
end

function BlueprintDialog:onInput(keys)
    local idx,obj = self.subviews.list:getSelected()
    if keys.STANDARDSCROLL_RIGHT and obj then
        BlueprintDetails{
            frame_title='Details',
            text=obj.full_text:wrap(self.frame_body.width)
        }:show()
    elseif keys.CUSTOM_ALT_O and obj then
        self.on_orders(idx, obj)
    elseif keys.CUSTOM_ALT_L then
        show_library = not show_library
        self:refresh()
    elseif keys.CUSTOM_ALT_H then
        show_hidden = not show_hidden
        self:refresh()
    elseif keys.LEAVESCREEN then
        self:dismiss()
        if self.on_cancel then
            self.on_cancel()
        end
    else
        self:inputToSubviews(keys)
    end
    filter_text = self.subviews.list:getFilter()
    if obj then
        selected_id = get_id(obj.text)
    else
        selected_id = nil
    end
end

local function dialog_command(command, text)
    local id = get_id(text)
    local blueprint_name, section_name, mode =
            quickfort_list.get_blueprint_by_number(id)

    local cursor = guidm.getCursorPos()
    if not cursor then
        if command == 'orders' or mode == 'notes' then
            cursor = {x=0, y=0, z=0}
        else
            dialogs.showMessage('Error',
                'Please position the game cursor at the blueprint start ' ..
                'location')
            return
        end
    end

    local id = get_id(text)
    local blueprint_name, section_name =
            quickfort_list.get_blueprint_by_number(id)

    print(string.format('executing via gui dialog: quickfort %s',
                        quickfort_parse.format_command(
                            command, blueprint_name, section_name)))
    local aliases = quickfort_list.get_aliases(blueprint_name)
    local ctx = quickfort_command.init_ctx(command, blueprint_name, cursor,
                                           aliases, false)
    quickfort_command.do_command_section(ctx, section_name)
    quickfort_command.finish_command(ctx, section_name, true)
    if command == 'run' and #ctx.messages > 0 then
        dialogs.showMessage('Attention',
                            table.concat(ctx.messages, '\n\n'):wrap(
                                 min_dialog_width))
    elseif command == 'orders' then
        local count = 0
        for _,_ in pairs(ctx.order_specs or {}) do count = count + 1 end
        local message = string.format(
            '%d orders enqueued for %s.', count,
            quickfort_parse.format_command(nil, blueprint_name, section_name))
        dialogs.showMessage('Orders enqueued', message:wrap(min_dialog_width))
    end
end

function do_dialog(args)
    -- allow passed-in flags and strings to pre-set our dialog flags and filter
    local filter_strings = argparse.processArgsGetopt(args, {
            {'l', 'library', handler=function() show_library = true end},
            {'h', 'hidden', handler=function() show_hidden = true end},
        })
    if #filter_strings > 0 then
        filter_text = table.concat(filter_strings, ' ')
    end
    if blueprint_dialog then blueprint_dialog:dismiss() end
    blueprint_dialog = BlueprintDialog{
        frame_title='Select quickfort blueprint',
        with_filter=true,
        frame_width=min_dialog_width,
        row_height=2,
        select2_hint='Undo',
        on_select=function(idx, obj) dialog_command('run', obj.text) end,
        on_select2=function(idx, obj) dialog_command('undo', obj.text) end,
        on_orders=function(idx, obj) dialog_command('orders', obj.text) end,
    }
    blueprint_dialog:show()
    blueprint_dialog:refresh() -- sets the choices and updates the layout
end
