notes
=====

.. dfhack-tool::
    :summary: Manage map-specific notes.
    :tags: fort interface map

The `notes` tool enables players to annotate specific tiles
on the Dwarf Fortress game map with customizable notes.

Each note is displayed as a green pin on the map and includes a one-line title and a detailed comment.

It can be used to e.g.:
 - marking plans for future constructions
 - explaining mechanisms or traps
 - noting historical events

Usage
-----

::

    notes add

Add new note in the current position of the keyboard cursor.

Creating a Note
---------------
1. Use the keyboard cursor to select the desired map tile where you want to place a note.
2. Execute ``notes add`` via the DFHack console.
3. In the pop-up dialog, fill in the note's title and detailed comment.
4. Press :kbd:`Alt` + :kbd:`S` to create the note.

Editing or Deleting a Note
--------------------------
- Click on the green pin representing the note directly on the map.
- A dialog will appear, offering options to edit the title or comment, or to delete the note entirely.

Managing Notes Visibility
-------------------------
- Access the `gui/control-panel` / ``UI Overlays`` tab.
- Toggle the ``notes.map-notes`` overlay to show or hide the notes on the map.
