
devel/query
===========
Query is a script useful for finding and reading values of data structure
fields. Purposes will likely be exclusive to writing lua script code,
possibly C++.

This script takes your data selection eg.{table,unit,item,tile,etc.} then
recursively iterates through it, outputting names and values of what it finds.

As it iterates you can have it do other things, like search for a specific
structure pattern (see lua patterns) or set the value of fields matching the
selection and any search pattern specified.

.. Note::

    This is a recursive search function. The data structures are also recursive.
    So there are a few things that must be considered (in order):

        - Is the search depth too high? (Default: 7)
        - Is the data capable of being iterated, or does it only have a value?
        - How can the data be iterated?
        - Is the iteration count for the data too high? (Default: 257)
        - Does the user want to exclude the data's type?
        - Is the data recursively indexing (eg. A.B.C.A.*)?
        - Does the data match the search pattern?

.. Warning::

  This is a recursive script that's primary use is to search recursive data
  structures. You can, fairly easily, cause an infinite loop. You can even
  more easily run a query that simply requires an inordinate amount of time
  to complete.

.. Tip::

  Should the need arise, you can kill the command from another shell with
  `kill-lua`, e.g. by running it with `dfhack-run` from another terminal.

Usage examples::

  devel/query -unit -getfield id
  devel/query -unit -search STRENGTH
  devel/query -unit -search physical_attrs -maxdepth 2
  devel/query -tile -search dig
  devel/query -tile -search "occup.*carv"
  devel/query -table df -maxdepth 2
  devel/query -table df -maxdepth 2 -excludekinds s -excludetypes fsu -oneline
  devel/query -table df.profession -findvalue FISH
  devel/query -table df.global.ui.main -maxdepth 0
  devel/query -table df.global.ui.main -maxdepth 0 -oneline
  devel/query -table df.global.ui.main -maxdepth 0 -1

**Selection options:**

``-tile``
  Selects the highlighted tile's block, and then
  uses the tile's local position to index the 2D data.

``-block``
  Selects the highlighted tile's block.

``-unit``
  Selects the highlighted unit

``-item``
  Selects the highlighted item.

``-plant``
  Selects the highlighted plant.

``-building``
  Selects the highlighted building.

``-job``
  Selects the highlighted job.

``-script <script name>``
  Selects the specified script (which must support being included with ``reqscript()``).

``-json <file>``
  Loads the specified json file as a table to query.

  .. Note::

    The path starts at the DF root directory.
    eg. -json /hack/scripts/dwarf_profiles.json

``-table <identifier>``
  Selects the specified table (ie. 'value').

  .. Note::

    You must use dot notation to denote sub-tables.
    eg. ``df.global.world``

``-getfield <name>``
  Gets the specified field from the selection.

  Must use in conjunction with one of the above selection
  options. Must use dot notation to denote sub-fields.

**Query options:**

``-search <pattern>``
  Searches the selection for field names with substrings
  matching the specified value.

  Usage::

    devel/query -table dfhack -search pattern
    devel/query -table dfhack -search [ pattern1 pattern2 ]

``-findvalue <value>``
  Searches the selection for field values matching the specified value.

``-maxdepth <value>``
  Limits the field recursion depth (default: 7)

``-maxlength <value>``
  Limits the table sizes that will be walked (default: 257)

``-excludetypes [a|bfnstu0]``
  Excludes native Lua data types. Single letters correspond to (in order):
  All types listed here, Boolean, Function, Number, String, Table, Userdata, nil

``-excludekinds [a|bces]``
  Excludes DF data types. Single letters correspond to (in order):
  All types listed here, Bitfield-type, Class-type, Enum-type, Struct-type

``-dumb``
  Disables intelligent checking for recursive data
  structures (loops) and increases the ``-maxdepth`` to 25 if a
  value is not already present

**General options:**

``-showpaths``
  Displays the full path of a field instead of indenting.

``-setvalue <value>``
  Attempts to set the values of any printed fields.
  Supported types: boolean, string, integer

``-oneline``, ``-1``
  Reduces output to one line, except with ``-debugdata``

``-alignto <value>``
  Specifies the alignment column.

``-nopointers``
  Disables printing values which contain memory addresses.

``-disableprint``
  Disables printing. Might be useful if you are debugging
  this script. Or to see if a query will crash (faster) but
  not sure what else you could use it for.

``-debug <value>``
  Enables debug log lines equal to or less than the value provided.

``-debugdata``
  Enables debugging data. Prints type information under each field.

``-help``
  Prints this help information.

