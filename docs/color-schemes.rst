color-schemes
=============

.. dfhack-tool::
    :summary: Modify the colors used by the DF UI.
    :tags: unavailable

This tool allows you to set exactly which shades of colors should be used in the
DF interface color palette.

To set up the colors, you must first create at least one file with color
definitions inside. These files must be in the same format as
:file:`data/init/colors.txt` and contain RGB values for each of the color names.
Just copy :file:`colors.txt` and edit the values for your custom color schemes.

If you are interested in alternate color schemes, also see:

- `gui/color-schemes`: the in-game GUI for this script
- `season-palette`: automatically swaps color schemes when the season changes

Usage
-----

``color-schemes register <directory> [-f] [-q]``
    Register the directory (relative to the main DF game directory) where your
    color scheme files are stored.
``color-schemes list``
    List the color schemes from the registered directories.
``color-schemes default set <scheme name> [-q]``
    Set the named color scheme as the default. This value is stored so you only
    have to set it once, even if you start a new adventure/fort.
``color-schemes default load [-q]``
    Load the default color scheme that you previously set with ``default set``.
``color-schemes load <scheme name> [-q]``
    Load the named color scheme.

Examples
--------

Read your color scheme files from the :file:`colorschemes` directory (a
directory you created and populated with color scheme files) and set the
default to the scheme named ``mydefault``::

    color-schemes register colorschemes
    color-schemes default set mydefault

Read your color scheme files from the :file:`colorschemes` directory (a
directory you created and populated with color scheme files) and load the saved
default. If you have a color scheme that you always want loaded, put these
commands in your :file:`dfhack-config/init/dfhack.init` file::

    color-schemes -q register colorschemes
    color-schemes default load

Options
-------

``-f``, ``--force``
    Register and read color schemes that are incomplete or are syntactically
    incorrect.
``-q``, ``--quiet``
    Don't print any informational output.

API
---

When loaded as a module, this script will export the following functions:

- ``register(path, force)`` : Register colors schemes by path (file or directory), relative to DF main directory
- ``load(name)``            : Load a registered color scheme by name
- ``list()``                : Return a list of registered color schemes
- ``set_default(name)``     : Set the default color scheme
- ``load_default()``        : Load the default color scheme
