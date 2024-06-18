devel/luacov
============

.. dfhack-tool::
    :summary: Lua script coverage report generator.
    :tags: unavailable

This script generates a coverage report from collected statistics. By default it
reports on every Lua file in all of DFHack. To filter filenames, specify one or
more Lua patterns matching files or directories to be included. Alternately, you
can configure reporting parameters in the .luacov file in your DF directory. See
https://keplerproject.github.io/luacov/doc/modules/luacov.defaults.html for
details.

Statistics are cumulative across reports. That is, if you run a report, run a
lua script, and then run another report, the report will include all activity
from the first report plus the recently run lua script. Restarting DFHack will
clear the statistics. You can also clear statistics after running a report by
passing the --clear flag to this script.

Note that the coverage report will be empty unless you have started DFHack with
the "DFHACK_ENABLE_LUACOV=1" environment variable defined, which enables the
coverage monitoring.

Also note that enabling both coverage monitoring and lua profiling via the
"profiler" module can produce strange results. Their interceptor hooks override
each other. Usage of the "kill-lua" command will likewise override the luacov
interceptor hook and may prevent coverage statistics from being collected.

Usage
-----

::

    luacov [options] [pattern...]

Examples
--------

``devel/luacov``
    Report on all DFHack lua scripts.
``devel/luacov -c quickfort``
    Report only on quickfort source files and then clear the stats. This is
    useful to run between test runs to see the coverage of your test changes.
``devel/luacov quickfort hack/lua``
    Report only on quickfort and DFHack library lua source files.

Options
-------

``-c``, ``--clear``
    Remove accumulated metrics after generating the report, ensuring the next
    report starts from a clean slate.
