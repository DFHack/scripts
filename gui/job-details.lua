-- Show and modify properties of jobs in a workshop or of manager orders.

--[[
    Credit goes to the author of `gui/workshop-job`.
    This is the gui/workshop-job.lua with gui/workorder-details.lua added on top
    and updated to the DF50.
]]

--@ module = true

local overlay = require('plugins.overlay')

local utils = require 'utils'
local gui = require 'gui'
local guimat = require 'gui.materials'
local widgets = require 'gui.widgets'
local dlg = require 'gui.dialogs'

JobDetailsScreen = defclass(JobDetailsScreen, gui.ZScreenModal)

JobDetailsScreen.ATTRS {
    focus_path = 'job-details',
}

function JobDetailsScreen:init(args)
    self:addviews{JobDetails(args)}
end

JobDetails = defclass(JobDetails, widgets.Window)

JobDetails.ATTRS {
    frame_title='Details',
    resizable = true,
    resize_min={w=50, h=20},
    frame = { l = 10, w = 50 },
    --
    job = DEFAULT_NIL,
    context = DEFAULT_NIL,
}

local function isManagerOrder(context)
    return context == df.job_details_context_type.MANAGER_WORK_ORDER
        or context == df.job_details_context_type.BUILDING_WORK_ORDER
end

function JobDetails:isManagerOrder()
    return isManagerOrder(self.context)
end

function JobDetails:init(args)
    local status
    if not self:isManagerOrder() then
        status = { text = 'No worker', pen = COLOR_DARKGREY }
        local worker = dfhack.job.getWorker(self.job)
        if self.job.flags.suspend then
            status = { text = 'Suspended', pen = COLOR_RED }
        elseif worker then
            status = { text = dfhack.TranslateName(dfhack.units.getVisibleName(worker)), pen = COLOR_GREEN }
        end
    end

    self:addviews{
        widgets.Label{
            frame = { l = 0, t = 0 },
            text = {
                { text = df.job_type.attrs[self.job.job_type].caption }, NEWLINE, NEWLINE,
                '  ', status
            }
        },
        widgets.HotkeyLabel{
            frame = { l = 0, t = 4},
            key = 'CUSTOM_I',
            label = "Input item",
            auto_width=true,
            enabled = self:callback('canChangeIType'),
            on_activate = self:callback('onChangeIType'),
        },
        widgets.HotkeyLabel{
            frame = { l = string.len("i: Input item") + 1, t = 4},
            key = 'CUSTOM_M',
            label = "Material",
            auto_width=true,
            enabled = self:callback('canChangeMat'),
            on_activate = self:callback('onChangeMat'),
        },
        widgets.HotkeyLabel{
            frame = { l = string.len("i: Input item m: Material") + 1, t = 4},
            key = 'CUSTOM_T',
            label = "Traits",
            auto_width=true,
            enabled = self:callback('canChangeTrait'),
            on_activate = self:callback('onChangeTrait'),
        },
        widgets.List{
            view_id = 'list',
            frame = { t = 6, b = 2 },
            row_height = 4,
            scroll_keys = widgets.SECONDSCROLL,
        },
        widgets.HotkeyLabel{
            frame = { l = 0, b = 0 },
            key = 'CUSTOM_CTRL_Z',
            label = "Reset changes",
            auto_width=true,
            -- enabled = self:callback('canResetChanges'),
            on_activate = self:callback('onResetChanges'),
        },
    }

    self.list = self.subviews.list

    self:initListChoices()
    self:storeInitialProperties()

    local h = 2 -- window border
        + self.list.frame.t -- everything above the list
        + 4 * #self.list.choices -- list body
        + 2 -- LEAVESCREEN
        + 2 -- window border
    self.frame.h = h
end

function JobDetails:storeInitialProperties()
    local stored = {}
    for _, choice in ipairs(self.list.choices) do
        local iobj = choice.iobj
        local copy = {}

        copy.item_type = iobj.item_type
        copy.item_subtype = iobj.item_subtype

        copy.mat_type = iobj.mat_type
        copy.mat_index = iobj.mat_index

        for i = 1, 5 do
            if not df['job_item_flags'..i] then break end
            local ffield = 'flags'..i

            copy[ffield] = {}
            for k,v in pairs(iobj[ffield]) do
                copy[ffield][k] = v
            end
        end

        stored[choice.index] = copy
    end

    self.stored = stored
end

local function describe_item_type(iobj)
    local itemline = 'any item'
    if iobj.item_type >= 0 then
        itemline = df.item_type.attrs[iobj.item_type].caption or iobj.item_type
        local def = dfhack.items.getSubtypeDef(iobj.item_type, iobj.item_subtype)
        local count = dfhack.items.getSubtypeCount(iobj.item_type, iobj.item_subtype)
        if def then
            itemline = def.name
        elseif count >= 0 then
            itemline = 'any '..itemline
        end
    end
    return itemline
end

local function is_caste_mat(iobj)
    return dfhack.items.isCasteMaterial(iobj.item_type)
end

local function describe_material(iobj)
    local matline = 'any material'
    if is_caste_mat(iobj) then
        matline = 'material not applicable'
    elseif iobj.mat_type >= 0 then
        local info = dfhack.matinfo.decode(iobj.mat_type, iobj.mat_index)
        if info then
            matline = info:toString()
        else
            matline = iobj.mat_type..':'..iobj.mat_index
        end
    end
    return matline
end

local function isString(o)
    return type(o) == "string"
end

local function list_flags(list, bitfield)
    for name,val in pairs(bitfield) do
        if val then
            -- as of DFHack version 50.11-r2 (git: 94d70e0) on x86_64,
            -- a job_item_flags3[20] might be set on a job item (f.e. Cut Gems)
            -- even though the flag is unnamed (i.e. `df.job_item_flags3[20] == nil`)
            -- we'll ignore those for clarity.
            if not dfhack.getHideArmokTools() or isString(name) then
                table.insert(list, name)
            end
        end
    end
end

local function describe_item_traits(iobj)
    local line1 = {}
    local reaction = df.reaction.find(iobj.reaction_id)
    if reaction and #iobj.contains > 0 then
        for _,ri in ipairs(iobj.contains) do
            table.insert(line1, 'has '..utils.call_with_string(
                reaction.reagents[ri],'getDescription',iobj.reaction_id
            ))
        end
    end
    if iobj.metal_ore >= 0 then
        local ore = dfhack.matinfo.decode(0, iobj.metal_ore)
        if ore then
            table.insert(line1, 'ore of '..ore:toString())
        end
    end
    if iobj.has_material_reaction_product ~= '' then
        table.insert(line1, iobj.has_material_reaction_product .. '-producing')
    end
    if iobj.reaction_class ~= '' then
        table.insert(line1, 'reaction class '..iobj.reaction_class)
    end
    if iobj.has_tool_use >= 0 then
        table.insert(line1, 'has use '..df.tool_uses[iobj.has_tool_use])
    end

    list_flags(line1, iobj.flags1)
    list_flags(line1, iobj.flags2)
    list_flags(line1, iobj.flags3)

    if #line1 == 0 then
        table.insert(line1, 'no traits')
    end
    return table.concat(line1, ', ')
end

local function GetHeader(iobj, items, i, is_active_job)
    local q = iobj.quantity
    if iobj.min_dimension > 0 then
        local q1 = q / iobj.min_dimension
        q = math.floor(q1) -- this makes it an int, removing `.0` from `1.0` when converted to string
        if q1 ~= q then
            -- round to 1 decimal point
            q = math.floor(q1 * 10) / 10
        end
    end

    local head = 'Item '..(i+1)
    if is_active_job then
        head = head..': '..(items[i] or 0)..' of '..q
    else
        head = head..' (quantity: '..q..')'
    end

    -- if iobj.min_dimension > 0 then
    --     head = head .. ' (size '..iobj.min_dimension..')'
    -- end

    return head
end

function JobDetails:initListChoices()
    local job_items
    local items = {}
    local is_active_job = false
    if self:isManagerOrder() then
        if not self.job.items then
            self.list:setChoices({})
            return
        end

        job_items = self.job.items
    else
        is_active_job = true

        for i,ref in ipairs(self.job.items) do
            local idx = ref.job_item_idx
            if idx >= 0 then
                items[idx] = (items[idx] or 0) + 1
            end
        end

        job_items = self.job.job_items
    end

    local headers = {}
    for i,iobj in ipairs(job_items) do
        headers[i] = GetHeader(iobj, items, i, is_active_job)
    end

    local choices = {}
    for i,iobj in ipairs(job_items) do
        local head = headers[i]

        table.insert(choices, {
            index = i,
            iobj = iobj,
            text = {
                head, NEWLINE,
                '  ', { text = curry(describe_item_type, iobj) }, NEWLINE,
                '  ', { text = curry(describe_material, iobj) }, NEWLINE,
                '  ', { text = curry(describe_item_traits, iobj) }, NEWLINE,
            }
        })
    end

    self.list:setChoices(choices)
end

function JobDetails:canChangeIType()
    if dfhack.getHideArmokTools() then
        -- as this could be considered an exploit
        return false
    end

    local idx, obj = self.list:getSelected()
    return obj ~= nil
end

function JobDetails:setItemType(obj, item_type, item_subtype)
    obj.iobj.item_type = item_type
    obj.iobj.item_subtype = item_subtype

    if is_caste_mat(obj.iobj) then
        self:setMaterial(obj, -1, -1)
    end
end

function JobDetails:onChangeIType()
    local idx, obj = self.list:getSelected()
    guimat.ItemTypeDialog{
        prompt = 'Please select a new item type for input '..idx,
        none_caption = 'any item',
        item_filter = curry(dfhack.job.isSuitableItem, obj.iobj),
        on_select = self:callback('setItemType', obj)
    }:show()
end

function JobDetails:canChangeMat()
    local idx, obj = self.list:getSelected()
    return obj ~= nil and not is_caste_mat(obj.iobj)
end

function JobDetails:setMaterial(obj, mat_type, mat_index)
    if  obj.index == 0
    and self.job.mat_type == obj.iobj.mat_type
    and self.job.mat_index == obj.iobj.mat_index
    and self.job.job_type ~= df.job_type.PrepareMeal
    then
        self.job.mat_type = mat_type
        self.job.mat_index = mat_index
    end

    obj.iobj.mat_type = mat_type
    obj.iobj.mat_index = mat_index
end

function JobDetails:findUnambiguousItem(iobj)
    local count = 0
    local itype

    for i = 0,df.item_type._last_item do
        if dfhack.job.isSuitableItem(iobj, i, -1) then
            count = count + 1
            if count > 1 then return nil end
            itype = i
        end
    end

    return itype
end

function JobDetails:onChangeMat()
    local idx, obj = self.list:getSelected()

    if obj.iobj.item_type == -1 and obj.iobj.mat_type == -1 then
        -- If the job allows only one specific item type, use it
        local vitype = self:findUnambiguousItem(obj.iobj)

        if vitype then
            obj.iobj.item_type = vitype
        else
            dlg.showMessage(
                'Bug Alert',
                { 'Please set a specific item type first.\n\n',
                  'Otherwise the material will be matched\n',
                  'incorrectly due to a limitation in DF code.' },
                COLOR_YELLOW
            )
            return
        end
    end

    guimat.MaterialDialog{
        prompt = 'Please select a new material for input '..idx,
        none_caption = 'any material',
        mat_filter = function(mat,parent,mat_type,mat_index)
            return dfhack.job.isSuitableMaterial(obj.iobj, mat_type, mat_index, obj.iobj.item_type)
        end,
        on_select = self:callback('setMaterial', obj)
    }:show()
end

function JobDetails:canChangeTrait()
    local idx, obj = self.list:getSelected()
    return obj ~= nil and not is_caste_mat(obj.iobj)
end

function JobDetails:onChangeTrait()
    local idx, obj = self.list:getSelected()
    guimat.ItemTraitsDialog{
        job_item = obj.iobj,
        prompt = 'Please select traits for input '..idx,
        none_caption = 'no traits',
    }:show()
end

function JobDetails:onResetChanges()
    for _, choice in pairs(self.list.choices) do
        local stored_obj = self.stored[choice.index]

        local item_type = stored_obj.item_type
        local item_subtype = stored_obj.item_subtype
        self:setItemType(choice, item_type, item_subtype)

        local mat_type = stored_obj.mat_type
        local mat_index = stored_obj.mat_index
        self:setMaterial(choice, mat_type, mat_index)

        for i = 1, 5 do
            local k = 'flags'..i
            local flags = stored_obj[k]
            if not flags then break end

            for k1,v1 in pairs(flags) do
                choice.iobj[k][k1] = v1
            end
        end
    end
end

local ScrJobDetails = df.global.game.main_interface.job_details
local ScrWorkorderConditions = df.global.game.main_interface.info.work_orders.conditions

local function get_current_job()
    local job
    local context
    local scr = ScrJobDetails

    if scr.open
    then
        context = scr.context
        if context == df.job_details_context_type.BUILDING_TASK_LIST
        or context == df.job_details_context_type.TASK_LIST_TASK
        then
            job = scr.jb
        elseif context == df.job_details_context_type.MANAGER_WORK_ORDER
            or context == df.job_details_context_type.BUILDING_WORK_ORDER
        then
            job = scr.wq
        end
        if job == nil then
            qerror("Unhandled screen context: ".. df.job_details_context_type[context])
        end
    else
        scr = ScrWorkorderConditions
        if scr.open
        then
            context = df.job_details_context_type.MANAGER_WORK_ORDER
            job = scr.wq
        end
    end

    return job, context
end

local function show_job_details()
    local job, context = get_current_job()

    if (job == nil) then
        qerror("This script needs to be run from a job details or order conditions screen")
    end

    JobDetailsScreen{ job = job, context = context }:show()
end

local function is_change_possible()
    -- we say it is if there is at least one item in the job
    local job, context = get_current_job()
    if isManagerOrder(context) then
        return job.items and #job.items ~= 0
    else
        return job.job_items and #job.job_items ~= 0
    end
end

-- --------------------
-- DetailsHotkeyOverlay
--

local LABEL_TEXT = 'Configure job inputs'
local LABEL_TEXT_LENGTH = string.len( LABEL_TEXT )

DetailsHotkeyOverlay = defclass(DetailsHotkeyOverlay, overlay.OverlayWidget)
DetailsHotkeyOverlay.ATTRS{
    default_pos={x=0,y=0},
    default_enabled=true,
    viewscreens="override this in a subclass",
    frame={w= 1   -- [
            + 6   -- Ctrl+d
            + 2   -- :_
            + LABEL_TEXT_LENGTH -- LABEL_TEXT
            + 1   -- ]
         , h= 1
        },
}

function DetailsHotkeyOverlay:init()
    self:addviews{
        widgets.TextButton{
            view_id = 'button',
            frame={t=0, l=0, w=DetailsHotkeyOverlay.ATTRS.frame.w, h=1},
            label=LABEL_TEXT,
            key='CUSTOM_CTRL_D',
            on_activate=show_job_details,
            enabled=is_change_possible,
        },
    }
end

DetailsHotkeyOverlay_BuildingTask = defclass(DetailsHotkeyOverlay_BuildingTask, DetailsHotkeyOverlay)
DetailsHotkeyOverlay_BuildingTask.ATTRS{
    -- 7 is the x position of the text on the narrowest screen
    -- we make the frame wider by 7 so we can move the label a bit if necessary
    default_pos={x=-110 + 7, y=6},
    frame={w=DetailsHotkeyOverlay.ATTRS.frame.w + 7, h= 1},
    viewscreens={
        'dwarfmode/JobDetails/BUILDING_TASK_LIST',
        'dwarfmode/JobDetails/BUILDING_WORK_ORDER',
    }
}

function DetailsHotkeyOverlay_BuildingTask:updateTextButtonFrame()
    local mainWidth, _ = dfhack.screen.getWindowSize()
    if (self._mainWidth == mainWidth) then return false end

    self._mainWidth = mainWidth

    -- calculated position of the left edge - not necessarily the real one if the screen is too narrow
    local x1 = mainWidth + DetailsHotkeyOverlay_BuildingTask.ATTRS.default_pos.x - DetailsHotkeyOverlay_BuildingTask.ATTRS.frame.w

    local offset = 0
    if x1 < 0 then
        x1 = 0
    end
    if x1 < 6 then
        offset = 6 - x1
    end

    self.subviews.button.frame.l = offset

    -- this restores original position for the case the screen was narrowed to the minimum
    -- and then expanded again.
    self.frame.r = - DetailsHotkeyOverlay_BuildingTask.ATTRS.default_pos.x - 1

    return true
end

function DetailsHotkeyOverlay_BuildingTask:onRenderBody(dc)
    if self:updateTextButtonFrame() then
        self:updateLayout()
    end

    DetailsHotkeyOverlay_BuildingTask.super.onRenderBody(self, dc)
end

DetailsHotkeyOverlay_ManagerWorkOrder = defclass(DetailsHotkeyOverlay_ManagerWorkOrder, DetailsHotkeyOverlay)
DetailsHotkeyOverlay_ManagerWorkOrder.ATTRS{
    default_pos={x=5, y=5}, -- {x=5, y=5} is right above the job title
    viewscreens={
        'dwarfmode/JobDetails/MANAGER_WORK_ORDER',
        -- as of DF50.11, once input materials in the task list are changed,
        -- there is no going back (the magnifying glass button disappears),
        -- which is why this option is disabled.
        -- 'dwarfmode/JobDetails/TASK_LIST_TASK',
    },
}

DetailsHotkeyOverlay_ManagerWorkOrderConditions = defclass(DetailsHotkeyOverlay_ManagerWorkOrderConditions, DetailsHotkeyOverlay)
DetailsHotkeyOverlay_ManagerWorkOrderConditions.ATTRS{
    default_pos={x=37, y=7},
    frame={w=DetailsHotkeyOverlay.ATTRS.frame.w, h=3}, -- we need h=3 here to move the button around depending on tabs in one or two rows
    viewscreens='dwarfmode/Info/WORK_ORDERS/Conditions',
}

--
-- change label position if window is resized
--
local function areTabsInTwoRows()
    local mainWidth, _ = dfhack.screen.getWindowSize()
    return mainWidth < 155
end

function DetailsHotkeyOverlay_ManagerWorkOrderConditions:updateTextButtonFrame()
    local twoRows = areTabsInTwoRows()
    if (self._twoRows == twoRows) then return false end

    self._twoRows = twoRows
    local frame = twoRows
            and {b=0, l=0, r=0, h=1}
            or  {t=0, l=0, r=0, h=1}
    self.subviews.button.frame = frame

    return true
end

function DetailsHotkeyOverlay_ManagerWorkOrderConditions:onRenderBody(dc)
    if (self.frame_rect.y1 == 7) then
        -- only apply this logic if the overlay is on the same row as
        -- originally thought: just above the order status icon

        if self:updateTextButtonFrame() then
            self:updateLayout()
        end
    end

    DetailsHotkeyOverlay_ManagerWorkOrderConditions.super.onRenderBody(self, dc)
end

-- -------------------

OVERLAY_WIDGETS = {
    job_details=DetailsHotkeyOverlay_BuildingTask,
    workorder_details=DetailsHotkeyOverlay_ManagerWorkOrder,
    workorder_conditions=DetailsHotkeyOverlay_ManagerWorkOrderConditions,
}

if dfhack_flags.module then
    return
end

show_job_details()
