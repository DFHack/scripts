devel/infinite-sky-probe
========================

.. dfhack-tool::
    :summary: test tool for validating behavior of infinite-sky and related construction/cave-column code.
    :tags: dev

Tool for attempting in-game reproduction of `issue #254
<https://github.com/DFHack/dfhack/issues/254>`_: sky z-levels created by
``infinite-sky`` periodically disappearing again down to the level of the
highest construction, causing cave-ins.

.. warning::

    This tool fabricates completed constructions and forces cave-column
    recomputation. It can cave-in or otherwise corrupt your fort. Only use it
    on a disposable save.

Usage:

``status``
    Print the current map z-level state: ``z_count``/``z_count_block``,
    the highest construction z-level, whether the top-level map blocks are
    allocated, and the state of the cave-column bookkeeping flags that are
    suspected to be involved in the issue.

``add <n>``
    Add *n* sky z-levels via the real ``infinite-sky`` plugin command.

``tower [--pos x,y,z] [--top z] [--platform]``
    Fabricate a completed construction tower: a column of pillar walls, the
    implied "top of wall" floor on top, and the matching ``df.construction``
    records (this is the same end state the game produces when a dwarf
    finishes a construction job). If ``--pos`` is not given, the keyboard
    cursor position is used; if it has no z component, building starts at
    the ground surface found at that x,y. The tower is built up to
    ``--top`` (default: one z-level below the current map ceiling, leaving
    one empty sky level like the game normally expects). ``--platform``
    additionally lays constructed floors adjacent to the top of the tower,
    mimicking the "constructions in progress near the top" scenario from
    the issue report.

``poke``
    Force the suspected trigger: set the world ``process_columns`` flag and
    mark every map block column ``UPDATE_CAVE_COLUMNS``, which is what the
    game sets when construction changes require cave-column recomputation.

``watch [frames]``
    Monitor ``z_count``/``z_count_block``, the construction list, the
    cave-column flags, and ``CAVE_COLLAPSE`` reports once per frame for the
    given number of frames (default 20000; at ~100 FPS that is a few
    minutes). The game is unpaused while watching and the pause state is
    restored afterwards. Any *decrease* in z-levels is reported loudly:
    that means issue #254 has been reproduced.

``run [frames] [--levels n] [--enable]``
    Run the full reproduction sequence: ``status``, optionally ``add n``
    sky levels, optionally ``enable infinite-sky`` (reproduces the
    "construction monitoring" variant of the report), ``tower
    --platform``, ``poke``, ``watch``.

``stop``
    Stop a running ``watch`` early.
