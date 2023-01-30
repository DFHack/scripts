devel/clear-script-env
======================

.. dfhack-tool::
    :summary: Clear a lua script environment.
    :tags: dev

This tool can clear the environment of the specified lua script(s). This is
useful during development since if you remove a global function, an old version
of the function will stick around in the environment until it is cleared.

Usage
-----

::

    devel/clear-script-env <script name> [<script name> ...]

Example
-------

``devel/clear-script-env gui/quickfort``
    Clear the `gui/quickfort` global environment, resetting state that normally
    persists from run to run.
