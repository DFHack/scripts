-- Interface powered, user friendly, unit editor

--[====[

gui/gm-unit
===========
An editor for various unit attributes.

]====]

local widgets = require 'gui.widgets'
local base_editor = reqscript("internal/gm-unit/base_editor")
local args = {...}

rng = rng or dfhack.random.new(nil, 10)

local target
--TODO: add more ways to guess what unit you want to edit
if args[1] ~= nil then
    target = df.units.find(args[1])
else
    target = dfhack.gui.getSelectedUnit(true)
end

if target == nil then
    qerror("No unit to edit") --TODO: better error message
end
local editors = {}
function add_editor(editor_class)
    local title = editor_class.ATTRS.frame_title
    table.insert(editors, {text=title, search_key=title:lower(), on_submit=function(unit)
        editor_class{target_unit=unit}:show()
    end})
end

function weightedRoll(weightedTable)
  local maxWeight = 0
  for index, result in ipairs(weightedTable) do
    maxWeight = maxWeight + result.weight
  end

  local roll = rng:random(maxWeight) + 1
  local currentNum = roll
  local result

  for index, currentResult in ipairs(weightedTable) do
    currentNum = currentNum - currentResult.weight
    if currentNum <= 0 then
      result = currentResult.id
      break
    end
  end

  return result
end


-------------------------------various subeditors---------
------- skill editor
local editor_skills = reqscript("internal/gm-unit/editor_skills")
add_editor(editor_skills.Editor_Skills)

------- civilization editor
local editor_civ = reqscript("internal/gm-unit/editor_civilization")
add_editor(editor_civ.Editor_Civ)

------- counters editor
local editor_counters = reqscript("internal/gm-unit/editor_counters")
add_editor(editor_counters.Editor_Counters)

------- profession editor
local editor_prof = reqscript("internal/gm-unit/editor_profession")
add_editor(editor_prof.Editor_Prof)

------- wounds editor
local editor_wounds = reqscript("internal/gm-unit/editor_wounds")
add_editor(editor_wounds.Editor_Wounds)

------- attributes editor
local editor_attrs = reqscript("internal/gm-unit/editor_attributes")
add_editor(editor_attrs.Editor_Attrs)

------- orientation editor
local editor_orientation = reqscript("internal/gm-unit/editor_orientation")
add_editor(editor_orientation.Editor_Orientation)

------- body / body part editor
local editor_body = reqscript("internal/gm-unit/editor_body")
add_editor(editor_body.Editor_Body)

------- colors editor
local editor_colors = reqscript("internal/gm-unit/editor_colors")
add_editor(editor_colors.Editor_Colors)

------- beliefs editor
local editor_beliefs = reqscript("internal/gm-unit/editor_beliefs")
add_editor(editor_beliefs.Editor_Beliefs)

------- personality editor
local editor_personality = reqscript("internal/gm-unit/editor_personality")
add_editor(editor_personality.Editor_Personality)

-------------------------------main window----------------
Editor_Unit = defclass(Editor_Unit, base_editor.Editor)
Editor_Unit.ATTRS = {
    frame_title = "GameMaster's unit editor"
}

function Editor_Unit:init(args)
    self:addviews{
        widgets.FilteredList{
            frame = {l=1, t=1},
            choices=editors,
            on_submit=function (idx,choice)
                if choice.on_submit then
                    choice.on_submit(self.target_unit)
                end
            end
        },
        widgets.Label{
            frame = { b=0,l=1},
            text = {{
                text = ": exit editor",
                key = "LEAVESCREEN",
                on_activate = self:callback("dismiss")
            }},
        }
    }
end


Editor_Unit{target_unit=target}:show()
