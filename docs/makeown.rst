makeown
=======

.. dfhack-tool::
    :summary: Converts the selected unit to be a fortress citizen.
    :tags: fort armok units

Select a unit in the UI and run this tool to converts that unit to be a fortress
citizen (if sentient). It also removes their foreign affiliation, if any.

This tool also fixes :bug:`10921`, where you request workers from your
holdings, but they come with the "Merchant" profession and are unable to
complete jobs in your fort. Select those units and run `makeown` to convert
them into functional citizens.

Usage
-----

::

    makeown
