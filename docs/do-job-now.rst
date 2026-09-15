do-job-now
==========

.. dfhack-tool::
    :summary: Mark the job related to what you're looking at as high priority.
    :tags: unavailable

The script will try its best to find a job related to the selected entity (which
can be a job, dwarf, animal, item, building, plant or work order) and then mark
the job as high priority.

This functionality is now part of `prioritize` (see ``prioritize this``), and
``do-job-now`` forwards to it for compatibility with existing keybindings.

Apart from jobs that are queued from buildings, there is normally no visual
indicator that the job is now high priority. If you use ``do-job-now`` from the
keybinding, you have to check the dfhack console for output to see if the
command succeeded.

If a work order is selected, every job currently active from this work order is
adjusted, but not the future ones.

Usage
-----

::

    do-job-now
