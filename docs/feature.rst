feature
=======

.. dfhack-tool::
    :summary: Control discovery flags for map features.
    :tags: fort armok map

This tool allows you to toggle the flags that the game uses to track your
discoveries of map features. For example, you can make the game think that you
have discovered magma so that you can build magma workshops and furnaces. You
can also toggle the cavern layer discovery flags so you can control whether
trees, shrubs, and grass from the various cavern layers grow within your
fortress.

Usage
-----

``feature list``
    List all map features in your current embark by index.
``feature magma``
    Enable magma furnaces (discovers a random magma feature).
``feature show <index>``
    Marks the indicated map feature as discovered.
``feature hide <index>``
    Marks the selected map feature as undiscovered.

There will usually be multiple features with the ``subterranean_from_layer``
type. These are the cavern layers, and they are listed in order from closest to
the surface to closest to the underworld.
