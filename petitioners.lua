--@ module = true
-- This script defines a DFHack overlay widget that augments the Petitioners screen
-- by showing additional information about the units involved in a selected petition.

local gui = require('gui')              -- GUI helpers (pens, frames, layout)
local overlay = require('plugins.overlay') -- Overlay framework (OverlayWidget base)
local widgets = require('gui.widgets')  -- Standard DFHack UI widgets (List, Panel, Label, etc.)

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
    self.last_petitions_size = #df.global.plotinfo.petitions -- Track petition count
    self.frame = { l=0, t=0, r=0, b=0 } -- Base frame; child widgets define actual layout

    -- Define child views for this overlay
    self:addviews{
        -- List showing petitioners and summary info
        widgets.Panel{
            frame={l=6, r=28, b=3, h=10},
            frame_style=gui.FRAME_INTERIOR,
            frame_background=gui.CLEAR_PEN,
            subviews={
                widgets.List{
                    view_id='list',               -- Identifier for lookup via self.subviews
                    on_select=self:callback('onSelect'), -- Called when selection changes
                },
            },
        },

        -- Info panel containing extended description text
        widgets.Panel{
            frame={l=60, r=28, t=30, b=14},
            frame_style=gui.FRAME_INTERIOR,
            subviews={
                -- Wrapped label that shows detailed skill info for the selected unit
                widgets.Label{
                    view_id='desc',
                    auto_height=false,
                    -- Text is computed dynamically based on the current list selection
                    text='',
                },
            },
        },
    }
end

-- Builds or refreshes the list contents based on the currently selected petition
function PetitionersOverlay:SetListChoices()
    if  #df.global.plotinfo.petitions == 0 then 
        self.subviews.list:setChoices({})
        self.subviews.desc:setText("")
        self.subviews.desc:updateLayout()
        return
    end
    
    local agmt_id = df.global.game.main_interface.petitions.selected_agreement_id
    local agmt = df.global.world.agreements.all[agmt_id]
    local party = agmt.parties[0]   -- First party involved in the agreement

    -- Collect all historical figure IDs associated with this petition
    local histfig_ids = {}
    if #party.histfig_ids > 0 then
        -- Direct histfig references
        for _, hf_id in ipairs(party.histfig_ids) do histfig_ids[hf_id] = true end
    elseif #party.entity_ids > 0 then
        -- Indirect references via an entity
        local ent = df.historical_entity.find(party.entity_ids[0])
        if ent then
            for _, hf in ipairs(ent.hist_figures) do histfig_ids[hf.id] = true end
        end
    end
    

    local choices = {}               -- Accumulates entries for the List widget

    -- Iterate over collected historical figures and resolve them to active units
    for hf_id, _ in pairs(histfig_ids) do
        local hf = df.historical_figure.find(hf_id)
        local u = (hf) and df.unit.find(hf.unit_id) or nil

        if u then
            -- Resolve and localize unit names
            local u_name = dfhack.translation.translateName(u.name)
            local trans_name = dfhack.translation.translateName(u.name, true, true)
            local u_caste = dfhack.units.getCasteProfessionName(u.race, u.caste, u.profession)

            local lines = {}

            if u.status.current_soul.skills then
                local skills_copy = {}

                for _, skill in ipairs(u.status.current_soul.skills) do
                    if skill.rating > 0 then
                        table.insert(skills_copy, skill)
                    end
                end

                table.sort(skills_copy, function(a, b)return a.rating > b.rating end) --sort skills high to low

                for _, skill in ipairs(skills_copy) do
                    --local skill_name_pen = COLOR_CYAN       -- for skill name
                    --local skill_rating_pen = COLOR_WHITE    -- for rating

                    table.insert(lines, { text = string.format("%-26s", df.job_skill[skill.id]), pen = COLOR_RED })
                    table.insert(lines, { text = string.format(" %2d", skill.rating), pen = COLOR_BLUE })
                    table.insert(lines, NEWLINE)
                end
            end

            -- Short text shown in the list, long text shown in the info panel
            local text = u_name .. " (" .. trans_name .. ") - " .. u_caste
            local text_long = (#lines > 0) and lines or ''

            table.insert(choices, {text=text, text_long=text_long, data={unit=u}})
        end
    end

    -- Apply the built choices to the List widget
    self.subviews.list:setChoices(choices)
end

-- Called every render frame while the overlay is visible
function PetitionersOverlay:onRenderFrame(dc, rect)
    if not df.global.game.main_interface.petitions.open then return end
    self:SetListChoices()
end

-- Called on selection of an entry in the list
-- Updates description text and zooms the camera to the selected unit
function PetitionersOverlay:onSelect()
    local _, choice = self.subviews.list:getSelected()
    if not choice then return end

    self.subviews.desc:setText(choice.text_long or '')
    self.subviews.desc:updateLayout()

    local unit = choice.data.unit
    local target = xyz2pos(dfhack.units.getPosition(unit))
    dfhack.gui.revealInDwarfmodeMap(target, true, true)
end

-- Register this overlay widget so DFHack can discover and load it
OVERLAY_WIDGETS = {PetitionersOverlay=PetitionersOverlay}
