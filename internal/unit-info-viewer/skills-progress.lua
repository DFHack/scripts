--@ module=true

local utils = require("utils")
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')

local view_sheets = df.global.game.main_interface.view_sheets

local function get_skill(id, unit)
    if not unit then return nil end
    local soul = unit.status.current_soul
    if not soul then return nil end
    return utils.binsearch(
        soul.skills,
        view_sheets.unit_skill[id],
        "id"
    )
end

SkillProgressOverlay=defclass(SkillProgressOverlay, overlay.OverlayWidget)
SkillProgressOverlay.ATTRS {
    desc="Display progress bars for learning skills on unit viewsheets.",
    default_pos={x=-43,y=18},
    default_enabled=true,
    viewscreens= {
        'dwarfmode/ViewSheets/UNIT/Skills/Labor',
        'dwarfmode/ViewSheets/UNIT/Skills/Combat',
        'dwarfmode/ViewSheets/UNIT/Skills/Social',
        'dwarfmode/ViewSheets/UNIT/Skills/Other',

        'dungeonmode/ViewSheets/UNIT/Skills/Labor',
        'dungeonmode/ViewSheets/UNIT/Skills/Combat',
        'dungeonmode/ViewSheets/UNIT/Skills/Social',
        'dungeonmode/ViewSheets/UNIT/Skills/Other',
    },
    frame={w=54, h=20},
}

function SkillProgressOverlay:init()
    self.current_uid = -1
    self.current_unit = nil

    self:addviews{
        widgets.Label{
            view_id='annotations',
            frame={t=0, r=0, w=16},
            text='',
            text_pen=COLOR_GRAY,
        },
        widgets.ToggleHotkeyLabel{
            frame={b=0, l=2, w=25},
            label='Progress Bar',
            key='CUSTOM_CTRL_B',
            options={
                {label='No', value=false, pen=COLOR_WHITE},
                {label='Yes', value=true, pen=COLOR_YELLOW},
            },
            view_id='toggle_progress',
            initial_option=true
        },
        widgets.ToggleHotkeyLabel{
            frame={b=0, l=28, w=25},
            label='Experience  ',
            key='CUSTOM_CTRL_E',
            options={
                {label='No', value=false, pen=COLOR_WHITE},
                {label='Yes', value=true, pen=COLOR_YELLOW},
            },
            view_id='toggle_experience',
            initial_option=true
        },
    }
end

function SkillProgressOverlay:preUpdateLayout()
    local screen_width, screen_height = dfhack.screen.getWindowSize()
    self.frame.h = screen_height - 20
end

function SkillProgressOverlay:onRenderFrame(dc, rect)
    local annotations = {}
    if view_sheets.active_id ~= self.current_uid then
        self.current_uid = view_sheets.active_id
        self.current_unit = df.unit.find(self.current_uid)
    end
    if self.current_unit and self.current_unit.portrait_texpos > 0 then
        -- If a portrait is present, displace the bars down 2 tiles
        table.insert(annotations, "\n\n")
    end

    local progress_bar_needed = not dfhack.world.isAdventureMode() or not dfhack.screen.inGraphicsMode()
    self.subviews.toggle_progress.disabled = not progress_bar_needed
    local progress_bar = self.subviews.toggle_progress:getOptionValue() and progress_bar_needed
    local experience = self.subviews.toggle_experience:getOptionValue()

    local margin = self.subviews.annotations.frame.w
    local num_elems = self.frame.h // 3 - 1
    local start = math.min(view_sheets.scroll_position_unit_skill,
        math.max(0,#view_sheets.unit_skill-num_elems))
    local max_elem = math.min(#view_sheets.unit_skill-1,
        view_sheets.scroll_position_unit_skill+num_elems-1)
    for idx = start, max_elem do
        local skill = get_skill(idx, self.current_unit)
        if not skill then
            table.insert(annotations, "\n\n\n\n")
            goto continue
        end
        local rating = df.skill_rating.attrs[math.max(0, math.min(skill.rating, 19))]
        if experience then
            if not progress_bar then
                table.insert(annotations, NEWLINE)
            end
            local level_color = COLOR_GRAY
            local level_chara = "Lv"

            level_color = COLOR_WHITE
            if skill.rating == df.skill_rating.Legendary then
                level_color = COLOR_CYAN
            end

            if skill.rating > df.skill_rating.Legendary then
                level_color = COLOR_LIGHTCYAN
            end

            if skill.demotion_counter > 0 then
                level_color = COLOR_YELLOW
            end

            if skill.rating - skill.demotion_counter < 0 then
                level_color = COLOR_BROWN
            end

            if skill.rating - skill.demotion_counter >= 100 then
                level_chara = "L"
            end

            table.insert(annotations, { text=tostring(
                    level_chara .. skill.rating - skill.demotion_counter
                ),
                width = 7,
                pen = level_color }
            )

            table.insert(annotations, { text=string.format(
                    "%4d/%4d",
                    skill.experience,
                    rating.xp_threshold
                ),
                pen = level_color,
                width = 9,
                rjustify=true, }
            )
        end

        -- 3rd line (last)

        -- Progress Bar
        if progress_bar then
            table.insert(annotations, NEWLINE)
            local percentage = skill.experience / rating.xp_threshold
            local barstop = math.floor((margin * percentage) + 0.5)
            for idx = 0, margin-1 do
                local color = COLOR_LIGHTCYAN
                local char = 219
                -- start with the filled middle progress bar
                local tex_idx = 1
                -- at the beginning, use the left rounded corner
                if idx == 0 then
                    tex_idx = 0
                end
                -- at the beginning, use the right rounded corner
                if idx == margin-1 then
                    tex_idx = 2
                end
                if idx >= barstop then
                    -- offset it to the hollow graphic
                    tex_idx = tex_idx + 3
                    color = COLOR_DARKGRAY
                    char = 177
                end
                table.insert(annotations, { width = 1, tile={tile=df.global.init.load_bar_texpos[tex_idx], ch=char, fg=color}})
            end
        end
        -- End!
        table.insert(annotations, NEWLINE)
        table.insert(annotations, NEWLINE)

        ::continue::
    end
    self.subviews.annotations:setText(annotations)
    self.subviews.annotations:updateLayout()

    SkillProgressOverlay.super.onRenderFrame(self, dc, rect)
end
