fix/protect-nicks
=================

.. dfhack-tool::
    :summary: Fix nicknames being erased or not displayed.
    :tags: fort bugfix units

Due to a bug, units nicknames are not displayed everywhere and are occasionally
lost.

`fix/protect-nicks` will save the nicknames of the units once an in-game day. It
works by setting the same nickname to the unit's corresponding "historical
figure", which was the behavior on pre-Steam releases.

After running it, the nicknames are properly displayed in locations such as
legends or image descriptions. Additionally, they are no longer lost after
killing a forgotten beast or retiring a fort.

Usage
-----

``enable fix/protect-nicks``
    Enable daily saving of the nicknames.

``disable fix/protect-nicks``
    Disable the daily check.

``fix/protect-nicks now``
    Immediately save the nicknames.
