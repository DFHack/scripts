order-trim-workorders
=====================

.. dfhack-tool::
    :summary: Pick, pretty-format, and trim work orders from DFHack order JSON files.

This script provides a two-step UI for trimming work order files in
``dfhack-config/orders``:

1. A picker that lists ``.json`` files and filters by filename.
2. A trimmer that opens a pretty-formatted ``.txt`` variant and lets you mark
   whole work-order objects for deletion.

When a work order is marked, the full top-level JSON object is targeted
(including lines currently hidden by hide-noise view filtering).

Usage
-----

::

    order-trim-workorders
    order-trim-workorders --file <orders.json>

Arguments
---------

``--file <path-or-name>``
    Pretty-formats the target ``.json`` into its ``.txt`` variant without
    opening the picker UI. If only a filename is provided, it is resolved under
    ``dfhack-config/orders``.

Picker controls
---------------

- Type in ``Search`` to filter filenames.
- :kbd:`Enter` or click opens the selected file in the trimmer.
- :kbd:`Esc` closes.

Trimmer controls
----------------

- Click to select a line.
- Toggle mark for the selected work order with:

  - double left-click on the same line, or
  - :kbd:`Enter` / :kbd:`Space`

- Hotkeys:

  - :kbd:`Alt` + :kbd:`D`: apply deletions (remove all marked lines)
  - :kbd:`Alt` + :kbd:`S`: save
  - :kbd:`Alt` + :kbd:`R`: reload from disk
  - :kbd:`Alt` + :kbd:`H`: toggle hide-noise display filter

- :kbd:`Esc` closes (prompts if there are unsaved changes).

Notes
-----

- Save writes both the working ``.txt`` file and its companion ``.json`` file.
- Search in the trimmer shows whole matching work-order groups.
- Alternating row colors are used to help distinguish adjacent work orders.
