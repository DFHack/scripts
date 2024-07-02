-- Fixes shooting/throwing options stacking on each other, causing null pointers and crashes
--@ module = true

local aim_projectile = df.global.game.main_interface.adventure.aim_projectile

local overlay = require('plugins.overlay')

FixShootingOverlay = defclass(FixShootingOverlay, overlay.OverlayWidget)
FixShootingOverlay.ATTRS{
    desc='Fixes Shooting your weapon breaking your Throw action.',
    default_enabled=true,
    viewscreens={
        'dungeonmode/Inventory',
        'dungeonmode/AimProjectile'
    },
    frame={w=0, h=0},
}

function FixShootingOverlay:onInput()
    if aim_projectile.open == false then
        aim_projectile.shooter_it = nil
        aim_projectile.ammo_it = nil
        aim_projectile.thrown_it = nil
        aim_projectile.shooting = false
    elseif aim_projectile.shooting then
        aim_projectile.thrown_it = nil
    end
end
