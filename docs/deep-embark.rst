deep-embark
===========

.. dfhack-tool::
    :summary: Start a fort deep underground.
    :tags: embark fort gameplay

Moves the starting units and equipment to a specified underground region upon
embarking so you can start your fort from there.

Run this script while setting up an embark, any time before the embark welcome
message appears.

Usage
-----

``deep-embark --depth <layer> [<options>]``
    Start monitoring the game for the welcome message. Once the embark welcome
    message appears, your units and equipment will automatically be moved to the
    specified layer.
``deep-embark --clear``
    Stop monitoring the game for the welcome message, effectively restoring
    normal embarks on the surface.

Example
-------

``deep-embark --depth CAVERN_2``
    Embark in the second cavern layer
``deep-embark --depth UNDERWORLD --blockDemons``
    Embark in the underworld and disable the usual welcoming party.

Options
-------

``--depth <layer>``
    Embark at the specified layer. Valid layers are: ``CAVERN_1``, ``CAVERN_2``,
    ``CAVERN_3``, and ``UNDERWORLD``.
``--blockDemons``
    Prevent the demon surge that is normally generated when you breach an
    underworld spire. Use this with ``--depth UNDERWORLD`` to survive past the
    first few minutes. Note that "wildlife" demon spawning will be unaffected.
``--atReclaim``
    Enable deep embarks when reclaiming sites.
``--clear``
    Re-enable normal surface embarks.

Deep embarks for mods
---------------------

If you are creating a mod and you want to enable deep embarks by default, create
a file called "onLoad.init" in the DF raw folder (if one does not exist already)
and enter the ``deep-embark`` command within it.
