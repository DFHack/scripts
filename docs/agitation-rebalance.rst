agitation-rebalance
===================

.. dfhack-tool::
    :summary: Make agitated wildlife and cavern invasions less persistent.
    :tags: fort gameplay

The DF agitation (or "irritation") system gives you challenges to face when
your dwarves impact the natural environment. It adds new depth to gameplay, but
it can also quickly drag the game down, both with constant incursions of
agitated animals and with FPS-killing massive buildups of hidden invaders in
the caverns. This mod changes how the agitation system behaves to ensure the
challenge remains fun and scales appropriately according to your dwarves'
current activities.

In short, this mod changes irritation-based attacks from a constant flood to a
system that is responsive to your recent actions on the surface and in the
caverns. If you irritate the natural environment enough, you will be attacked
exactly once. You will not be attacked further unless you continue to
antagonize nature. This mod can be enabled (and auto-started for new forts, if
desired) on the "Gameplay" tab of `gui/control-panel`.

Usage
-----

::

    enable agitation-rebalance
    agitation-rebalance [status]
    agitation-rebalance preset <name>
    agitation-rebalance enable|disable <feature>

When run without arguments (or with the ``status`` argument), it will print out
whether it is enabled, the current configuration, how many agitated creatures
and (visible) cavern invaders are on the map, and your current chances of
suffering retaliation on the surface and in each of the cavern layers.

The `Presets`_ allow you to quickly set the game irritation-related difficulty
settings to tested, balanced values. You can adjust them further (or set your
own values) on the DF difficulty settings screen. Note that
``agitation-rebalance preset`` can be used to set the difficulty settings even
if the mod is not enabled. Even with vanilla mechanics, the presets are still
handy.

Finally, each feature of the mod can be individually enabled or disabled. More
details in the `Features`_ section below.

Examples
--------

``agitation-rebalance preset lenient``
    Load the ``lenient`` preset, which allows for a fair amount of tree cutting
    and other activity between attacks. This preset is loaded automatically if
    the ``auto-preset`` feature enabled (it's enabled by default) and you have
    the "Enemies" difficulty settings at their default "Normal" values.

``enable agitation-rebalance``
    Manually enable the mod (not needed if you are using `gui/control-panel`)

``agitation-rebalance enable monitor``
    Enables an overlay that shows the current chances of being attacked on the
    surface or in the caverns. The danger ratings shown on the overlay are
    accurate regardless of whether ``agitation-rebalance`` is enabled, so you
    can use the monitor even if you're not using the mod.

How the DF agitation system works
---------------------------------

The surface
~~~~~~~~~~~

For the surface wilderness in savage biomes (non-savage biomes will never see
agitated wildlife), DF maintains a counter. Your dwarves increase the counter
when they chop down trees or catch fish. Once it crosses a threshold, wildlife
that enters the map has a chance of becoming agitated and aggressively attacking
your units. This chance increases the higher the counter rises. Once a year,
the counter is decremented by a fixed amount.

Only one group of wildlife can be on the surface at a time. When you kill all
the creatures in a group, or when they finally wander off on their own, the
game spawns a new group to replace them. Each new group rolls against the
current surface irritation counter for a chance to become agitated.

Since agitated wildlife seeks out your units to attack, they are often quickly
destroyed -- if they don't quickly destroy *you* -- and a new wave will spawn.
The new wave will have a similar chance to the previous wave for becoming
agitated. This means that once you cross the threshold that starts the
agitation attacks, you may suffer near-constant retribution until you stop all
tree cutting and fishing on the surface and hide for sufficient time (years)
until the counter falls low enough again.

The caverns
~~~~~~~~~~~

DF similarly maintains counters for each cavern layer, with chances of cavern
invasion and forgotten beast attack independently checked once per season. The
cavern irritation counter is increased for tree felling and fishing within the
cavern. Moreover, doing anything that makes :wiki:`noise` will increase the
irritation. For example, digging anywhere within the cavern's z-level range
(even if it is not in the open space of the cavern itself) will raise the
cavern's irritation level.

The chance of cavern invasion increases linearly with respect to irritation
until it reaches 100% after about 100 cavern trees felled. While irritation
chances are calculated separately for each cavern layer, only one attack may
occur per season. The upper cavern layers get rolled first, so even if all
layers have the same irritation level, invasions will tend to happen in the
uppermost layer. There are no player-configurable settings to change the cavern
invasion thresholds. Regardless of irritation level, cavern invasions do not
spawn until the cavern layer is discovered by the current fort.

The chance of forgotten beast attack in a particular layer is affected by the
cavern layer's irritation level, but your fortress's wealth has a much greater
impact. Even with an irritation level of zero, a wealthy fortress will
encourage forgotten beasts to attack at their maximum rate. The chance of
forgotten beast attack is capped at 33% per layer, but unlike cavern invasions,
you can have as many forgotten beast attacks in a season as you have layers.
With high irritation and/or high fortress wealth, forgotten beasts can invade a
cavern before you discover it.

You can wall off the caverns to insulate your fort from the invasions, but
invaders will continue to spawn and build up over time. Cavern invaders spawn
hidden, so you will not be aware that they are there until you send a unit in
to investigate. Eventually, your FPS will be impacted by the large numbers of
cavern invaders. The irritation counters for the cavern layers do not decay over
time, so once attacks begin, cavern invasions will occur once a season
thereafter, regardless of the continued presence of previous invaders.

Irritation counters are saved with the cavern layer in the world region, which
extends beyond the boundaries of your current fort. If you retire a fort and
start another one nearby, the caverns will retain any irritation added by the
first fort. This means that new forts may start with already-irritated caverns
and meet with immediate resistence.

The settings
~~~~~~~~~~~~

There are several variables that affect the behavior of this system, all
customizable in the DF difficulty settings:

``Wilderness irritation minimum``
    While the surface irritation counter is below this value, no agitated
    wildlife will appear.
``Wilderness sensitivity``
    After the surface irritation counter rises above the minimum, this value
    represents the range over which the chance of attack increases from 0% to
    100%.
``Wilderness irritation decay``
    This is the amount that the surface irritation counter decreases per year,
    regardless of activity. Due to a bug in DF, the widget for this setting in
    the difficulty settings panel always displays and controls the value for
    ``Wilderness irritation minimum`` and thus the setting cannot be changed in
    the vanilla interface from its default value of 500 (if initialized by the
    "Normal" vanilla preset) or 100 (if initialized by the "Hard" vanilla
    preset).
``Cavern dweller maximum attackers``
    This controls the maximum number of cavern invaders that can spawn in a
    single invasion. If ``agitation-rebalance`` is not managing the invader
    population, the number of invaders in the caverns can grow beyond this
    number if the invaders from a previous invasion are still alive.
``Cavern dweller scale``
    Each time your civilization is attacked, the number of attackers in a
    single cavern invasion increases by this value. The total number of
    attackers is still capped by ``Cavern dweller maximum attackers``.
``Forgotten beast wealth divisor``
    Your fortress wealth is divided by this number and the result is added to a
    cavern's "natural" irritation to get the effective irritation that a
    forgotten beast rolls against for a chance to attack.
``Forgotten beast irritation minimum``
    While a cavern's effective irritation (see
    ``Forgotten beast wealth divisor``) is below this value, no forgotten
    beasts will invade that cavern.
``Forgotten beast sensitivity``
    After the cavern's effective irritation rises above the minimum, this value
    represents the range over which the chance of forgotten beast attack
    increases from 0% to 100%.

What does this mod do?
----------------------

When enabled, this mod makes the following changes:

When agitated wildlife enters the map on the surface, the surface irritation
counter is set to the value of ``Wilderness irritation minimum``, ensuring
that the *next* group of widlife that enters the map will *not* be agitated.
This means that the incursions act more like a warning shot than an open
floodgate. You will not be attacked again unless you continue your activities
on the surface that raise the chance of a subsequent attack.

The larger the value of ``Wilderness sensitivity``, the more you can irritate
the surface before you suffer another incursion. For reference, each tree
chopped adds 100 to the counter, so a ``Wilderness irritation minimum``
value of 3500 and a ``Wilderness sensitivity`` value of 10000 will allow you to
initially chop 35 trees before having any chance of being attacked by agitated
creatures. Each tree you chop beyond those initial 35 raises the chance that
the next wave of wildlife will be agitated by 1%.

If you cross a year boundary, then you will have additional leniency granted by
the ``Wilderness irritation decay`` value (if it is set to a value greater than
zero).

For the caverns, we don't want to adjust the irritation counters directly since
that would negatively affect the chances of being attacked by (the much more
interesting) forgotten beasts. Instead, when a cavern invasion begins, we
record the current irritation counter value and effectively use that as the new
"minimum". A "sensitivity" value is synthesized from the average of the values
of ``Wilderness irritation minimum`` and ``Wilderness sensitivity``. This makes
cavern invasions behave similarly to surface agitation and lets it be
controlled by the same difficulty settings. The parameters for forgotten beast
attacks can still be controlled independently of this mod.

Finally, if you have walled yourself off from the danger in the caverns, yet you
continue to irritate nature down there, this mod will ensure that the number of
active cavern invaders, cumulative across all cavern levels, never exeeds the
value set for ``Cavern dweller maximum attackers``. This prevents excessive FPS
loss during gameplay and keeps the number of creatures milling around outside
your gates (or hidden in the shadows) to a reasonable number.

The monitor
~~~~~~~~~~~

You can optionally enable a small monitor panel that displays the current
threat rating for an upcoming attack. The chance of being attacked is shown for
the surface and for the caverns as a whole (so as not to spoil exactly where the
attack will happen). Moreover, to avoid spoiling when a cavern invasion has
begun, the displayed threat rating for the caverns is not reset to "None" (or,
more likely, "Low", since the act of fighting the invaders will have raised the
cavern's irritation a bit) until you have discovered and neutralized the
invaders.

The ratings shown on the overlay are accurate regardless of whether
``agitation-rebalance`` is enabled. That is, if this mod is not enabled, then
the monitor will display ratings according to vanilla mechanics.

Presets
-------

The tree counts in these presets are only estimates. There are other actions
that contribute to irritation other than chopping trees, like fishing.
:wiki:`Noise` also contributes to irritation in the caverns. However, tree
chopping is the most important factor.

``casual``
    - Trees until chance of invasion: 1000
    - Surface invasion chance increase per additional tree: 0.1%
    - Additional allowed trees per year: 1000
    - Trees until risk of next cavern invasion: 1000
    - Max cavern invaders: 0
``lenient``
    - Trees until chance of invasion: 100
    - Surface invasion chance increase per additional tree: 1%
    - Additional allowed trees per year: 50
    - Trees until risk of next cavern invasion: 100
    - Max cavern invaders: 20
``strict``
    - Trees until chance of invasion: 25
    - Surface invasion chance increase per additional tree: 20%
    - Additional allowed trees per year: 10
    - Trees until risk of next cavern invasion: 15
    - Max cavern invaders: 50
``insane``
    - Trees until chance of invasion: 6
    - Surface invasion chance increase per additional tree: 50%
    - Additional allowed trees per year: 2
    - Trees until risk of next cavern invasion: 4
    - Max cavern invaders: 100

After using any of these presets, you can always to go the vanilla difficulty
settings and adjust them further to your liking.

If the ``auto-preset`` feature is enabled and the difficulty settings exactly
match any of the vanilla "Enemies" presets when the mod is enabled, a
corresponding mod preset will be loaded. See the `Features`_ section below for
details.

Features
--------

Features of the mod can be individually enabled or disabled. All features
except for ``monitor`` are enabled by default. Available features are:

``auto-preset``
    Auto-load a preset based on which vanilla "Enemies" preset is active:
    - "Off" loads the "casual" preset
    - "Normal" loads the "lenient" preset
    - "Hard" loads the "strict" preset
    This feature takes effect at the time when the mod is enabled, so if you
    don't want your default vanilla settings changed, be sure to disable this
    feature before enabling ``agitation-rebalance``.
``surface``
    Manage surface agitated wildlife frequency.
``cavern``
    Manage cavern invasion frequency.
``cap-invaders``
    Ensure the number of live invaders in the caverns does not exceed the
    configured maximum.
``monitor``
    Display a panel on the main map showing your chances of an
    irritation-related attack on the surface and in the caverns. See
    `The monitor`_ section above for details. The monitor overlay can also be
    enabled and disabled via `gui/control-panel`, or repositioned with
    `gui/overlay`.

Caveat
------

If a cavern invasion causes the number of active attackers to exceed the
maximum, this mod will gently redirect the excess cavern invaders towards
oblivion as they enter the map. You may notice some billowing smoke near the
edge of the map as the surplus invaders are lovingly vaporized.
