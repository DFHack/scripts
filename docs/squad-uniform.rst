squad-uniform
=============

.. dfhack-tool::
    :summary: Import and export squad uniform templates from the military equipment screen.
    :tags: fort military interface

This script adds an overlay to the ``Military > Equipment > Customize`` screen
that can save and restore uniform templates.

Uniform templates are stored as JSON files in:
``dfhack-config/squad_uniform/*.dfuniform``

Usage
-----

``squad-uniform``
    Enables the overlay (enabled by default) on the squad equipment
    customization screen.

Overlay hotkeys
---------------

``Ctrl-I``
    Open the import dialog.

``Ctrl-E``
    Open the export dialog.

Import dialog
-------------

In the import dialog, you can:

- select a file to import a saved uniform
- type to filter the file list
- use the secondary action to delete the selected file

Export behavior
---------------

When exporting, enter a file name (without extension). The script writes a
``.dfuniform`` file containing:

- uniform nickname
- uniform slot entries
- uniform flag metadata

Notes
-----

- The ``Military > Equipment`` screen must be open when importing or exporting.
- Invalid or malformed files are rejected with an error message.
