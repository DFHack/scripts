-- Add a display for how much melted metal is stored inside smelters.
--@module = true
--@enable = true
--[====[

gui/melt-remainder
==================
When enabled, a line of text is added to the Tasks screen of melters and magma smelters
that shows how much metal is "stored" as a result of melting items in it. (The base game
has no display of this information,)

Click on the text for more detailed information.

]====]

local overlay = require("plugins.overlay")
local widgets = require("gui.widgets")
-- the existence of this is not documented anywhere of course
local dialogs = require("gui.dialogs")

ENABLED = ENABLED or false

local function i_hate_lua(tbl)
  local worst_language = 0
  for _,_ in pairs(tbl) do
    worst_language = worst_language + 1
  end
  return worst_language
end

local function get_melt_remainders(smelter)
  if not smelter.melt_remainder then return nil end
  local fractions = {}
  local mat_count = #df.global.world.raws.inorganics
  for i = 0, mat_count - 1 do
    local melt_frac = smelter.melt_remainder[i]
    if melt_frac > 0 then
      fractions[i] = melt_frac
    end
  end
  return fractions
end

-- lua doesn't hoist functions nerd emoji
local function popup_full_list()
  local workshop = dfhack.gui.getSelectedBuilding(true)
  if not workshop then return end
  local rems = get_melt_remainders(workshop)
  if not rems then return end

  printall(rems)
  local lines = {}
  for mat_id, tenths in pairs(rems) do
    local mat_name = df.global.world.raws.inorganics[mat_id].id
    table.insert(lines, mat_name .. ": " .. (tenths * 10) .. "%\n")
  end
  if #lines == 0 then
    table.insert(lines, "<There were no melt remainders>")
  end
  dialogs.DialogScreen{
    title = "Melt Remainders",
    message_label_attrs = { text = lines },
  }:show():raise()
end

MeltRemainderOverlay = defclass(MeltRemainderOverlay, overlay.OverlayWidget)
MeltRemainderOverlay.ATTRS = {
  desc = "Displays the fractions of a complete bar 'stored' in the smelter by melting",
  default_pos = { x = -39, y = 41 },
  version = 1,
  default_enabled = true,
  viewscreens = {
    'dwarfmode/ViewSheets/BUILDING/Furnace/Smelter/Tasks',
    'dwarfmode/ViewSheets/BUILDING/Furnace/MagmaSmelter/Tasks',
  },
  frame = { w = 58, h = 1 },
  visible = function() return ENABLED end,
}

function MeltRemainderOverlay:init()
  self:addviews {
    widgets.Label{
      view_id = "the_label",
      text = "<loading...>",
      on_click = popup_full_list,
    }
  }
end

function MeltRemainderOverlay:onRenderBody(painter)
  local workshop = dfhack.gui.getSelectedBuilding(true)
  if not workshop then return end
  local rems = get_melt_remainders(workshop)
  if not rems then return end

  local count = i_hate_lua(rems)
  if count == 0 then
    self.subviews.the_label:setText("No melt remainders.")
  elseif count == 1 then
    -- Singleton material
    local mat_id, tenths = next(rems)
    local mat_name = df.global.world.raws.inorganics[mat_id].id
    self.subviews.the_label:setText("Melting " .. mat_name .. ": " .. (tenths * 10) .. "%")
  else
    self.subviews.the_label:setText(count .. " melt remainders...")
  end
end

OVERLAY_WIDGETS = { melt_remainder = MeltRemainderOverlay }

function isEnabled()
  return ENABLED
end
if dfhack_flags.enable then
  ENABLED = dfhack_flags.enable_state
  return
end

print("gui/melt-remainder is " .. (ENABLED and "enabled" or "disabled") .. ".")
