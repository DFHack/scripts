--rename items or units
--[====[

names
=====
Rename units or items.  Usage:

:-help:     print this help message
:-if a first name is desired press f, leave blank to clear current first name
:-if viewing an artifact you can rename it
:-if viewing a unit you can rename them
]====]
local gui = require 'gui'
local dlg = require 'gui.dialogs'
local widgets = require 'gui.widgets'
local utils = require 'utils'
local vw
local trg
local choices

validArgs = validArgs or utils.invert({
 'help',
})
local args = utils.processArgs({...}, validArgs)
if args.help then
    print(
[[names.lua
arguments:
    -help                
        print this help message
    if a first name is desired press f, leave blank to clear current first name
    if viewing an artifact you can rename it
    if viewing a unit you can rename them
]])
    return
end
namescr = defclass(namescr, gui.Screen)
namescr.focus_path = 'names'
function namescr:init()
    if not dfhack.gui.getViewscreenByType(df.viewscreen_layer_choose_language_namest)==true then
        self:addviews{
            widgets.Label{
                view_id='namescr',
                frame = {b=4, l=1},
                text = {
                    {text = "Press f to Change First Name"},NEWLINE,
                    {text = "Press Esc to Set Name and Exit"},
                        },
                    }
                }
        vw = dfhack.gui.getCurViewscreen()
        if df.viewscreen_itemst:is_instance(vw.parent) then
            fact = vw.parent.item.general_refs[0].artifact_id
            trg = df.artifact_record.find(fact)
        elseif df.viewscreen_dungeon_monsterstatusst:is_instance(vw.parent) then
            uid = vw.parent.unit.id
            trg = df.unit.find(uid)
        elseif df.global.ui_advmode.menu==1 then
            local t_look=df.global.ui_look_list.items[df.global.ui_look_cursor]
            if t_look.type==2 then
                trg=t_look.unit
            end
        end
        choices = df.viewscreen_setupadventurest:new()
        choices.page = 7
        local tn = choices.adventurer
        utils.assign(tn.name, trg.name)
        gui.simulateInput(choices, 'A_CUST_NAME')
        vw = dfhack.gui.getViewscreenByType(df.viewscreen_layer_choose_language_namest)
    elseif dfhack.gui.getViewscreenByType(df.viewscreen_layer_choose_language_namest)==true then
        qerror('names screen already displayed')
    end
    return vw,trg
end
function namescr:setName()
    for k = 0,6 do
        trg.name.words[k] = vw.name.words[k]
        trg.name.parts_of_speech[k] = vw.name.parts_of_speech[k]
        trg.name.language = vw.name.language
        trg .name.has_name = vw.name.has_name
    end
end
function namescr:setFirst()
local str = ''
    dlg.showInputPrompt("Set First Name?","First: ",COLOR_WHITE,'',
        function(str)
            if str==nil then
                self:callback("setFirst")
            else
                vw.name.first_name = str
                trg.name.first_name = str
            end
        end)
    return str
end
function namescr:onRenderBody(dc)
    self._native.parent:render()
end
function namescr:onInput(keys)
    if keys.SELECT then
        self:setName()
    end
    if keys.CUSTOM_F then
        self:setFirst()
        if not str==nil then
            trg.name.first_name = str
        end
    end
    if keys.LEAVESCREEN then
        self:setName()
        self:dismiss()
        dfhack.screen.dismiss(self._native.parent)
    end
    return self:sendInputToParent(keys)
end
namescr():show()
