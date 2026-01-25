flavor-text
===========

Overview
--------
The ``flavor-text`` script writes the currently viewed unit or item flavor text to
``flavor text/read flavor.txt``.

Usage
-----
Run the script from DFHack:

::

  flavor-text

Notes
-----
- The file is overwritten each time the script runs.
- If the wrong window is open, the script clears the output file.
- Supported unit tabs:
  - Health (Status/Wounds/Treatment/History/Description)
  - Personality (Traits/Values/Preferences/Needs)
- Supported item window: item view sheets.
- You must use your own text-to-speech (TTS) program to read the output.
  On Windows 11, Voice Attack works well, and a profile with the launch command
  can be included for others to use.
