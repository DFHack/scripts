-- Detects citizens stuck in trees

--[====[

warn-stuck-trees
================

Displays an announcement for any civilians detected stuck in trees. Intended to
be run with `repeat`.

By default, the game pauses and recenters when an announcement is made. This
behavior can be changed with the following flags:

- ``-no-recenter``: Do not recenter on stuck dwarves.
- ``-no-pause``: Do not pause the game. This flag is not recommended unless
  ``-no-recenter`` is used as well.

]====]

args = require("utils").processArgs{...}

announcement_flags = {
    D_DISPLAY = true,
    PAUSE = not args["no-pause"],
    RECENTER = not args["no-recenter"],
}

function getName(unit)
    local name = dfhack.TranslateName(dfhack.units.getVisibleName(unit))
    if name == '' then
        name = dfhack.units.getProfessionName(unit)
    end
    return name
end

for _, unit in pairs(df.global.world.units.all) do
    if dfhack.units.isCitizen(unit) then
        if df.tiletype.attrs[dfhack.maps.getTileType(unit.pos)].material == df.tiletype_material.TREE then
            dfhack.gui.makeAnnouncement(0, announcement_flags, unit.pos,
                getName(unit) .. ' is stuck in a tree', COLOR_LIGHTMAGENTA)
        end
    end
end
