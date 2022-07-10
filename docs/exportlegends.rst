
exportlegends
=============
Controls legends mode to export data - especially useful to set-and-forget large
worlds, or when you want a map of every site when there are several hundred.

The 'info' option exports more data than is possible in vanilla, to a
:file:`region-date-legends_plus.xml` file developed to extend
:forums:`World Viewer <128932>` and other legends utilities.

Usage::

    exportlegends OPTION [FOLDER_NAME]

Valid values for ``OPTION`` are:

:info:   Exports the world/gen info, the legends XML, and a custom XML with more information
:custom: Exports a custom XML with more information
:sites:  Exports all available site maps
:maps:   Exports all seventeen detailed maps
:all:    Equivalent to calling all of the above, in that order

``FOLDER_NAME``, if specified, is the name of the folder where all the files
will be saved. This defaults to the ``legends-regionX-YYYYY-MM-DD`` format. A path is
also allowed, although everything but the last folder has to exist. To export
to the top-level DF folder, pass ``.`` for this argument.

Examples:

* Export all information to the ``legends-regionX-YYYYY-MM-DD`` folder::

    exportlegends all

* Export all information to the ``region6`` folder::

    exportlegends all region6

* Export just the files included in ``info`` (above) to the ``legends-regionX-YYYYY-MM-DD`` folder::

    exportlegends info

* Export just the custom XML file to the DF folder (no subfolder)::

    exportlegends custom .

