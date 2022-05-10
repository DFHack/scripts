-- common logic for the quickfort modules
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

verbose = false

function log(...)
    if verbose then print(string.format(...)) end
end

function logfn(target_fn, ...)
    if verbose then target_fn{...} end
end

-- if the table t doesn't include the specified key, t[key] is set to default
-- default defaults to {} if not set
function ensure_key(t, key, default)
    if t[key] == nil then
        t[key] = (default ~= nil) and default or {}
    end
    return t[key]
end
