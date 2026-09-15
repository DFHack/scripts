config.target = 'fix/stuck-written-materials'

local swm = reqscript('fix/stuck-written-materials')

local QUIRE_SUBTYPE, SCROLL_SUBTYPE = 100, 200
local ACTIVITY_EVENT, JOB_REF = 61, 2

local mock_df, mock_items, mock_print
local live_activities

-- emulates a df vector: 0-based indexing, # gives the element count
local function mock_vector(data)
    local vec = {_data = data or {}}
    return setmetatable(vec, {
        __index = function(self, k)
            if k == 'erase' then
                return function(_, i) table.remove(self._data, i + 1) end
            end
            if type(k) == 'number' then return self._data[k + 1] end
        end,
        __newindex = function(self, k, v) self._data[k + 1] = v end,
        __len = function(self) return #self._data end,
        __ipairs = function(self)
            local i = -1
            return function()
                i = i + 1
                local v = self._data[i + 1]
                if v ~= nil then return i, v end
            end
        end,
    })
end

local function mock_item(id, class, subtype)
    return {
        id = id,
        _class = class,
        flags = {in_job = false},
        general_refs = mock_vector(),
        specific_refs = mock_vector(),
        container = nil,
        getSubtype = function(self) return self._subtype end,
        _subtype = subtype,
    }
end

local function mock_book(id)
    return mock_item(id, 'book')
end

local function mock_tool(id, subtype)
    return mock_item(id, 'tool', subtype)
end

local function mock_activity_ref(activity_id)
    return {
        activity_id = activity_id,
        getType = function() return ACTIVITY_EVENT end,
        delete = mock.func(),
    }
end

local function mock_job_ref(job)
    return {
        type = JOB_REF,
        data = {job = job},
        delete = mock.func(),
    }
end

local function mock_other_ref()
    return {
        type = 0,
        getType = function() return 0 end,
        delete = mock.func(),
    }
end

local function mock_job(item_refs)
    return {items = mock_vector(item_refs)}
end

local function linked_list(jobs)
    local head = {}
    local link = head
    for _, job in ipairs(jobs) do
        link.next = {item = job}
        link = link.next
    end
    return head
end

local book_items, tool_items, jobs

config.wrapper = function(test_fn)
    book_items = mock_vector()
    tool_items = mock_vector()
    jobs = {}
    live_activities = {}

    mock_df = {
        item_bookst = {is_instance = function(_, item) return item._class == 'book' end},
        item_toolst = {is_instance = function(_, item) return item._class == 'tool' end},
        general_ref_type = {ACTIVITY_EVENT = ACTIVITY_EVENT},
        specific_ref_type = {JOB = JOB_REF},
        activity_entry = {find = function(id) return live_activities[id] end},
        global = {world = {
            items = {other = {BOOK = book_items, TOOL = tool_items}},
            jobs = {list = linked_list(jobs)},
        }},
    }
    mock_items = {
        findSubtype = function(name)
            if name == 'TOOL:ITEM_TOOL_QUIRE' then return QUIRE_SUBTYPE end
            if name == 'TOOL:ITEM_TOOL_SCROLL' then return SCROLL_SUBTYPE end
        end,
        getContainer = function(item) return item.container end,
        getDescription = function() return 'mock item' end,
    }
    mock_print = mock.func()

    mock.patch({{swm, 'df', mock_df},
                {swm.dfhack, 'items', mock_items},
                {swm.dfhack, 'df2console', function(s) return s end},
                {swm, 'print', mock_print}},
               test_fn)
end

local function add_job(items)
    local job = mock_job(items)
    table.insert(jobs, job)
    mock_df.global.world.jobs.list = linked_list(jobs)
    return job
end

function test.no_stuck_items()
    swm.fixWrittenMaterials({})
    expect.eq(0, mock_print.call_count)
end

function test.clears_stuck_in_job_flag()
    local book = mock_book(1)
    book.flags.in_job = true
    book_items[0] = book
    swm.fixWrittenMaterials({})
    expect.false_(book.flags.in_job)
    expect.str_find('Fixed 1 stuck written material', mock_print.call_args[2][1])
end

function test.removes_dead_job_ref()
    local book = mock_book(1)
    book.flags.in_job = true
    local ref = mock_job_ref({})
    book.specific_refs[0] = ref
    book_items[0] = book
    swm.fixWrittenMaterials({})
    expect.false_(book.flags.in_job)
    expect.eq(1, ref.delete.call_count)
    expect.eq(0, #book.specific_refs)
end

function test.removes_dead_activity_ref()
    local book = mock_book(1)
    local dead_ref = mock_activity_ref(42)
    local live_ref = mock_activity_ref(7)
    live_activities[7] = {}
    book.general_refs[0] = dead_ref
    book.general_refs[1] = live_ref
    book_items[0] = book
    swm.fixWrittenMaterials({})
    expect.eq(1, dead_ref.delete.call_count)
    expect.eq(0, live_ref.delete.call_count)
    expect.eq(1, #book.general_refs)
    expect.eq(live_ref, book.general_refs[0])
end

function test.ignores_item_in_live_job()
    local book = mock_book(1)
    book.flags.in_job = true
    book_items[0] = book
    add_job({{item = book}})
    swm.fixWrittenMaterials({})
    expect.true_(book.flags.in_job)
    expect.eq(0, mock_print.call_count)
end

function test.ignores_item_whose_container_is_in_live_job()
    local bag = mock_item(2, 'tool')
    local book = mock_book(1)
    book.flags.in_job = true
    book.container = bag
    book_items[0] = book
    add_job({{item = bag}})
    swm.fixWrittenMaterials({})
    expect.true_(book.flags.in_job)
    expect.eq(0, mock_print.call_count)
end

function test.handles_quire_and_scroll()
    local quire = mock_tool(1, QUIRE_SUBTYPE)
    local scroll = mock_tool(2, SCROLL_SUBTYPE)
    quire.flags.in_job = true
    scroll.flags.in_job = true
    tool_items[0] = quire
    tool_items[1] = scroll
    swm.fixWrittenMaterials({})
    expect.false_(quire.flags.in_job)
    expect.false_(scroll.flags.in_job)
end

function test.ignores_unrelated_tool()
    local item = mock_tool(1, 999)
    item.flags.in_job = true
    tool_items[0] = item
    swm.fixWrittenMaterials({})
    expect.true_(item.flags.in_job)
    expect.eq(0, mock_print.call_count)
end

function test.dry_run_reports_without_changing()
    local book = mock_book(1)
    book.flags.in_job = true
    local ref = mock_job_ref({})
    book.specific_refs[0] = ref
    book_items[0] = book
    swm.fixWrittenMaterials({dry_run = true})
    expect.true_(book.flags.in_job)
    expect.eq(0, ref.delete.call_count)
    expect.str_find('Found 1 stuck written material', mock_print.call_args[2][1])
end
