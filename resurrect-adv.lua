local fullHeal = reqscript('full-heal')

if not dfhack.world.isAdventureMode() then
    qerror("This script can only be used in adventure mode!")
end

local adventurer = dfhack.world.getAdventurer()
if not adventurer or not adventurer.flags2.killed then
    qerror("Your adventurer hasn't died yet!")
end

fullHeal.heal(adventurer, true)

-- this ensures that the player will be able to regain control of their unit after
-- resurrection if the script is run before hitting DONE at the "You are deceased" message
df.global.adventure.player_control_state = 1
