modtools/fire-rate
==================

.. dfhack-tool::
    :summary: Alter the fire rate of ranged weapons.
    :tags: unavailable

Allows altering the fire rates of ranged weapons. Each are defined on a per-item
basis. As this is done in an on-world basis, commands for this should be placed
in an ``onLoad*.init``. This also technically serves as a patch to any of the
weapons targeted in adventure mode, reducing the times down to their intended
speeds (the game applies an additional hardcoded recovery time to any ranged
attack you make in adventure mode).

Once run, all ranged attacks will use this script's systems for calculating
recovery speeds, even for items that haven't directly been modified using this
script's commands. One minor side effect is that it can't account for
interactions with the ``FREE_ACTION`` token; interactions with that tag which
launch projectiles will be subject to recovery times (though there aren't any
interaction in vanilla where this would happen, as far as I know).

Requires a Target and any number of Modifiers.

Targets:

:-item <item token>:
  The full token of the item to modify.
  Example: ``WEAPON:ITEM_WEAPON_BOW``
:-throw:
  Modify the fire rate for throwing.
  This is specifically for thrown attacks without a weapon - if you have a
  weapon that uses ``THROW`` as its skill, you need to use the ``-item``
  argument for it.

Modifiers:

:-material <material token>:
  Apply only to items made of the given material token. With the ``-item``
  argument, this will apply to the material that the weapon is made of, whereas
  with the ``-throw`` argument this will apply to the material being thrown (or
  fired, in the case of interactions). This is optional.
  Format examples: "CREATURE:COW:MILK", "PLANT:MUSHROOM_HELMET_PLUMP:DRINK",
  "INORGANIC:GOLD", "VOMIT"
:-fortBase <integer> -advBase <integer>:
  Set the base fire rate for the weapon in ticks to use in the respective mode
  (fortress/adventure). Means one shot per x ticks. Defaults to the game default
  of 80.
:-fortSkillFactor <float> -advSkillFactor <float>:
  Multiplier that modifies how effective a user's skill is at improving the fire
  rate in the respective modes. In basic mode, recovery time is reduced by this
  value * user's skill ticks. Defaults to 2.7. With that value and default
  settings, it will make a Legendary shooter fire at the speed cap.
:-fortCap <integer> -advCap <integer>:
  Sets a cap on the fastest fire rate that can be achieved in their respective
  mode. Due to game limitations, the cap can't be less than 10 in adventure
  mode. Defaults to half of the base fire rate defined by the ``-fort`` or
  ``-adv`` arguments.

Other:

:-mode <"basic" | "vanilla">:
  Sets what method is used to determine how skill affects fire rates. This is
  applied globally, rather than on a per-item basis. Basic uses a simplified
  method for working out fire rates - each point in a skill reduces the fire
  cooldown by a consistent, fixed amount. This method is the default.
  Vanilla mode attempts to replicate behaviour for fire rates - skill rolls
  determine which of 6 fixed increments of speeds is used, with a unit's skill
  affecting the range and averages. **NOT YET IMPLEMENTED!**
