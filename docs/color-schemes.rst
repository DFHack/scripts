
color-schemes
=============
A script to manage color schemes.

Current features are :
    * :Registration:
    * :Loading:
    * :Listing:
    * :Default: Setting/Loading

For detailed information and usage, type ``color-schemes`` in console.

Loaded as a module, this script will export those methods :
    * register(path, force) : Register colors schemes by path (file or directory), relative to DF main directory
    * load(name)            : Load a registered color scheme by name
    * list()                : Return a list of registered color schemes
    * set_default(name)     : Set the default color scheme
    * load_default()        : Load the default color scheme

For more information about arguments and return values, see ``hack/scripts/color-schemes.lua``.

Related scripts:
    * `gui/color-schemes` is the in-game GUI for this script.
    * `season-palette` swaps color schemes when the season changes.

