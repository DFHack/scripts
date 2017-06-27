--Script for making randomized, entity-specific intros on embark
--Written by Khaos with input from Amostubal

local help = [====[
intro-loader.lua
================

Alters the fort mode intro text before embarking

This script should be called in "dfhack.init" for proper operation. Attempting
 to call the script at any other point in execution will have unpredictable
 results.

This script should not be called from the terminal outside of debug usage.

The script requires either the -entity, -rand, or both parameters be included
 in the call to operate, and will indicate failure without


Usage:

-help
    print this text
-v
    Activate verbose mode, kinda spammy
-folder
    Designate a folder to get the input intro files from relative to
    the DF directory
    Defaults to /data/announcement/ if not specified
-now
    Run the script now, as opposed to waiting for the correct timing
    For debug use, don't implement in init files.
-file
    Change the prefix for input filenames.
    By default, the prefix is "INTRO", as in "INTRO_MOUNTAIN_1"
-entity
    Enables entity-specific intro files
-rand
    Enables random selection for intro files


Introduction files have to be set up by the user
Intro files must
    -Be in the custom format used by Toady, editable via the WTF tools
     developed by Andux. Available as of now at:
        http://dffd.bay12games.com/file.php?id=4175
    -In plaintext, the file must begin with the word "fortressintro" followed
     by a newline. The first line must be exactly such, or it will fail to be
     loaded by the game.
    -The file must be named according to your chosen mode for the script:
      - Parts of the filename are separated by underscores for readability
        purposes
      - Filenames must start with the defined prefix, which defaults to INTRO,
        but can be changed with the -file parameter
      - If the -entity argument is supplied, the entity name must be appeneded
        to the prefix, as in INTRO_MOUNTAIN for dwarves
      - If the -rand argument is supplied, the filenames must each have a unique
        number appended, as in INTRO_MOUNTAIN_2
      - Further, for the -rand argument, usable numbers start at 1 and all
	    numbers must be consecutive.
      - The files must not have file extensions
]====]


local utils = require 'utils'


validArgs = validArgs or utils.invert({
    'help',
    'v',
    'now',
    'folder',
    'file',
    'rand',
    'entity',
})

local args = utils.processArgs({...}, validArgs)

if args.help then
    print(help)
    return
end

local prefix = "INTRO"
if args.file then
    prefix = args.file
end

local inputfolder = dfhack.getDFPath() .. "/data/announcement/"
if args.folder then
    inputfolder = dfhack.getDFPath() ..  args.folder .. "/"
end

rngesus = dfhack.random.new()


--Code main body, this is where the magic happens
local function introloader(folder,dorand,doent,verbose)
    local entity = ""
	if args.entity then
		entity = "_" .. df.historical_entity.find(df.global.ui.civ_id).entity_raw.code
	end
    
    local inputfile = prefix .. entity
    
    if args.rand then
        --Determine number of usable files
		local index = " "
		for foo,filename in pairs(dfhack.filesystem.listdir(folder)) do
			index = index .. "\n" .. filename
		end
		
        local filecount = 0
        for foo in string.gmatch(index,inputfile .. "_%d+") do
            filecount = filecount + 1
        end
        
        --Random decision
        if filecount > 0 then
            local rand = rngesus:random(filecount)+1
            inputfile = inputfile .. "_" .. rand
        end
    end
	
	inputfile = folder .. inputfile
    
    if verbose then print("Loading intro text from " .. inputfile) end
    local input = assert(io.open(inputfile, "rb"),"No matching intro file, leaving as-is")
    if input == false then return end
    local output = assert(io.open(dfhack.getDFPath() .. "/data/announcement/fortressintro", "wb"),"Could not create or open data/announcement/fortressintro, somehow.")
    if output == false then input:close() return end
    local t = input:read("*all")
    t = string.gsub(t, "\r\n", "\n") --You can never be too sure with these things; Windows is absolutely obsessive with its \r characters
    output:write(t)
    if verbose then print("Civilization intro text written") end
    output:close()
    input:close()
end



--Flow control for the code; runs process code after embark selection has been made, to ensure proper operation.
dfhack.onStateChange.loadNewFortressIntro = function(code)
	if(args.rand or args.entity) then
		if args.v then print("Intro loader ready") end
		if (code == SC_VIEWSCREEN_CHANGED and dfhack.gui.getCurFocus() == 'setupdwarfgame') or (args.now) then
			dfhack.with_suspend(introloader,inputfolder,args.rand,args.entity, args.v)
		end
	else
		dfhack.printerr("Intro loader has invalid parameters, aborting")
	end
end