chronicler
==========

.. dfhack-tool::
    :summary: Monitors game events and exports fortress state for AI narration.
    :tags: fort interface

The ``chronicler`` script acts as the data source for "The Chronicler" AI narration
system. It periodically extracts recent announcements, combat reports, and
detailed citizen data (including stress levels and recent emotions) and exports
them to a JSON file (``fortress_state.json``) within the active save directory.

Usage
-----

::

    chronicler start [interval_mins]
    chronicler stop
    chronicler now

Examples
--------

``chronicler start 5``
    Starts the monitoring loop, exporting data every 5 minutes.
``chronicler stop``
    Stops the monitoring loop.
``chronicler now``
    Triggers an immediate data export regardless of the schedule.

Data Export details
-------------------

The script creates a ``chronicler`` directory inside your current save folder
and writes ``fortress_state.json`` there.

Extracted data includes:
- **Meta**: Current frame count, year, year tick, and fortress name.
- **Reports**: Recent announcements and combat reports since the last export.
- **Citizens**: Names, IDs, race, profession, stress levels, moods, and recent emotions.
