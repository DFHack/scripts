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
local mock_reactions = {{code='TAN_A_HIDE'}}
local function get_mock_reactions() return mock_reactions end
local function test_wrapper(test_fn)
    mock.patch({{eventful, 'onUnload', mock_eventful_onUnload},
                {eventful, 'onJobInitiated', mock_eventful_onJobInitiated},
                {prioritize, 'print', mock_print},
                {prioritize, 'get_watched_job_matchers',
                 get_mock_watched_job_matchers},
                {prioritize, 'get_postings', get_mock_postings},
                {prioritize, 'get_reactions', get_mock_reactions}},
               test_fn)
    mock_eventful_onUnload, mock_eventful_onJobInitiated = {}, {}
    mock_print = mock.func()
    mock_watched_job_matchers, mock_postings = {}, {}
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

function test.status()
    p.status()
    expect.eq(1, mock_print.call_count)
    expect.eq('Not automatically prioritizing any jobs.',
              mock_print.call_args[1][1])

    mock_watched_job_matchers[REST] = {num_prioritized=5}
    p.status()
    expect.eq(3, mock_print.call_count)
    expect.eq('Automatically prioritized jobs:', mock_print.call_args[2][1])
    expect.str_find('Rest', mock_print.call_args[3][1])
end

function test.status_labor()
    mock_watched_job_matchers[STORE_ITEM_IN_STOCKPILE] =
            {num_prioritized=5, hauler_matchers={[HAUL_BODY]=2}}
    p.status()
    expect.eq(2, mock_print.call_count)
    expect.eq('Automatically prioritized jobs:', mock_print.call_args[1][1])
    expect.str_find('Stockpile.*Body', mock_print.call_args[2][1])
end

function test.status_reaction()
    mock_watched_job_matchers[CUSTOM_REACTION] =
            {num_prioritized=5, reaction_matchers={TAN_A_HIDE=2}}
    p.status()
    expect.eq(2, mock_print.call_count)
    expect.eq('Automatically prioritized jobs:', mock_print.call_args[1][1])
    expect.str_find('Custom.*TAN_A_HIDE', mock_print.call_args[2][1])
end

function test.boost()
    mock_postings = {{job={job_type=DIG, flags={}}, flags={}},
                     {job={job_type=DIG, flags={}}, flags={}},
                     {job={job_type=EAT, flags={}}, flags={dead=true}},
                     {job={job_type=EAT, flags={}}, flags={}},
                     {job={job_type=REST, flags={}}, flags={dead=true}}}
    local expected_postings =
            {{job={job_type=DIG, flags={}}, flags={}},
             {job={job_type=DIG, flags={}}, flags={}},
             {job={job_type=EAT, flags={}}, flags={dead=true}},
             {job={job_type=EAT, flags={do_now=true}}, flags={}},
             {job={job_type=REST, flags={}}, flags={dead=true}}}
    p.boost({[EAT]={num_prioritized=0}}, {})
    expect.eq(1, mock_print.call_count)
    expect.eq('Prioritized 1 job.', mock_print.call_args[1][1])
    expect.table_eq(expected_postings, mock_postings)
end

function test.boost_quiet()
    mock_postings = {{job={job_type=DIG, flags={}}, flags={}},
                     {job={job_type=DIG, flags={}}, flags={}},
                     {job={job_type=EAT, flags={}}, flags={dead=true}},
                     {job={job_type=EAT, flags={}}, flags={}},
                     {job={job_type=REST, flags={}}, flags={dead=true}}}
    local expected_postings =
            {{job={job_type=DIG, flags={}}, flags={}},
             {job={job_type=DIG, flags={}}, flags={}},
             {job={job_type=EAT, flags={}}, flags={dead=true}},
             {job={job_type=EAT, flags={do_now=true}}, flags={}},
             {job={job_type=REST, flags={}}, flags={dead=true}}}
    p.boost({[EAT]={num_prioritized=0}}, {quiet=true})
    expect.eq(0, mock_print.call_count)
    expect.table_eq(expected_postings, mock_postings)
end

function test.boost_and_watch()
    p.boost_and_watch({[DIG]={num_prioritized=0}}, {})
    expect.eq(2, mock_print.call_count)
    expect.str_find('^Prioritized', mock_print.call_args[1][1])
    expect.str_find('^Automatically', mock_print.call_args[2][1])
    expect.table_eq({[DIG]={num_prioritized=0}}, mock_watched_job_matchers)

    p.boost_and_watch({[DIG]={num_prioritized=0}}, {})
    expect.eq(4, mock_print.call_count)
    expect.str_find('^Prioritized', mock_print.call_args[3][1])
    expect.str_find('^Skipping', mock_print.call_args[4][1])
    expect.table_eq({[DIG]={num_prioritized=0}}, mock_watched_job_matchers)
end

function test.boost_and_watch_quiet()
    p.boost_and_watch({[DIG]={num_prioritized=0}}, {quiet=true})
    expect.eq(0, mock_print.call_count)
    expect.table_eq({[DIG]={num_prioritized=0}}, mock_watched_job_matchers)

    p.boost_and_watch({[DIG]={num_prioritized=0}}, {quiet=true})
    expect.eq(0, mock_print.call_count)
    expect.table_eq({[DIG]={num_prioritized=0}}, mock_watched_job_matchers)
end

function test.remove_watch()
    p.remove_watch({[DIG]={num_prioritized=0}}, {})
    expect.eq(1, mock_print.call_count)
    expect.str_find('Skipping unwatched', mock_print.call_args[1][1])
    expect.table_eq({}, mock_watched_job_matchers)

    mock_watched_job_matchers[DIG] = {num_prioritized=0}
    p.remove_watch({[DIG]={num_prioritized=0}}, {})
    expect.eq(2, mock_print.call_count)
    expect.str_find('No longer', mock_print.call_args[2][1])
end

function test.remove_watch_quiet()
    p.remove_watch({[DIG]={num_prioritized=0}}, {quiet=true})
    expect.eq(0, mock_print.call_count)
    expect.table_eq({}, mock_watched_job_matchers)

    mock_watched_job_matchers[DIG] = {num_prioritized=0}
    p.remove_watch({[DIG]={num_prioritized=0}}, {quiet=true})
    expect.eq(0, mock_print.call_count)
    expect.table_eq({}, mock_watched_job_matchers)
end

function test.boost_and_watch_labor()
    mock_postings = {{job={job_type=DIG, flags={}}, flags={}},
        {job={job_type=STORE_ITEM_IN_STOCKPILE, item_subtype=HAUL_FOOD,
              flags={}}, flags={}},
        {job={job_type=STORE_ITEM_IN_STOCKPILE, item_subtype=HAUL_ITEM,
              flags={}}, flags={}},
        {job={job_type=STORE_ITEM_IN_STOCKPILE, item_subtype=HAUL_ITEM,
              flags={}}, flags={}},
        {job={job_type=STORE_ITEM_IN_STOCKPILE, item_subtype=HAUL_ITEM,
              flags={}}, flags={dead=true}}}

    p.boost_and_watch({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0,
                            hauler_matchers={[HAUL_ITEM]=0}}},
                      {})
    expect.eq(2, mock_print.call_count)
    expect.str_find('^Prioritized 2', mock_print.call_args[1][1])
    expect.str_find('^Automatically', mock_print.call_args[2][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0,
                            hauler_matchers={[HAUL_ITEM]=0}}},
                    mock_watched_job_matchers)

    p.boost_and_watch({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0}}, {})
    expect.eq(4, mock_print.call_count)
    expect.str_find('^Prioritized 1', mock_print.call_args[3][1])
    expect.str_find('^Automatically', mock_print.call_args[4][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0}},
                    mock_watched_job_matchers)
end

function test.boost_and_watch_store_all_labors()
    p.boost_and_watch({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0}}, {})
    expect.eq(2, mock_print.call_count)
    expect.str_find('^Prioritized 0', mock_print.call_args[1][1])
    expect.str_find('^Automatically', mock_print.call_args[2][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0}},
                    mock_watched_job_matchers)

    p.boost_and_watch({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0}}, {})
    expect.eq(4, mock_print.call_count)
    expect.str_find('^Prioritized 0', mock_print.call_args[3][1])
    expect.str_find('^Skipping', mock_print.call_args[4][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0}},
                    mock_watched_job_matchers)

    p.boost_and_watch({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0,
                            hauler_matchers={[HAUL_ITEM]=0}}}, {})
    expect.eq(6, mock_print.call_count)
    expect.str_find('^Prioritized 0', mock_print.call_args[3][1])
    expect.str_find('^Skipping.*Item', mock_print.call_args[4][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0}},
                    mock_watched_job_matchers)
end

function test.boost_and_watch_store_add_labors()
    p.boost_and_watch({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0,
                            hauler_matchers={[HAUL_ITEM]=0}}}, {})
    expect.eq(2, mock_print.call_count)
    expect.str_find('^Prioritized 0', mock_print.call_args[1][1])
    expect.str_find('^Automatically.*Item', mock_print.call_args[2][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0,
                            hauler_matchers={[HAUL_ITEM]=0}}},
                    mock_watched_job_matchers)

    p.boost_and_watch({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0,
                            hauler_matchers={[HAUL_FOOD]=0}}}, {})
    expect.eq(4, mock_print.call_count)
    expect.str_find('^Prioritized 0', mock_print.call_args[3][1])
    expect.str_find('^Automatically.*Food', mock_print.call_args[4][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0,
                            hauler_matchers={[HAUL_ITEM]=0, [HAUL_FOOD]=0}}},
                    mock_watched_job_matchers)

    p.boost_and_watch({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0,
                            hauler_matchers={[HAUL_FOOD]=0}}}, {})
    expect.eq(6, mock_print.call_count)
    expect.str_find('^Prioritized 0', mock_print.call_args[5][1])
    expect.str_find('^Skipping.*Food', mock_print.call_args[6][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0,
                            hauler_matchers={[HAUL_ITEM]=0, [HAUL_FOOD]=0}}},
                    mock_watched_job_matchers)
end

function test.boost_and_watch_reactions()
    p.boost_and_watch({[CUSTOM_REACTION]={num_prioritized=0,
                                    reaction_matchers={TAN_A_HIDE=0}}}, {})
    expect.eq(2, mock_print.call_count)
    expect.str_find('^Prioritized 0', mock_print.call_args[1][1])
    expect.str_find('^Automatically.*TAN_A_HIDE', mock_print.call_args[2][1])
    expect.table_eq({[CUSTOM_REACTION]={num_prioritized=0,
                                        reaction_matchers={TAN_A_HIDE=0}}},
                    mock_watched_job_matchers)
end

function test.remove_one_labor_from_all()
    -- top-level num_prioritized should be persisted
    mock_watched_job_matchers = {[STORE_ITEM_IN_STOCKPILE]={num_prioritized=5}}

    p.remove_watch({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0,
                            hauler_matchers={[HAUL_FOOD]=0}}},
                      {})
    expect.eq(1, mock_print.call_count)
    expect.str_find('No longer.*Food', mock_print.call_args[1][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=5,
        hauler_matchers={[HAUL_STONE]=0, [HAUL_WOOD]=0, [HAUL_BODY]=0,
                         [HAUL_REFUSE]=0, [HAUL_ITEM]=0, [HAUL_FURNITURE]=0,
                         [HAUL_ANIMALS]=0}}},
                    mock_watched_job_matchers)

    p.remove_watch({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=0,
                            hauler_matchers={[HAUL_FOOD]=0}}},
                   {})
    expect.eq(2, mock_print.call_count)
    expect.str_find('Skipping.*Food', mock_print.call_args[2][1])
    expect.table_eq({[STORE_ITEM_IN_STOCKPILE]={num_prioritized=5,
        hauler_matchers={[HAUL_STONE]=0, [HAUL_WOOD]=0, [HAUL_BODY]=0,
                         [HAUL_REFUSE]=0, [HAUL_ITEM]=0, [HAUL_FURNITURE]=0,
                         [HAUL_ANIMALS]=0}}},
                    mock_watched_job_matchers)
end

function test.remove_all_reactions_from_all()
    mock_watched_job_matchers = {[CUSTOM_REACTION]={num_prioritized=5}}

    -- we only have one reaction in our mock registry. if we remove it by name
    -- from an unrestricted CUSTOM_REACTION matcher, the entire matcher should
    -- disappear
    p.remove_watch({[CUSTOM_REACTION]={num_prioritized=0,
                                       reaction_matchers={TAN_A_HIDE=0}}},
                   {})
    expect.eq(1, mock_print.call_count)
    expect.str_find('No longer.*TAN_A_HIDE', mock_print.call_args[1][1])
    expect.table_eq({}, mock_watched_job_matchers)
end

function test.eventful_hook_lifecycle()
    expect.nil_(mock_eventful_onUnload.prioritize)
    expect.nil_(mock_eventful_onJobInitiated.prioritize)

    p.boost_and_watch({[DIG]={num_prioritized=0}}, {quiet=true})
    expect.table_eq({[DIG]={num_prioritized=0}}, mock_watched_job_matchers)

    expect.eq(p.clear_watched_job_matchers, mock_eventful_onUnload.prioritize)
    expect.eq(p.on_new_job, mock_eventful_onJobInitiated.prioritize)

    p.remove_watch({[DIG]={num_prioritized=0}}, {quiet=true})
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
    expected = {job_type=DIG, flags={do_now=true}}
    p.boost_and_watch({[DIG]={num_prioritized=0}}, {quiet=true})
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
            {num_prioritized=0, hauler_matchers={[HAUL_FOOD]=0}}

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
    expected_watched_job_matchers =
            {[STORE_ITEM_IN_STOCKPILE]={num_prioritized=1,
                                        hauler_matchers={[HAUL_FOOD]=1}}}
    p.on_new_job(job)
    expect.table_eq(expected_job, job)
    expect.table_eq(expected_watched_job_matchers, mock_watched_job_matchers)
end

function test.eventful_callbacks_reaction()
    mock_watched_job_matchers[CUSTOM_REACTION] =
            {num_prioritized=0, reaction_matchers={TAN_A_HIDE=0}}

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
    expected_watched_job_matchers =
            {[CUSTOM_REACTION]={num_prioritized=1,
                                reaction_matchers={TAN_A_HIDE=1}}}
    p.on_new_job(job)
    expect.table_eq(expected_job, job)
    expect.table_eq(expected_watched_job_matchers, mock_watched_job_matchers)
end

function test.print_current_jobs_empty()
    p.print_current_jobs({})
    expect.eq(1, mock_print.call_count)
    expect.eq('No current unclaimed jobs.', mock_print.call_args[1][1])
end

function test.print_current_jobs_full()
    mock_postings = {{job={job_type=DIG}, flags={}},
                     {job={job_type=DIG}, flags={}},
                     {job={job_type=EAT}, flags={dead=true}},
                     {job={job_type=EAT}, flags={}},
                     {job={job_type=REST}, flags={dead=true}},
                     {job={job_type=STORE_ITEM_IN_STOCKPILE,
                           item_subtype=HAUL_FOOD, flags={}}, flags={}},
                     {job={job_type=CUSTOM_REACTION,
                           reaction_name='TAN_A_HIDE', flags={}}, flags={}}}
    p.print_current_jobs({})
    expect.eq(5, mock_print.call_count)
    expect.eq('Current unclaimed jobs:', mock_print.call_args[1][1])
    local result = {}
    for i,v in ipairs(mock_print.call_args) do
        if i == 1 then goto continue end
        local _,_,num,job_type = v[1]:find('^(%d+)%s+(%S+)')
        expect.ne(nil, num)
        expect.nil_(result[job_type])
        result[job_type] = num
        ::continue::
    end
    expect.table_eq({[df.job_type[DIG]]='2', [df.job_type[EAT]]='1',
                     [df.job_type[STORE_ITEM_IN_STOCKPILE]]='1',
                     [df.job_type[CUSTOM_REACTION]]='1'},
                    result)
end

function test.print_current_jobs_filtered()
    mock_postings = {{job={job_type=DIG}, flags={}},
                     {job={job_type=DIG}, flags={}},
                     {job={job_type=EAT}, flags={dead=true}},
                     {job={job_type=EAT}, flags={}},
                     {job={job_type=REST}, flags={dead=true}}}
    p.print_current_jobs({[EAT]=true})
    expect.eq(2, mock_print.call_count)
    expect.eq('Current unclaimed jobs:', mock_print.call_args[1][1])
    local result = {}
    for i,v in ipairs(mock_print.call_args) do
        if i == 1 then goto continue end
        local _,_,num,job_type = v[1]:find('(%d+)%s+(%S+)')
        expect.ne(nil, num)
        expect.nil_(result[job_type])
        result[job_type] = num
        ::continue::
    end
    expect.table_eq({[df.job_type[EAT]]='1'}, result)
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
                     job_matchers={[SUTURE]={num_prioritized=0}}},
                    p.parse_commandline{'Suture'})
    expect.printerr_match('Ignoring unknown job type',
        function()
            expect.table_eq({action=p.status, job_matchers={}},
                            p.parse_commandline{'XSutureX'})
        end)
    expect.printerr_match('Ignoring unknown job type',
        function()
            expect.table_eq({action=p.boost,
                             job_matchers={[SUTURE]={num_prioritized=0}}},
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
                     job_matchers={[SUTURE]={num_prioritized=0}}},
                    p.parse_commandline{'-a', 'Suture'})
    expect.table_eq({action=p.boost_and_watch,
                     job_matchers={[SUTURE]={num_prioritized=0}}},
                    p.parse_commandline{'--add', 'Suture'})

    expect.table_eq({action=p.remove_watch,
                     job_matchers={[SUTURE]={num_prioritized=0}}},
                    p.parse_commandline{'-d', 'Suture'})
    expect.table_eq({action=p.remove_watch,
                     job_matchers={[SUTURE]={num_prioritized=0}}},
                    p.parse_commandline{'--delete', 'Suture'})

    expect.table_eq({action=p.print_current_jobs, job_matchers={}},
                    p.parse_commandline{'-j'})
    expect.table_eq({action=p.print_current_jobs,
                     job_matchers={[SUTURE]={num_prioritized=0}}},
                    p.parse_commandline{'-j', 'Suture'})
    expect.table_eq({action=p.print_current_jobs,
                     job_matchers={[SUTURE]={num_prioritized=0}}},
                    p.parse_commandline{'--jobs', 'Suture'})


    expect.table_eq({action=p.status, job_matchers={}},
                    p.parse_commandline{'-lfood'})
    expect.table_eq({action=p.print_current_jobs,
                     job_matchers={[SUTURE]={num_prioritized=0}}},
                    p.parse_commandline{'-jlfood', 'Suture'})
    expect.table_eq({action=p.print_current_jobs,
                     job_matchers={[STORE_ITEM_IN_STOCKPILE]=
                                   {num_prioritized=0,
                                    hauler_matchers={[HAUL_FOOD]=0}}}},
                    p.parse_commandline{'-jlfood', 'StoreItemInStockpile'})

    expect.table_eq({action=p.status, job_matchers={}},
                    p.parse_commandline{'-nTAN_A_HIDE'})
    expect.table_eq({action=p.boost,
                     job_matchers={[SUTURE]={num_prioritized=0}}},
                    p.parse_commandline{'-nTAN_A_HIDE', 'Suture'})
    expect.table_eq({action=p.boost,
                     job_matchers={[STORE_ITEM_IN_STOCKPILE]=
                                   {num_prioritized=0}}},
                    p.parse_commandline{'-nTAN_A_HIDE', 'StoreItemInStockpile'})
    expect.table_eq({action=p.boost,
                     job_matchers={[CUSTOM_REACTION]=
                                   {num_prioritized=0,
                                    reaction_matchers={TAN_A_HIDE=0}}}},
                    p.parse_commandline{'-nTAN_A_HIDE', 'CustomReaction'})

    expect.table_eq({action=p.print_registry, job_matchers={}},
                    p.parse_commandline{'-r'})
    expect.table_eq({action=p.print_registry, job_matchers={}},
                    p.parse_commandline{'--registry'})
end
