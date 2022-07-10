
fix/item-occupancy
==================
Diagnoses and fixes issues with nonexistant 'items occupying site', usually
caused by `autodump` bugs or other hacking mishaps. Checks that:

#. Item has ``flags.on_ground`` <=> it is in the correct block item list
#. A tile has items in block item list <=> it has ``occupancy.item``
#. The block item lists are sorted

