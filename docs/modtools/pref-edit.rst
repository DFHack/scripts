modtools/pref-edit
==================

.. dfhack-tool::
    :summary: Modify unit preferences.
    :tags: unavailable

Add, remove, or edit the preferences of a unit.
Requires a modifier, a unit argument, and filters.

- ``-unit <UNIT ID>``:
    The given unit will be affected.
    If not found/provided, the script will try defaulting to the currently selected unit.

Valid modifiers:

- ``-add``:
    Add a new preference to the unit. Filters describe the preference's variables.
- ``-remove``:
    Remove a preference from the unit. Filters describe what preference to remove.
- ``-has``:
    Checks if the unit has a preference matching the filters. Prints a message in the console.
- ``-removeall``:
    Remove all preferences from the unit. Doesn't require any filters.


Valid filters:

- ``-id <VALUE>``:
    This is the ID used for all preferences that require an ID.
    Represents item_type, creature_id, color_id, shape_id, plant_id, poetic_form_id, musical_form_id, and dance_form_id.
    Text IDs (e.g. "TOAD", "AMBER") can be used for all but poetic, musical, and dance.
- ``-item``, ``-creature``, ``-color``, ``-shape``, ``-plant``, ``-poetic``, ``-musical``, ``-dance``:
    Include one of these to describe what the id argument represents.
- ``-type <PREFERENCE TYPE>``:
    This describes the type of the preference. Can be entered either using the numerical ID or text id.
    Run ``lua @df.unit_preference.T_type`` for a full list of valid values.
- ``-subtype <ID>``:
    The value for an item's subtype
- ``-material <ID>``:
    The id of the material. For example "MUSHROOM_HELMET_PLUMP:DRINK" or "INORGANIC:IRON".
- ``-state <STATE ID>``:
    The state of the material. Values can be the numerical or text ID.
    Run ``lua @df.matter_state`` for a full list of valid values.
- ``-active <TRUE/FALSE>``:
    Whether the preference is active or not (?)


Other arguments:

- ``-help``:
    Shows this help page.

Example usage:

- Like drinking dwarf blood::

    modtools/pref-edit -add -item -id DRINK -material DWARF:BLOOD -type LikeFood
