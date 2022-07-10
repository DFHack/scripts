
gui/workflow
============
Bind to a key (the example config uses Alt-W), and activate with a job selected
in a workshop in :kbd:`q` mode.

.. image:: /docs/images/workflow.png

This script provides a simple interface to constraints managed by `workflow`.
When active, it displays a list of all constraints applicable to the
current job, and their current status.

A constraint specifies a certain range to be compared against either individual
*item* or whole *stack* count, an item type and optionally a material. When the
current count is below the lower bound of the range, the job is resumed; if it
is above or equal to the top bound, it will be suspended. Within the range, the
specific constraint has no effect on the job; others may still affect it.

Pressing :kbd:`i` switches the current constraint between counting stacks or items.
Pressing :kbd:`r` lets you input the range directly;
:kbd:`e`, :kbd:`r`, :kbd:`d`, :kbd:`f` adjust the
bounds by 5, 10, or 20 depending on the direction and the :kbd:`i` setting (counting
items and expanding the range each gives a 2x bonus).

Pressing :kbd:`a` produces a list of possible outputs of this job as guessed by
workflow, and lets you create a new constraint by choosing one as template. If you
don't see the choice you want in the list, it likely means you have to adjust
the job material first using `job` ``item-material`` or `gui/workshop-job`,
as described in the `workflow` documentation. In this manner, this feature
can be used for troubleshooting jobs that don't match the right constraints.

.. image:: /docs/images/workflow-new1.png

If you select one of the outputs with :kbd:`Enter`, the matching constraint is simply
added to the list. If you use :kbd:`Shift`:kbd:`Enter`, the interface proceeds to the
next dialog, which allows you to edit the suggested constraint parameters to
suit your need, and set the item count range.

.. image:: /docs/images/workflow-new2.png

Pressing :kbd:`s` (or, with the example config, Alt-W in the :kbd:`z` stocks screen)
opens the overall status screen:

.. image:: /docs/images/workflow-status.png

This screen shows all currently existing workflow constraints, and allows
monitoring and/or changing them from one screen. The constraint list can
be filtered by typing text in the field below.

The color of the stock level number indicates how "healthy" the stock level
is, based on current count and trend. Bright green is very good, green is good,
red is bad, bright red is very bad.

The limit number is also color-coded. Red means that there are currently no
workshops producing that item (i.e. no jobs). If it's yellow, that means the
production has been delayed, possibly due to lack of input materials.

The chart on the right is a plot of the last 14 days (28 half day plots) worth
of stock history for the selected item, with the rightmost point representing
the current stock value. The bright green dashed line is the target
limit (maximum) and the dark green line is that minus the gap (minimum).

