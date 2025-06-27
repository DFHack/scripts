zprospectanalyzer
=================

**Goal**: Filter and print stones that are worth **3 points**.

Features
--------

- **Output Parsing**: Automatically runs ``prospect all`` and parses the text output.
- **Section Filtering**: Optionally filters materials by specific sections like ores or gems.
- **Presets**: Running ``zprospectanalyzer`` **without parameters** will only run the preset of **3-point stones**.
- **Missing Materials Reporting**: Displays ``<not found>`` next to any requested material that doesn't appear in the output.

Usage
-----

.. code-block:: bash

  zprospectanalyzer [material1] [material2] ...

Example
-------

.. code-block:: bash

  zprospectanalyzer claystone granite ruby tetrahedrite
