devel/send-key
==============

.. dfhack-tool::
    :summary: Deliver key input to a viewscreen.
    :tags: dev interface

This tool can send a key to the current screen or to a parent screen. Note that
if you are trying to dismiss a screen, `devel/pop-screen` may be more useful,
particularly if the screen is unresponsive to :kbd:`Esc`.

Usage
-----

::

    devel/send-key <key> [<depth>]

The key to send is the name of an ``interface_key`` (see valid values by running
``:lua @df.interface_key``, looking in ``data/init/interface.txt``, or by
checking ``df.keybindings.xml`` in the df-structures repository.

You can optionally specify the depth of the screen that you want to send the key
to. ``1`` corresponds to the current screen's parent.
