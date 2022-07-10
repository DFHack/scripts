
fix/stuck-merchants
===================

Dismisses merchants that haven't entered the map yet. This can fix :bug:`9593`.
This script should probably not be run if any merchants are on the map, so using
it with `repeat` is not recommended.

Run ``fix/stuck-merchants -n`` or ``fix/stuck-merchants --dry-run`` to list all
merchants that would be dismissed but make no changes.
