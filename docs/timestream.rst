
timestream
==========
Controls the speed of the calendar and creatures. Fortress mode only. Experimental.

The script is also capable of dynamically speeding up the game based on your current FPS to mitigate the effects of FPS death. See examples below to see how.

Usage::

    timestream [-rate R] [-fps FPS] [-units [FLAG]] [-debug]

Examples:

- ``timestream -rate 2``:
    Calendar runs at x2 normal speed, units run at normal speed
- ``timestream -fps 100``:
    Calendar runs at dynamic speed to simulate 100 FPS, units normal
- ``timestream -fps 100 -units``:
    Calendar & units are simulated at 100 FPS
- ``timestream -rate 1``:
    Resets everything back to normal, regardless of other arguments
- ``timestream -rate 1 -fps 50 -units``:
    Same as above
- ``timestream -fps 100 -units 2``:
    Activates a different mode for speeding up units, using the native DF
    ``debug_turbospeed`` flag (similar to `fastdwarf` 2) instead of adjusting
    timers of all units. This results in rubberbanding unit motion, so it is not
    recommended over the default method.

Original timestream.lua: https://gist.github.com/IndigoFenix/cf358b8c994caa0f93d5
