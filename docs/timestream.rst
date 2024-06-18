timestream
==========

.. dfhack-tool::
    :summary: Fix FPS death.
    :tags: unavailable

Do you remember when you first start a new fort, your initial 7 dwarves zip
around the screen and get things done so quickly? As a player, you never had
to wait for your initial dwarves to move across the map. Don't you wish that
your fort of 200 dwarves could be as zippy? This tool can help.

``timestream`` keeps the game running quickly by dynamically adjusting the
calendar speed relative to the frames per second that your computer can support.
Your dwarves spend the same amount of in-game time to do their tasks, but the
time that you, the player, have to wait for the dwarves to do things speeds up.
This means that the dwarves in your fully developed fort appears as energetic as
a newly created one, and mature forts are much more fun to play.

If you just want to change the game calendar speed without adjusting dwarf
speed, this tool can do that too. Your dwarves will just be able to get
less/more done per season (depending on whether you speed up or slow down the
calendar).

Usage
-----

``timestream --units [--fps <target FPS>]``
    Keep the game running as responsively as it did when it was running at the
    given frames per second. Dwarves get the same amount done per game day, but
    game days go by faster. If a target FPS is not given, it defaults to 100.
``timestream --rate <rate>``, ``timestream --fps <target FPS>``
    Just change the rate of the calendar, without corresponding adjustments to
    units. Game responsiveness will not change, but dwarves will be able to get
    more (or less) done per game day. A rate of ``1`` is "normal" calendar
    speed. Alternately, you can run the calendar at a rate that it would have
    moved at while the game was running at the specified frames per second.

Examples
--------

``timestream --units``
    Keep the game running as quickly and smoothly as it did when it ran
    "naturally" at 100 FPS. This mode makes things much more pleasant for the
    player without giving any advantage/disadvantage to your in-game dwarves.
``timestream --rate 2``
    Calendar runs at 2x normal speed and units get half as much done as usual
    per game day.
``timestream --fps 100``
    Calendar runs at a dynamic speed to simulate 100 FPS. Units get a varying
    amount of work done per game day, but will get less and less done as your
    fort grows and your unadjusted FPS decreases.
``timestream --rate 1``
    Reset everything back to normal.
