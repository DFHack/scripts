dead-noble
==========

.. dfhack-tool::
    :summary: Repair or replace a fortress's dead/missing land holder.
    :tags: fort armok

When a fortress that has been granted a barony, county, or duchy loses its
baron, count, or duke, the game can fail to ever assign a replacement.
This tool diagnoses and repairs the land-holder assignment the parent
civilization keeps for the fort's site, letting normal game mechanics
resume -- or directly installing a chosen citizen.

Usage
-----

``dead-noble status``
    Show every land-holder assignment linked to this site: the current and
    previous holders (alive/dead, whereabouts), the civilization's
    site-link pointer, and which vacancy caches the assignment occupies.
    Run this first to see exactly where the pipeline stalled.

``dead-noble vacate [--living]``
    Perform the same cleanup the native death path performs for each dead
    (or, with ``--living``, living but off-site) holder of a land-holder
    assignment tied to this site: the holder's position link is retired to
    a former-position link, a ``remove_hf_entity_link`` history event is
    recorded, ``histfig`` is cleared while ``histfig2`` is kept (the game
    uses it to find the rightful heir), and the assignment is re-queued
    for evaluation.  On the next entity-advance tick the game itself will
    run succession, appointment, or claim -- normal vanilla behavior.

``dead-noble claim [--living]``
    Like ``vacate``, but pushes the vacant assignment directly onto the
    civilization's ``possible_claimable`` cache so a claimant is spawned
    and travels to the fort (the same-landmass limitation from vanilla
    still applies).

``dead-noble army``
    Diagnose the native successor-travel mechanism for each site-tied
    assignment: the holder's nemesis record, ``whereabouts`` state,
    blocking links, ``st_id``/``ab_id``/``squad_id`` fields, any
    army membership, the destination the native sweep would resolve
    (the assignment's ``st_id`` site, else the civ capital/residence),
    and a worldwide histogram of army-controller goals.

``dead-noble recall``
    Point the site-tied assignment's ``st_id`` recall-destination field
    at this fort (site-id semantics).  The vanilla civilized-actor
    sweep resolves it with ``get_site`` and creates a real
    ``MOVE_TO_SITE`` army that walks the holder here.  Note: the
    sweep's ``land_holder > 0`` gate skips baron/count/duke positions
    before the destination is ever read -- recall only works for them
    if that native check is bypassed (see Notes).  A created army can
    be redirected in flight by rewriting its controller's
    ``site_id``/``pos_x``/``pos_y``.

``dead-noble install [--unit ID] [--position CODE]``
    Install a citizen (the selected unit, or ``--unit ID``) as the holder
    of the fort's land-holder position, replicating the diplomat's
    ESTABLISH_LAND_HOLDER path: a vacant assignment is reused or created,
    holder links and a ``add_hf_entity_link`` history event are written,
    responsibility caches and the civilization's site link are updated,
    and native position-activity evaluation is re-triggered.
    ``--position`` selects a specific position code (e.g. ``BARON``) when
    the site has more than one land-holder assignment.

``dead-noble fetch``
    Patch-free alternative to ``recall`` for land-holder positions: the
    native sweep's ``land_holder > 0`` gate skips barons/counts/dukes no
    matter what ``st_id`` says, so instead of patching the binary this
    command emulates the sweep's army-creation tail directly -- it
    allocates an ``army_controller`` (``MOVE_TO_SITE`` to the fort) and
    an ``army`` at the holder's position, adds their nemesis record, and
    switches the whereabouts state to in-army.  The game's normal
    army-advance machinery then marches them to the fort exactly like a
    native recall.

``dead-noble settle``
    Finish the arrival half of a recall/fetch: a holder delivered by a
    ``MOVE_TO_SITE`` army materializes still flagged as a visitor/guest
    -- vanilla performs the travel but never the take-office step.
    Runs the native citizenship routine (``unitst::make_own``) on the
    materialized holder, granting the MEMBER link to the fort's site
    government, updating its member lists, switching the whereabouts
    record to settler, and clearing guest/visitor flags, then emits the
    matching ``add_hf_entity_link``/``change_hf_state`` history events
    and resets ``st_id`` to -1.  After settling, the holder appears on
    the nobles screen and in the citizens list.

Examples
--------

``dead-noble status``
    Find out why no replacement baron ever arrived.

``dead-noble vacate``
    Let the game find the rightful heir or a new appointee itself.

``dead-noble install``
    Make the selected citizen the new baron (or count/duke, matching the
    fort's current rank) immediately.

``dead-noble recall``
    Have the native traveler sweep fetch the living off-site holder
    itself -- run ``dead-noble army`` afterward to see the created army,
    then ``dead-noble settle`` once the holder arrives.

``dead-noble fetch``
    Same result as ``recall`` without touching native code: the script
    builds the ``MOVE_TO_SITE`` army itself.  Works for land-holder
    positions where the native sweep's gate prevents ``recall`` from
    ever firing.

``dead-noble settle``
    Turn an arrived but still-visiting holder into a proper citizen and
    officeholder (nobles screen + citizens list).

Notes
-----

- All history is preserved: former holders get ``FORMER_POSITION`` links
  and removal events; new holders get position links and
  ``add_hf_entity_link`` events, exactly as the native paths do.
- ``vacate`` is the safest option -- every subsequent step (heir search,
  appointment, claimant spawn, travel) is performed by the game itself.
- An off-site successor who has already been appointed but never traveled
  can be fetched with ``recall`` (native travel), or cleared with
  ``vacate --living``, after which ``claim`` or ``install`` will fill the
  slot.
- ``recall`` for land-holder positions is limited by a native gate: the
  successor-travel sweep skips any position whose definition has
  ``land_holder > 0`` *before* reading the destination, so a baron,
  count, or duke never gets a native travel army no matter what
  ``st_id`` says.  The ``st_id`` write is still correct and consumed
  by the same native path -- it just needs the one native check
  bypassed for the target only.  A production fix should scope the
  bypass (call the creation path for the single intended nemesis, or
  patch for a single sweep window); a global patch makes every
  stranded land-holder in the world travel at once.
- ``st_id`` is the recall-destination field, not the site binding:
  every settled land-holder has ``st_id = -1``, and the site binding
  lives on the civilization's site link (``position_profile_id``).
