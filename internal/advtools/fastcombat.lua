--@ module=true
local overlay = require('plugins.overlay')
local gui = require('gui')
local widgets = require('gui.widgets')

-- Overlay
AdvCombatOverlay = defclass(AdvCombatOverlay, overlay.OverlayWidget)
AdvCombatOverlay.ATTRS{
    desc='Skip combat animations and announcements with a click or key press.',
    default_enabled=true,
    viewscreens='dungeonmode',
    fullscreen=true,
    default_pos={x=1, y=7},
    frame={h=15},
}

function AdvCombatOverlay:init()
    self.skip_combat = false

    self:addviews{
        widgets.Panel{
            frame={w=113},
            view_id='announcement_panel_mask'
        }
    }
end

function AdvCombatOverlay:preUpdateLayout(parent_rect)
    self.frame.w = parent_rect.width
end

function AdvCombatOverlay:render(dc)
    if df.global.adventure.player_control_state == df.adventure_game_loop_type.TAKING_INPUT then
        self.skip_combat = false
        return
    end
    if self.skip_combat then
        -- Instantly process the projectile travelling
        df.global.adventure.projsubloop_visible_projectile = false
        -- Skip the combat swing animations
        df.global.adventure.game_loop_animation_timer_start = df.global.adventure.game_loop_animation_timer_start + 1000
    end
end


local COMBAT_MOVE_KEYS = {
    _MOUSE_L=true,
    SELECT=true,
    A_MOVE_N=true,
    A_MOVE_S=true,
    A_MOVE_E=true,
    A_MOVE_W=true,
    A_MOVE_NW=true,
    A_MOVE_NE=true,
    A_MOVE_SW=true,
    A_MOVE_SE=true,
    A_MOVE_SAME_SQUARE=true,
    A_ATTACK=true,
    A_COMBAT_ATTACK=true,
}

function AdvCombatOverlay:onInput(keys)
    for code,_ in pairs(keys) do
        if not COMBAT_MOVE_KEYS[code] then goto continue end
        if df.global.adventure.player_control_state ~= df.adventure_game_loop_type.TAKING_INPUT then
            -- Instantly speed up the combat
            self.skip_combat = true
        elseif df.global.world.status.temp_flag.adv_showing_announcements then
            -- Don't let mouse skipping work when you click within the adventure mode announcement panel
            if keys._MOUSE_L and self.subviews.announcement_panel_mask:getMousePos() then
                return
            end
            -- Instantly process the projectile travelling
            -- (for some reason, projsubloop is still active during "TAKING INPUT" phase)
            df.global.adventure.projsubloop_visible_projectile = false

            -- If there is more to be seen in this box...
            if df.global.world.status.temp_flag.adv_have_more then
                -- Scroll down to the very bottom
                df.global.world.status.adv_scroll_position = #df.global.world.status.adv_announcement - 10
            -- Nothing new left to see, get us OUT OF HERE!!
            else
                -- Allow us to quit out of showing announcements by clicking anywhere OUTSIDE the box
                df.global.world.status.temp_flag.adv_showing_announcements = false
            end
        end
        ::continue::
    end
end
