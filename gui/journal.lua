-- Fort journal with a multi-line text editor
--@ module = true

local gui = require 'gui'
local widgets = require 'gui.widgets'
local utils = require 'utils'
local json = require 'json'
local shifter = reqscript('internal/journal/shifter')
local table_of_contents = reqscript('internal/journal/table_of_contents')
local journal_context = reqscript('internal/journal/journal_context')

local RESIZE_MIN = {w=54, h=20}
local TOC_RESIZE_MIN = {w=24}

journal_config = journal_config or json.open('dfhack-config/journal.json')

JOURNAL_CONTEXT_MODE = journal_context.JOURNAL_CONTEXT_MODE

JournalWindow = defclass(JournalWindow, widgets.Window)
JournalWindow.ATTRS {
    frame_title='DF Journal',
    resizable=true,
    resize_min=RESIZE_MIN,
    frame_inset={l=0,r=0,t=0,b=0},
    init_text=DEFAULT_NIL,
    init_cursor=1,
    save_layout=true,
    show_tutorial=false,

    toc_welcome_copy=DEFAULT_NIL,
    journal_welcome_copy=DEFAULT_NIL,

    on_text_change=DEFAULT_NIL,
    on_cursor_change=DEFAULT_NIL,
    on_layout_change=DEFAULT_NIL
}

function JournalWindow:init()
    local frame, toc_visible, toc_width = self:loadConfig()

    self.frame = frame and self:sanitizeFrame(frame) or self.frame

    self:addviews{
        table_of_contents.TableOfContents{
            view_id='table_of_contents_panel',
            frame={l=0, w=toc_width, t=0, b=1},
            visible=toc_visible,
            frame_inset={l=1, t=0, b=1, r=1},

            resize_min=TOC_RESIZE_MIN,
            resizable=true,
            resize_anchors={l=false, t=false, b=true, r=true},

            on_resize_begin=self:callback('onPanelResizeBegin'),
            on_resize_end=self:callback('onPanelResizeEnd'),

            on_submit=self:callback('onTableOfContentsSubmit'),
            subviews={
                widgets.WrappedLabel{
                    view_id='table_of_contents_tutorial',
                    frame={l=0,t=0,r=0,b=3},
                    text_to_wrap=self.toc_welcome_copy or '',
                    visible=false
                }
            }
        },
        shifter.Shifter{
            view_id='shifter',
            frame={l=0, w=1, t=1, b=2},
            collapsed=not toc_visible,
            on_changed = function (collapsed)
                self.subviews.table_of_contents_panel.visible = not collapsed
                self.subviews.table_of_contents_divider.visible = not collapsed

                if not collapsed then
                    self:reloadTableOfContents()
                end

                self:ensurePanelsRelSize()
                self:updateLayout()
            end,
        },
        widgets.Divider{
            frame={l=0,r=0,b=2,h=1},
            frame_style_l=false,
            frame_style_r=false,
            interior_l=true,
        },
        widgets.Divider{
            view_id='table_of_contents_divider',

            frame={l=30,t=0,b=2,w=1},
            visible=toc_visible,

            interior_b=true,
            frame_style_t=false,
        },
        widgets.TextArea{
            view_id='journal_editor',
            frame={t=1, b=3, l=25, r=0},
            resize_min={w=30, h=10},
            frame_inset={l=1,r=0},
            init_text=self.init_text,
            init_cursor=self.init_cursor,
            on_text_change=self:callback('onTextChange'),
            on_cursor_change=self:callback('onCursorChange'),
        },
        widgets.HelpButton{command="gui/journal", frame={r=0,t=1}},
        widgets.Panel{
            frame={l=0,r=0,b=1,h=1},
            frame_inset={l=1,r=1,t=0, w=100},
            subviews={
                widgets.HotkeyLabel{
                    frame={l=0},
                    key='CUSTOM_CTRL_O',
                    label='Toggle table of contents',
                    auto_width=true,
                    on_activate=function() self.subviews.shifter:toggle() end
                }
            }
        }
    }

    if self.show_tutorial then
        self.subviews.journal_editor:addviews{
            widgets.WrappedLabel{
                view_id='journal_tutorial',
                frame={l=0,t=1,r=0,b=0},
                text_to_wrap=self.journal_welcome_copy or ''
            }
        }
    end

    self:reloadTableOfContents()
end

function JournalWindow:reloadTableOfContents()
    self.subviews.table_of_contents_panel:reload(
        self.subviews.journal_editor:getText(),
        self.subviews.journal_editor:getCursor() or self.init_cursor
    )
    self.subviews.table_of_contents_panel.subviews.table_of_contents_tutorial.visible =
       #self.subviews.table_of_contents_panel:sections() == 0
end

function JournalWindow:sanitizeFrame(frame)
    local w, h = dfhack.screen.getWindowSize()
    local min = RESIZE_MIN
    if frame.t and h - frame.t - (frame.b or 0) < min.h then
        frame.t = h - min.h
        frame.b = 0
    end
    if frame.b and h - frame.b - (frame.t or 0) < min.h then
        frame.b = h - min.h
        frame.t = 0
    end
    if frame.l and w - frame.l - (frame.r or 0) < min.w then
        frame.l = w - min.w
        frame.r = 0
    end
    if frame.r and w - frame.r - (frame.l or 0) < min.w then
        frame.r = w - min.w
        frame.l = 0
    end
    return frame
end

function JournalWindow:saveConfig()
    if not self.save_layout then
        return
    end

    local toc = self.subviews.table_of_contents_panel

    utils.assign(journal_config.data, {
        frame = self.frame,
        toc = {
            width = toc.frame.w,
            visible = toc.visible
        }
    })
    journal_config:write()
end

function JournalWindow:loadConfig()
    if not self.save_layout then
        return nil, false, 25
    end

    local window_frame = copyall(journal_config.data.frame or {})
    window_frame.w = window_frame.w or 80
    window_frame.h = window_frame.h or 50

    local toc = copyall(journal_config.data.toc or {})
    toc.width = math.max(toc.width or 25, TOC_RESIZE_MIN.w)
    toc.visible = toc.visible or false

    return window_frame, toc.visible, toc.width
end

function JournalWindow:onPanelResizeBegin()
    self.resizing_panels = true
end

function JournalWindow:onPanelResizeEnd()
    self.resizing_panels = false
    self:ensurePanelsRelSize()

    self:updateLayout()
end

function JournalWindow:onRenderBody(painter)
    if self.resizing_panels then
        self:ensurePanelsRelSize()
        self:updateLayout()
    end

    return JournalWindow.super.onRenderBody(self, painter)
end

function JournalWindow:ensurePanelsRelSize()
    local toc_panel = self.subviews.table_of_contents_panel
    local editor = self.subviews.journal_editor
    local divider = self.subviews.table_of_contents_divider

    toc_panel.frame.w = math.min(
        math.max(toc_panel.frame.w, TOC_RESIZE_MIN.w),
        self.frame.w - editor.resize_min.w
    )
    editor.frame.l = toc_panel.visible and toc_panel.frame.w or 1
    divider.frame.l = editor.frame.l - 1
end

function JournalWindow:preUpdateLayout()
    self:ensurePanelsRelSize()
end

function JournalWindow:postUpdateLayout()
    self:saveConfig()
end

function JournalWindow:onCursorChange(cursor)
    self.subviews.table_of_contents_panel:setCursor(cursor)
    local section_index = self.subviews.table_of_contents_panel:currentSection()
    self.subviews.table_of_contents_panel:setSelectedSection(section_index)

    if self.on_cursor_change ~= nil then
        self.on_cursor_change(cursor)
    end
end

function JournalWindow:onTextChange(text)
    if self.show_tutorial then
        self.subviews.journal_editor.subviews.journal_tutorial.visible = false
    end
    self:reloadTableOfContents()

    if self.on_text_change ~= nil then
        self.on_text_change(text)
    end
end

function JournalWindow:onTableOfContentsSubmit(ind, section)
    self.subviews.journal_editor:setCursor(section.line_cursor)
    self.subviews.journal_editor:scrollToCursor(section.line_cursor)
end

JournalScreen = defclass(JournalScreen, gui.ZScreen)
JournalScreen.ATTRS {
    focus_path='journal',
    pass_pause=false,
    context_mode=DEFAULT_NIL,
    save_layout=true,
    save_prefix=''
}

function JournalScreen:init()
    self.journal_context = journal_context.journal_context_factory(
        self.context_mode,
        self.save_prefix
    )
    local content = self.journal_context:load_content()

    self:addviews{
        JournalWindow{
            view_id='journal_window',
            frame={w=65, h=45},

            save_layout=self.save_layout,

            init_text=content.text[1],
            init_cursor=content.cursor[1],
            show_tutorial=content.show_tutorial or false,

            toc_welcome_copy=self.journal_context:tocWelcomeCopy(),
            journal_welcome_copy=self.journal_context:welcomeCopy(),

            on_text_change=self:callback('onTextChange'),
            on_cursor_change=self:callback('onTextChange')
        },
    }
end

function JournalScreen:onTextChange()
    local text = self.subviews.journal_editor:getText()
    local cursor = self.subviews.journal_editor:getCursor()

    self.journal_context:save_content(text, cursor)
end

function JournalScreen:onDismiss()
    view = nil
end

function main(options)
    if not dfhack.isMapLoaded() or (not dfhack.world.isFortressMode()
        and not dfhack.world.isAdventureMode()) then
        qerror('journal requires a fortress/adventure map to be loaded')
    end

    local save_layout = options and options.save_layout
    local overrided_context_mode = options and options.context_mode
    local context_mode = overrided_context_mode == nil and
        journal_context.detect_journal_context_mode() or overrided_context_mode

    view = view and view:raise() or JournalScreen{
        save_prefix=options and options.save_prefix or '',
        save_layout=save_layout == nil and true or save_layout,
        context_mode=context_mode,
    }:show()
end

if not dfhack_flags.module then
    main()
end
