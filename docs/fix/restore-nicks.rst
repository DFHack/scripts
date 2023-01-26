fix/restore-nicks
=================

.. dfhack-tool::
    :summary: Restore nicknames when DF loses them.
    :tags: fort bugfix units

Due to a bug, units occasionally lose their nicknames, such as when killing a forgotten beast.

`fix/restore-nicks` will save the nicknames of the units once an in-game day, and restore any removed
nickname.

.. note::
    It does not distinguish between a nickname removed by the player or by a bug. If you want
    to remove a dwarf's nickname, please run ``fix/restore-nicks forget`` to reset the tracking.

Usage
-----

``enable fix/restore-nicks``
    Enable daily restoring and saving of the nicknames.

``disable fix/restore-nicks``
    Disable the daily check.

``fix/restore-nicks now``
    Immediately restore lost nicknames. Note for this to work, ``fix/restore-nicks`` must have
    already been enabled when the dwarf lost their nickname.

``fix/restore-nicks forget``
    Forget all the saved nicknames. Useful in order to actually remove nicknames.
