add-thought
===========

.. dfhack-tool::
    :summary: Adds a thought to the selected unit.
    :tags: fort armok units

Usage
-----

``add-thought --gui [--unit <id>]``
    Allows you to choose the thought to apply to the selected (or specified)
    unit through a series of graphical prompts.
``add-thought [--unit <id>] [<options>]``
    Add a thought to the selected (or specified) unit.

Examples
--------

``add-thought --gui``
    Add a thought to the unit currently selected in the UI.
``add-thought --unit 23142 --emotion GRATITUDE --thought GoodMeal --strength 1``
    Make unit 23142 feel a light sense of gratitude for eating a good meal.

Options
-------

``--emotion <id>``
    Specifies an emotion for the unit to associate with the given thought. To
    see a list of possible emotions, run ``:lua @df.emotion_type``. If not
    specified, defaults to ``-1`` (i.e. no emotion).
``--thought <id>``
    The thought. To see a list of possible thoughts, run
    ``:lua @df.unit_thought_type``. If not specified, defaults to ``180``, or
    ``NeedsUnfulfilled``. The id could also be the name of a syndrome. To see
    a list of syndromes in your world, run
    ``devel/query --table df.global.world.raws.syndromes.all --search syn_name --maxdepth 1``.
    The id is the numerical index and the syn_name field is the name.
``--subthought <id>``
    The subthought identifier. If the thought is the name of a syndrome, then
    the subthought should be the syndrome id. If not specified, defaults to
    ``0`` (which is what you want for most thought types).
``--strength <strength>``
    The strength of the emotion, corresponding to the strength of the need that
    this emotion might cause or fulfill. Common values for this are ``1``
    (Slight need), ``2`` (Moderate need), ``5`` (Strong need), and ``10``
    (Intense need). If not specified, defaults to ``0``.
``--severity <severity>``
    If the thought is the name of a syndrome, then the severity will be used as
    the severity of the syndrome.
