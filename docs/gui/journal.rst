gui/journal
===========

.. dfhack-tool::
    :summary: Fort journal with a multi-line text editor.
    :tags: fort interface

The `gui/journal` interface makes it easy to take notes and document
important details for the fortresses.

With this multi-line text editor, you can keep track of your fortress's
background story, goals, notable events, and both short- and long-term plans.

This is particularly useful when you need to take a longer break from the game.
Having detailed notes makes it much easier to resume your game after a few
weeks or months without losing track of your progress and objectives.

Supported Features
------------------

- Cursor Control: Navigate through text using arrow keys (Left, Right, Up,
    and Down) for precise cursor placement.
- Fast Rewind: Use :kbd:`Ctrl` + :kbd:`Left` and :kbd:`Ctrl` + :kbd:`Right` to
    move the cursor one word back or forward.
- Longest X Position Memory: The cursor remembers the longest x position when
    moving up or down, making vertical navigation more intuitive.
- Mouse Control: Use the mouse to position the cursor within the text,
    providing an alternative to keyboard navigation.
- New Lines: Easily insert new lines using the :kbd:`Enter` key, supporting
    multiline text input.
- Text Wrapping: Text automatically wraps within the editor, ensuring lines fit
    within the display without manual adjustments.
- Backspace Support: Use the backspace key to delete characters to the left of
    the cursor.
- Delete Character: :kbd:`Delete` deletes the character under the cursor.
- Line Navigation: :kbd:`Home` moves the cursor to the beginning of the current
    line, and :kbd:`End` moves it to the end.
- Delete Current Line: :kbd:`Ctrl` + :kbd:`U` deletes the entire current line
    where the cursor is located.
- Delete Rest of Line: :kbd:`Ctrl` + :kbd:`K` deletes text from the cursor to
    the end of the line.
- Delete Last Word: :kbd:`Ctrl` + :kbd:`W` removes the word immediately before
    the cursor.
- Text Selection: Select text with the mouse, with support for replacing or
    removing selected text.
- Jump to Beginning/End: Quickly move the cursor to the beginning or end of the
    text using :kbd:`Ctrl` + :kbd:`Home` and :kbd:`Ctrl` + :kbd:`End`.
- Select Word/Line: Use double click to select current word, or triple click to
    select current line
- Select All: Select entire text by :kbd:`Ctrl` + :kbd:`A`
- Undo/Redo: Undo/Redo changes by :kbd:`Ctrl` + :kbd:`Z` / :kbd:`Ctrl` +
    :kbd:`Y`
- Clipboard Operations: Perform OS clipboard cut, copy, and paste operations on
    selected text, allowing you to paste the copied content into other
    applications.
- Copy Text: Use :kbd:`Ctrl` + :kbd:`C` to copy selected text.
    - copy selected text, if available
    - If no text is selected it copy the entire current line, including the
      terminating newline if present.
- Cut Text: Use :kbd:`Ctrl` + :kbd:`X` to cut selected text.
    - cut selected text, if available
    - If no text is selected it will cut the entire current line, including the
      terminating newline if present
- Paste Text: Use :kbd:`Ctrl` + :kbd:`V` to paste text from the clipboard into
    the editor.
    - replace selected text, if available
    - If no text is selected, paste text in the cursor position
- Scrolling behaviour for long text build-in
- Table of contents (:kbd:`Ctrl` + :kbd:`O`), with headers line prefixed by
    ``#``, e.g. ``# Fort history``, ``## Year 1``
- Table of contents navigation: jump to previous/next section by :kbd:`Ctrl` +
    :kbd:`Up` / :kbd:`Ctrl` + :kbd:`Down`

Usage
-----

::

    gui/journal
