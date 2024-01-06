workorder-detail-fix
====================

.. dfhack-tool::
    :summary: Fixes a bug with modified work orders creating incorrect jobs.
    :tags: fort bugfix workorders

Some work order jobs have a bug when their input item details have been modified.

Example 1: a Stud With Iron order, modified to stud a cabinet, instead creates a job to stud any furniture.

Example 2: a Prepare Meal order, modified to use all plant type ingredients, instead creates a job to use any ingredients.

This fix forces these jobs to properly inherit the item details from their work order.

Usage
-----

``workorder-detail-fix enable``
    enables the fix
``workorder-detail-fix disable``
    disables the fix
``workorder-detail-fix status``
    print fix status
