fix/stuck-merchants
===================

.. dfhack-tool::
    :summary: Dismiss merchants that are stuck off the edge of the map.
    :tags: fort bugfix units

This tool dismisses merchants that haven't entered the map yet. This can fix
:bug:`9593`. Where you get a trade caravan announcement, but no merchants ever
enter the map.

This script should not be run if any merchants are on the map, so using it with
`repeat` is not recommended.

Usage
-----

``fix/stuck-merchants``
    Dismiss merchants that are stuck off the edge of the map.
``fix/stuck-merchants -n``, ``fix/stuck-merchants --dry-run``
    List the merchants that would be dismissed, but make no changes.
