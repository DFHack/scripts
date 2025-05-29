modtools/anonymous-script
=========================

.. dfhack-tool::
    :summary: Run dynamically generated script code.
    :tags: unavailable

This allows running a short simple Lua script passed as an argument instead of
running a script from a file. This is useful when you want to do something too
complicated to make with the existing modtools, but too simple to be worth its
own script file.  Example::

    anonymous-script "print(args[1])" arg1 arg2
    # prints "arg1"
