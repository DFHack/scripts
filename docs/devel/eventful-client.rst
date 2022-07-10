devel/eventful-client
=====================

Usage::

    devel/eventful-client help
    devel/eventful-client add <event type> <frequency>
    devel/eventful-client add all <frequency>
    devel/eventful-client list
    devel/eventful-client clear

:help:  shows this help text and a list of valid event types
:add:   add a handler for the named event type at the requested tick frequency
:list:  lists active handlers and their metadata
:clear: unregisters all handlers

Note this script does not handle the eventful reaction or workshop events.
