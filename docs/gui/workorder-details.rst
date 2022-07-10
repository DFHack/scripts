
gui/workorder-details
=====================
Adjust input items, material, or traits for work orders. Actual
jobs created for it will inherit the details.

This is the equivalent of `gui/workshop-job` for work orders,
with the additional possibility to set input items' traits.

It has to be run from a work order's detail screen
(:kbd:`j-m`, select work order, :kbd:`d`).

For best experience add the following to your ``dfhack*.init``::

    keybinding add D@workquota_details gui/workorder-details

