
stripcaged
==========
For dumping items inside cages. Will mark selected items for dumping, then
a dwarf may come and actually dump them (or you can use `autodump`).

Arguments:

:list:      display the list of all cages and their item content on the console
:items:     dump items in the cage, excluding stuff worn by caged creatures
:weapons:   dump equipped weapons
:armor:     dump everything worn by caged creatures (including armor and clothing)
:all:       dump everything in the cage, on a creature or not

Without further arguments, all commands work on all cages and animal traps on
the map. With the ``here`` argument, considers only the in-game selected cage
(or the cage under the game cursor). To target only specific cages, you can
alternatively pass cage IDs as arguments::

  stripcaged weapons 25321 34228

