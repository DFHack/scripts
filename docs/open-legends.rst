
open-legends
============
Open a legends screen when in fortress mode. Requires a world loaded in fortress
or adventure mode. Compatible with `exportlegends`.

Note that this script carries a significant risk of save corruption if the game
is saved after exiting legends mode. To avoid this:

1. Pause DF
2. Run `quicksave` to save the game
3. Run `open-legends` (this script) and browse legends mode as usual
4. Immediately after exiting legends mode, run `die` to quit DF without saving
   (saving at this point instead may corrupt your save)

Note that it should be safe to run "open-legends" itself multiple times in the
same DF session, as long as DF is killed immediately after the last run.
Unpausing DF or running other commands risks accidentally autosaving the game,
which can lead to save corruption.

The optional ``force`` argument will bypass all safety checks, as well as the
save corruption warning.

