gui/launcher
============

.. dfhack-tool::
    :summary: In-game DFHack command launcher with integrated help.
    :tags: dfhack

This tool is the primary GUI interface for running DFHack commands. You can open
it from any screen with the \` hotkey. Tap \` again (or hit :kbd:`Esc`) to
close. Users with keyboard layouts that make the \` key difficult (or
impossible) to press can use the alternate hotkey of
:kbd:`Ctrl`:kbd:`Shift`:kbd:`D`.

Usage
-----

::

    gui/launcher [initial commandline]
    gui/launcher -m|--minimal [initial commandline]

Examples
--------

``gui/launcher``
    Open the launcher dialog with a blank initial commandline.
``gui/launcher --minimal``
    Open the launcher dialog in minimal mode with a blank initial commandline.
``gui/launcher prospect --show ores,veins``
    Open the launcher dialog with the edit area pre-populated with the given
    command, ready for modification or running. Tools related to ``prospect``
    will appear in the autocomplete list, and help text for ``prospect`` will be
    displayed in the lower panel.

Editing and running commands
----------------------------

Enter the command you want to run by typing its name. If you want to start over,
:kbd:`Ctrl`:kbd:`C` will clear the line. When you are happy with the command,
hit :kbd:`Enter` or click on the ``run`` button to run it. Any output from the
command will appear in the lower panel after you run it. If you want to run the
command but close the dialog immediately so you can get back to the game, hold
down the :kbd:`Shift` key and click on the ``run`` button instead. The dialog
also closes automatically if you run a command that brings up a new GUI screen.
In any case, the command output will also be written to the DFHack terminal
console (the separate window that comes up when you start DF) if you need to
find it later.

If your keyboard layout makes any key impossible to type (such as :kbd:`[` and
:kbd:`]` on German QWERTZ keyboards), use :kbd:`Ctrl`:kbd:`Shift`:kbd:`K` to
bring up the on-screen keyboard. You can "type" the text you need by clicking
on the characters with the mouse.

Autocomplete
------------

As you type, autocomplete options for DFHack commands appear in the right
column. If the first word of what you've typed matches a valid command, then the
autocomplete options will also include commands that have similar functionality
to the one that you've named. Click on an autocomplete list option to select it
or cycle through them with :kbd:`Shift`:kbd:`Left` and :kbd:`Shift`:kbd:`Right`.

Context-sensitive help and command output
-----------------------------------------

When you start ``gui/launcher`` without parameters, it shows some useful
information in the lower panel about how to get started with browsing DFHack
tools by their category `tags`.

Once you have typed (or autocompleted) a word that matches a valid command, the
lower panel shows the help for that command, including usage instructions and
examples. You can scroll the help text with the mouse or with :kbd:`PgUp` and
:kbd:`PgDn`. You can also scroll line by line with :kbd:`Shift`:kbd:`Up` and
:kbd:`Shift`:kbd:`Down`.

Once you run a command, the lower panel will switch to command output mode,
where you can see any text the command printed to the screen. If you want to
see more help text as you run further commands, you can switch the lower panel
back to help mode with :kbd:`Ctrl`:kbd:`T`. The output text is kept for all the
commands you run while the launcher window is open, but is cleared if you
dismiss the launcher window and bring it back up.

Command history
---------------

``gui/launcher`` keeps a history of commands you have run to let you quickly run
those commands again. You can scroll through your command history with the
:kbd:`Up` and :kbd:`Down` arrow keys, or you can search your history for
something specific with the :kbd:`Alt`:kbd:`S` hotkey. When you hit
:kbd:`Alt`:kbd:`S`, start typing to search your history for a match. To find the
next match for what you've already typed, hit :kbd:`Alt`:kbd:`S` again. You can
run the matched command immediately with :kbd:`Enter`, or hit :kbd:`Esc` to edit
the command before running it.

Dev mode
--------

By default, commands intended for developers and modders are filtered out of the
autocomplete list. This includes any tools tagged with ``untested``. You can
toggle this filtering by hitting :kbd:`Ctrl`:kbd:`D` at any time.
