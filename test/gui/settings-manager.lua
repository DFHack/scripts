config = {
    mode = 'fortress',
    target = 'gui/settings-manager',
}

local settings_manager = reqscript('gui/settings-manager')

local function make_vector(entries)
    local data = entries or {}
    return setmetatable({}, {
        __len=function() return #data end,
        __index=function(_, key)
            if key == 'resize' then
                return function(_, size)
                    for i = #data, size - 1 do data[i+1] = false end
                    for i = #data, size + 1, -1 do data[i] = nil end
                end
            end
            return type(key) == 'number' and data[key+1] or nil
        end,
        __newindex=function(_, key, value)
            if type(key) ~= 'number' then return end
            if type(value) == 'table' and value.new == df.work_detail then
                value = {
                    name=value.name,
                    icon=value.icon,
                    flags=value.flags,
                    allowed_labors={},
                }
            end
            data[key+1] = value
        end,
    })
end

local function with_work_details(work_details, saved, fn)
    local load_fn = settings_manager.WorkDetailsOverlay.ATTRS.load_fn
    local li_idx, old_li
    for i = 1, 10 do
        local name, value = debug.getupvalue(load_fn, i)
        if name == 'li' then
            li_idx, old_li = i, value
            break
        end
    end
    local old_config = settings_manager.config
    debug.setupvalue(load_fn, li_idx, {work_details=work_details})
    settings_manager.config = {
        data={work_details=saved},
        read=function() end,
        write=function() end,
    }
    dfhack.with_finalize(
        function()
            debug.setupvalue(load_fn, li_idx, old_li)
            settings_manager.config = old_config
        end,
        function() fn(load_fn) end)
end

local function saved_detail(index)
    return {
        name=('built-in %d'):format(index),
        icon=index,
        flags={cannot_be_everybody=false, no_modify=true, mode=1},
        allowed_labors={},
    }
end

local function current_details()
    local current = {}
    for i = 1, 10 do current[i] = saved_detail(i) end
    current[11] = {
        name='Siege Operators',
        icon=df.work_detail_icon_type.SIEGE_OPERATORS,
        flags={cannot_be_everybody=false, no_modify=true, mode=1},
        allowed_labors={},
    }
    return current
end

function test.loading_old_details_preserves_new_builtin()
    local saved = {}
    for i = 1, 10 do saved[i] = saved_detail(i) end
    local work_details = make_vector(current_details())

    with_work_details(work_details, saved, function(load_fn)
        load_fn()
        expect.eq(11, #work_details)
        if #work_details < 11 then return end
        expect.eq('Siege Operators', work_details[10].name)
    end)
end

function test.loading_legacy_work_detail_flags()
    local saved = {}
    for i = 1, 10 do saved[i] = saved_detail(i) end
    saved[1].work_detail_flags = saved[1].flags
    saved[1].flags = nil
    saved[1].work_detail_flags.mode = 3
    local work_details = make_vector(current_details())

    with_work_details(work_details, saved, function(load_fn)
        load_fn()
        expect.eq(3, work_details[0].flags.mode)
    end)
end

function test.loading_renamed_builtin_matches_by_icon()
    -- a saved built-in whose name was changed (by the user or a DF update)
    -- is still identified by its unique built-in icon
    local saved = {}
    for i = 1, 10 do saved[i] = saved_detail(i) end
    saved[3] = {
        name='Old Hunters Name',
        icon=3,
        flags={cannot_be_everybody=false, no_modify=true, mode=3},
        allowed_labors={true, false, true},
    }
    local work_details = make_vector(current_details())

    with_work_details(work_details, saved, function(load_fn)
        load_fn()
        local detail = work_details[2]
        expect.eq('Old Hunters Name', detail.name)
        expect.eq(3, detail.flags.mode)
        expect.eq(true, detail.allowed_labors[0])
        expect.eq(true, detail.allowed_labors[2])
    end)
end

function test.builtin_icon_fallback_ignores_custom_icons()
    -- a saved no_modify entry with a custom icon must not steal a built-in
    local saved = {}
    for i = 1, 10 do saved[i] = saved_detail(i) end
    saved[3] = {
        name='built-in 3',
        icon=df.work_detail_icon_type.CUSTOM_1,
        flags={cannot_be_everybody=false, no_modify=true, mode=3},
        allowed_labors={true},
    }
    local work_details = make_vector(current_details())

    with_work_details(work_details, saved, function(load_fn)
        load_fn()
        local detail = work_details[2]
        expect.eq('built-in 3', detail.name)
        expect.eq(1, detail.flags.mode)
        expect.ne(true, detail.allowed_labors[0])
    end)
end

function test.loading_malformed_entries_are_skipped()
    local saved = {}
    for i = 1, 10 do saved[i] = saved_detail(i) end
    saved[5] = {name='no flags', icon=4} -- no flags/work_detail_flags
    saved[6] = 'not a table'
    local work_details = make_vector(current_details())

    with_work_details(work_details, saved, function(load_fn)
        load_fn()
        -- the two malformed entries are skipped, not recreated as customs
        expect.eq(11, #work_details)
        expect.eq('Siege Operators', work_details[10].name)
        -- unmatched built-ins are left alone
        expect.eq('built-in 5', work_details[4].name)
    end)
end

function test.loading_recomputes_unit_labors()
    local saved = {}
    for i = 1, 10 do saved[i] = saved_detail(i) end
    local work_details = make_vector(current_details())
    local citizens = {{id=1}, {id=2}}
    local recomputed = {}
    mock.patch({
        {dfhack.units, 'getCitizens', function() return citizens end},
        {dfhack.units, 'setAutomaticProfessions', function(unit)
            recomputed[unit] = true
        end},
    }, function()
        with_work_details(work_details, saved, function(load_fn)
            load_fn()
            expect.true_(recomputed[citizens[1]])
            expect.true_(recomputed[citizens[2]])
        end)
    end)
end

function test.loading_old_custom_details_after_new_builtins()
    local saved = {}
    for i = 1, 10 do saved[i] = saved_detail(i) end
    saved[11] = {
        name='Custom detail',
        icon=1,
        flags={cannot_be_everybody=false, no_modify=false, mode=1},
        allowed_labors={},
    }
    local current = current_details()
    current[12] = {
        name='Unsaved custom detail',
        icon=2,
        flags={cannot_be_everybody=false, no_modify=false, mode=1},
        allowed_labors={},
    }
    local work_details = make_vector(current)

    with_work_details(work_details, saved, function(load_fn)
        load_fn()
        expect.eq(12, #work_details)
        expect.eq('Siege Operators', work_details[10].name)
        expect.eq('Custom detail', work_details[11].name)
    end)
end
