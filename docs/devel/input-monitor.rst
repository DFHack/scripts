devel/input-monitor
===================

.. dfhack-tool::
    :summary: Live monitor and logger for input events.
    :tags: dev

This UI allows you to discover how DF is interpreting input from your keyboard
and mouse device.

The labels for Shift, Ctrl, and Alt light up when those modifier keys are being
held down.

Similar lables for left, middle, and right mouse buttons light up when any of
those buttons are being held down.

The input stream panel shows the keybindings that are being triggered. You can
resize the window to see more of the stream history. The events are also logged
to the `external console <show>`, if you need a more permanent record of the
stream.

Since right click is intercepted, it cannot be used to close this window.
Instead, hit :kbd:`Esc` twice in a row or click twice on the exit button.

Usage
-----

::

    devel/input-monitor
