zAutowheelbarrow
================

Automatically manages wheelbarrow assignments for your fortress stockpiles.

This script evaluates all stockpiles and assigns wheelbarrows to those that
would benefit the most (e.g., stone, furniture, or corpse stockpiles) based on
their size. It also clears stale or invalid wheelbarrow assignments.

Overview
--------

This script performs the following tasks:

1. **Scans all stockpiles** in the fortress.
2. **Calculates desired wheelbarrows** for each applicable stockpile (one per 3 tiles).
3. **Assigns wheelbarrows** only to stone, furniture, or corpse stockpiles.
4. **Clears existing wheelbarrow assignments** if they are no longer valid.
5. **Provides a summary** of total stockpiles, total wheelbarrows, and how many more are needed or excess.

Usage
-----

Run the script from the DFHack console: