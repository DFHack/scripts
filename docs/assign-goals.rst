assign-goals
============

.. dfhack-tool::
    :summary: Adjust a unit's goals and dreams.
    :tags: fort armok units

Goals are defined with a goal token and a flag indicating whether the goal has
been achieved. For now, this flag should always be set to false. For a list of
possible goals, please run ``devel/query --table df.goal_type`` or see the
:wiki:`wiki <Personality_trait>`.

Bear in mind that nothing will stop you from assigning zero or multiple goals,
but it's not clear how that will affect the game.

Usage
-----

::

    assign-goals [--unit <id>] <options>

Example
-------

::

    assign-goals --reset --goals [ MASTER_A_SKILL false ]

Clears all the selected unit goals, then sets the "master a skill" goal. The
final result will be: "dreams of mastering a skill".

Options
-------

``--unit <id>``
    The target unit ID. If not present, the currently selected unit will be the
    target.
``--goals [ <goal> false [<goal> false ...] ]``
    The list of goals to add. The valid goal tokens can be found in the
    :wiki:`Personality_trait` (substitute any space with underscores). There
    must be a space before and after each square bracket.
``--reset``
    Clear all goals. If both this option and ``--goals`` are specified, the
    unit's goals will be cleared and then the listed goals will be added.
