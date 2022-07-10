
combat-harden
=============
Sets the combat-hardened value on a unit, making them care more/less about seeing corpses.
Requires a value and a target.

Valid values:

:``-value <0-100>``:
    A percent value to set combat hardened to.
:``-tier <1-4>``:
    Choose a tier of hardenedness to set it to.
      1 = No hardenedness.
      2 = "is getting used to tragedy"
      3 = "is a hardened individual"
      4 = "doesn't really care about anything anymore" (max)

If neither are provided, the script defaults to using a value of 100.

Valid targets:

:``-all``:
    All active units will be affected.
:``-citizens``:
    All (sane) citizens of your fort will be affected. Will do nothing in adventure mode.
:``-unit <UNIT ID>``:
    The given unit will be affected.

If no target is given, the provided unit can't be found, or no unit id is given with the unit
argument, the script will try and default to targeting the currently selected unit.
