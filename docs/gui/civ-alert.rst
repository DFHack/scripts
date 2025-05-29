gui/civ-alert
=============

.. dfhack-tool::
    :summary: Quickly get your civilians to safety.
    :tags: fort gameplay interface military units

Normally, assigning a unit to a burrow is treated more like a suggestion than a
command. This can be frustrating when you're assigning units to burrows in
order to get them out of danger. In contrast, triggering a civilian alert with
`gui/civ-alert` will cause all your non-military citizens to immediately rush
to a burrow ASAP and stay there. This gives you a way to keep your civilians
safe when there is danger about.

Usage
-----

::

    gui/civ-alert

How to set up and use a civilian alert
--------------------------------------

A civ alert needs a burrow to send civilians to. Go set one up if you haven't
already. If you have walls around a secure interior, you can include all your
below-ground area and the safe parts inside your walls. You can name the burrow
"Inside" or "Safety" or "Panic room" or whatever you like.

Then, start up `gui/civ-alert` and select the burrow from the list. You can
activate the civ alert right away with the button in the upper right corner.
You can also access this button at any time from the squads panel.

When danger appears, open up the squads menu and click on the new "Activate
civilian alert" button in the lower left corner of the panel. It's big and red;
you can't miss it. Your civilians will rush off to safety and you can
concentrate on dealing with the incursion without Urist McArmorsmith getting in
the way.

When the civ alert is active, the civilian alert button will stay on the
screen, even if the squads menu is closed. After the danger has passed,
remember to turn the civ alert off again by clicking the button. Otherwise,
your units will continue to be confined to their burrow and may eventually
become unhappy or starve.

Overlay
-------

The position of the "Activate civilian alert" button that appears when the
squads panel is open is configurable via `gui/overlay`. The overlay panel also
gives you a way to launch `gui/civ-alert` if you need to change which burrow(s)
civilians should be gathering in.

Technical notes
---------------

The functionality for civilian alerts is actually already inside the vanilla
game. The ability to configure civilian alerts was lost when the DF UI was
updated for the v50 release. This tool simply provides an interface layer for
the vanilla functionality.
