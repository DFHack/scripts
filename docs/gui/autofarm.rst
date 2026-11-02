gui/autofarm
============

.. dfhack-tool::
    :summary: Manage autofarm crop thresholds.
    :tags: fort auto plants

This is the configuration interface for the `autofarm` plugin. It lists all
farmable crops along with their current stock counts and their assigned
thresholds, and allows you to set individual thresholds, reset them to the
default, set the default threshold, or set the threshold for all crops at
once. Autofarm itself can also be enabled or disabled from this interface.

Crops that produce usable growth items (such as fruits, leaves, or bulbs)
list those products indented beneath the crop. A growth product counts toward
its crop's pooled threshold unless you assign it a threshold of its own, in
which case the crop is grown until both the pool and that product's stock
meet their thresholds.

The bottom of the window shows how many farm plots are currently excluded
from autofarm management. Individual farm plots can be excluded (or
re-included) via the controls that appear on the farm plot information sheet.

Usage
-----

::

    gui/autofarm
