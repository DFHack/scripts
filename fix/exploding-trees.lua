-- removes "phantom" trees before they can explode.
--[====[
fix/exploding-trees
===================

By default, this script runs once a month by the Control Panel's Bug Fixes tab.

This script mitigates a longstanding Dwarf Fortress bug.

Once a year, trees check if they should grow.  The exact day and time of this
growth is different for every tree.

Occasionally, when a tree is cut down or otherwise removed from the game, the
game engine doesn't remove the tree's data from the list of plants.  The exact
details of this are not currently understood.

For some reason, these "phantom" trees will sometimes collapse during this
growth.  This can stun, injure, or kill units which happen to be near this
collapse.

This script finds those trees and sets their dead flag, preventing them from
growing and collapsing.
--]====]

function suppress_phantom_exploding_trees()
    for idx, tree in ipairs(df.global.world.plants.all) do
        if      not tree.damage_flags.dead
            and tree.tree_info ~= nil
            and (tree.type == df.plant_type.DRY_TREE
                or tree.type == df.plant_type.WET_TREE)
        then
            local tt = dfhack.maps.getTileType(tree.pos)
            local is_trunk = df.tiletype.attrs[tt].material == df.tiletype_material.TREE
            if not is_trunk then
                tree.damage_flags.dead = true
                local announcement = string.format(
                    "DFHack %s: phantom tree %d at location (%d,%d,%d) suppressed.",
                    dfhack.current_script_name(), idx, tree.pos.x, tree.pos.y, tree.pos.z)
                dfhack.printerr(announcement)
            end
        end
    end
end

suppress_phantom_exploding_trees()