--@ module = true
-- This script defines a DFHack overlay widget that augments the Petitioners screen
-- by showing additional information about the units involved in a selected petition.

local gui = require('gui')              -- GUI helpers (pens, frames, layout)
local overlay = require('plugins.overlay') -- Overlay framework (OverlayWidget base)
local widgets = require('gui.widgets')  -- Standard DFHack UI widgets (List, Panel, Label, etc.)
local utils = require('utils')          -- Misc DFHack utilities

-- -------------------
-- Utility functions
-- -------------------

-- Determines which petition row is currently selected in the vanilla UI
-- by comparing screen texture positions. This is a heuristic that tracks
-- which row's screen texpos matches the initially captured value.
function getActivePetitionRow(self)
    local starty = 6                     -- Y offset where the first petition row starts
    local steps = 3                      -- Vertical spacing between petition rows
    local listlength = #df.global.plotinfo.petitions -- Number of petitions currently listed
    local gps = df.global.gps            -- Global screen state (texture positions, dimensions)
    if not gps then 
        return nil                       -- If GPS is unavailable, we cannot determine selection
    end

    -- Capture the initially selected texpos once. This serves as the reference
    -- value that identifies the currently highlighted row.
    if self.tocheck == nil or self.tocheck == 0 then
        self.tocheck = gps.screentexpos_lower[6 * gps.dimy + starty] or 0
        --print("tocheck " .. self.tocheck)
    end

    -- Iterate over all visible petition rows and compare their texpos
    -- against the captured reference. The matching row index is returned.
    for i = 0, listlength - 1 do
        local y = starty + i * steps
        local idx = (6 * gps.dimy) + y
        local tex = gps.screentexpos_lower[idx] or 0

        if tex == self.tocheck then
            return i                     -- Found the active petition row
        end
    end
    return nil
end

-- Helper that returns a localized caste/profession name for a unit
local function get_caste_name(race, caste, profession)
    return dfhack.units.getCasteProfessionName(race, caste, profession)
end

-- -------------------
-- PetitionersOverlay
-- -------------------

-- Define a new overlay widget that attaches to the Petitioners screen
PetitionersOverlay = defclass(PetitionersOverlay, overlay.OverlayWidget)
PetitionersOverlay.ATTRS{
    desc="Add information about the petitioners to the Petition screen", -- Short description
    default_enabled=true,          -- Overlay is enabled by default
    version=3,                     -- Config version for migration/reset
    viewscreens={'dwarfmode/Petitions'}, -- Only active on the Petitions screen
    frame_background=gui.CLEAR_PEN, -- Transparent background
}

-- Initialization runs once when the widget is created
function PetitionersOverlay:init()
    self.firstrender = true         -- Flag to perform one-time setup on first render
    self.tocheck = nil              -- Stored texpos reference for row detection
    self.last_petitions_size = #df.global.plotinfo.petitions -- Track petition count
    self.last_selected_petition = 0 -- Track currently selected petition index
    self.frame = { l=0, t=0, r=0, b=0 } -- Base frame; child widgets define actual layout

    -- Define child views for this overlay
    self:addviews{
        -- List showing petitioners and summary info
        widgets.List{
            frame={l=60, r=28, t=30, b=14}, -- Position relative to screen edges
            frame_style=gui.FRAME_INTERIOR,
            view_id='list',               -- Identifier for lookup via self.subviews
            on_select=self:callback('onZoom'), -- Called when selection changes
        },
        -- Footer panel containing extended description text
        widgets.Panel{
            view_id='footer',
            frame={l=6, r=28, b=3, h=10},
            frame_style=gui.FRAME_INTERIOR,
            subviews={
                -- Wrapped label that shows detailed skill info for the selected unit
                widgets.WrappedLabel{
                    frame={l=0, h=7},
                    view_id='desc',
                    auto_height=false,
                    -- Text is computed dynamically based on the current list selection
                    text_to_wrap=function()
                        local _, choice = self.subviews.list:getSelected()
                        return choice and choice.text_long or ''
                    end,
                },
            },
        },
    }
end

-- Builds or refreshes the list contents based on the currently selected petition
function PetitionersOverlay:initListChoices()
    local choices = {}               -- Accumulates entries for the List widget

    local agmt_id = df.global.plotinfo.petitions[self.last_selected_petition]
    if not agmt_id then
        --print("no id for selected petition or selected petition invalid")              -- No petition selected
        return
    end
    local agmt = df.global.world.agreements.all[agmt_id]
    if not agmt then 
        --print("error no petition found")
        return
    end

    local party0 = agmt.parties[0]   -- First party involved in the agreement

    -- Collect all historical figure IDs associated with this petition
    local histfig_ids = {}
    if #party0.histfig_ids > 0 then
        -- Direct histfig references
        for _, hf_id in ipairs(party0.histfig_ids) do histfig_ids[hf_id] = true end
    elseif #party0.entity_ids > 0 then
        -- Indirect references via an entity
        local ent = df.global.world.entities.all[party0.entity_ids[0]]
        if ent then
            for _, hf in ipairs(ent.hist_figures) do histfig_ids[hf.id] = true end
        end
    end

    -- Iterate over collected historical figures and resolve them to active units
    for hf_id, _ in pairs(histfig_ids) do
        local u = nil
        for _, unit in ipairs(df.global.world.units.active) do
            if unit.hist_figure_id == hf_id then
                u = unit                -- Found the active unit for this histfig
                break
            end
        end

        if u then
            -- Resolve and localize unit names
            local u_name = dfhack.translation.translateName(u.name)
            local trans_name = dfhack.translation.translateName(u.name, true, true)
            local u_caste = get_caste_name(u.race, u.caste, u.profession)
            local u_race = dfhack.units.getRaceName(u) == "DWARF" and " (DWARF)" or ""

            local info_text = ""        -- Long description text (skills)
                
            -- Collect skills with rating > 0
            if u.status.current_soul.skills then
                local skills_copy = {}
                for _, skill in ipairs(u.status.current_soul.skills) do
                    if skill.rating > 0 then
                        table.insert(skills_copy, skill)
                    end
                end

                -- Sort skills by rating, highest first
                table.sort(skills_copy, function(a, b)
                    return a.rating > b.rating
                end)

                -- Append skill names and ratings into a single string
                for _, skill in ipairs(skills_copy) do
                    info_text = info_text .. df.job_skill[skill.id] .. ": " .. skill.rating .. "  "
                end
            end

            if info_text == "" then info_text = "None" end

            -- Short text shown in the list, long text shown in the footer
            local text = u_name .. " (" .. trans_name .. ") - " .. u_caste .. u_race
            local text_long = info_text

            table.insert(choices, {text=text, text_long=text_long, data={unit=u}})
        end
    end

    -- Apply the built choices to the List widget
    self.subviews.list:setChoices(choices)
end

-- Checks whether the petition list size or selected petition has changed
-- and refreshes the list contents if necessary
function PetitionersOverlay:ListChangeCheck()
    local current_size = #df.global.plotinfo.petitions
    if current_size < 1 then 
        self.subviews.list:setChoices({})
        return 
    end
    local current_selected = getActivePetitionRow(self)
    if current_selected == nil then return end
    if current_size ~= self.last_petitions_size or current_selected ~= self.last_selected_petition then
        self.last_petitions_size = current_size
        self.last_selected_petition = current_selected
        --print("Petitions list or selection changed: " .. current_size)
        self:initListChoices()
    end
end

-- Called every render frame while the overlay is visible
function PetitionersOverlay:onRenderFrame(dc, rect)
    -- Perform one-time initialization on the first render
    if self.firstrender == nil or self.firstrender then
        --print("first render" )
        self:initListChoices()
        self.firstrender = false
    end

    -- Continuously monitor for petition list or selection changes
    self:ListChangeCheck()
end

-- Called when the user selects an entry in the list
-- Zooms the camera to the selected unit and updates layout if needed
function PetitionersOverlay:onZoom()
    local _, choice = self.subviews.list:getSelected()
    if not choice then return end
    local unit = choice.data.unit
    local target = xyz2pos(dfhack.units.getPosition(unit))
    dfhack.gui.revealInDwarfmodeMap(target, true, true)
    local desc = self.subviews.desc
    if desc.frame_body then desc:updateLayout() end
end

-- Register this overlay widget so DFHack can discover and load it
OVERLAY_WIDGETS = {PetitionersOverlay=PetitionersOverlay}
