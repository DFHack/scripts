-- List and pull levers

local gui = require('gui')
local guidm = require('gui.dwarfmode')
local utils = require('utils')
local widgets = require('gui.widgets')

local lever_script = reqscript('lever')

local REFRESH_MS = 1000

local function get_levers()
    local levers = {}
    for _, building in ipairs(df.global.world.buildings.other.TRAP) do
        if building.trap_type == df.trap_type.Lever then
            table.insert(levers, building)
        end
    end
    return levers
end

local function get_lever_label(lever)
    local status = (lever.state == 1) and 'Pulled' or 'Not Pulled'
    local name = utils.getBuildingName(lever)
    local queued = 0
    for _, job in ipairs(lever.jobs) do
        if job.job_type == df.job_type.PullLever then
            queued = queued + 1
        end
    end
    local queued_text = queued > 0 and (' (queued: %d)'):format(queued) or ''
    return ('[%s] %s (#%d)%s'):format(status, name, lever.id, queued_text)
end

local function get_queued_count(levers)
    local queued = 0
    for _, lever in ipairs(levers) do
        for _, job in ipairs(lever.jobs) do
            if job.job_type == df.job_type.PullLever then
                queued = queued + 1
            end
        end
    end
    return queued
end

LeverWindow = defclass(LeverWindow, widgets.Window)
LeverWindow.ATTRS{
    frame_title = 'Lever Tasks',
    frame = {w=60, h=18, r=2},
}

function LeverWindow:init()
    local _, screen_height = dfhack.screen.getWindowSize()
    if screen_height then
        self.frame.t = math.max(0, math.floor((screen_height - self.frame.h) / 2))
    end
    self.next_refresh_ms = dfhack.getTickCount() + REFRESH_MS
    self.filter_text = ''
    self:addviews{
        widgets.EditField{
            view_id='search',
            frame={t=0, l=0, r=0},
            label_text='Search: ',
            on_change=self:callback('set_filter'),
        },
        widgets.List{
            view_id='lever_list',
            frame={t=1, l=0, r=0, b=4},
            on_submit=self:callback('queue_pull'),
            on_select=self:callback('focus_lever'),
        },
        widgets.Label{
            view_id='empty_message',
            frame={t=1, l=0, r=0},
            text='No levers found.',
            visible=false,
        },
        widgets.HotkeyLabel{
            frame={b=3, l=0},
            label='Pull selected lever',
            key='CUSTOM_P',
            on_activate=self:callback('queue_pull'),
        },
        widgets.HotkeyLabel{
            frame={b=2, l=0},
            label='Remove queued pulls',
            key='CUSTOM_X',
            on_activate=self:callback('remove_queued_pulls'),
        },
        widgets.Label{
            view_id='queued_count',
            frame={b=3, r=0},
            text='Queued pulls: 0',
            auto_width=true,
        },
        widgets.HotkeyLabel{
            frame={b=1, l=0},
            label='Refresh list',
            key='CUSTOM_R',
            on_activate=self:callback('refresh_list'),
        },
    }

    self:refresh_list()
end

function LeverWindow:set_filter(text)
    self.filter_text = text or ''
    self:refresh_list()
end

function LeverWindow:refresh_list()
    local list = self.subviews.lever_list
    local selected_id
    if list then
        local _, selected = list:getSelected()
        if selected and selected.data then
            selected_id = selected.data.id
        end
    end

    local choices = {}
    local levers = get_levers()
    table.sort(levers, function(a, b)
        if a.state == b.state then
            return a.id < b.id
        end
        return a.state > b.state
    end)
    local filter = (self.filter_text or ''):lower()
    local filtered_levers = {}
    if filter == '' then
        filtered_levers = levers
    else
        for _, lever in ipairs(levers) do
            local name = utils.getBuildingName(lever)
            if name:lower():find(filter, 1, true) then
                table.insert(filtered_levers, lever)
            end
        end
    end
    local selected_idx = 1
    for idx, lever in ipairs(filtered_levers) do
        table.insert(choices, {text=get_lever_label(lever), data=lever})
        if selected_id and lever.id == selected_id then
            selected_idx = idx
        end
    end
    list:setChoices(choices, selected_idx)
    self.subviews.empty_message.visible = #choices == 0
    self.subviews.queued_count:setText(('Queued pulls: %d'):format(get_queued_count(levers)))
end

function LeverWindow:queue_pull()
    local _, choice = self.subviews.lever_list:getSelected()
    if not choice then
        return
    end
    lever_script.leverPullJob(choice.data, false)
    self:refresh_list()
end

function LeverWindow:remove_queued_pulls()
    local _, choice = self.subviews.lever_list:getSelected()
    if not choice then
        return
    end
    local jobs = {}
    for _, job in ipairs(choice.data.jobs) do
        if job.job_type == df.job_type.PullLever then
            table.insert(jobs, job)
        end
    end
    for _, job in ipairs(jobs) do
        dfhack.job.removeJob(job)
    end
    self:refresh_list()
end

function LeverWindow:onRenderFrame(dc, rect)
    LeverWindow.super.onRenderFrame(self, dc, rect)

    local list = self.subviews.lever_list
    local hover_idx = list:getIdxUnderMouse()
    if hover_idx and hover_idx ~= self.hover_index then
        self.hover_index = hover_idx
        list:setSelected(hover_idx)
        local _, choice = list:getSelected()
        if choice then
            self:focus_lever(nil, choice)
        end
    end
end

function LeverWindow:onRenderBody()
    if dfhack.getTickCount() >= self.next_refresh_ms then
        self.next_refresh_ms = dfhack.getTickCount() + REFRESH_MS
        self:refresh_list()
    end
end

function LeverWindow:focus_lever(_, choice)
    if not choice then
        return
    end
    local lever = choice.data
    local pos = {x=lever.centerx, y=lever.centery, z=lever.z}
    dfhack.gui.revealInDwarfmodeMap(pos, true, true)
    guidm.setCursorPos(pos)
end

LeverScreen = defclass(LeverScreen, gui.ZScreen)
LeverScreen.ATTRS{focus_path='lever'}

function LeverScreen:init()
    self:addviews{LeverWindow{}}
end

function LeverScreen:onDismiss()
    view = nil
end

if not dfhack.isMapLoaded() then
    qerror('gui/lever requires a map to be loaded')
end

view = view and view:raise() or LeverScreen{}:show()
