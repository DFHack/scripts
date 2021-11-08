-- Interface front-end for enlinker plugin.

local utils = require 'utils'
local gui = require 'gui'
local guidm = require 'gui.dwarfmode'
local dlg = require 'gui.dialogs'
local script = require 'gui.script'

local plugin = require('plugins.enlink')
local bselector = df.global.ui_build_selector

--local buildings = df.global.buildings

function get_current_building()

  local selb = dfhack.gui.getSelectedBuilding(true)

  if not selb then
    local cursor = guidm.getCursorPos()
    selb = dfhack.buildings.findAtTile(pos2xyz(cursor))
  end

  return selb

end

function WrapValue(value, under, over)
  if value > over then
    return under
  elseif value < under then
    return over
  else
    return value
  end
end

function PromptValue(name, current, under, over, updatefunc)
  dlg.showInputPrompt(name,'Please enter a value between ' .. under .. ' and ' .. over,nil,nil,
                      function ( txt )
                        local num=tonumber(txt)
                        num = WrapValue(num, under, over)
                        updatefunc(num)
                      end)
  return
end

function ShowLinkList(EG, canmanage)
  if EG.link_num == 0 then return end
  local tempt = {}
  for k,v in pairs(EG.linked_list) do
    tempt[k] = v
  end
  for k,v in pairs(EG.modified_links) do
    if tempt[k] ~= nil then
      tempt[k] = tempt[k] + v
    else
      tempt[k] = v
    end
  end
  local choicelist = {}
  for k,v in pairs(tempt) do
    local bld = df.building.find(k)
    local str = utils.getBuildingName(bld).." ("..v..")"
    table.insert(choicelist, {str, nil, k, v})
  end
  dlg.showListPrompt("Links", "Choose a link to view.", nil, choicelist,
                     function(ret)
                      EG.is_managing = true
                      EG.manage_pos = utils.getBuildingCenter(EG.building)
                      local mngbld = df.building.find(choicelist[ret][3])
                      local mngpos = utils.getBuildingCenter(mngbld)
                      EG.managing_building = mngbld
                      EG.old_pos = mngpos
                      EG.managing_count = choicelist[ret][4]
                      if canmanage then
                        guidm.setCursorPos(mngpos)
                        EG:getViewport():centerOn(mngpos):set()
                      end
                     end
                    )
end

function CenterOnManaged(EG)
  guidm.setCursorPos(EG.manage_pos)
  EG:getViewport():centerOn(EG.manage_pos):set()
end

function ClearManaging(EG, canmanage)
  EG.is_managing = false
  EG.managing_building = nil
  EG.managing_count = 0
  if canmanage then CenterOnManaged(EG) end
  EG.old_pos = EG.manage_pos
end

function UpdateManaging(EG)
  local cursor = guidm.getCursorPos()
  if cursor ~= EG.old_pos then
    EG.old_pos = cursor
    local bld = dfhack.buildings.findAtTile(pos2xyz(cursor))
    if bld and not plugin.can_be_enlinked(bld.id) then
      bld = nil
    end
    EG.managing_building = bld
    EG.managing_count = 0
    if bld then
      if EG.linked_list[bld.id] ~= nil then EG.managing_count = EG.managing_count + EG.linked_list[bld.id] end
      if EG.modified_links[bld.id] ~= nil then EG.managing_count = EG.managing_count + EG.modified_links[bld.id] end
    end
  end
end

function DeltaLinkCount(num, EG)
  if EG.managing_building ~= nil then
    local delta = num
    if EG.managing_count + num > 255 then
      delta = -EG.managing_count
    elseif EG.managing_count + num < 0 then
      delta = 255-EG.managing_count
    end
    if delta == 0 then return end
    local newval = EG.managing_count + delta
    EG.managing_count = newval

    if EG.linked_list[EG.managing_building.id] ~= nil then
      newval = newval - EG.linked_list[EG.managing_building.id]
    elseif EG.modified_links[EG.managing_building.id] == nil then
      EG.link_num = EG.link_num + 1
    end

    EG.modified_links[EG.managing_building.id] = newval

  end
end


function ProcessInput(keys, EG, canmanage)
  if keys.CUSTOM_Q then
    plugin.set_building_active(EG.building.id, true)
  elseif keys.CUSTOM_A then
    plugin.set_building_active(EG.building.id, false)
  end

  if not EG.is_enlinked then
    if keys.CUSTOM_Z then
      EG.is_enlinked = true
    end
  elseif EG.is_managing then
    if keys.CUSTOM_W then
      DeltaLinkCount(1, EG)
    elseif keys.CUSTOM_S then
      DeltaLinkCount(-1, EG)
    elseif keys.CUSTOM_C then
      if canmanage then 
        CenterOnManaged(EG)
        UpdateManaging(EG)
      end
    elseif keys.CUSTOM_M then
      ClearManaging(EG, canmanage)
    elseif canmanage then
      if EG:propagateMoveKeys(keys) then UpdateManaging(EG) end
    end
  else
    if keys.CUSTOM_Z then
      EG.is_enlinked = false
    elseif keys.CUSTOM_R then
      EG.on_th =  EG.on_th - 1
    elseif keys.CUSTOM_T then
      PromptValue("On Threshold", EG.on_th, 0, 65535, function(num) EG.on_th = num end)
    elseif keys.CUSTOM_Y then
      EG.on_th = EG.on_th + 1
    elseif keys.CUSTOM_F then
      EG.off_th = EG.off_th - 1
    elseif keys.CUSTOM_G then
      PromptValue("Off Threshold", EG.off_th, 0, 65535, function(num) EG.off_th = num end)
    elseif keys.CUSTOM_H then
      EG.off_th = EG.off_th + 1
    elseif keys.CUSTOM_U then
      EG.on_tm = EG.on_tm - 1
    elseif keys.CUSTOM_I then
      PromptValue("On Delay", EG.on_tm, 0, 65535, function(num) EG.on_tm = num end)
    elseif keys.CUSTOM_O then
      EG.on_tm = EG.on_tm + 1
    elseif keys.CUSTOM_J then
      EG.off_tm = EG.off_tm - 1
    elseif keys.CUSTOM_K then
      PromptValue("Off Delay", EG.off_tm, 0, 65535, function(num) EG.off_tm = num end)
    elseif keys.CUSTOM_L then
      EG.off_tm = EG.off_tm + 1
    elseif keys.CUSTOM_E then
      EG.on_i = not EG.on_i
    elseif keys.CUSTOM_D then
      EG.off_i = not EG.off_i
    elseif keys.CUSTOM_V then
      EG.v_o = not EG.v_o
    elseif keys.CUSTOM_N then
      ShowLinkList(EG, canmanage)
    elseif keys.CUSTOM_M then
      if canmanage then
        EG.is_managing = true
        EG.manage_pos = utils.getBuildingCenter(EG.building)
        EG.old_pos = nil
        CenterOnManaged(EG)
        UpdateManaging(EG)
      end
    end
    EG.on_th = WrapValue(EG.on_th, 0, 65535)
    EG.off_th = WrapValue(EG.off_th, 0, 65535)
    EG.on_tm = WrapValue(EG.on_tm, 0, 65535)
    EG.off_tm = WrapValue(EG.off_tm, 0, 65535)
  end
  if keys.LEAVESCREEN then
    EG:dismiss()
    --self:sendInputToParent('LEAVESCREEN')
  elseif keys.SELECT then
    Commit(EG)
    EG:dismiss()
    --self:sendInputToParent('LEAVESCREEN')
  end
end


function Commit(EG)
  if EG.was_enlinked and not EG.is_enlinked then
    plugin.unmake_enlinked(EG.building.id)
    return
  elseif EG.is_enlinked and not EG.was_enlinked then
    plugin.make_enlinked(EG.building.id)
  end
  local num1 = 4 * (EG.on_i and 1 or 0) + 2 * (EG.off_i and 1 or 0) + (EG.v_o and 1 or 0)
  local num2 = EG.on_th * 65536 + EG.off_th
  local num3 = EG.on_tm  * 65536 + EG.off_tm
  plugin.set_enlink_info(EG.building.id, num1, num2, num3)
  for k,v in pairs(EG.modified_links) do
    if v < 0 then
      for i=1,-v do plugin.remove_enlink(EG.building.id, k) end
    elseif v > 0 then
      for i=1,v do plugin.add_enlink(EG.building.id, k) end
    end
  end
end

function Render(dc, rect, EG, canmanage)
  dc:seek(rect.x1+1,rect.y1+1):pen(COLOR_WHITE):key_pen(COLOR_LIGHTRED)

  dc:string("Linkable: "..utils.getBuildingName(EG.building)):newline():newline(rect.x1+11)
  if plugin.is_building_active(EG.building.id) then
    dc:pen(COLOR_YELLOW):string("ON"):pen(COLOR_WHITE):newline():newline()
  else
    dc:pen(COLOR_RED):string("OFF"):pen(COLOR_WHITE):newline():newline()
  end
  if EG.is_managing then
    if EG.managing_building ~= nil then
      if EG.managing_building == EG.building then
        dc:newline(rect.x1+1):string("Link: (SELF)"):newline():newline():newline()
      else
        dc:newline(rect.x1+1):string("Link: "..utils.getBuildingName(EG.managing_building)):newline():newline(rect.x1+11)
        if plugin.is_building_active(EG.managing_building.id) then
          dc:pen(COLOR_YELLOW):string("ON"):pen(COLOR_WHITE):newline()
        else
          dc:pen(COLOR_RED):string("OFF"):pen(COLOR_WHITE):newline()
        end
      end
      dc:newline(rect.x1+3):key('CUSTOM_W'):key('CUSTOM_S'):string(": Link Weight: "..EG.managing_count):newline():newline()
    else
      dc:newline():newline():newline():newline():newline():newline():newline()
    end
    dc:newline():newline():newline():newline():newline():newline():newline():newline():newline():newline()
    if canmanage then dc:newline(rect.x1+1):key('CUSTOM_C'):string(": Recenter on Managed"):newline() else dc:newline():newline() end
    dc:newline(rect.x1+1):key('CUSTOM_M'):string(": Stop Managing Links")
  elseif EG.is_enlinked then
    dc:newline(rect.x1+3):key('CUSTOM_Z'):string(": Disable Enlinking"):newline():newline(rect.x1+1)
    
    dc:string("Threshold:")

    dc:newline(rect.x1+3):key('CUSTOM_R')
    dc:key('CUSTOM_T'):key('CUSTOM_Y')
    dc:string(": On:  ")
    dc:string(''..EG.on_th)

    dc:newline(rect.x1+3):key('CUSTOM_F')
    dc:key('CUSTOM_G'):key('CUSTOM_H')
    dc:string(": Off: ")
    dc:string(''..EG.off_th)
    dc:newline():newline(rect.x1+1)

    dc:string("Delay:")

    dc:newline(rect.x1+3):key('CUSTOM_U')
    dc:key('CUSTOM_I'):key('CUSTOM_O')
    dc:string(": On:  ")
    dc:string(''..EG.on_tm)

    dc:newline(rect.x1+3):key('CUSTOM_J')
    dc:key('CUSTOM_K'):key('CUSTOM_L')
    dc:string(": Off: ")
    dc:string(''..EG.off_tm)
    dc:newline():newline(rect.x1+1)

    dc:string("Interrupt:")

    dc:newline(rect.x1+3):key('CUSTOM_E')
    dc:string(": On:  ")
    if EG.on_i then
        dc:string("Yes")
    else
        dc:string("No")
    end
    dc:newline(rect.x1+3):key('CUSTOM_D')
    dc:string(": Off: ")
    if EG.off_i then
        dc:string("Yes")
    else
        dc:string("No")
    end
    dc:newline():newline(rect.x1+1)

    dc:key('CUSTOM_V'):string(": ")
    if EG.v_o then
        dc:string("Override")
    else
        dc:string("No Override")
    end
    dc:newline():newline():newline(rect.x1+1):key('CUSTOM_N'):string(": List Links"):newline(rect.x1+18):string("("..EG.link_num..")")
    if canmanage then dc:newline(rect.x1+1):key('CUSTOM_M'):string(": Manage Links") else dc:newline() end
  else
    dc:newline(rect.x1+3):key('CUSTOM_Z'):string(": Enable Enlinking")
  end
    dc:seek(rect.x1+1,rect.y2-5):pen(COLOR_WHITE)
    dc:newline(rect.x1+1):key('SELECT'):string(": Apply Changes"):newline()
    dc:newline(rect.x1+1):key('LEAVESCREEN'):string(": Cancel Changes")

end

function Initialize(EG)
  EG:assign{
      on_th = 1, off_th = 0, on_tm = 0, off_tm = 0, on_i = true, off_i = true, v_o = true,
      building = get_current_building(), is_enlinked = false,
      linked_list = {}, modified_links = {}, link_num = 0, was_enlinked = false,
      old_pos = guidm.getCursorPos(), is_managing = false, managing_building = nil, managing_count = 0,
      manage_pos = guidm.getCursorPos()
  }
  local num1 = plugin.get_enlink_info_p1(EG.building.id)
  if num1 ~= 0 then
    local num2 = plugin.get_enlink_info_p2(EG.building.id)
    local num3 = plugin.get_enlink_info_p3(EG.building.id)
    EG.on_i = num1 & 4
    EG.off_i = num1 & 2
    EG.v_o = num1 & 1
    EG.on_th = num2 // 65536
    EG.off_th = num2 & 65535 
    EG.on_tm = num3 // 65536
    EG.off_tm = num3 & 65535
    for i=1,plugin.get_num_links(EG.building.id) do
      local lk = plugin.get_linked_building(EG.building.id, i-1)
      if EG.linked_list[lk] ~= nil then
        EG.linked_list[lk] = EG.linked_list[lk] + 1
      else
        EG.linked_list[lk] = 1
        EG.link_num = EG.link_num + 1
      end
    end
    EG.is_enlinked = true
    EG.was_enlinked = true
  end
end

--------------------------------------------------------------------

EnlinkGui = defclass(EnlinkGui, guidm.MenuOverlay)

EnlinkGui.focus_path = 'enlinker'

EnlinkGui.ATTRS {
    frame_background = false
}

function EnlinkGui:init() 
  Initialize(self)
end

function EnlinkGui:onShow()
    EnlinkGui.super.onShow(self)
end

function EnlinkGui:onRenderBody(dc)
  dc:fill(0,0,dc.width,dc.height,gui.CLEAR_PEN)
  Render(dc, {x1 = 0, y1 = 0, x2 = dc.width, y2 = dc.height}, self, true)
end

function EnlinkGui:onInput(keys)
  ProcessInput(keys, self, true)
end

-----------------------------------------------------------------------

EnlinkGuiAlt = defclass(nil, dlg.MessageBox)

function EnlinkGuiAlt:getWantedFrameSize()
    local w, h = EnlinkGuiAlt.super.getWantedFrameSize(self)
    if w < 32 then w = 32 end
    if h < 32 then h = 32 end
    return w, h
end

function EnlinkGuiAlt:init()
  self.label = "Enlinker GUI"
  Initialize(self)
end

function EnlinkGuiAlt:onRenderFrame(dc, rect)
  EnlinkGuiAlt.super.onRenderFrame(self,dc,rect)
  Render(dc, rect, self, false)
end

function EnlinkGuiAlt:onInput(keys)
  ProcessInput(keys, self, false)
end

------------------------------------------------------------------------------


local selb = get_current_building()

if not selb or not plugin.can_be_enlinked(selb.id) then
  qerror("A valid building for enlinking must be selected!")
end

if df.global.gamemode == df.game_mode.ADVENTURE then
  local gui = EnlinkGuiAlt()
  gui:show()
else 
  local gui = EnlinkGui()
  gui:show()
end
