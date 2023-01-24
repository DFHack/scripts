local help = [====[
pregnancy-postpone
=============
Delays childbirths by a week or an user-definable amount of time (in ticks).
Used as a workaround for a crash involving werebeasts giving birth. (https://www.bay12games.com/dwarves/mantisbt/view.php?id=11549)
Can also be used simply to gather information about pregnancies in the world/playable area.
Can act on: a selected unit, citizens on the map, non-citizens on the map, or worldwide.

Examples
=============
"pregnancy-postpone --info-only --citizens --non-citizens"
    Prints pregnancy information about all creatures in the playable area.

"pregnancy-postpone --world --ticks 1200"
    Postpones historical figures' childbirths worldwide by one day. (including those on your map)

"pregnancy-postpone -iu"
	Prints pregnancy information about the selected unit.

"pregnancy-postpone -u"
	Postpones selected unit's childbirth by a week. (the default amount of time)

Options
=============

"-i" "--info-only"
    Print pregnancy information without changing anything.

"-s" "--silent"
    Do not print pregnancy info.

"-u" "--unit"
    Acts only on the selected unit.

"-c" "--citizens"
    Acts on fort-controlled citizens in the playable area. (excludes animals)

"-x" "--non-citizens"
    Acts on all non-citizen units in the playable area, like animals and guests. (excludes citizens)

"-w" "--world"
    Act on the whole world. (INCLUDING your map, for now)

"-t <number>" "--ticks <number>""
    Postpone births by this many ticks.
    If unspecified, the default value is 8400. (1 week)
    in-game-time conversion table:
      1 hour  = 50 ticks
      1 day   = 1200 ticks
      1 week  = 8400 ticks
      1 month = 33600 ticks
      1 year  = 403200 ticks

Notes
=============
Short optional arguments can be chained together! 
   this command: "postpone-pregnancy --silent --citizens --ticks 2400"
is identical to: "postpone-pregnancy -sct2400"
Just make sure that the "-t <number>" argument comes last, if you want to use it.

For best results, be sure that the game is paused while running the script!
]====]
--[[ Credits:
---------------
made by TaxiService during a secretive mood.
  super duper turbo thanks to:
<3 ab9rf - for hunting down the cause of my map's crash with a debugger, setting me off on this coding journey.
<3 sdegrace - for mentioning how to use the lua console and "~" to print all. Invaluable tools for testing!
<3 myk002, Lethosor, nuvu (vallode), ab9rf (again) - for always pointing me in the right direction and putting up with me and my questions!
<3 all the giants from the DFHack community, on whose shoulders i stood on! 

notes for function grafters:
  Whenever i refer to a "dude", it means a "unit OR historical_figure" 
  ...otherwise, i tried to go for "readable" over "compact". hopefully it'll be understandable enough!
--]]
local argparse = require 'argparse'
local args = {
	DEBUG = false,
	info_only = false,
	silent = false,
	thisunit = false,
	citizens = false,
	noncitizens = false,
	worldwide = false,
	}
local TICKS = 8400

local cur_year = df.global.cur_year
local cur_tick = df.global.cur_year_tick

-------------------------------------

function formatName(dude) --returns a dude's name as a string, formatted for printing
	if dude.name.has_name == true then 
		return dfhack.df2console(dfhack.TranslateName(dude.name))
	else return '(unnamed)'
	end
end

function formatRace(dude) --returns a dude's race as a string
	if dude.race >= 0 then 
		return df.creature_raw.find(dude.race).caste[dude.caste].caste_name[0]
	else return 'unknown'
	end
end

function formatDude(dude) --returns a nicely formatted string with info about a dude
	if dude._type == df.unit then 
		return '(unit# '..dude.id..', histfig#: '..dude.hist_figure_id..') ('..formatRace(dude)..') '..formatName(dude)
	elseif dude._type == df.historical_figure then 
		return '(unit# '..dude.unit_id..', histfig#: '..dude.id..') ('..formatRace(dude)..') '..formatName(dude)
	else return '/!\\ formatDude(dude._type) is not "df.unit" or "df.historical_figure"'
	end
end

function getSpouse(dude) -- returns the histfig of a dude's spouse, if present. otherwise returns nil
	if dude._type == df.unit then 
		return df.historical_figure.find(dude.pregnancy_spouse)
	elseif dude._type == df.historical_figure then 
		for i,j in ipairs(dude.histfig_links) do 
			if j._type == df.histfig_hf_link_spousest then 
				return df.historical_figure.find(dude.histfig_links[i].target_hf)
			end
		end
	end
end

function checkGenes(unit) --returns a string with a unit's genes information
	if unit.pregnancy_genes ~= nil then 
		return 'appearance: '..#unit.pregnancy_genes.appearance..
			 ', colors: '..#unit.pregnancy_genes.colors
	else return ' UNIT MISSING GENES '
	end
end

function checkCaste(unit) --returns a string with caste information (this function is only used in "--debug" mode)
	if args.DEBUG then 
		return' | caste: '..unit.pregnancy_caste
	else return ''
	end
end

function checkWounds(histfig) --checks if a pregnancy is present, then returns a string with info about it
	if histfig.info ~= nil then 
		if histfig.info.wounds ~= nil then 
			return ' birth_year: '..histfig.info.wounds.childbirth_year..' | birth_tick: '..histfig.info.wounds.childbirth_tick
		else return '        [ HISTFIG MISSING WOUNDS ]'
		end
	else return '        [ HISTFIG MISSING INFO ]'
	end
end

function formatUnitPregnancyInfo(unit) --returns a string with a unit's pregnancy info
	return ' genes: ['..checkGenes(unit)..'] | timer: '..unit.pregnancy_timer..checkCaste(unit)
end

function formatHistfigPregnancyInfo(histfig) --returns a string with a histfig's pregnancy info
	return' birth_year: '..histfig.info.wounds.childbirth_year..' | birth_tick: '..histfig.info.wounds.childbirth_tick
end

--------------------------------------

function formatPregnancyInfo(dude) --combines previous functions to print the second part of a dude's information sheet
	if dude._type == df.unit then 
		print(formatUnitPregnancyInfo(dude)) 
		if dude.hist_figure_id ~= -1 then 
			print(checkWounds(df.historical_figure.find(dude.hist_figure_id))) 
		end

	elseif dude._type == df.historical_figure then 
		if df.unit.find(dude.unit_id) ~= nil then 
			print(formatUnitPregnancyInfo(df.unit.find(dude.unit_id))) 
		end
		print(formatHistfigPregnancyInfo(dude))

	else --if you see this, something went horribly wrong
		print('/!\\ formatPregnancyInfo(dude._type) is not "df.unit" or "df.historical_figure"')
	end
end

function printPregnancyInfo(dude) --prints a dude's information sheet (unless in "--silent" mode)
	if not args.silent then 
		print('-------------------------')
		print('bearer: '..formatDude(dude) )
		if getSpouse(dude) ~= nil then 
			print('spouse: '..formatDude(getSpouse(dude)) )
		end
		formatPregnancyInfo(dude)
	end
end

function printUpdatedInfo(dude) --this prints the third and last part of the info sheet (unless in "--silent" or "--info-only" modes)
	if not args.silent and not args.info_only then 
		if dude._type == df.unit then 
			print('>>>>>> modified into >>>>>> timer: '..dude.pregnancy_timer)
			if dude.hist_figure_id ~= -1 then 
				print(formatHistfigPregnancyInfo(df.historical_figure.find(dude.hist_figure_id))) 
			end
		elseif dude._type == df.historical_figure then 
			if dude.unit_id ~= -1 then 
				print('>>>>>> modified into >>>>>>') 
			end
			print(formatHistfigPregnancyInfo(dude))
		end
	end
end
--------------------------------------
function thisUnitIsPregnant(unit) --checks if a unit is pregnant
	if unit.pregnancy_genes ~= nil and unit.pregnancy_timer > 0 then 
		return true 
	elseif args.DEBUG and unit.pregnancy_caste ~= -1 then 
		return true --in "--debug" mode, returns true even for some units that have (probably) been pregnant in the past already
	end
	return false
end

function thisHistfigIsPregnant(histfig) --checks if a histfig is pregnant
	if histfig.info ~= nil then 
		if histfig.info.wounds ~= nil then 
			if histfig.info.wounds.childbirth_year ~= -1 or histfig.info.wounds.childbirth_tick ~= -1 then 
				if histfig.info.wounds.childbirth_year >= cur_year and histfig.info.wounds.childbirth_tick >= cur_tick then 
					return true
				elseif args.DEBUG then 
					return true --in "--debug" mode, returns true even for some histfigs that have been pregnant previously (probably)
				end
			end
		end
	end
	return false
end

function postponeHistfigPregnancy(histfig) --increases a histfig's pregnancy values by TICKS
	local hf = histfig.info.wounds
	hf.childbirth_tick = hf.childbirth_tick + TICKS % 403200 --this adds the remainder of (TICKS divided by 403200)
	hf.childbirth_year = hf.childbirth_year + math.floor(TICKS / 403200) --this adds 1 year for each 403200 ticks in TICKS
end

function postponePregnancy(dude) --attempts to perform changes to a unit and its histfig counterpart, or vice versa. (unless in "--info-only" mode)
	if not args.info_only then 
		if dude._type == df.unit then 
			dude.pregnancy_timer = dude.pregnancy_timer + TICKS --for units, it's this easy...
			if dude.hist_figure_id ~= -1 then 
				postponeHistfigPregnancy(df.historical_figure.find(dude.hist_figure_id))
			end
		elseif dude._type == df.historical_figure then 
			postponeHistfigPregnancy(dude)
			if dude.unit_id ~= -1 and df.unit.find(dude.unit_id) ~= nil then 
				local unit = df.unit.find(dude.unit_id)
				unit.pregnancy_timer = unit.pregnancy_timer + TICKS
			end
		else --you should never see this
			print('/!\\ postponePregnancy(dude._type) is not "df.unit" or "df.historical_figure"')
		end
	end
end

function doTheThing(dude) --does the thing
	printPregnancyInfo(dude)
	postponePregnancy(dude)
	printUpdatedInfo(dude)
end

function main(...) --this is where the magic happens
	local positionals = argparse.processArgsGetopt({...}, {
		{nil, 'debug',
			handler=function() args.DEBUG = true end},--]]
		{'i', 'info-only', 
			handler=function() args.info_only = true end}, 
		{'s', 'silent', 
			handler=function() args.silent = true end},
		{'u', 'unit', 
			handler=function() args.thisunit = true end},
		{'c', 'citizens', 
			handler=function() args.citizens = true end},
		{'x', 'non-citizens', 
			handler=function() args.noncitizens = true end},
		{'w', 'world',
			handler=function() args.worldwide = true end},
		{'t', 'ticks', hasArg=true,
			handler=function(optarg) TICKS = argparse.positiveInt(optarg) end} 
		})
	local counter = 0

	if args.thisunit then 
		local thisdude = dfhack.gui.getSelectedUnit()
		if thisdude then 
			if thisUnitIsPregnant(thisdude) then 
				doTheThing(thisdude)
				if not args.info_only then counter = counter + 1 end
			else
				print('The selected unit is not pregnant.')
			end
		else
			print('Select a unit and try again!')
		end
	else
		if args.worldwide then --TODO: ideally, this should exclude "--citizens" and "--not-citizens" modes histfigs, but it doesn't right now!
			for i,hsfg in ipairs(df.historical_figure.get_vector()) do
				if thisHistfigIsPregnant(hsfg) then
					doTheThing(hsfg)
					if not args.info_only then counter = counter + 1 end
				end
			end
		end 
		if args.citizens or args.noncitizens then 
			for i,unit in ipairs(df.global.world.units.active) do
				if thisUnitIsPregnant(unit) then 
					if args.citizens and dfhack.units.isCitizen(unit, true) then 
						doTheThing(unit)
						if not args.info_only then counter = counter + 1 end
					end
					if args.noncitizens and not dfhack.units.isCitizen(unit, true) then 
						doTheThing(unit)
						if not args.info_only then counter = counter + 1 end
					end
				end
			end
		end
	end
	if not args.silent then
		print('\ncurrent year: '..cur_year..' | current tick: '..cur_tick)
	end
	if counter > 1 then print('Postponed '..counter..' pregnancies by '..TICKS..' ticks.') 
    elseif counter == 1 then print('Postponed 1 pregnancy by '..TICKS..' ticks.')
    else print('No pregnancies have been postponed.') end
end

main(...) --dont forget to actually call this shit