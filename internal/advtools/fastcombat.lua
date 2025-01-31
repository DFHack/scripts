--@ module=true
local overlay = require('plugins.overlay')

-- Overlay
AdvCombatOverlay = defclass(AdvCombatOverlay, overlay.OverlayWidget)
AdvCombatOverlay.ATTRS{
    desc='Faster combat!',
    default_enabled=true,
    viewscreens='dungeonmode',
    fullscreen=true,
    default_pos={x=1,y=1},
    skip_combat = false
}

function AdvCombatOverlay:render()
    if df.global.adventure.player_control_state == df.adventurest.T_player_control_state.TAKING_INPUT then
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
    if AdvCombatOverlay.super.onInput(self, keys) then
        return true
    end
    for code,_ in pairs(keys) do
        if COMBAT_MOVE_KEYS[code] then
            if df.global.adventure.player_control_state ~= df.adventurest.T_player_control_state.TAKING_INPUT then
                -- Instantly speed up the combat
                self.skip_combat = true
            elseif df.global.adventure.player_control_state == df.adventurest.T_player_control_state.TAKING_INPUT then
                if COMBAT_MOVE_KEYS[code] and df.global.world.status.temp_flag.adv_showing_announcements then
                    -- We're using mouse to skip, more unique behavior to mouse clicking is handled here
                    if keys._MOUSE_L then
                        x,y = dfhack.screen.getMousePos()
                        local screen_width, _ = dfhack.screen.getWindowSize()
                        -- Calculate if we're clicking within the vanilla adv announcements box
                        adv_announce_width = 112
                        adv_announce_x1 = screen_width/2 - adv_announce_width/2 - 1
                        adv_announce_x2 = screen_width/2 + adv_announce_width/2 - 1
                        -- The Y values for this box don't change
                        adv_announce_y1, adv_announce_y2 = 6, 20
                        -- Check if we're clicking within the bounds of the adv announcements box that is being shown right now
                        if y >= adv_announce_y1 and y <= adv_announce_y2 and x >= adv_announce_x1 and x <= adv_announce_x2 then
                            -- Don't do anything on our end, the player is clicking within the adv announcements box.
                            -- We don't want to overtake vanilla behavior in this ui element.
                            return
                        end
                    end
                    -- Instantly process the projectile travelling
                    -- (for some reason, projsubloop is still active during "TAKING INPUT" phase)
                    df.global.adventure.projsubloop_visible_projectile = false

                    -- If there is more to be seen in this box...
                    if df.global.world.status.temp_flag.adv_have_more then
                        -- Scroll down 10 paces aka the same way it'd happen if you pressed on "more"
                        df.global.world.status.adv_scroll_position = math.min(df.global.world.status.adv_scroll_position + 10, #df.global.world.status.adv_announcement)
                    -- Nothing new left to see, get us OUT OF HERE!!
                    else
                        -- Allow us to quit out of showing announcements by clicking anywhere OUTSIDE the box
                        df.global.world.status.temp_flag.adv_showing_announcements = false
                    end
                end
            end
        end
    end
end