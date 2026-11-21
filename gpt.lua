--@ module = true

local json = require('json')
local utils = require('utils')
local luasocket = require('plugins.luasocket')
local gui = require('gui')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')

--
-- TYPES
--

-- Enum for state of progress of the script.
local Status = {
  start = 0,
  waiting = 1,
  receiving = 2,
  done = 3
}

local function string_from_Status(status)
  if status == Status.start then return "start" end
  if status == Status.waiting then return "waiting" end
  if status == Status.receiving then return "receiving" end
  if status == Status.done then return "done" end
end

local Content_Type = {
  -- Non-fiction
  manual = 'manual',
  guide = 'guide',
  treatise = 'treatise',
  essay = 'essay',
  dictionary = 'dictionary',
  encyclopedia = 'encyclopedia',
  star_chart = 'star chart',
  -- Literature
  poem = 'poem',
  short_story = 'short story',
  novel = 'novel',
  alternate_history = 'alternate history',
  -- Individual
  letter = 'letter',
  autobiography = 'autobiography',
  biography = 'biography',
  comparative_biography = 'comparative biography',
  -- Group
  genealogy = 'genealogy',
  cultural_history = 'cultural history',
  cultural_comparison = 'cultural comparison',
  -- Unsupported
  unsupported = 'unsupported'
}

local Progress_Symbol = { '/', '-', '\\', '|' }

--
-- CONSTS
--

-- Whether or not to print debug outpuut to the console.
local is_debug_output_enabled = false

-- Port on which to communicate with the python helper.
local port = 5001

-- Max number of empty responses from the helper after receiving data before
-- assuming that the response is complete. (Each line is received individually.)
local max_retries = 5

-- Whether or not the client object should be configured as blocking.
local is_client_blocking = false

-- Seconds to configure the client object's timeout.
local client_timeout_secs = 60

-- Milliseconds to configure the client object's timeout.
local client_timeout_msecs = 0

-- Total client timeout time.
local timeout = client_timeout_secs + client_timeout_msecs/1000

-- Number of onRenderFrame events to wait before polling again.
local polling_interval = 10

-- Prompt component to use for generating excerpts of non-poetry knowledge items.
local excerpts_prompt = 'Now, imagine two paragraphs, each one taken directly from a different section within the described book. These excerpts should seem like two of the most interesting, insightful, or groundbreaking passages in the treatise. They should read as direct quotes from the text, not as summaries/reviews or quotations of an interview with the author. They should concern minute details of the subject, as an interesting example given by the author, or a colorful anecdote within the text. The two paragraphs should be labeled, Excerpt A and Excerpt B. Two blank newlines should separate the two excerpts cleanly. The text should generally fit in the context of the game, Dwarf Fortress.'
local star_chart_prompt = 'render an ASCII-art Dwarf Fortress star-chart inspired by that description using only Dwarvish names for stellar objects in the legend. DO NOT INCLUDE ANY references to Dwarf Fortress or the process of AI generation, the whole thing must be in-character! The star chart\'s title should match the above description!'

-- Local config filename.
local config = config or json.open('dfhack-config/gpt.json')

-- User-facing list of valid content types that the script currently supports.
local valid_content_type_list = (function()
  local list = 'a '

  local size = (function()
    local count = 0
    for _ in pairs(Content_Type) do count = count + 1 end
    return count
  end)()

  local last_supported_index = size - 2
  local index = 0

  for key, content_type in pairs(Content_Type) do
    if key == Content_Type.unsupported then goto continue end

    if index == last_supported_index then
      list = list .. 'or ' .. content_type .. '.'
    else
      list = list .. content_type .. ', '
    end

    index = index + 1
    ::continue::
  end

  return list
end)()

--
-- STATE VARS
--

-- Tracks the state of the script to manage execution flow.
local current_status = Status.start

-- Stores a reference to the client object while waiting/receiving a request.
local client = nil

-- Tracking to maintain polling interval.
local poll_count = 0

-- Current number of active retries.
local retries = 0

-- Cache for receiving data during polling.
local total_data = ''

-- When the request was submitted. Used for calculating timeout.
local start_time = nil

-- Text to display to the user.
local gui_text = "Waiting for knowledge text description..."

-- The most recently-submitted knowledge item. Used to avoid re-sending
-- the same item multiple times in a row.
local last_knowledge_description = nil

-- Counter to throttle checks of the UI.
local skip = 0

--
-- FUNCS
--

-- Prints `text` to the console if `is_debug_output_enabled` is true.
local function debug_log(text)
  if is_debug_output_enabled then print(text) end
end

-- Saves any configuration data to a JSON file.
local function save_config(data)
  utils.assign(config.data, data)
  config:write()
end

-- Observing setter for the `current_status` state var.
local function set_current_status(status)
  debug_log('Setting current status from ' .. string_from_Status(current_status) .. ' to ' .. string_from_Status(status))
  current_status = status
end

-- Determines and returns the Content_Type of a given written content description.
local function content_type_of(knowledge_text, is_knowledge_skill)
  for content_type in pairs(Content_Type) do
    local search_string = '' .. Content_Type[content_type]

    local knowledge_skill_prefix = 'is a '

    if content_type == Content_Type.essay or content_type == Content_Type.autobiography then
      knowledge_skill_prefix = 'is an '
    end

    if is_knowledge_skill then
      search_string = knowledge_skill_prefix .. search_string
    end

    if string.find(knowledge_text, search_string) then return content_type
    else debug_log('Warning: search string "' .. search_string .. 'not found in knowledge text: "' .. knowledge_text .. '".') end
  end

  return Content_Type.unsupported
end

-- Returns the knowledge item description of the currently-selected in-world object,
-- or nil if the item is not supported.
local function knowledge_item_description()
  local view_sheet = df.global.game.main_interface.view_sheets
  local knowledge_text = dfhack.df2utf(view_sheet.raw_description)

  if not knowledge_text then
    qerror('Error: item description unexpectedly nil. This script may have become out-of-date vs. the released game.')
  end

  local current_content_type = content_type_of(knowledge_text, false)

  return knowledge_text, current_content_type
end

-- Returns the in-game description of the currently selected written content, or nil if none is shown.
-- Also updates the UI to prompt the user for appropriate action.
local function knowledge_description()
  local view_sheet = df.global.game.main_interface.view_sheets

  if view_sheet.active_sheet == 1 then
    return knowledge_item_description()
  end

  local is_knowledge_tab_active = view_sheet.unit_skill_active_tab == 4

  if not is_knowledge_tab_active then
     gui_text = 'Please open the Skills > Knowledge tab.'
    return nil
  end

  if view_sheet.skill_description_width == 0 then
    debug_log('No knowledge item selected yet. Reloading.')
    gui_text = 'Please select a ' .. valid_content_type_list .. ' from the list.'
    return nil
  end

  local knowledge_text = dfhack.df2utf(view_sheet.skill_description_raw_str[0].value)
  local if_error_persists = 'Please retry this script. If this error persists, the latest DF update may have broken this script.'

  if not knowledge_text then
    qerror(string.concat("Error: Currently selected knowledge item's description is missing or empty. "..if_error_persists))
  end

  local knowledge_prefix_end_index = string.find(knowledge_text, ']')

  if not knowledge_prefix_end_index or string.len(knowledge_text) < knowledge_prefix_end_index then
    qerror(string.concat("Error: Currently selected knowledge item's text appears malformed. "..if_error_persists))
  end

  local current_content_type = content_type_of(knowledge_text, true)

  if current_content_type == Content_Type.unsupported then
    gui_text = 'This item is not ' .. valid_content_type_list .. ' Please select a valid category to have it generated.'
    return nil
  end

  local description = string.sub(knowledge_text, knowledge_prefix_end_index + 1)

  return description, current_content_type
end

-- Generate a prompt from the knowledge_description and content_type supplied.
local function promptFrom(knowledge_description, content_type)
  local prompt_value = ''
  debug_log('Creating prompt from content_type: ' .. content_type)

  if content_type == Content_Type.poem then
    debug_log('Creating poem.')
    prompt_value = 'Please write a poem given the following description of the poem and its style: \n\n'..knowledge_description
  elseif Content_Type[content_type] == Content_Type.star_chart then
    debug_log('Creating star chart.')
    prompt_value = 'Considering the star chart description between the >>> <<< below, ' .. star_chart_prompt .. ' >>> ' .. knowledge_description .. ' <<< '
  elseif content_type == Content_Type.unsupported then
    debug_log('Creating error response.')
    prompt_value = 'Return a response stating simply, "There has been an error."'
  else
    debug_log('Creating prompt for non-poem/non-star-chart/non-unsupported content_type: ' .. content_type)
    prompt_value = 'In between the four carrots is a description of a written ' .. content_type .. ': ^^^^' .. knowledge_description .. '^^^^. \n\n' .. excerpts_prompt
  end

  return prompt_value
end

-- Returns a properly formatted json request to send to
-- the gptserver.py script for submission to OpenAI APIs.
local function request_from(knowledge_description, content_type)
  local payload = {
    prompt = promptFrom(knowledge_description, content_type)
  }
  local request = json.encode(payload)
  return request
end

-- Sets up the `client` state var.
local function make_client()
  -- Setup client
  local client = luasocket.tcp:connect('localhost', port)
  if is_client_blocking then client:setBlocking() else client:setNonblocking() end
  client:setTimeout(client_timeout_secs,client_timeout_msecs)
  return client
end

-- Tears down the `client` state var and resets the `total_data` and `current_status` state vars.
local function stop_polling(client)
  debug_log('Final generated text:' .. gui_text)
  set_current_status(Status.done)
  debug_log('Done polling. Closing client and processing the response.\n')
  client:close()
  client = nil
  debug_log('Final status: ' .. current_status .. '\n')
  total_data = ''
  debug_log('Set gui_text to generated text, updating layout...')
  set_current_status(Status.start)
end

-- Swaps out common characters that don't render in DF and converts data to DF's character set.
local function sanitize_response(data)
  print(data)
  data = string.gsub(data, '“', '"')
  data = string.gsub(data, '”', '"')
  data = string.gsub(data, '‘', "'")
  data = string.gsub(data, '’', "'")
  data = string.gsub(data, ' — ', ' -- ')
  data = string.gsub(data, ' – ', ' -- ')
  data = string.gsub(data, '–', ' -- ')
  data = string.gsub(data, '—', ' -- ')
  data = dfhack.utf2df(data)
  return data
end

-- Updates a spinning progress indicator while waiting for response from OpenAI API.
local function update_progress_indicator()
  assert(current_status == Status.waiting, 'Assertion failure: progress indicator should only be updated while status is waiting. Actual status was: ' .. string_from_Status(current_status))
  local offset = os.difftime(os.time(), start_time) % 4
  local progress_symbol = Progress_Symbol[offset + 1]
  gui_text = gui_text:sub(1, gui_text:len() - 2) .. ' ' .. progress_symbol
end

-- Tries to get the latest data from the client while updating state vars used for
-- tracking progress of polling.
local function poll(client)
  if current_status == Status.done or current_status == Status.start then
    qerror('Callback tried to poll without being in receiving or waiting status. Status was: ' .. string_from_Status(current_status))
  end

  local data, err = client:receive()

  if err then
    qerror("Error from service: " .. err)
  end

  if data then
    retries = 0
    if current_status == Status.waiting then
      set_current_status(Status.receiving)
    elseif current_status ~= Status.receiving then
      qerror('Error: data received by polling while status was ' .. string_from_Status(current_status))
    end

    local sanitized_data = sanitize_response(data)

    if string.find(data, "Excerpt") then
      total_data = total_data .. NEWLINE .. NEWLINE .. sanitized_data
    else
      total_data = total_data .. NEWLINE .. sanitized_data
    end

    gui_text = total_data
  else
    if current_status == Status.receiving then
      if retries >= max_retries then
        debug_log("Max retries reached.")
        retries = 0
        stop_polling(client)
        return
      else
        retries = retries + 1
      end
    elseif current_status == Status.waiting then
      update_progress_indicator()
    end
  end

  if os.difftime(os.time(), start_time) >= timeout then
    debug_log('Reached time limit of ' .. timeout .. ', stopping polling.')
    retries = 0
    stop_polling(client)
    return
  end
end

-- Sends json request to the remote service helper.
local function send(request)
  if not pcall(function() client = make_client() end) then
    gui_text = 'Helper server is not running. cd into dfhack/scripts and run `python srv/gptserver.py` to start it. Press escape twice to close the current views, run gptserver.py, then reopen this window to generate the text.'
    last_knowledge_description = nil
    return
  end

  set_current_status(Status.waiting)
  start_time = os.time()
  debug_log('Sending request... \n')
  client:send(request)
  poll(client)
end

-- Primary entrypoint to the script's functionality. Initiates a check
-- of the UI to see if a supported written content item is being displayed.
-- If so, then submit a request to the remote helper script.
function fetch_generated_text()
  skip = skip + 1
  if skip < 20 then return end
  skip = 0

  if current_status ~= Status.start then
    debug_log("Current status was not start status, aborting. Status was: " .. string_from_Status(current_status))
    return
  end

  local knowledge_description, content_type = knowledge_description()

  if knowledge_description == last_knowledge_description then
    return
  end

  if not knowledge_description then
    debug_log('Poem description became nil, retrying...')
    last_knowledge_description = nil
    return
  end

  if content_type == Content_Type.unsupported then
    gui_text = "This content type is not supported. Please select a " .. valid_content_type_list .. "."
    last_knowledge_description = nil
    return
  end

  debug_log('Got new ' .. content_type .. " description: " .. knowledge_description .. "\n")
  last_knowledge_description = knowledge_description
  gui_text = "Generating text from description, please wait...  "
  debug_log("Submitting request to OpenAI remote service... \n")
  send(request_from(knowledge_description, content_type))
end

--
-- GUI: Overlay
--

GPTBannerOverlay = defclass(GPTBannerOverlay, overlay.OverlayWidget)
GPTBannerOverlay.ATTRS{
    default_pos={x=-35,y=-2},
    default_enabled=true,
    viewscreens={'dwarfmode/ViewSheets/UNIT','dwarfmode/ViewSheets/ITEM'},
    frame={w=30, h=1},
    frame_background=gui.CLEAR_PEN,
}

function GPTBannerOverlay:init()
    self:addviews{
      widgets.TextButton{
        frame={t=0, l=0},
        label='AI Generation View',
        key='CUSTOM_CTRL_G',
        on_activate=function() view = view and view:raise() or GPTScreen{}:show() end,
      },
    }
end

function GPTBannerOverlay:onInput(keys)
  if GPTBannerOverlay.super.onInput(self, keys) then return true end

  if keys._MOUSE_R_DOWN or keys.LEAVESCREEN then
    if view then
      view:dismiss()
    end
  end
end

OVERLAY_WIDGETS = {
    gptbanner=GPTBannerOverlay,
}

--
-- GUI: Window
--

local default_frame = {w=60, h=30, l=10, t=5}

GPTWindow = defclass(GPTWindow, widgets.Window)
GPTWindow.ATTRS{
    frame_title='Generated Text',
    resize_min=default_frame,
    resizable=true,
  }

function GPTWindow:init()
  self:addviews{
    widgets.WrappedLabel{
        view_id='label',
        frame={t=0, l=0, r=0, b=0},
        auto_height=false,
        text_to_wrap=function() return gui_text end,
        text_pen=COLOR_YELLOW,
    },
  }
  self.frame=copyall(config.data.frame or default_frame)
end

function GPTWindow:onRenderFrame(dc, rect)
    GPTWindow.super.onRenderFrame(self, dc, rect)

    if current_status == Status.start then fetch_generated_text()
    elseif current_status == Status.done then return
    elseif client ~= nil then
      if poll_count == polling_interval then
        poll(client)
        poll_count = 0
      else
        poll_count = poll_count + 1
      end
    end

    self.subviews.label:updateLayout()
end

function GPTWindow:postUpdateLayout()
  debug_log('saving frame')
  save_config({frame = self.frame})
end

--
-- GUI: Screen
--

GPTScreen = defclass(GPTScreen, gui.ZScreen)

GPTScreen.ATTRS {
    focus_path='gptscreen',
}

function GPTScreen:init()
    self:addviews{GPTWindow{}}
end

function GPTScreen:onDismiss()
    view = nil
end

--
-- Bootstrap
--

if dfhack_flags.module then
  return
end

debug_log('Loaded GPT.')
debug_log('valid content types: ' .. valid_content_type_list)
