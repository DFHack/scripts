
gui/mod-manager
===============
A simple way to install and remove small mods, which are not included
in DFHack.  Examples are `available here <https://github.com/warmist/df-mini-mods>`_.

.. image:: /docs/images/mod-manager.png

Each mod is a lua script located in :file:`{<DF>}/mods/`, which MUST define
the following variables:

:name:          a name that is displayed in list
:author:        mod author, also displayed
:description:   a description of the mod

Of course, this doesn't actually make a mod - so one or more of the
following should also be defined:

:raws_list:     a list (table) of file names that need to be copied over to df raws
:patch_entity:  a chunk of text to patch entity
                *TODO: add settings to which entities to add*
:patch_init:    a chunk of lua to add to lua init
:patch_dofile:  a list (table) of files to add to lua init as "dofile"
:patch_files:   a table of files to patch

                :filename:  a filename (in raws folder) to patch
                :patch:     what to add
                :after:     a string after which to insert

:guard:         a token that is used in raw files to find additions and remove them on uninstall
:guard_init:    a token for lua file
:[pre|post]_(un)install:
                Callback functions, which can trigger more complicated behavior
