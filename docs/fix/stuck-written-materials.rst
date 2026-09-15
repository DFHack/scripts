fix/stuck-written-materials
===========================

.. dfhack-tool::
    :summary: Allow bugged written materials to be interacted with again.
    :tags: fort bugfix items

Fixes books, quires, and scrolls that are stuck permanently in a job that no
longer exists. This can happen, for example, when a visitor that was reading
or carrying a written work joins the fortress, or when squads return from
missions with written materials.

This works around the same family of issues as `fix/stuck-instruments`
(:bug:`9485`), and should be run if you notice any written materials that
cannot be hauled or interacted with.


Usage
-----

``fix/stuck-written-materials``
    Fixes item data for all stuck written materials on the map.
``fix/stuck-written-materials -n``, ``fix/stuck-written-materials --dry-run``
    List how many written materials would be fixed without performing the
    action.
