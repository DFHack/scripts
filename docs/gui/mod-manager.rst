gui/mod-manager
===============

.. dfhack-tool::
    :summary: Manange your active mods.
    :tags: dfhack interface

When run with a world loaded, shows a list of active mods. You can copy the
list to the system clipboard for easy sharing or posting.

Usage
-----

::

    gui/mod-manager

Overlay
-------

This tool also provides two overlays that are managed by the `overlay`
framework.

gui/mod-manager.button
~~~~~~~~~~~~~~~~~~~~~~

Adds a widget to the mod list screen that allows you to save and load mod list
presets. You can also set a default mod list preset for new worlds so you don't
have to manualy re-select the same mods every time you generate a world.

gui/mod-manager.notification
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Displays a message when a mod preset has been auto-applied.
