-- Runtime data mining: watch live values and diff structure snapshots.
--[====[

devel/datamine
==============

Aids script development and reverse engineering by observing live game state.
Lua expressions are evaluated with the normal script environment, so ``df``,
``dfhack``, and friends are all available.

Usage::

    devel/datamine watch [-n name] [-i frames] <lua expression>
    devel/datamine unwatch <name>|all
    devel/datamine watches
    devel/datamine snap <name> <lua expression>
    devel/datamine diff <name>
    devel/datamine find <lua expression> <substring>

``watch`` polls the expression every ``frames`` frames (default 1) and prints a
line to the DFHack console whenever its value changes. Watches are cleared when
the world is unloaded; use ``unwatch`` to stop earlier.

``snap`` records the current value of every field reachable from the
expression's result (bounded depth and vector length), and ``diff`` prints the
paths whose values changed since the snapshot -- e.g. "perform action X, then
see which fields changed". ``find`` prints the paths of all fields whose name
or value contains the given substring.

Examples::

    devel/datamine watch -n cursor df.global.cursor.x
    devel/datamine snap site df.global.world.world_data.active_site[0]
    devel/datamine diff site
    devel/datamine find df.global.world.units.all[0] stress

]====]

local repeat_util = require('repeat-util')

local TIMER_NAME = 'devel/datamine'
local MAX_CONTAINER_ELEMS = 200
local MAX_DEPTH = 5
local MAX_LEAVES = 20000
local MAX_OUTPUT_LINES = 200

-- script environments persist across invocations
watches = watches or {}
snapshots = snapshots or {}

dfhack.onStateChange.devel_datamine = function(sc)
    if sc == SC_WORLD_UNLOADED then
        for k in pairs(watches) do watches[k] = nil end
        for k in pairs(snapshots) do snapshots[k] = nil end
    end
end

local function eval_expr(expr)
    local fn, err = load('return ' .. expr, 'datamine:' .. expr, 't', _ENV)
    if not fn then
        fn, err = load(expr, 'datamine:' .. expr, 't', _ENV)
    end
    if not fn then
        return nil, err
    end
    local ok, ret = pcall(fn)
    if not ok then
        return nil, ret
    end
    return ret
end

local function safe_get(obj, key)
    local ok, v = pcall(function() return obj[key] end)
    if ok then return v end
end

-- short printable representation of a leaf value
local function repr(v)
    return tostring(v)
end

local function is_compound(v)
    if type(v) == 'table' then return true end
    if type(v) ~= 'userdata' then return false end
    local kind = safe_get(v, '_kind')
    return kind == 'struct' or kind == 'bitfield' or kind == 'container'
end

-- walk obj, calling cb(path, v) for every leaf value; leaves beyond the cap
-- are counted but not walked, so a truncated walk finishes promptly
local function walk(obj, path, depth, visited, leaf_count, cb)
    if leaf_count[1] > MAX_LEAVES then return end
    if not is_compound(obj) then
        leaf_count[1] = leaf_count[1] + 1
        cb(path, obj)
        return
    end
    if depth > MAX_DEPTH then return end
    -- userdata wrappers are not identity-stable across field accesses, but
    -- tostring() includes the object address; tables use identity directly
    local vkey = type(obj) == 'userdata' and tostring(obj) or obj
    if visited[vkey] then return end
    visited[vkey] = true
    local container = type(obj) == 'userdata' and
        safe_get(obj, '_kind') == 'container'
    local count = 0
    local truncated = false
    local ok = pcall(function()
        for k, v in pairs(obj) do
            count = count + 1
            if container and count > MAX_CONTAINER_ELEMS then break end
            local sub = type(k) == 'number' and
                (path .. '[' .. k .. ']') or (path .. '.' .. tostring(k))
            walk(v, sub, depth + 1, visited, leaf_count, cb)
        end
    end)
    truncated = not ok or (container and count > MAX_CONTAINER_ELEMS)
    if truncated then
        cb(path, '<uniterable or truncated>')
    end
end

local function snapshot(root)
    local map = {}
    walk(root, '', 0, {}, {0}, function(path, v)
        map[path] = repr(v)
    end)
    return map
end

local function sorted_keys(map)
    local keys = {}
    for k in pairs(map) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

local function print_lines(lines)
    for i = 1, math.min(#lines, MAX_OUTPUT_LINES) do
        dfhack.print(lines[i] .. '\n')
    end
    if #lines > MAX_OUTPUT_LINES then
        dfhack.print(('... and %d more\n'):format(#lines - MAX_OUTPUT_LINES))
    end
end

local function poll_watches()
    for name, w in pairs(watches) do
        w.countdown = w.countdown - 1
        if w.countdown <= 0 then
            w.countdown = w.interval
            local val, err = eval_expr(w.expr)
            if err then
                if w.last_err ~= err then
                    w.last_err = err
                    dfhack.printerr(('datamine[%s]: %s'):format(name, err))
                end
            else
                w.last_err = nil
                local r = repr(val)
                if r ~= w.last then
                    dfhack.print(('datamine[%s]: %s -> %s\n'):format(
                        name, w.last or 'nil', r))
                    w.last = r
                end
            end
        end
    end
end

local function ensure_timer()
    if next(watches) then
        repeat_util.scheduleUnlessAlreadyScheduled(
            TIMER_NAME, 1, 'frames', poll_watches)
    else
        repeat_util.cancel(TIMER_NAME)
    end
end

local function cmd_watch(args)
    local name, interval, i = nil, 1, 1
    while i <= #args do
        if args[i] == '-n' then
            name = args[i + 1]; i = i + 2
        elseif args[i] == '-i' then
            interval = tonumber(args[i + 1]) or 1; i = i + 2
        else
            break
        end
    end
    local expr = table.concat(args, ' ', i)
    if expr == '' then qerror('missing lua expression') end
    name = name or expr
    local val, err = eval_expr(expr)
    if err then qerror(('cannot evaluate: %s'):format(err)) end
    watches[name] = {expr = expr, interval = math.max(1, interval),
                     countdown = 0, last = repr(val)}
    dfhack.print(('watching %s = %s\n'):format(name, watches[name].last))
    ensure_timer()
end

local function cmd_unwatch(name)
    if name == 'all' then
        watches = {}
        repeat_util.cancel(TIMER_NAME)
        dfhack.print('all watches removed\n')
        return
    end
    if not name or not watches[name] then
        qerror(('no watch named %q'):format(tostring(name)))
    end
    watches[name] = nil
    ensure_timer()
    dfhack.print(('stopped watching %s\n'):format(name))
end

local function cmd_watches()
    if not next(watches) then
        dfhack.print('no active watches\n')
        return
    end
    for name, w in pairs(watches) do
        dfhack.print(('%s = %s   [%s]\n'):format(name, w.last or 'nil', w.expr))
    end
end

local function cmd_snap(args)
    local name = args[1]
    local expr = table.concat(args, ' ', 2)
    if not name or expr == '' then
        qerror('usage: snap <name> <lua expression>')
    end
    local val, err = eval_expr(expr)
    if err then qerror(('cannot evaluate: %s'):format(err)) end
    snapshots[name] = {expr = expr, map = snapshot(val)}
    local n = 0
    for _ in pairs(snapshots[name].map) do n = n + 1 end
    dfhack.print(('snapshot %q: %d fields recorded\n'):format(name, n))
end

local function cmd_diff(name)
    if not name then qerror('usage: diff <name>') end
    local snap = snapshots[name]
    if not snap then qerror(('no snapshot named %q'):format(name)) end
    local val, err = eval_expr(snap.expr)
    if err then qerror(('cannot evaluate: %s'):format(err)) end
    local now = snapshot(val)
    local lines = {}
    local seen = {}
    for _, path in ipairs(sorted_keys(snap.map)) do
        seen[path] = true
        if now[path] == nil then
            lines[#lines + 1] = ('%s: %s -> <gone>'):format(path, snap.map[path])
        elseif now[path] ~= snap.map[path] then
            lines[#lines + 1] = ('%s: %s -> %s'):format(
                path, snap.map[path], now[path])
        end
    end
    for _, path in ipairs(sorted_keys(now)) do
        if not seen[path] then
            lines[#lines + 1] = ('%s: <new> -> %s'):format(path, now[path])
        end
    end
    if #lines == 0 then
        dfhack.print('no changes\n')
    else
        print_lines(lines)
    end
end

local function cmd_find(args)
    if #args < 2 then
        qerror('usage: find <lua expression> <substring>')
    end
    local pat = args[#args]:lower()
    local expr = table.concat(args, ' ', 1, #args - 1)
    local val, err = eval_expr(expr)
    if err then qerror(('cannot evaluate: %s'):format(err)) end
    local lines = {}
    walk(val, '', 0, {}, {0}, function(path, v)
        local r = repr(v)
        if path:lower():find(pat, 1, true) or r:lower():find(pat, 1, true) then
            lines[#lines + 1] = ('%s = %s'):format(path, r)
        end
    end)
    if #lines == 0 then
        dfhack.print('no matching fields\n')
    else
        print_lines(lines)
    end
end

local args = {...}
local cmd = table.remove(args, 1)

if not cmd or cmd == 'help' then
    print(dfhack.script_help())
elseif cmd == 'watch' then
    cmd_watch(args)
elseif cmd == 'unwatch' or cmd == 'stop' then
    cmd_unwatch(args[1])
elseif cmd == 'watches' or cmd == 'list' then
    cmd_watches()
elseif cmd == 'snap' then
    cmd_snap(args)
elseif cmd == 'diff' then
    cmd_diff(args[1])
elseif cmd == 'find' then
    cmd_find(args)
else
    qerror(('unknown command: %s'):format(cmd))
end
