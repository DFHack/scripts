gui/embark-anywhere
===================

.. dfhack-tool::
    :summary: Embark wherever you want.
    :tags: embark armok interface

If you run this command when you're choosing a site for embark, you can bypass
any warnings the game gives you about potential embark locations. Want to
embark in an inaccessible location on top of a mountain range? Go for it! Want
to try a brief existence in the middle of the ocean? Nobody can stop you! Want
to tempt fate by embarking *inside of* a necromancer tower? !!FUN!!

If you are using this tool to create a fort that will bridge two disconnected
areas of land, see `So you want to bridge a gap?`_ below for tips and caveats.

Any and all consequences of embarking in strange locations are up to you to
handle (possibly with other `armok <armok-tag-index>` tools). In particular,
embarking in inaccessible locations will prevent migrants, caravans, and
visitors from arriving.

Usage
-----

::

    gui/embark-anywhere

The command will only work when you are on the screen where you can choose the
embark site for your fort.

So you want to bridge a gap?
----------------------------

A popular use case for this tool is to create a fort (or a series of forts) that
bridges two disconnected landmasses so sites on the two landmasses can reach
each other (that is, they can send raiding parties and/or engage in trade).

However, the way this works is not entirely intuitive.

A single large embark is not necessarily going to functionally connect the two
shores so that armies can cross the gap. You could still choose to use this
approach to build a continuous constructed bridge in fort mode for later use as
an *adventurer* in adventure mode, but it will not be usable by the other
characters/armies in the world.

The DF world map is divided into blocks of 16x16 tiles. When you are choosing
where to embark and you move the mouse so that your embark area "shadow" moves
over a little bit -- that's one "tile". An embark area can span block
boundaries, and there is no indication on the map where those boundaries are.

The way DF determines world pathability is to check if the ground is continuous
**or** if the enclosing 16x16 block contains the upper left tile of a fort
embark area.

In order for a connection to be formed for armies, one fort upper left corner
must exist in each 16x16 block that contains part of the gap.

Therefore, the simplest solution for making a "bridge" that armies can use (but
walking adventurers cannot) is to make a 1x1 fort every 16 tiles across the
water gap, starting on land on one shore and finishing on land on the opposite
shore. That will ensure that every 16x16 block in the gap is covered by a fort.
