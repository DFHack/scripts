
lua
===
There are the following ways to invoke this command:

1. ``lua`` (without any parameters)

   This starts an interactive lua interpreter.

2. ``lua -f "filename"`` or ``lua --file "filename"``

   This loads and runs the file indicated by filename.

3. ``lua -s ["filename"]`` or ``lua --save ["filename"]``

   This loads and runs the file indicated by filename from the save
   directory. If the filename is not supplied, it loads "dfhack.lua".

4. ``:lua`` *lua statement...*

   Parses and executes the lua statement like the interactive interpreter would.

