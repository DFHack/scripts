zprospectanalyzer
=================

A DFHack CLI utility and Lua module for scanning and reporting material occurrences
and elevation ranges using the built-in `prospect` command. It provides an easy-to-use
interface to list material counts and elevation ranges, with sorting and preset lists.

Features
--------

- **Output Parsing**: Runs `prospect all` or `prospect all --show <section>` and parses the text output.
- **Section Filtering**: Filter materials by specific sections like layers, ores, gems, or globally.
- **Presets**: Built-in "blocks" preset for common stone materials.
- **Missing Material Handling**: Lists missing materials at the end with `<not found>` marker.

Usage
-----

Load the script in DFHack and run:

.. code-block:: bash

  zprospectanalyzer [section] [material1] [material2] ...

Examples:

- **Default** (blocks preset):

  .. code-block:: bash

  zprospectanalyzer

- **Filter by section**:

  .. code-block:: bash

  zprospectanalyzer layer_materials chert granite

- **Global search**:

  .. code-block:: bash

  zprospectanalyzer jet ruby tetrahedrite