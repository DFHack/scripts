modtools/reaction-trigger
=========================

.. dfhack-tool::
    :summary: Run DFHack commands when custom reactions complete.
    :tags: unavailable

Triggers dfhack commands when custom reactions complete, regardless of whether
it produced anything, once per completion.  Arguments::

    -clear
        unregister all reaction hooks
    -reactionName name
        specify the name of the reaction
    -syndrome name
        specify the name of the syndrome to be applied to valid targets
    -allowNonworkerTargets
        allow other units to be targeted if the worker is invalid or ignored
    -allowMultipleTargets
        allow all valid targets within range to be affected
        if absent:
            if running a script, only one target will be used
            if applying a syndrome, then only one target will be infected
    -ignoreWorker
        ignores the worker when selecting the targets
    -dontSkipInactive
        when selecting targets in range, include creatures that are inactive
        dead creatures count as inactive
    -range [ x y z ]
        controls how far eligible targets can be from the workshop
        defaults to [ 0 0 0 ] (on a workshop tile)
        negative numbers can be used to ignore outer squares of the workshop
        line of sight is not respected, and the worker is always within range
    -resetPolicy policy
        the policy in the case that the syndrome is already present
        policy
            NewInstance (default)
            DoNothing
            ResetDuration
            AddDuration
    -command [ commandStrs ]
        specify the command to be run on the target(s)
        special args
            \\WORKER_ID
            \\TARGET_ID
            \\BUILDING_ID
            \\LOCATION
            \\REACTION_NAME
            \\anything -> \anything
            anything -> anything
        when used with -syndrome, the target must be valid for the syndrome
        otherwise, the command will not be run for that target
