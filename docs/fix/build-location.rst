
fix/build-location
==================
Fixes construction jobs that are stuck trying to build a wall while standing
on the same exact tile (:bug:`5991`), designates the tile restricted traffic to
hopefully avoid jamming it again, and unsuspends them.
