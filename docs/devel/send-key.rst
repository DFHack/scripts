
devel/send-key
==============
Send a key to the current screen or a parent. If you are trying to dismiss
a screen, `devel/pop-screen` may be more useful, particularly if the screen
is unresponsive to ``Esc``.

Usage::

    devel/send-key KEY_NAME [X]

* ``KEY_NAME`` is the name of an ``interface_key`` - a full list of valid
  names can be obtained by running ``lua @df.interface_key``, looking in
  ``data/init/interface.txt``, or by checking ``df.keybindings.xml`` in
  the df-structures repository.

* ``X`` (optional) - if specified, the key is sent to the screen ``X`` screens
  above the current screen in the screen stack (e.g. ``1`` corresponds to the
  current screen's parent)

