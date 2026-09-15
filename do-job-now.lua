-- makes a job involving current selection high priority

-- the implementation moved to `prioritize this`; this script forwards for
-- compatibility with existing keybindings and aliases

if (...) then
    print(dfhack.script_help())
    return
end

reqscript('prioritize').prioritize_this()
