gui/notify
==========

.. dfhack-tool::
    :summary: Show notifications for important events.
    :tags: adventure fort interface

This tool is the configuration interface for the provided overlay. It allows
you to select which notifications to enable for the overlay display. See the
descriptions in the `gui/notify` list for more details on what each
notification is for. Adventure mode and fort mode have different notifications
that can be enabled.

Usage
-----

::

    gui/notify

Overlay
-------

This script provides an overlay that shows the currently enabled notifications
(when applicable). If you click on an active notification in the list, it will
bring up a screen where you can do something about it or will zoom the map to
the target. If there are multiple targets, each successive click on the
notification (or press of the :kbd:`Enter` key) will zoom to the next target.
You can also shift click (or press :kbd:`Shift`:kbd:`Enter`) to zoom to the
previous target.
