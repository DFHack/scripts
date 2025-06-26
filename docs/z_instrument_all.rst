z_instrument_all.lua
=====================

**Automatically queue work orders for all discovered instruments in Dwarf Fortress using DFHack.**

Features
--------

- Detects all valid, craftable instruments via `instruments` command
- Normalizes and filters instrument names for compatibility
- Automatically places a work order for each instrument without having to manually input order and name

Usage
-----

Run with a number to place **that many** orders per instrument (defaults to 1 if omitted):

::

  z_instrument_all 5

This example queues 5 of each discovered instrument.

Acknowledgments
---------------

This script utilizes the DFHack `instruments` command to retrieve and process instrument definitions.