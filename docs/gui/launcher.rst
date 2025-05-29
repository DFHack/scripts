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
    command, ready for modification or running. Tools related to
    `prospect <prospector>` will appear in the autocomplete list, and help text
    for ``prospect`` will be displayed in the lower panel.

Editing and running commands
----------------------------

Enter the command you want to run by typing its name. If you want to start over,
:kbd:`Ctrl`:kbd:`X` will clear the line. When you are happy with the command,
hit :kbd:`Enter` or click on the ``run`` button to run it. Any output from the
command will appear in the lower panel after you run it. If you want to run the
command but close the dialog immediately so you can get back to the game, hold
down the :kbd:`Shift` key and click on the ``run`` button instead. The dialog
also closes automatically if you run a command that brings up a new GUI screen.
In any case, the command output will also be written to the DFHack terminal
console (the separate window that comes up when you start DF) if you need to
find it later.

If the game was unpaused when you started `gui/launcher`, you can toggle pause
by hit the spacebar once or twice. If you are already typing a command, the
first space will go into the edit box for your commandline. If the commandline
is empty or already has a space just before the cursor, the space key will be
passed through to the game to affect the pause button. If the game was paused
when you started `gui/launcher`, then this behavior is disabled to prevent
accidental unpausing.

If your keyboard layout makes any key impossible to type (such as :kbd:`[` and
:kbd:`]` on German QWERTZ keyboards), use :kbd:`Ctrl`:kbd:`Shift`:kbd:`K` to
bring up the on-screen keyboard. You can "type" the text you need by clicking
on the characters with the mouse and then clicking the ``Enter`` button to
send the text to the launcher editor.

Autocomplete
------------

As you type, autocomplete options for DFHack commands appear in the right
column. You can restrict which commands are shown in the autocomplete list by
setting the tag filter with :kbd:`Ctrl`:kbd:`W` or by clicking on the ``Tags``
button. If the first word of what you've typed matches a valid command, then the
autocomplete options switch to showing commands that have similar functionality
to the one that you've typed. Click on an autocomplete list option to select it
or cycle through them with :kbd:`Tab` and :kbd:`Shift`:kbd:`Tab`. You can run a
command quickly without parameters by double-clicking on the tool name in the
list. Holding down shift while you double-click allows you to run the command
and close `gui/launcher` at the same time.

Context-sensitive help and command output
-----------------------------------------

When you start ``gui/launcher`` without parameters, it shows some useful
information in the lower panel about how to get started with DFHack.

Once you have typed (or autocompleted) a word that matches a valid command, the
lower panel shows the help for that command, including usage instructions and
examples. You can scroll the help text with the mouse wheel or with :kbd:`PgUp`
and :kbd:`PgDn`. You can also scroll line by line with :kbd:`Shift`:kbd:`Up` and
:kbd:`Shift`:kbd:`Down`.

Once you run a command, the lower panel will switch to command output mode,
where you can see any text the command printed to the screen. If you want to
see more help text as you browse further commands, you can switch the lower
panel back to help mode with :kbd:`Ctrl`:kbd:`T`. The output text is kept for
all the commands you run while the launcher window is open (up to 256KB of
text), but only the most recent 32KB of text is saved if you dismiss the
launcher window and bring it back up. Command output is also printed to the
external DFHack console (the one you can show with `show` on Windows) or the
parent terminal on Unix-based systems if you need a longer history of the
output.

You can run the `clear <cls>` command or click the ``Clear output`` button to
clear the output scrollback buffer.

Command history
---------------

``gui/launcher`` keeps a history of commands you have run to let you quickly run
those commands again. You can scroll through your command history with the
:kbd:`Up` and :kbd:`Down` arrow keys. You can also search your history for
something specific with the :kbd:`Alt`:kbd:`S` hotkey. When you hit
:kbd:`Alt`:kbd:`S`, start typing to search your history for a match. To find the
next match for what you've already typed, hit :kbd:`Alt`:kbd:`S` again. You can
run the matched command immediately with :kbd:`Enter`, or hit :kbd:`Esc` to edit
the command before running it.

Default tag filters
-------------------

By default, commands intended for developers and modders are filtered out of the
autocomplete list. This includes any tools tagged with ``unavailable``. If you
have "mortal mode" enabled in the `gui/control-panel` preferences, any tools
with the ``armok`` tag are filtered out as well.

You can toggle this default filtering by hitting :kbd:`Ctrl`:kbd:`D` to switch
into "Dev mode" at any time. You can also adjust your command filters in the
``Tags`` filter list.
