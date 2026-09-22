color-schemes
=============

.. dfhack-tool::
    :summary: Modify the colors used by the classic ASCII interface.
    :tags: unavailable interface

This tool allows you to set exactly which shades of colors should be used in the
color palette of the classic DF interface. Unfortunately, this tool can *only*
modify the colours of the classic interface; when using the new interface, only
the color of text can be modified, which is probably not what you want.

To set up color schemes, you must first create at least one file with color
definitions inside. These files must be in the same format as
:file:`data/init/colors.txt` and contain RGB values for each of the color names.
Just copy :file:`colors.txt` and edit the values for your custom color schemes.

If you are interested in alternate color schemes, also see:

- `gui/color-schemes`: the in-game GUI for this script
- `season-palette`: automatically swaps color schemes when the season changes

Usage
-----

``color-schemes list``
    List available color schemes in :file:`dfhack-config/color-schemes`.
``color-schemes default set <path> [-q]``
    Set the given color scheme as the default. This file is saved as :file:`prefs/colors.txt`
    so you only have to set it once, even if you start a new adventure/fort.
``color-schemes default load [-q]``
    Load the default color scheme that you previously set with ``default set``.
``color-schemes load <path> [-q]``
    Load the specified color scheme.
``color-schemes default reset [-q]``
    Reset the default color scheme to the original color scheme that comes with the game.

Examples
--------

List color scheme files found in the :file:`dfhack-config/color-schemes` directory::

    color-schemes list

Load a colour scheme from the location :file:`dfhack-config/color-schemes/foo.txt`::

    color-schemes load foo

Load a colour scheme from the location :file:`/home/urist/bar.txt`::

    color-schemes load /home/urist/bar.txt

Set the default color scheme to the currently loaded scheme::

    color-schemes default set

Set the default color scheme to a scheme located at :file:`dfhack-config/color-schemes/mydefault.txt`, and load it::

    color-schemes default set mydefault
    color-schemes default load

Change the default color scheme back to the initial dwarf fortress default::

    color-schemes default reset
    color-schemes default load

Options
-------

``-q``, ``--quiet``
    Don't print any informational output.

API
---

When loaded as a module, this script will export the following functions:

- ``load_color_scheme_from_path(path)`` : Load a registered color scheme by path, searching first in ``COLOR_SCHEME_DIR``
- ``available_color_schemes()``         : Return a list of registered color schemes
- ``set_default_color_scheme(path)``    : Set the default color scheme
- ``load_default_color_scheme()``       : Load the default color scheme
- ``reset_default_color_scheme()``      : Reset the default color scheme to the color scheme that comes with the game

The following variables will also be made available:

``COLOR_SCHEME_DIR``              : Shorthand for :file:`dfhack-config/color-schemes/`
``current_color_scheme_location`` : The location of the currently loaded color scheme. You should use ``load_color_scheme_from_path`` to change this - setting it manually won't do anything
