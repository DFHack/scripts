config.target = 'prioritize'

local eventful = require('plugins.eventful')
local prioritize = reqscript('prioritize')
local utils = require('utils')
local p = prioritize.unit_test_hooks

-- mock out state and external dependencies
local mock_eventful_onUnload, mock_eventful_onJobInitiated = {}, {}
local mock_print = mock.func()
local mock_watched_job_matchers = {}
local function get_mock_watched_job_matchers()
    return mock_watched_job_matchers
end
local mock_postings = {}
local function get_mock_postings() return mock_postings end
local mock_job_list = {}
local function get_mock_job_list() return mock_job_list end
local mock_reactions = {{code='TAN_A_HIDE'}}
local function get_mock_reactions() return mock_reactions end
local function test_wrapper(test_fn)
    mock.patch({{eventful, 'onUnload', mock_eventful_onUnload},
                {eventful, 'onJobInitiated', mock_eventful_onJobInitiated},
                {prioritize, 'print', mock_print},
                {prioritize, 'get_watched_job_matchers',
                 get_mock_watched_job_matchers},
                {prioritize, 'get_postings', get_mock_postings},
                {prioritize, 'get_job_list', get_mock_job_list},
                {prioritize, 'get_reactions', get_mock_reactions}},
               test_fn)
    mock_eventful_onUnload, mock_eventful_onJobInitiated = {}, {}
    mock_print = mock.func()
    mock_watched_job_matchers, mock_postings = {}, {}
    mock_job_list = {}
    mock_reactions = {{code='TAN_A_HIDE'}}
end
config.wrapper = test_wrapper

local DIG, EAT, REST = df.job_type.Dig, df.job_type.Eat, df.job_type.Rest
local STORE_ITEM_IN_STOCKPILE = df.job_type.StoreItemInStockpile
local CUSTOM_REACTION = df.job_type.CustomReaction
local SUTURE = df.job_type.Suture

local HAUL_STONE, HAUL_WOOD = df.unit_labor.HAUL_STONE, df.unit_labor.HAUL_WOOD
local HAUL_BODY, HAUL_FOOD = df.unit_labor.HAUL_BODY, df.unit_labor.HAUL_FOOD
local HAUL_REFUSE = df.unit_labor.HAUL_REFUSE
local HAUL_ITEM = df.unit_labor.HAUL_ITEM
local HAUL_FURNITURE = df.unit_labor.HAUL_FURNITURE
local HAUL_ANIMALS = df.unit_labor.HAUL_ANIMALS

-- build a df-style linked list (sentinel head node) containing the given jobs
local function make_job_list(jobs)
    local list = {}
    local tail = list
    for _,job in ipairs(jobs) do
        tail.next = {item=job}
        tail = tail.next
    end
    return list
end

function test.status()
    p.status()
    expect.eq(1, mock_print.call_count)
    expect.eq('Not automatically prioritizing any jobs.',
              mock_print.call_args[1][1])

    mock_watched_job_matchers[REST] = {}
    p.status()
    expect.eq(3, mock_print.call_count)
    expect.eq('Automatically prioritized jobs:', mock_print.call_args[2][1])
    expect.str_find('Rest', mock_print.call_args[3][1])
end

function test.status_labor()
    mock_watched_job_matchers[STORE_ITEM_IN_STOCKPILE] =
            {hauler_matchers={[HAUL_BODY]=0}}
    p.status()
    expect.eq(2, mock_print.call_count)
    expect.eq('Automatically prioritized jobs:', mock_print.call_args[1][1])
    expect.str_find('Stockpile.*Body', mock_print.call_args[2][1])
end

function test.status_reaction()
    mock_watched_job_matchers[CUSTOM_REACTION] =
            {reaction_matchers={TAN_A_HIDE=0}}
    p.status()
    expect.eq(2, mock_print.call_count)
    expect.eq('Automatically prioritized jobs:', mock_print.call_args[1][1])
    expect.str_find('Custom.*TAN_A_HIDE', mock_print.call_args[2][1])
end

function test.boost()
    local dig1 = {job_type=DIG, flags={}}
    local dig2 = {job_type=DIG, flags={}}
    local eat1 = {job_type=EAT, flags={do_now=true}}
    local eat2 = {job_type=EAT, flags={}}
    local special = {job_type=EAT, flags={special=true}}
    mock_job_list = make_job_list{dig1, dig2, eat1, eat2, special}
    p.boost({[EAT]={}}, {})
    expect.eq(2, mock_print.call_count)
    expect.eq('Prioritized 1 job.', mock_print.call_args[1][1])
    expect.eq('1 job already prioritized.', mock_print.call_args[2][1])
    expect.nil_(dig1.flags.do_now)
    expect.nil_(dig2.flags.do_now)
    expect.true_(eat1.flags.do_now)
    expect.true_(eat2.flags.do_now)
    expect.nil_(special.flags.do_now)
end

function test.boost_quiet()
    local eat1 = {job_type=EAT, flags={}}
    local eat2 = {job_type=EAT, flags={}}
    mock_job_list = make_job_list{eat1, eat2}
    p.boost({[EAT]={}}, {quiet=true})
    expect.eq(0, mock_print.call_count)
    expect.true_(eat1.flags.do_now)
    expect.true_(eat2.flags.do_now)
end

function test.boost_and_watch()
    p.boost_and_watch({[SUTURE]={}}, {})
    expect.eq(2, mock_print.call_count)
    expect.str_find('^Prioritized', mock_print.call_args[1][1])
    expect.str_find('^Automatically', mock_print.call_args[2][1])
    expect.table_eq({[SUTURE]={}}, mock_watched_job_matchers)

    p.boost_and_watch({[SUTURE]={}}, {})
    expect.eq(4, mock_print.call_count)
    expect.str_find('^Prioritized', mock_print.call_args[3][1])
    expect.str_find('^Skipping', mock_print.call_args[4][1])
    expect.table_eq({[SUTURE]={}}, mock_watched_job_matchers)
end

-- dig/smooth job types are on the denylist: current jobs still get boosted,
-- but no watch is registered and a warning is printed
function test.boost_and_watch_denylisted()
    expect.printerr_match({'Priortizing current jobs', 'smooth/engrave',
                           'overwhelm', 'mining'},
        function()
            p.boost_and_watch({[DIG]={}}, {})
        end)
    expect.table_eq({}, mock_watched_job_matchers)
end

function test.boost_and_watch_quiet()
    p.boost_and_watch({[SUTURE]={}}, {quiet=true})
    expect.eq(0, mock_print.call_count)
    expect.table_eq({[SUTURE]={}}, mock_watched_job_matchers)

    p.boost_and_watch({[SUTURE]={}}, {quiet=true})
    expect.eq(0, mock_print.call_count)
    expect.table_eq({[SUTURE]={}}, mock_watched_job_matchers)
end

function test.remove_watch()
    p.remove_watch({[SUTURE]={}}, {})
    expect.eq(1, mock_print.call_count)
    expect.str_find('Skipping unwatched', mock_print.call_args[1][1])
    expect.table_eq({}, mock_watched_job_matchers)

    mock_watched_job_matchers[SUTURE] = {}
    p.remove_watch({[SUTURE]={}}, {})
    expect.eq(2, mock_print.call_count)
    expect.str_find('No longer', mock_print.call_args[2][1])
end

function test.remove_watch_quiet()
    p.remove_watch({[SUTURE]={}}, {quiet=true})
    expect.eq(0, mock_print.call_count)
    expect.table_eq({}, mock_watched_job_matchers)

    mock_watched_job_matchers[SUTURE] = {}
    p.remove_watch({[SUTURE]={}}, {quiet=true})
    expect.eq(0, mock_print.call_count)
    expect.table_eq({}, mock_watched_job_matchers)
end

function test.boost_and_watch_labor()
    mock_job_list = make_job_list{
        {job_type=DIG, flags={}},
        {job_type=STORE_ITEM_IN_STOCKPILE, item_subtype=HAUL_FOOD, flags={}},
        {job_type=STORE_ITEM_IN_STOCKPILE, item_subtype=HAUL_ITEM, flags={}},
        {job_type=STORE_ITEM_IN_STOCKPILE, item_subtype=HAUL_ITEM, flags={}},
        {job_type=STORE_ITEM_IN_STOCKPILE, item_subtype=HAUL_ITEM,
         flags={special=true}}}

    p.boost_and_watch({[STORE_ITEM_IN_STOCKPILE]=
                            {hauler_matchers={[HAUL_ITEM]=0}}},
                      {})
    expect.eq(2, mock_print.call_count)
    expect.str_find('^Prioritized 2', mock_print.call_args[1][1])
    expect.str_find('^Automatically', mock_print.call_args[2][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]=
                         {hauler_matchers={[HAUL_ITEM]=0}}},
                    mock_watched_job_matchers)

    p.boost_and_watch({[STORE_ITEM_IN_STOCKPILE]={}}, {})
    expect.eq(5, mock_print.call_count)
    expect.str_find('^Prioritized 1', mock_print.call_args[3][1])
    expect.str_find('^2 jobs already prioritized', mock_print.call_args[4][1])
    expect.str_find('^Automatically', mock_print.call_args[5][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]={}}, mock_watched_job_matchers)
end

function test.boost_and_watch_store_all_labors()
    p.boost_and_watch({[STORE_ITEM_IN_STOCKPILE]={}}, {})
    expect.eq(2, mock_print.call_count)
    expect.str_find('^Prioritized 0', mock_print.call_args[1][1])
    expect.str_find('^Automatically', mock_print.call_args[2][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]={}},
                    mock_watched_job_matchers)

    p.boost_and_watch({[STORE_ITEM_IN_STOCKPILE]={}}, {})
    expect.eq(4, mock_print.call_count)
    expect.str_find('^Prioritized 0', mock_print.call_args[3][1])
    expect.str_find('^Skipping', mock_print.call_args[4][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]={}},
                    mock_watched_job_matchers)

    p.boost_and_watch({[STORE_ITEM_IN_STOCKPILE]=
                            {hauler_matchers={[HAUL_ITEM]=0}}}, {})
    expect.eq(6, mock_print.call_count)
    expect.str_find('^Prioritized 0', mock_print.call_args[5][1])
    expect.str_find('^Skipping.*Item', mock_print.call_args[6][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]={}},
                    mock_watched_job_matchers)
end

function test.boost_and_watch_store_add_labors()
    p.boost_and_watch({[STORE_ITEM_IN_STOCKPILE]=
                            {hauler_matchers={[HAUL_ITEM]=0}}}, {})
    expect.eq(2, mock_print.call_count)
    expect.str_find('^Prioritized 0', mock_print.call_args[1][1])
    expect.str_find('^Automatically.*Item', mock_print.call_args[2][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]=
                         {hauler_matchers={[HAUL_ITEM]=0}}},
                    mock_watched_job_matchers)

    p.boost_and_watch({[STORE_ITEM_IN_STOCKPILE]=
                            {hauler_matchers={[HAUL_FOOD]=0}}}, {})
    expect.eq(4, mock_print.call_count)
    expect.str_find('^Prioritized 0', mock_print.call_args[3][1])
    expect.str_find('^Automatically.*Food', mock_print.call_args[4][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]=
                         {hauler_matchers={[HAUL_ITEM]=0, [HAUL_FOOD]=0}}},
                    mock_watched_job_matchers)

    p.boost_and_watch({[STORE_ITEM_IN_STOCKPILE]=
                            {hauler_matchers={[HAUL_FOOD]=0}}}, {})
    expect.eq(6, mock_print.call_count)
    expect.str_find('^Prioritized 0', mock_print.call_args[5][1])
    expect.str_find('^Skipping.*Food', mock_print.call_args[6][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]=
                         {hauler_matchers={[HAUL_ITEM]=0, [HAUL_FOOD]=0}}},
                    mock_watched_job_matchers)
end

function test.boost_and_watch_reactions()
    p.boost_and_watch({[CUSTOM_REACTION]=
                            {reaction_matchers={TAN_A_HIDE=0}}}, {})
    expect.eq(2, mock_print.call_count)
    expect.str_find('^Prioritized 0', mock_print.call_args[1][1])
    expect.str_find('^Automatically.*TAN_A_HIDE', mock_print.call_args[2][1])
    expect.table_eq({[CUSTOM_REACTION]={reaction_matchers={TAN_A_HIDE=0}}},
                    mock_watched_job_matchers)
end

function test.remove_one_labor_from_all()
    mock_watched_job_matchers = {[STORE_ITEM_IN_STOCKPILE]={}}

    p.remove_watch({[STORE_ITEM_IN_STOCKPILE]=
                        {hauler_matchers={[HAUL_FOOD]=0}}},
                      {})
    expect.eq(1, mock_print.call_count)
    expect.str_find('No longer.*Food', mock_print.call_args[1][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]=
        {hauler_matchers={[HAUL_STONE]=0, [HAUL_WOOD]=0, [HAUL_BODY]=0,
                          [HAUL_REFUSE]=0, [HAUL_ITEM]=0, [HAUL_FURNITURE]=0,
                          [HAUL_ANIMALS]=0}}},
                    mock_watched_job_matchers)

    p.remove_watch({[STORE_ITEM_IN_STOCKPILE]=
                        {hauler_matchers={[HAUL_FOOD]=0}}},
                   {})
    expect.eq(2, mock_print.call_count)
    expect.str_find('Skipping.*Food', mock_print.call_args[2][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]=
        {hauler_matchers={[HAUL_STONE]=0, [HAUL_WOOD]=0, [HAUL_BODY]=0,
                          [HAUL_REFUSE]=0, [HAUL_ITEM]=0, [HAUL_FURNITURE]=0,
                          [HAUL_ANIMALS]=0}}},
                    mock_watched_job_matchers)
end

function test.remove_all_reactions_from_all()
    mock_watched_job_matchers = {[CUSTOM_REACTION]={}}

    -- we only have one reaction in our mock registry. if we remove it by name
    -- from an unrestricted CUSTOM_REACTION matcher, the entire matcher should
    -- disappear
    p.remove_watch({[CUSTOM_REACTION]={reaction_matchers={TAN_A_HIDE=0}}},
                   {})
    expect.eq(1, mock_print.call_count)
    expect.str_find('No longer.*TAN_A_HIDE', mock_print.call_args[1][1])
    expect.table_eq({}, mock_watched_job_matchers)
end

function test.eventful_hook_lifecycle()
    expect.nil_(mock_eventful_onUnload.prioritize)
    expect.nil_(mock_eventful_onJobInitiated.prioritize)

    p.boost_and_watch({[SUTURE]={}}, {quiet=true})
    expect.table_eq({[SUTURE]={}}, mock_watched_job_matchers)

    expect.eq(p.clear_watched_job_matchers, mock_eventful_onUnload.prioritize)
    expect.eq(p.on_new_job, mock_eventful_onJobInitiated.prioritize)

    p.remove_watch({[SUTURE]={}}, {quiet=true})
    expect.table_eq({}, mock_watched_job_matchers)

    expect.nil_(mock_eventful_onUnload.prioritize)
    expect.nil_(mock_eventful_onJobInitiated.prioritize)
end

function test.eventful_callbacks()
    -- unwatched job
    local job = {job_type=DIG, flags={}}
    local expected = {job_type=DIG, flags={}}
    p.on_new_job(job)
    expect.table_eq(expected, job)

    -- watched job
    job = {job_type=SUTURE, flags={}}
    expected = {job_type=SUTURE, flags={do_now=true}}
    p.boost_and_watch({[SUTURE]={}}, {quiet=true})
    p.on_new_job(job)
    expect.table_eq(expected, job)

    -- map unload
    p.clear_watched_job_matchers()
    expect.table_eq({}, mock_watched_job_matchers)
    expect.nil_(mock_eventful_onUnload.prioritize)
    expect.nil_(mock_eventful_onJobInitiated.prioritize)
end

function test.eventful_callbacks_labor()
    mock_watched_job_matchers[STORE_ITEM_IN_STOCKPILE] =
            {hauler_matchers={[HAUL_FOOD]=0}}

    -- unwatched job
    local job = {job_type=STORE_ITEM_IN_STOCKPILE, item_subtype=HAUL_BODY,
                 flags={}}
    local expected_job = utils.clone(job)
    local expected_watched_job_matchers = utils.clone(mock_watched_job_matchers)
    p.on_new_job(job)
    expect.table_eq(expected_job, job)
    expect.table_eq(expected_watched_job_matchers, mock_watched_job_matchers)

    -- watched job
    job = {job_type=STORE_ITEM_IN_STOCKPILE, item_subtype=HAUL_FOOD,
           flags={}}
    expected_job = {job_type=STORE_ITEM_IN_STOCKPILE, item_subtype=HAUL_FOOD,
           flags={do_now=true}}
    p.on_new_job(job)
    expect.table_eq(expected_job, job)
    expect.table_eq(expected_watched_job_matchers, mock_watched_job_matchers)
end

function test.eventful_callbacks_reaction()
    mock_watched_job_matchers[CUSTOM_REACTION] =
            {reaction_matchers={TAN_A_HIDE=0}}

    -- unwatched job
    local job = {job_type=CUSTOM_REACTION, reaction_name='STEEL_MAKING',
                 flags={}}
    local expected_job = utils.clone(job)
    local expected_watched_job_matchers = utils.clone(mock_watched_job_matchers)
    p.on_new_job(job)
    expect.table_eq(expected_job, job)
    expect.table_eq(expected_watched_job_matchers, mock_watched_job_matchers)

    -- watched job
    job = {job_type=CUSTOM_REACTION, reaction_name='TAN_A_HIDE', flags={}}
    expected_job = {job_type=CUSTOM_REACTION, reaction_name='TAN_A_HIDE',
           flags={do_now=true}}
    p.on_new_job(job)
    expect.table_eq(expected_job, job)
    expect.table_eq(expected_watched_job_matchers, mock_watched_job_matchers)
end

function test.print_current_jobs_empty()
    p.print_current_jobs({})
    expect.eq(1, mock_print.call_count)
    expect.eq('No current prioritizable jobs.', mock_print.call_args[1][1])
end

function test.print_current_jobs_full()
    local dig1 = {job_type=DIG, flags={}}
    local store_job = {job_type=STORE_ITEM_IN_STOCKPILE,
                       item_subtype=HAUL_FOOD, flags={}}
    local custom_job = {job_type=CUSTOM_REACTION,
                        reaction_name='TAN_A_HIDE', flags={}}
    mock_job_list = make_job_list{
        dig1,
        {job_type=DIG, flags={}},
        {job_type=EAT, flags={}},
        {job_type=EAT, flags={do_now=true}},
        {job_type=EAT, flags={special=true}},
        {job_type=REST, flags={}},
        store_job,
        custom_job}
    mock_postings = {{job=dig1, flags={}},
                     {job=store_job, flags={}},
                     {job=custom_job, flags={}},
                     {job={job_type=DIG, flags={}}, flags={dead=true}}}
    p.print_current_jobs({})
    -- 4 header lines plus one line per job type
    expect.eq(9, mock_print.call_count)
    expect.eq('Current prioritizable jobs:', mock_print.call_args[1][1])
    local result = {}
    for i,v in ipairs(mock_print.call_args) do
        if i <= 4 then goto continue end
        local _,_,unclaimed,total,job_type = v[1]:find('^%s*(%d+)%s+(%d+)%s+(.+)$')
        expect.ne(nil, unclaimed)
        expect.nil_(result[job_type])
        result[job_type] = {unclaimed, total}
        ::continue::
    end
    expect.table_eq({
            ['Dig']={'1', '2'},
            ['Eat']={'0', '1'},
            ['Rest']={'0', '1'},
            ['StoreItemInStockpile --haul-labor Food']={'1', '1'},
            ['CustomReaction --reaction-name TAN_A_HIDE']={'1', '1'},
        }, result)
end

function test.print_current_jobs_filtered()
    local dig1 = {job_type=DIG, flags={}}
    mock_job_list = make_job_list{
        dig1,
        {job_type=DIG, flags={}},
        {job_type=EAT, flags={}},
        {job_type=EAT, flags={special=true}},
        {job_type=REST, flags={}}}
    mock_postings = {{job=dig1, flags={}}}
    p.print_current_jobs({[EAT]={}})
    expect.eq(5, mock_print.call_count)
    expect.eq('Current prioritizable jobs:', mock_print.call_args[1][1])
    local _,_,unclaimed,total,job_type =
        mock_print.call_args[5][1]:find('^%s*(%d+)%s+(%d+)%s+(.+)$')
    expect.eq('0', unclaimed)
    expect.eq('1', total)
    expect.eq('Eat', job_type)
end

function test.print_registry()
    p.print_registry()
    expect.lt(1, mock_print.call_count)
    for i,v in ipairs(mock_print.call_args) do
        local out = v[1]:trim()
        expect.ne('nil', tostring(out))
        expect.ne('NONE', out)
    end
end

function test.print_registry_no_raws()
    mock_reactions = {}
    p.print_registry()
    expect.lt(1, mock_print.call_count)
    expect.eq('Load a game to see reactions',
              mock_print.call_args[#mock_print.call_args][1]:trim())
end

function test.parse_commandline()
    expect.table_eq({help=true}, p.parse_commandline{'help'})
    expect.table_eq({help=true}, p.parse_commandline{'-h'})
    expect.table_eq({help=true}, p.parse_commandline{'--help'})

    expect.table_eq({action=p.status, job_matchers={}}, p.parse_commandline{})
    expect.table_eq({action=p.boost,
                     job_matchers={[SUTURE]={}}},
                    p.parse_commandline{'Suture'})
    expect.printerr_match('Ignoring unknown job type',
        function()
            expect.table_eq({action=p.status, job_matchers={}},
                            p.parse_commandline{'XSutureX'})
        end)
    expect.printerr_match('Ignoring unknown job type',
        function()
            expect.table_eq({action=p.boost,
                             job_matchers={[SUTURE]={}}},
                            p.parse_commandline{'XSutureX', 'Suture'})
        end)
    expect.printerr_match('Ignoring unknown unit labor',
        function()
            expect.table_eq({action=p.status, job_matchers={}},
                            p.parse_commandline{'-lXFoodX'})
        end)
    expect.printerr_match('Ignoring unknown reaction name',
        function()
            expect.table_eq({action=p.status, job_matchers={}},
                            p.parse_commandline{'-nXTAN_A_HIDEX'})
        end)

    expect.table_eq({action=p.status, job_matchers={}, quiet=true},
                    p.parse_commandline{'-q'})
    expect.table_eq({action=p.status, job_matchers={}, quiet=true},
                    p.parse_commandline{'--quiet'})

    expect.table_eq({action=p.boost_and_watch,
                     job_matchers={[SUTURE]={}}},
                    p.parse_commandline{'-a', 'Suture'})
    expect.table_eq({action=p.boost_and_watch,
                     job_matchers={[SUTURE]={}}},
                    p.parse_commandline{'--add', 'Suture'})

    expect.table_eq({action=p.remove_watch,
                     job_matchers={[SUTURE]={}}},
                    p.parse_commandline{'-d', 'Suture'})
    expect.table_eq({action=p.remove_watch,
                     job_matchers={[SUTURE]={}}},
                    p.parse_commandline{'--delete', 'Suture'})

    expect.table_eq({action=p.print_current_jobs, job_matchers={}},
                    p.parse_commandline{'-j'})
    expect.table_eq({action=p.print_current_jobs,
                     job_matchers={[SUTURE]={}}},
                    p.parse_commandline{'-j', 'Suture'})
    expect.table_eq({action=p.print_current_jobs,
                     job_matchers={[SUTURE]={}}},
                    p.parse_commandline{'--jobs', 'Suture'})


    expect.table_eq({action=p.status, job_matchers={}},
                    p.parse_commandline{'-lfood'})
    expect.table_eq({action=p.print_current_jobs,
                     job_matchers={[SUTURE]={}}},
                    p.parse_commandline{'-jlfood', 'Suture'})
    expect.table_eq({action=p.print_current_jobs,
                     job_matchers={[STORE_ITEM_IN_STOCKPILE]=
                                   {hauler_matchers={[HAUL_FOOD]=true}}}},
                    p.parse_commandline{'-jlfood', 'StoreItemInStockpile'})

    expect.table_eq({action=p.status, job_matchers={}},
                    p.parse_commandline{'-nTAN_A_HIDE'})
    expect.table_eq({action=p.boost,
                     job_matchers={[SUTURE]={}}},
                    p.parse_commandline{'-nTAN_A_HIDE', 'Suture'})
    expect.table_eq({action=p.boost,
                     job_matchers={[STORE_ITEM_IN_STOCKPILE]={}}},
                    p.parse_commandline{'-nTAN_A_HIDE', 'StoreItemInStockpile'})
    expect.table_eq({action=p.boost,
                     job_matchers={[CUSTOM_REACTION]=
                                   {reaction_matchers={TAN_A_HIDE=true}}}},
                    p.parse_commandline{'-nTAN_A_HIDE', 'CustomReaction'})

    expect.table_eq({action=p.print_registry, job_matchers={}},
                    p.parse_commandline{'-r'})
    expect.table_eq({action=p.print_registry, job_matchers={}},
                    p.parse_commandline{'--registry'})
end

local function selected_patches(sel)
    local patches = {}
    for _,kind in ipairs{'job', 'item', 'building', 'unit', 'plant',
                         'work_order'} do
        table.insert(patches, {prioritize, 'get_selected_' .. kind,
                               function() return sel[kind] end})
    end
    return patches
end

function test.parse_commandline_this()
    expect.table_eq({action=prioritize.prioritize_this, job_matchers={}},
                    p.parse_commandline{'this'})
    expect.error_match('cannot be combined', function()
        p.parse_commandline{'this', 'Suture'}
    end)
    expect.error_match('cannot be combined', function()
        p.parse_commandline{'-a', 'this'}
    end)
    expect.error_match('cannot be combined', function()
        p.parse_commandline{'-lfood', 'this'}
    end)
end

function test.this_boosts_selected_job()
    local job = {job_type=DIG, flags={}}
    local patches = selected_patches{job=job}
    table.insert(patches, {dfhack.job, 'getName', function() return 'Dig' end})
    table.insert(patches, {dfhack.job, 'getHolder', function() return nil end})
    table.insert(patches, {dfhack.job, 'getWorker', function() return nil end})
    mock.patch(patches, function()
        prioritize.prioritize_this()
    end)
    expect.true_(job.flags.do_now)
    expect.str_find('top priority', mock_print.call_args[1][1])
end

function test.this_already_boosted_job()
    local job = {job_type=DIG, flags={do_now=true}}
    local patches = selected_patches{job=job}
    table.insert(patches, {dfhack.job, 'getName', function() return 'Dig' end})
    table.insert(patches, {dfhack.job, 'getHolder', function() return nil end})
    table.insert(patches, {dfhack.job, 'getWorker', function() return nil end})
    mock.patch(patches, function()
        prioritize.prioritize_this()
    end)
    expect.str_find('already top priority', mock_print.call_args[1][1])
end

function test.this_boosts_item_job()
    local job = {job_type=DIG, flags={}}
    local item = {flags={in_job=true}}
    local patches = selected_patches{item=item}
    table.insert(patches, {dfhack.items, 'getSpecificRef',
                           function() return {data={job=job}} end})
    table.insert(patches, {dfhack.job, 'getName', function() return 'Dig' end})
    table.insert(patches, {dfhack.job, 'getHolder', function() return nil end})
    table.insert(patches, {dfhack.job, 'getWorker', function() return nil end})
    mock.patch(patches, function()
        prioritize.prioritize_this()
    end)
    expect.true_(job.flags.do_now)
end

function test.this_item_not_in_job()
    local item = {flags={in_job=false}}
    local patches = selected_patches{item=item}
    table.insert(patches, {dfhack.items, 'getDescription',
                           function() return 'a thing' end})
    mock.patch(patches, function()
        expect.error_match('must be in a job', function()
            prioritize.prioritize_this()
        end)
    end)
end

function test.this_nothing_selected()
    mock.patch(selected_patches{}, function()
        expect.error_match('Select something', function()
            prioritize.prioritize_this()
        end)
    end)
end
