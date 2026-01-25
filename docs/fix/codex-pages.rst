fix/codex-pages
===============

.. dfhack-tool::
    :summary: Add pages to written content that have no pages.
    :tags: fort bugfix items

Add pages to codices, quires, and scrolls that do not have specified page counts.

Usage
-----

``fix/codex-pages [this|site|all]``

Pages will be added to written works that do not have properly specified page
counts. The number of pages to be added will be determined mainly by the type
of the written content, modified by its writing style and the strength of the
style, with weighted randomization.

Options
-------

``this``
    Add pages to the selected codex, quire, or scroll item.

``site``
    Add pages to all written works that are currently in the player's fortress.

``all``
    Add pages to all written works to have ever existed in the world.

Note
----

This tool mitigates :bug:`9268` by generating new, randomized information for
written content that do not have the start and end pages specified in their
data structure. It cannot retrieve page count from written content that was
already missing the page count information.

Also, unbound quires and scrolls do not display the number of pages they contain
in their item description even if the data structure of their written content
holds the information. However, once a quire that has written content with
appropriately specified page count information is bound into a codex, its page
count will be properly displayed in the resulting codex's item description.
