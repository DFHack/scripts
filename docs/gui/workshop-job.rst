
gui/workshop-job
================
Run with a job selected in a workshop in the :kbd:`q` mode.

.. image:: /docs/images/workshop-job.png

The script shows a list of the input reagents of the selected job, and allows changing
them like the `job` ``item-type`` and `job` ``item-material`` commands.

Specifically, pressing the :kbd:`i` key pops up a dialog that lets you select an item
type from a list.

.. image:: /docs/images/workshop-job-item.png

Pressing :kbd:`m`, unless the item type does not allow a material,
lets you choose a material.

.. image:: /docs/images/workshop-job-material.png

Since there are a lot more materials than item types, this dialog is more complex
and uses a hierarchy of sub-menus. List choices that open a sub-menu are marked
with an arrow on the left.

.. warning::

  Due to the way input reagent matching works in DF, you must select an item type
  if you select a material, or the material will be matched incorrectly in some cases.
  If you press :kbd:`m` without choosing an item type, the script will auto-choose
  if there is only one valid choice, or pop up an error message box instead of the
  material selection dialog.

Note that both materials and item types presented in the dialogs are filtered
by the job input flags, and even the selected item type for material selection,
or material for item type selection. Many jobs would let you select only one
input item type.

For example, if you choose a *plant* input item type for your prepare meal job,
it will only let you select cookable materials.

If you choose a *barrel* item instead (meaning things stored in barrels, like
drink or milk), it will let you select any material, since in this case the
material is matched against the barrel itself. Then, if you select, say, iron,
and then try to change the input item type, now it won't let you select *plant*;
you have to unset the material first.
