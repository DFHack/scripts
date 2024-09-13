-- common logic for the nestboxes modules
--@ module = true
verbose = verbose or nil
GLOBAL_KEY = GLOBAL_KEY or ""

function print_local(text)
    print(GLOBAL_KEY .. ": " .. text)
end
---------------------------------------------------------------------------------------------------
function handle_error(text)
    qerror(GLOBAL_KEY .. ": " .. text)
end
---------------------------------------------------------------------------------------------------
function print_details(text)
    if verbose then
        print_local(text)
    end
end
