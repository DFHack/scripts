-- Editor base class for gui/gm-unit. Every other editor should inherit from this.
--@ module = true

local gui = require 'gui'

Editor = defclass(Editor, gui.FramedScreen)
Editor.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    target_unit = DEFAULT_NIL
}
