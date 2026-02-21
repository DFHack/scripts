--- Simple menu to quickly execute common commands.
--[[
Copyright (c) 2014, Michon van Dooren
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the {organization} nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

local dlg = require('gui.dialogs')
local json = require('json')
local gui = require('gui')
local widgets = require('gui.widgets')

local CONFIG_FILE_BACKUP = 'dfhack-config/quickcmd.json.bak'
local CONFIG_FILE = 'dfhack-config/quickcmd.json'
local HOTKEYWIDTH = 7
local OUTWIDTH = 4
local HOTKEYS = 'asdfghjklqwertyuiopzxcvbnm'

local function save_commands(data)
    json.encode_file({version=2, commands=data}, CONFIG_FILE)
end

local function migrate_to_v2(data)
    json.encode_file(data, CONFIG_FILE_BACKUP)

    local commands = {}
    for i, cmd in ipairs(data) do
        if type(cmd) == 'string' then
            table.insert(commands, {command = cmd, name = nil, show_output = false})
        end
    end

    save_commands(commands)
    return commands
end

local function load_commands()
    local ok, data = pcall(json.decode_file, CONFIG_FILE)
    if ok then
        if type(data) == 'table' and data.version then
            if data.version == 2 then
                return data.commands or {}
            end
        end
        -- Old format: array of strings
        if type(data) == 'table' and #data > 0 then
            return migrate_to_v2(data)
        end
    end

    return {}
end

QCMDDialog = defclass(QCMDDialog, widgets.Window)
QCMDDialog.ATTRS {
    frame_title='Quick Command',
    frame={w=40, h=28},
    resizable=true,
    resize_min={h=10},
}

function QCMDDialog:init(info)
    self.commands = load_commands()

    self:addviews{
        widgets.Label{
            frame={t=0},
            text={{text='Hotkey', width=HOTKEYWIDTH}, {text='Out', width=OUTWIDTH}, 'Name/Command'},
            visible=function() return #self.commands > 0 end,
        },
        widgets.List{
            view_id='list',
            frame={t=2, b=4},
            on_submit=self:callback('submit'),
        },
        widgets.Label{
            frame={t=0},
            text={'Command list is empty.', NEWLINE, 'Hit "A" to add one!'},
            visible=function() return #self.commands == 0 end,
        },
        widgets.HotkeyLabel{
            frame={b=2, l=0},
            key='CUSTOM_SHIFT_A',
            label='Add command',
            auto_width=true,
            on_activate=self:callback('onAddCommand'),
        },
        widgets.HotkeyLabel{
            frame={b=2, l=19},
            key='CUSTOM_SHIFT_D',
            label='Delete command',
            auto_width=true,
            on_activate=self:callback('onDelCommand'),
        },
        widgets.HotkeyLabel{
            frame={b=1, l=0},
            key='CUSTOM_SHIFT_E',
            label='Edit command',
            auto_width=true,
            on_activate=self:callback('onEditCommand'),
        },
        widgets.HotkeyLabel{
            frame={b=1, l=19},
            key='CUSTOM_SHIFT_N',
            label='Edit name',
            auto_width=true,
            on_activate=self:callback('onSetName'),
        },
        widgets.HotkeyLabel{
            frame={b=0, l=0},
            key='CUSTOM_SHIFT_O',
            label='Capture output',
            auto_width=true,
            on_activate=self:callback('onToggleOutput'),
        },
    }

    self:updateList()
end

function QCMDDialog:submit(idx, choice)
    local cmd_obj = self.commands[idx]

    if cmd_obj.show_output then
        self:showCommandOutput(cmd_obj.command, cmd_obj.name)
    else
        local screen = self.parent_view
        dfhack.screen.hideGuard(screen, function()
            dfhack.run_command(cmd_obj.command)
        end)
        screen:dismiss()
    end
end

function QCMDDialog:showCommandOutput(command, name)
    local output = dfhack.run_command_silent(command)

    -- Dismiss the quickcmd dialog before showing output
    local screen = self.parent_view
    screen:dismiss()

    local OutputDialog = defclass(OutputDialog, gui.ZScreen)
    OutputDialog.ATTRS{
        focus_path='quickcmd_output',
        command='',
        name='',
        output='',
    }

    function OutputDialog:init()
        local title = ('%s%s'):format(self.name ~= '' and self.name .. ': ' or '', self.command)

        self:addviews{
            widgets.Window{
                frame_title=title,
                frame={w=80, h=25},
                resizable=true,
                resize_min={h=10, w=40},
                subviews={
                    widgets.WrappedLabel{
                        view_id='output',
                        frame={t=0, l=0, r=0, b=2},
                        text_to_wrap=self.output or 'No output',
                        scroll_keys=widgets.STANDARDSCROLL,
                    },
                    widgets.HotkeyLabel{
                        frame={b=0, l=0},
                        key='LEAVESCREEN',
                        label='Close',
                        auto_width=true,
                        on_activate=self:callback('dismiss'),
                    },
                }
            }
        }
    end

    if #output == 0 then
        output = 'Command finished successfully'
    end

    OutputDialog{command=command, name=name, output=output}:show()
end

function QCMDDialog:updateList()
    -- Build the list entries.
    local choices = {}
    for i,cmd_obj in ipairs(self.commands) do
        -- Get the hotkey for this entry.
        local hotkey = nil
        if i <= HOTKEYS:len() then
            hotkey = HOTKEYS:sub(i, i)
        end

        -- Display name if set, otherwise display command
        local display_text = cmd_obj.name or cmd_obj.command

        -- Store the entry.
        table.insert(choices, {
            text={{text=hotkey or '', width=HOTKEYWIDTH}, {text=cmd_obj.show_output and '[X]' or '[ ]', width=OUTWIDTH}, display_text},
            command=cmd_obj.command,
            name=cmd_obj.name,
            show_output=cmd_obj.show_output,
            hotkey=hotkey and ('CUSTOM_' .. hotkey:upper()) or '',
        })
    end
    self.subviews.list:setChoices(choices);
end

function QCMDDialog:onInput(keys)
    -- If the pressed key is a hotkey, perform that command and close.
    for idx,choice in ipairs(self.subviews.list:getChoices()) do
        if keys[choice.hotkey] then
            self:submit(idx, choice)
            return true
        end
    end

    -- Else, let the parent handle it.
    return QCMDDialog.super.onInput(self, keys)
end

function QCMDDialog:onAddCommand()
    dlg.showInputPrompt(
        'Add command',
        'Enter new command:',
        COLOR_GREEN,
        '',
        function(command)
            table.insert(self.commands, {command=command, name=nil, show_output=false})
            save_commands(self.commands)
            self:updateList()
        end
    )
end

function QCMDDialog:onDelCommand()
    -- Get the selected command.
    local index, item = self.subviews.list:getSelected()
    if not item then
        return
    end

    -- Prompt for confirmation.
    dlg.showYesNoPrompt(
        'Delete command',
        'Are you sure you want to delete this command: ' .. NEWLINE .. self.commands[index].command,
        COLOR_GREEN,
        function()
            table.remove(self.commands, index)
            save_commands(self.commands)
            self:updateList()
        end
    )
end

function QCMDDialog:onEditCommand()
    -- Get the selected command.
    local index, item = self.subviews.list:getSelected()
    if not item then
        return
    end

    -- Prompt for new value.
    dlg.showInputPrompt(
        'Edit command',
        'Enter command:',
        COLOR_GREEN,
        self.commands[index].command,
        function(command)
            self.commands[index].command = command
            save_commands(self.commands)
            self:updateList()
        end
    )
end

function QCMDDialog:onSetName()
    -- Get the selected command.
    local index, item = self.subviews.list:getSelected()
    if not item then
        return
    end

    -- Prompt for new name.
    dlg.showInputPrompt(
        'Set name',
        'Enter name:',
        COLOR_GREEN,
        self.commands[index].name or '',
        function(name)
            self.commands[index].name = name ~= '' and name or nil
            save_commands(self.commands)
            self:updateList()
        end
    )
end

function QCMDDialog:onToggleOutput()
    -- Get the selected command.
    local index, item = self.subviews.list:getSelected()
    if not item then
        return
    end

    -- Toggle the show_output flag.
    self.commands[index].show_output = not self.commands[index].show_output
    save_commands(self.commands)
    self:updateList()
end

QCMDScreen = defclass(QCMDScreen, gui.ZScreen)
QCMDScreen.ATTRS {
    focus_path='quickcmd',
}

function QCMDScreen:init()
    self:addviews{QCMDDialog{}}
end

function QCMDScreen:onDismiss()
    view = nil
end

view = view and view:raise() or QCMDScreen{}:show()
