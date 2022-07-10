
modtools/reaction-product-trigger
=================================
This triggers dfhack commands when reaction products are produced, once per
product.  Usage::

    -clear
        unregister all reaction hooks
    -reactionName name
        specify the name of the reaction
    -command [ commandStrs ]
        specify the command to be run on the target(s)
        special args
            \\WORKER_ID
            \\REACTION
            \\BUILDING_ID
            \\LOCATION
            \\INPUT_ITEMS
            \\OUTPUT_ITEMS
            \\anything -> \anything
            anything -> anything
