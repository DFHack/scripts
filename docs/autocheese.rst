autocheese
==========

.. dfhack-tool::
    :summary: Schedule cheese making jobs based on milk reserves.
    :tags: fort auto

Cheese making is difficult to automate using work orders. A single job
can consume anything from a bucket with a single unit of milk to a barrel
with 100 units of milk. This makes it hard to predict how much cheese will
actually be produced by an automated order.

The script will scan your fort for barrels with a certain minimum amount of milk
(default: 50), create a cheese making job specifically for that barrel, and
assign this job to one of your idle dwarves (giving preference to skilled cheese
makers).

When enabled using `gui/control-panel`, the script will run automatically, with
default options, twice a month.

Usage
-----

::

    autocheese [<options>]

Examples
--------

``autocheese -m 100``
    Only create a job if there is a barrel that is filled to the maximum.

Options
-------

``-m``, ``--min-milk``
    Set the minimum number of milk items in a barrel for the barrel to be
    considered for cheese making.
