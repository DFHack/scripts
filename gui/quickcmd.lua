--- Simple menu to quickly execute common commands.
--[====[

gui/quickcmd
============
A list of commands which you can edit while in-game, and which you can execute
quickly and easily. For stuff you use often enough to not want to type it, but
not often enough to be bothered to find a free keybinding.

]====]

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

local gui = require 'gui'
local widgets = require 'gui.widgets'
local dlg = require 'gui.dialogs'

local HOTKEYWIDTH = 7
local COMMANDWIDTH = 28 - HOTKEYWIDTH - 3
local STORAGEKEY = 'quickcmd.command'
local HOTKEYS = 'asdfghjklqwertyuiopzxcvbnm'

QCMDDialog = defclass(QCMDDialog, gui.FramedScreen)
QCMDDialog.focus_path = 'QuickCMDDialog'
QCMDDialog.ATTRS {
    frame_title = 'Quick Command',
}

function QCMDDialog:init(info)
    self:addviews{
        widgets.Panel{
            frame = { t = 0, r = 0, b = 0, l = 0 },
            frame_inset = 1,
            subviews = {
                widgets.Label{
                    frame = { t = 0 },
                    text = {
                        { text = 'Hotkey', width = HOTKEYWIDTH }, ' ',
                        { text = 'Command', width = COMMANDWIDTH },
                    },
                },
                widgets.List{
                    view_id = 'list',
                    frame = { t = 2, b = 3 },
                    not_found_label = 'Command list is empty.',
                },
                widgets.Label{
                    frame = { b = 0, h = 2 },
                    text = {
                        { key = 'CUSTOM_SHIFT_A', text = ': Add command',
                          on_activate = self:callback('onAddCommand') }, ' ',
                        { key = 'CUSTOM_SHIFT_D', text = ': Delete command',
                          on_activate = self:callback('onDelCommand') }, NEWLINE,
                        { key = 'CUSTOM_SHIFT_E', text = ': Edit command',
                          on_activate = self:callback('onEditCommand') }, ' ',
                    },
                }
            },
        },
    }

    self:updateList()
end

function QCMDDialog:updateList()
    -- Get the stored commands.
    local entries = dfhack.persistent.get_all(STORAGEKEY) or {}

    -- Build the list entries.
    self.commands = {}
    for i, entry in ipairs(entries) do
        -- Get the hotkey for this entry.
        local hotkey = nil
        if i <= HOTKEYS:len() then
            hotkey = HOTKEYS:sub(i, i)

            -- Store the entry.
            table.insert(self.commands, {
                text = {
                        { text = hotkey or '', width = HOTKEYWIDTH }, ' ',
                        { text = entry.value, width = COMMANDWIDTH },
                },
                entry = entry,
                command = entry.value,
                hotkey = 'CUSTOM_' .. hotkey:upper(),
            })
        end
    end
    self.subviews.list:setChoices(self.commands);
end

function QCMDDialog:getWantedFrameSize(rect)
    return 40, 28
end

function QCMDDialog:onInput(keys)
    if keys.LEAVESCREEN then
        self:dismiss()
    else
        -- If the pressed key is a hotkey, perform that command and close.
        for _, command in pairs(self.commands) do
            if keys[command.hotkey] then
                dfhack.run_command(command.command)
                self:dismiss()
                return
            end
        end

        -- Else, let the parent handle it.
        QCMDDialog.super.onInput(self, keys)
    end
end

function QCMDDialog:onAddCommand()
    dlg.showInputPrompt(
        'Add command',
        'Enter new command:',
        COLOR_GREEN,
        '',
        function(command)
            dfhack.persistent.save({
                key = STORAGEKEY,
                value = command
            }, true)
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
        'Are you sure you want to delete this command: ' .. NEWLINE .. item.entry.value,
        COLOR_GREEN,
        function()
            item.entry:delete()
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
        item.entry.value,
        function(command)
            item.entry.value = command
            item.entry:save()
            self:updateList()
        end
    )
end

local screen = QCMDDialog{}
screen:show()
