
do-job-now
==========

The script will try its best to find a job related to the selected entity
(which can be a job, dwarf, animal, item, building, plant or work order) and then
mark this job as high priority. There is no visual indicator, please look
at the dfhack console for output. If a work order is selected, every job
currently present job from this work order is affected, but not the future ones.

For best experience add the following to your ``dfhack*.init``::

    keybinding add Alt-N do-job-now

Also see ``do-job-now`` `tweak` and `prioritize`.
