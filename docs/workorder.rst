
workorder
=========
``workorder`` is a script to queue work orders as in ``j-m-q`` menu.
It can automatically count how many creatures can be milked or sheared.

The most simple and obvious usage is automating shearing and milking of creatures
using ``repeat``::

  repeat -time 14 -timeUnits days -command [ workorder ShearCreature ] -name autoShearCreature
  repeat -time 14 -timeUnits days -command [ workorder MilkCreature ] -name autoMilkCreature

It is also possible to define complete work orders using ``json``. It is very similar to
what ``orders import filename`` does, with a few key differences. ``workorder`` is a planning
tool aiming to provide scripting support for vanilla manager. As such it will ignore work order
state like ``amount_left`` or ``is_active`` and can optionally take current orders into account.
See description of ``<json>``-parameter for more details.

**Examples**:

  * ``workorder ShearCreature 10`` add an order to "Shear Animal" 10 times.
  * ``workorder ShearCreature`` same, but calculate amount automatically (can be 0).
  * ``workorder MilkCreature`` same, but "Milk Animal".

**Advanced examples**:

 * ``workorder "{\"job\":\"EncrustWithGems\",\"item_category\":[\"finished_goods\"],\"amount_total\":5}"``
    add an order to ``EncrustWithGems`` ``finished_goods`` using any material (since not specified).

 * ``workorder "{\"job\":\"MilkCreature\",\"item_conditions\":[{\"condition\":\"AtLeast\",\"value\":2,\"flags\":[\"empty\"],\"item_type\":\"BUCKET\"}]}"``
    same as ``workorder MilkCreature`` but with an item condition ("at least 2 empty buckets").

**Usage**:

``workorder [ --<command> | <jobtype> [<amount>] | <json> | --file <file> ]``

:<command>:  one of ``help``, ``listtypes``, ``verbose``, ``very-verbose``

--help              this help.
--listtypes filter  print all values for all used DF types (``job_type``, ``item_type`` etc.).
                    ``<filter>`` is optional and is applied to type name (using ``Lua``'s ``string.find``),
                    f.e. ``workorder -l "manager"`` is useful.

:<jobtype>:  number or name from ``df.job_type``.
:<amount>:   optional number; if omitted, the script will try to determine amount automatically
             for some jobs. Currently supported are ``MilkCreature`` and ``ShearCreature`` jobs.
:<json>:     json-representation of a workorder. Must be a valid Lua string literal
             (see advanced examples: note usage of ``\``).
             Use ``orders export some_file_name`` to get an idea how does the ``json``-structure
             look like.

             It's important to note this script behaves differently compared to
             ``orders import some_file_name``: ``workorder`` is meant as a planning
             tool and as such it **will ignore** some fields like ``amount_left``,
             ``is_active`` or ``is_validated``.

             This script doesn't need values in all fields:
              * ``id`` is only used for order conditions;
              * ``frequency`` is set to ``OneTime`` by default;
              * ``amount_total`` can be missing, a function name from this script (one of
                ``calcAmountFor_MilkCreature`` or ``calcAmountFor_ShearCreature``) or ``Lua``
                code called as ``load(code)(order, orders)``. Missing ``amount_total`` is
                equivalent to ``calcAmountFor_<order.job>``.

             A custom field ``__reduce_amount`` can be set if existing open orders should
             be taken into account reducing new order's ``total_amount`` (possibly all the
             way to ``0``). An empty ``amount_total`` implies ``"__reduce_amount": true``.

--file filename    loads the json-representation of a workorder from a file in ``dfhack-config/workorder/``.

**Debugging**:

--verbose        toggle script's verbosity.
--very-verbose   toggle script's very verbose mode.
--reset          reset script environment for next execution.
