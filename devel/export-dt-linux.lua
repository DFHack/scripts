-- uses the dwarf therapist export script to generate a layout in the right directory under linux

dfhack.run_command('export-dt-ini')

local home = os.getenv("HOME")
local vstring = dfhack.getDFVersion()
local platform = vstring:match("(%S+)%s*$")
local filename = (string.sub(vstring, 1, 8) .. "-" .. platform .. "_linux64.ini")

local src = assert(io.open("therapist.ini", "r"))
local dest = assert(io.open(home .. "/.local/share/dwarftherapist/memory_layouts/linux/" .. filename , "w"))

dest:write(src:read("*all"))
src:close()
dest:close()

os.remove("therapist.ini")