fix/protect-nicks
=================

.. dfhack-tool::
    :summary: Restore nicknames when DF loses them.
    :tags: fort bugfix units

Due to a bug, units occasionally lose their nicknames, such as when killing a forgotten beast.

`fix/protect-nicks` will save the nicknames of the units once an in-game day, and restore any removed
nickname.

.. note::
    It does not distinguish between a nickname removed by the player or by a bug. If you want
    to remove a dwarf's nickname, please run ``fix/protect-nicks forget`` immediately after manually
    removing the nickname to reset the tracking.

Usage
-----

``enable fix/protect-nicks``
    Enable daily restoring and saving of the nicknames.

``disable fix/protect-nicks``
    Disable the daily check.

``fix/protect-nicks now``
    Immediately restore lost nicknames. Note for this to work, ``fix/protect-nicks`` must have
    already been enabled when the dwarf lost their nickname.

``fix/protect-nicks forget``
    Forget all the saved nicknames. Useful in order to actually remove nicknames.
