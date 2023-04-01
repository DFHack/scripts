-- cult-lists 1.1
-- 
-- Prints all deities and religions in fort and lists all their worshippers by name.
-- Inspired by Fortunawhisk's Monotheism and Robob27's Adjust-Piety
-- Thanks to myk002, Rumrusher, ab9rf and coskerstrike for tips with LUA and DFhack API.
-- Special thanks to myk002 for the crash course on overlay widgets
--
------------------------------------------------------------------------------------------

-- NOTES:

-- things that would greatly simplify this script's horrible spaghetti coding:
	-- Wrapping label widget taking tokens so I can properly colour words in sentences
	-- Deity's entity links vector leading to their associated civs (is empty) so i don't depend on so many iterations
	-- force-opening DF screens, such as unit screen, on unit selection so i don't have to open unit screen separately (doesn't help the code tho)

--TO-DO
	-- draw pen lines to act as separators
	-- zoom on unit -- HOW??
	-- never touch LUA script again

------------------------------------------------------------------------------------------

-- error handling

if not dfhack.isMapLoaded() then
    qerror('This script requires fort mode to be loaded')
end

-- init

local utils = require('utils');
local gui = require('gui');
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets');

validArgs = utils.invert({
 'help',
 'nogui',
 'console',
 'printunits',
 'printreligions',
 'printall',
 'showids'
})

local args = utils.processArgs({...}, validArgs)

local nogui = false
local printstate = false
local printreligions = false
local printunits = false
local printall = false
local showids = false
local helpText = [===[

	cult-lists.lua
	==============
	Organizes fort deities in a list. Default opens a GUI with deities and religions.
	Alternative format lets results be printed to console, with some extra additions.
	NOTE: DFHack API is currently unable to filter for permanent residents

	arguments:
		-help
			print this help message
			
		-nogui
			disables the GUI
			
		-console 
			prints reults to console plus a number of options
			default state prints all deities and their followers
			
		-printreligions
			prints all religions and their members
			
		-printunits
			prints all units and their personal deities
			
		-printall
			prints cults list, worship list and unit list
			warning: large forts will exceed the console history limit.
			
		-showids
			prints religion's history entity ids, deity's history figure ids and unit's in-game ids

		Examples:
			All cults with clickable gui and no prints
			cult-lists
			
			All gods per unit with game id:
			cult-lists -console -printunits -showids

]===];

-- arg handling

if args.help then
    print(helpText)
    return
end

if args.nogui then
	print('no gui')
	nogui = true;
end

if (args.console) then
	print("prints enabled")
	printstate = true;
end

if (args.showids) then
	print("printing IDs")
	showids = true;
end

if (args.printreligions) then
	print("printing religion list")
	printreligions = true;
end

if (args.printunits) then
	print("printing unit list")
	printunits = true;
end

if (args.printall) then
	print("printing all lists")
	printall = true;
	printunits = false;
	printreligions = false;
end

if printstate == true then
	print('')
end

-- main body

local globalCivList = {};  -- necessary, there's no way to link to a civ from a god's hist figure.
						--[[ structure: { [index]={ [civ_race],
													[civ_id],
													[civ_deities]={ [index]={ [deity_name] } } 
													} } --]]
local filteredUnitList = {}; -- we pull in-game gods and religions here
						--[[ structure: { [index]={ [unit_data]={df.historical_figure},						-- table
													[unit_id] 
													} } --]]


local religionList = {}; -- pulled from unit list, rest of info pulled from entity links
						--[[ structure: { [index]={ [religion_id],
													[religion_name],                                        -- translated 
													[religion_deity],                                       -- translated
													[religion_civ],											-- translated 
													[religion_civ_race_name],								-- written, singular noun
													[member_list]={ [index] = { [member_game_id],
																				[member_id], 
																				[member_name],              -- untranslated
																				[member_race], } }			-- written, singular noun
													} } --]]
													
local deityList = {}; -- pulled from unit list and civ list, rest of info pulled from entity links
						--[[ structure: { [index]={ [deity_id],	
													[deity_name],											-- untranslated
													[deity_race],											-- ID, for procedural races
													[deity_race_name],                                      -- written, singular noun
													[deity_civ_id],
													[deity_civ_name],										-- translated
													[deity_civ_race_name],                                  -- written, singular noun
													[deity_spheres]={ [index]={ [deity_sphere] } }			-- written
													[worshipper_list]={ [index] = { [worshipper_game_id], 
																					[worshipper_id]
																					[worshipper_name], 		 -- untranslated
																					[worshipper_race],		 -- written, singular noun
																					[worshipper_faith] } },  -- turned to text
													} } --]]
													
local faithStrengthTable = { "ardent", "faithful", "regular", "casual", "dubious" };

local function faithStrengthSort(strength)

	local value
	
	if strength <= 20 then	
		value = faithStrengthTable[5]	
	elseif strength <= 40 then	
		value = faithStrengthTable[4]		
	elseif strength <= 60 then
		value = faithStrengthTable[3]	
	elseif strength <= 80 then	
		value = faithStrengthTable[2]	
	else 		
		value = faithStrengthTable[1]		
	end
	
	return value

end

-- array handling 

local function createCivList() -- up the chopping block if deity entity links ever get figured out

	local counter = 0

	for i, v in pairs(df.global.world.entities.all) do
	
		if v.type == 0 then -- type: civilization
		
			--print(v.id.." "..v.race.." "..dfhack.TranslateName(df.historical_entity.find(v.id).name,true))
			counter = counter + 1
			table.insert(globalCivList,{["civ_id"] = v.id,
										["civ_race"] = v.race,
										["civ_deities"] = {}
										});
										
			for j, v2 in pairs(v.relations.deities) do
			
				--print("       "..df.historical_figure.find(v2).id.." "..dfhack.TranslateName(df.historical_figure.find(v2).name))
				table.insert(globalCivList[counter].civ_deities, { ["deity_id"] = df.historical_figure.find(v2).id } )
				
			end
		end	
	end
end 

local function filterActiveUnits() --for each in-game unit, extracts historical figure data from save

	for i, activeUnit in pairs(df.global.world.units.active) do
	
		if dfhack.units.isCitizen(activeUnit) then

			table.insert( filteredUnitList,{["unit_data"] = df.historical_figure.find(activeUnit.hist_figure_id),
											["unit_id"] = activeUnit.id
											} )
											
		end
	end
end

local function createDeityList() -- hunts hist fig relations for deities. 

	local tempKeyTable = {} -- stores deity ids to prevent dupes
	local sphereTable = {}  -- temp table
	local deityRace = nil   
	local deityRaceName = nil 
	
	for i,unit in pairs(filteredUnitList) do
		
		for j,link in pairs(unit.unit_data.histfig_links) do 
		
			if link._type == df.histfig_hf_link_deityst then -- Checks deity type relation
			
				if not tempKeyTable[link.target_hf] then 
				
					sphereTable = {};
				
					--print("first entry: "..dfhack.TranslateName(df.historical_figure.find(link.target_hf).name).." --- "..link.target_hf)
					tempKeyTable[link.target_hf] = true -- turning it into a key makes the operator return false if there's a dupe
				
					if	df.historical_figure.find(link.target_hf).info.spheres ~= nil then
						for k, deitySpheres in pairs(df.historical_figure.find(link.target_hf).info.spheres.spheres) do
							--print(dfhack.TranslateName(df.historical_figure.find(link.target_hf).name), deitySpheres)
							table.insert(sphereTable, string.lower(df.sphere_type[deitySpheres]))
						end
					end	

						
					if df.historical_figure.find(link.target_hf).race ~= -1 then 
						deityRace = df.global.world.raws.creatures.all[df.historical_figure.find(link.target_hf).race].creature_id
						deityRaceName = df.global.world.raws.creatures.all[df.historical_figure.find(link.target_hf).race].name[0]
					end
					
					table.insert(deityList,{["deity_name"] = dfhack.TranslateName(df.historical_figure.find(link.target_hf).name),
											["deity_id"] = link.target_hf,
											["deity_race"] = deityRace,
											["deity_race_name"] = deityRaceName,
											["worshipper_list"] = {},
											["deity_spheres"] = sphereTable
											} )
				end	
			end
		end
	end
	
	for i, deity in pairs(deityList) do -- for gui labels
	
		--print("Checking local deities for civs: "..i..". "..deity.deity_name)
	
		for j, civ in pairs(globalCivList) do
		
			for k, civDeity in pairs(civ.civ_deities) do
			
				if deity.deity_id == civDeity.deity_id then
				
				--print("Match: "..deity.deity_name.." with "..dfhack.TranslateName(df.historical_entity.find(civ.civ_id).name))
					deity["deity_civ_name"] = dfhack.TranslateName(df.historical_entity.find(civ.civ_id).name, true)
					deity["deity_civ_id"] = civ.civ_id
					deity["deity_civ_race_name"] = df.global.world.raws.creatures.all[civ.civ_race].name[0]
					
				end
			end
		end
	end
	
	table.sort(deityList,function(k1, k2) return k1.deity_id < k2.deity_id end) -- puts related gods together	
	
end

local function createWorshippperList() -- add worshippers to each deity

	local tempKeyTable = {} -- this is a crutch to solve a duplication bug. read below

	for i,deity in pairs(deityList) do
	
	tempKeyTable = {}
	
		for j, unit in pairs(filteredUnitList) do
		
			for k, link in pairs(unit.unit_data.histfig_links) do
			
				if link.target_hf == deity.deity_id then						
							
					if not tempKeyTable[unit.unit_id] then
					
						--print("first entry: ".. dfhack.TranslateName(unit.unit_data.name).." --- "..unit.unit_id)
						tempKeyTable[unit.unit_id] = true -- turning it into a key makes the operator return false if there's a dupe
						table.insert(deity.worshipper_list,{["worshipper_name"] = dfhack.TranslateName(unit.unit_data.name),
															["worshipper_game_id"] = unit.unit_id,
															["worshipper_id"] = unit.unit_data.id,
															["worshipper_faith"] = faithStrengthSort(link.link_strength),
															["worshipper_race"] = df.global.world.raws.creatures.all[unit.unit_data.race].name[0],
															});
															
					else 
						--print("      dupe found: "..k.." "..deity.deity_name.." "..deity.deity_id)
						
					end		
				end
				
				--[[ -----------------BUG------------------
				-- when nested iterators are used (ie: here)
				-- there's a chance some units may be duplicated
				-- I can't find the cause, so I can't prevent the bug.
				-- may be a core game bug
				
				if unit.unit_id == A then
					print(dfhack.TranslateName(filteredUnitList[INDEX].unit_data.name)) -- prints twice
					print(filteredUnitList[INDEX].unit_id)						
				end
				if unit.unit_id == B then
					print(dfhack.TranslateName(filteredUnitList[INDEX].unit_data.name)) -- prints once
					print(filteredUnitList[INDEX].unit_id)						
				end 
				
				--]]

			end
		end
	end	
end

local function createReligionList()

	local tempKeyTable = {}; -- stores religion ids to prevent dupes
	local tempValue = 0;

	for i, unit in pairs(filteredUnitList) do

		for j,link in pairs(unit.unit_data.entity_links) do 
		
			if df.historical_entity.find(link.entity_id).type == 5 then -- religion
			
				temptValue = 0;
			
				if not tempKeyTable[link.entity_id] then
				
				--print("first entry: ".. dfhack.TranslateName(df.historical_entity.find(link.entity_id).name, true).." --- "..link.entity_id)
				tempKeyTable[link.entity_id] = true
				
				for k, parentCiv in pairs(df.historical_entity.find(link.entity_id).entity_links) do
				
					if parentCiv.type == 0 then -- type: parent civ
					
						tempValue = parentCiv.target;
						break
						
					end
				
				end
				
				table.insert(religionList, {["religion_id"]=link.entity_id,
											["religion_name"]=dfhack.TranslateName(df.historical_entity.find(link.entity_id).name, true),
											["religion_civ"]=dfhack.TranslateName(df.historical_entity.find(tempValue).name, true),
											["religion_civ_race_name"]=df.global.world.raws.creatures.all[df.historical_entity.find(tempValue).race].name[0],
											["religion_deity"]=dfhack.TranslateName(df.historical_figure.find(df.historical_entity.find(link.entity_id).relations.deities[0]).name, true),
											["member_list"]= { }
											} )
				else 
					--print("      dupe found: "..i.." "..dfhack.TranslateName(df.historical_entity.find(link.entity_id).name, true).." "..link.entity_id)
				end
			end
		end
	end	
	
	table.sort(religionList,function(k1, k2) return k1.religion_id < k2.religion_id end)
	
end
	
	
local function createMemberList()

	local temptKeyTable = {}

	for i, religion in pairs(religionList) do
	
		tempKeyTable = {} -- resets per religion
	
		for j, unit in pairs(filteredUnitList) do

			for k, link in pairs(unit.unit_data.entity_links) do
			
				if link.entity_id == religion.religion_id then	
				
					if not tempKeyTable[unit.unit_id] then
				
						--print("first entry: ".. dfhack.TranslateName(unit.unit_data.name).." --- "..unit.unit_id)
						tempKeyTable[unit.unit_id] = true
						table.insert(religion.member_list, {["member_name"] = dfhack.TranslateName(unit.unit_data.name),
															["member_race"] = df.global.world.raws.creatures.all[unit.unit_data.race].name[0],
															["member_id"] = unit.unit_data.id,
															["member_game_id"] = unit.unit_id,
															});
					else 
						--print("      dupe found: "..k.." "..religion.religion_name.." "..religion.religion_id)
						
					end	
				end
			end
		end
	end
end

-- console handling

local function showidsControl(state, counter, index, name, id, civ, faithStrength) -- this could be written better
	
	if state == 1 then
		if counter == 0 then
			print(index..".".." "..name.." is not religious.");
			return
		end
		if showids == false then
			print(index..".".." "..name.." worships:");
		else 
			print(index..".".." "..name.." ("..id..") worships:");
		end
		return
	end
	if state == 2 then
		if civ == nil then
			if showids == false then
			print('\t'.."- "..name.." the Divine Beast. ("..faithStrength..")")
			else 
			print('\t'.."- "..name.. " ("..id..") the Divine Beast. ("..faithStrength..")")
			end
		else 
			if showids == false then
			print('\t'.."- "..name.." of "..civ.." ("..faithStrength..")")
			else 
			print('\t'.."- "..name.. " ("..id..") of "..civ.." ("..faithStrength..")")
			end
		end
		return
	end
	if state == 3 then
		if civ == nil then
			if showids == false then
			print(index..". "..name.." the Divine Beast. Worshippers:");
			else
			print(index..". "..name.." ("..id..") the Divine Beast. Worshippers:");
			end
		else
			if showids == false then
				print(index..". "..name.." of "..civ..". Worshippers:");
			else
				print(index..". "..name.." ("..id..") of "..civ..". Worshippers:");
			end
		return
		end
	end
	if state == 4 then
		if showids == false then
			print('\t'..index..". "..name.." ("..faithStrength..")");
		else
			print('\t'..index..". "..name.." ("..id..") ("..faithStrength..")");
		end
		return
	end
	if state == 5 then
		if showids == false then
			print(index..". "..name.." of "..civ..". Members:")
		else
			print(index..". "..name.." ("..id..") of "..civ..". Members:")	
		end
		return
	end
	if state == 6 then
		if showids == false then
			print('\t'..index..". "..name);
		else
			print('\t'..index..". "..name.." ("..id..")");
		end
		return
	end
end


local function cultPrint()

	local counter = 0;

	if printunits == true or printall == true then
	
		for i,unit in pairs(filteredUnitList) do
		
			for j, link in pairs(unit.unit_data.histfig_links) do 
			
				if link._type == df.histfig_hf_link_deityst then
					counter = counter + 1;
					break
				end

			end			
			
			showidsControl(1, counter, i, dfhack.TranslateName(unit.unit_data.name), unit.unit_id);

			for j, link in pairs(unit.unit_data.histfig_links) do 
			
				for k, deity in pairs(deityList) do
				
					if link.target_hf == deity.deity_id then
					
					showidsControl(2, nil, nil, dfhack.TranslateName(df.historical_figure.find(link.target_hf).name), link.target_hf, deity.deity_civ_name, link.link_strength)
					
					end
				
				end
			end
			print("")
			counter = 0;
		end
	end
	
	if printreligions == true or printall == true then
	
	print('\n'..'\t'.."CULT: FINAL TALLY IS :"..'\n')
	
		for i, religion in pairs(religionList) do
		
			showidsControl(5, nil, i, religion.religion_name, religion.religion_id, religion.religion_civ)
		
			for j, unit in pairs(religion.member_list) do
			
				showidsControl(6, nil, j, unit.member_name, unit.member_id)
			
			end		
		end	
	end
	
	if printunits == false and printreligions == false then
	
		print('\n'..'\t'.."DEITY: FINAL TALLY IS:"..'\n')

		for i, deity in pairs(deityList) do
		
			showidsControl(3, nil, i, deity.deity_name, deity.deity_id, deity.deity_civ_name);
			
			for j, unit in pairs(deity.worshipper_list) do
						
				showidsControl(4, nil, j, unit.worshipper_name, unit.worshipper_game_id, nil, unit.worshipper_faith);
				
			end
		end 
	end
end

-- gui rendering

Deities = defclass(Deities, widgets.Panel) -- page-panel 1
Deities.ATTRS{
    focus_path='Deities',
	frame={t=0, b=0, l=0, t=0},
	on_submit=DEFAULT_NIL, -- becomes self.on_submit, passes value down the stack
	--frame_background = dfhack.pen.parse{tile_bg=COLOR_BLACK, tile_fg=COLOR_BLACK},
}

function Deities:init()

	--print("deities works?")

	self:addviews{
	
		widgets.List{
			view_id='deity_list',
			frame={w=36, h=18, l=0, t=0},
			scroll_keys={},
			on_submit=function(idx, value) return self.on_submit('deity_list', idx, value) end,  -- passes on_submit event and widget id to class on_submit
		},
		
		widgets.List{
			view_id='unit_list',
			frame={w=41, h=18, l=37, t=0},
			scroll_keys={},
			on_submit=function(idx, value) return self.on_submit('unit_list', idx, value) end,

		},
	}
	
end

Religions = defclass(Religions, widgets.Panel) -- page-panel 2
Religions.ATTRS{
    focus_path='Religions',
	frame={t=0, b=0, l=0, t=0},	
	on_submit=DEFAULT_NIL,
	--frame_background = dfhack.pen.parse{tile_bg=COLOR_BLACK, tile_fg=COLOR_BLACK},
}

function Religions:init()

	--print("religions works?")

	self:addviews{
	
		widgets.List{
			view_id='religion_list',
			frame={w=36, h=18, l=0, t=0},
			scroll_keys={},
			on_submit=function(idx, value) return self.on_submit('religion_list', idx, value) end,
		},
		
		widgets.List{
			view_id='member_list',
			frame={w=41, h=18, l=37, t=0},
			scroll_keys={},
			on_submit=function(idx, value) return self.on_submit('member_list', idx, value) end,
		},
	}

end

Enablegui = defclass(Enablegui, widgets.Window) -- main window - static inside zscreen
Enablegui.ATTRS{
	focus_path='Enablegui',
	frame_title='Deity & Cult Viewer',
	drag_anchors={title=true, frame=true},
	frame={w=127, h=25},
	resizable=true,
	religion_table=religionList,
	deity_table=deityList
}

function Enablegui:init() -- main mount structure

	self:addviews{
	
		widgets.HotkeyLabel{ 
			frame={t=0, l=26},
			key='CUSTOM_CTRL_T',
			label='Page',
            on_activate=self:callback('keyboard_control', "ctrl_t"),
		},

		widgets.HotkeyLabel{ 
			frame={t=0, l=41},
			key='CUSTOM_CTRL_V',
			label='Next Cult',
            on_activate=self:callback('keyboard_control', "ctrl_v"),
		},
		widgets.HotkeyLabel{ 
			frame={t=1, l=41},
			key='CUSTOM_CTRL_B',
			label='Prev Cult',
            on_activate=self:callback('keyboard_control', "ctrl_b"),
		},
		widgets.HotkeyLabel{ 
			frame={t=0, l=61},
			key='CUSTOM_CTRL_N',
			label='Next Unit',
            on_activate=self:callback('keyboard_control', "ctrl_n"),
		},
		widgets.HotkeyLabel{ 
			frame={t=1, l=61},
			key='CUSTOM_CTRL_M',
			label='Prev Unit',
            on_activate=self:callback('keyboard_control', "ctrl_m"),
		},

		widgets.TabBar{ -- auto-resizes
			frame={t=0, l=0},
			labels={
                'Deities',
                'Religions',
            },
			on_select=self:callback('set_page'), -- this changes tabs
			get_cur_page=function() return self.subviews.pages:getSelected() end, -- this changes pages
            key='CUSTOM_CTRL_T',
		},
		
		widgets.Pages{ -- just below tab bar
            view_id='pages',
            frame={t=3, b=0, l=0, r=0},
            subviews={
				Deities{
					view_id='deities_panel',
					on_submit=self:callback("list_handler"),
					
				},
                Religions{
					view_id='religions_panel',
					on_submit=self:callback("list_handler"),
				},
            },
        },
		
		widgets.Panel{ -- simpler than it looks. two text paragraphs, same line position. not my best idea
			frame={b=0, l=79, t=3, r=0},
			view_id='deities_info_panel',
				
			subviews={
			
				widgets.Label{
					frame={t=0, l=1},
					text= { {text=function() return self:label_sorter("line_1_title") end, pen=COLOR_RED},
                            NEWLINE,
                            NEWLINE, -- t=2
                            {text=function() return self:label_sorter("line_3_text") end},
                            NEWLINE,
                            {text=function() return self:label_sorter("line_4_subject") end, pen=COLOR_BROWN},
                            NEWLINE,
                            NEWLINE, -- t=5
                            {text=function() return self:label_sorter("line_6_text") end},
                            NEWLINE,
                            NEWLINE, -- t=7
                            {text=function() return self:label_sorter("line_8_text") end},
                            NEWLINE,
                            {text=function() return self:label_sorter("line_9_subject") end, pen=COLOR_YELLOW},
                            NEWLINE,
                            NEWLINE, --t=10
                            {text=function() return self:label_sorter("line_11_counter") end},
                            NEWLINE,
                            NEWLINE, --t=12
                            {text=function() return self:label_sorter("line_13_text") end},
                            NEWLINE,
                            NEWLINE, -- t=14
                            {text=function() return self:label_sorter("line_15_subject") end, pen=COLOR_BLUE},
                            NEWLINE,
                            NEWLINE, -- t=16
                            {text=function() return self:label_sorter("line_17_subject") end},
                            {text=function() return self:label_sorter("line_17_color") end, pen=COLOR_LIGHTBLUE},
                            {text=function() return self:label_sorter("line_17_end") end},
                    },
            
                },
			},
		},
	}
	
	--print('main screen works?')
	self:set_options(nil, 1, nil)
	self:refresh_page()
end

function Enablegui:refresh_page() -- updates the page on tab change

	self.subviews.pages:getSelectedPage()
	
	if self.subviews.pages:getSelected() == 1 then -- updates lists on tab change
		self.subviews.pages.subviews.deities_panel.subviews.deity_list:setSelected(1)
		self.subviews.pages.subviews.deities_panel.subviews.unit_list:setSelected(1)
		self:set_options(nil, 1, nil)
	else
		self.subviews.pages.subviews.religions_panel.subviews.religion_list:setSelected(1)
		self.subviews.pages.subviews.religions_panel.subviews.member_list:setSelected(1)
		self:set_options(nil, 1, nil)
	end
	
end

function Enablegui:set_page(val) -- updates the render on tab change

	self.subviews.pages:setSelected(val)
	self:refresh_page()
	self:updateLayout()
	--print("PAGECHANGED", self.subviews.pages:getSelected())
	
end

function Enablegui:list_handler(arg, index, value) -- determines what list got triggered

	--print('list_handler works?',arg,index,value)

	if arg == "deity_list" or arg == "religion_list" then
		self:set_options(arg, index, value)
	else
		self.faithful_index_state = index
	end

end


function Enablegui:set_options(arg, index, value) -- updates lists

	--print("set_options works?", arg, index, value)

	local listCult = {}
	local listFaithful = {}
	local deity_spheres_table = {} -- for label widgets
	
	local function iterator(tableArg, arg2)
		for i, cult in pairs(tableArg) do
			if arg2 then
				table.insert (listCult, cult.deity_name)
			else
				table.insert (listCult, cult.religion_name)
			end
		end
		if arg2 then
			for j, unit in pairs(tableArg[index].worshipper_list) do
				table.insert (listFaithful, unit.worshipper_name)
			end
		else
			for j, unit in pairs(tableArg[index].member_list) do
				table.insert (listFaithful, unit.member_name)
			end
		end
		
		if arg2 then
			self.subviews.deity_list:setChoices(listCult)
			self.subviews.unit_list:setChoices(listFaithful)
		else
			self.subviews.religion_list:setChoices(listCult)
			self.subviews.member_list:setChoices(listFaithful)
		end
		
		self.list_cult = #listCult
		self.list_faithful = #listFaithful
		listCult = {}
		listFaithful = {}
		self.cult_index_state = index -- used in set_label
		
	end
	
	if self.subviews.pages:getSelected() == 1 then
		iterator(self.deity_table, true)
		for i, v in pairs(self.deity_table[self.cult_index_state].deity_spheres) do
			table.insert(deity_spheres_table, v)
		end
		self.deity_spheres_table = deity_spheres_table
	elseif self.subviews.pages:getSelected() == 2 then
		iterator(self.religion_table, false)
	end
	
	self.subviews.pages.subviews.religions_panel.subviews.member_list:setSelected(1)	
	self.subviews.pages.subviews.deities_panel.subviews.unit_list:setSelected(1)
	self.faithful_index_state = 1 -- always first list in members	
	
end

function Enablegui:label_sorter(arg) -- writes text snippets

    if arg == "line_1_title" then -- title
        if 	self.subviews.pages:getSelected() == 1 then
            return dfhack.TranslateName(df.historical_figure.find(  self.deity_table[self.cult_index_state].deity_id  ).name, true)	
        else 
            return self.religion_table[self.cult_index_state].religion_name
        end
    end

    if arg == "line_3_text" then -- dressing text
        if self.subviews.pages:getSelected() == 1 then

            if self.deity_spheres_table[2] ~= nil then
                return 'Is sovereign in the realms of:'		
            elseif self.deity_spheres_table[1] ~= nil then
                return 'Is sovereign in the realm of:'		
            else 
                return 'Holds claim over no power.'
            end

        else
            return 'Dedicates a cult to:'
        end	
    end

    if arg == "line_4_subject" then -- spheres and deity
        if self.subviews.pages:getSelected() == 1 then
            return table.concat(self.deity_spheres_table, ", ")..'.'
        else
            return self.religion_table[self.cult_index_state].religion_deity
        end
    end

    if arg  == "line_6_text" then -- deity race
        if self.subviews.pages:getSelected() == 1 then

            if self.deity_table[self.cult_index_state].deity_civ_name ~= nil then
                if string.match(self.deity_table[self.cult_index_state].deity_civ_race_name, "elf") then
                    return 'It is a shapeless force of nature.'
                else 
                    return 'They oft take the form of a '..self.deity_table[self.cult_index_state].deity_race_name.."."
                end
            elseif string.match(self.deity_table[self.cult_index_state].deity_race, "FORGOTTEN") then
                return 'They are a terrifying cthonic monster.'
            elseif string.match(self.deity_table[self.cult_index_state].deity_race, "TITAN") then
                return 'They are a primordial being from ages prior.'
            elseif string.match(self.deity_table[self.cult_index_state].deity_race, "DIVINE") then
                return 'They are a servant of the god\'s.'
            elseif string.match(self.deity_table[self.cult_index_state].deity_race, "DEMON") then
                return 'They are a fierce demon, bent on destruction.'
            else 											-- megabeast
                return 'They are a great '..self.deity_table[self.cult_index_state].deity_race_name..', bound to no master.'
            end

        else

            if string.match(self.religion_table[self.cult_index_state].religion_civ_race_name, "elf") ~= true then
                return 'and their dominion.'
            else
                return 'and it\'s primordial forces'
            end

        end	
    end

    if arg == "line_8_text" then -- civ text
        if self.subviews.pages:getSelected() == 1 then

            if self.deity_table[self.cult_index_state].deity_civ_name ~= nil then
                return 'Their myth was first told by '..self.deity_table[self.cult_index_state].deity_civ_race_name..'s from:'
            else
                return nil
            end	

        else
            return 'It was founded by faithful from:'
        end	
    end	

    if arg == "line_9_subject" then -- civ name
        if self.subviews.pages:getSelected() == 1 then

            if self.deity_table[self.cult_index_state].deity_civ_name ~= nil then		
                return self.deity_table[self.cult_index_state].deity_civ_name
            else
                return nil
            end

        else
            return self.religion_table[self.cult_index_state].religion_civ
        end	
    end

    if arg == "line_11_counter" then -- cult size
        if self.subviews.pages:getSelected() == 1 then

            if #self.deity_table[self.cult_index_state].worshipper_list ~= 1 then
                return 'Their cult accounts for '..#self.deity_table[self.cult_index_state].worshipper_list..' citizens.'
            else
                return 'Their cult accounts for '..#self.deity_table[self.cult_index_state].worshipper_list..' citizen.'
            end

        else

            if #self.religion_table[self.cult_index_state].member_list ~= 1 then
                return 'Some '..#self.religion_table[self.cult_index_state].member_list..' citizens follow their doctrine.'
            else
                return 'A single citizen follows their doctrine.'
            end

        end			
    end

    if arg == "line_13_text" then -- unit race
        if self.subviews.pages:getSelected() == 1 then
            return 'Of whom the '..self.deity_table[self.cult_index_state].worshipper_list[self.faithful_index_state].worshipper_race..' '
        else
            return 'Which the '..self.religion_table[self.cult_index_state].member_list[self.faithful_index_state].member_race..' '
        end	
    end

    if arg == "line_15_subject" then -- unit name
        if self.subviews.pages:getSelected() == 1 then
            return dfhack.TranslateName(  df.historical_figure.find(  self.deity_table[self.cult_index_state].worshipper_list[self.faithful_index_state].worshipper_id  ).name, true)
        else
            return dfhack.TranslateName(  df.historical_figure.find(  self.religion_table[self.cult_index_state].member_list[self.faithful_index_state].member_id  ).name, true)
        end	
    end    

    if arg == "line_17_subject" then -- unit dressing 1
        if self.subviews.pages:getSelected() == 1 then
            if self.deity_table[self.cult_index_state].worshipper_list[self.faithful_index_state].worshipper_faith == "ardent" then
                return 'is an '
            else
                return 'is a '
            end
        else
            return 'is known to practice.'
        end	
    end

    if arg == "line_17_color" then -- unit faith
        if self.subviews.pages:getSelected() == 1 then
            return self.deity_table[self.cult_index_state].worshipper_list[self.faithful_index_state].worshipper_faith
        else
            return nil
        end	
    end
	
    if arg == "line_17_end" then -- unit dressing 2
        if self.subviews.pages:getSelected() == 1 then
            return ' worshipper of.'
        else
            return 
        end
    end

end

function Enablegui:keyboard_control(arg) -- what it says on the tin.
	
	if arg == 'ctrl_t' then
		if self.subviews.pages:getSelected() == 1 then
			return self:set_page(2)
		else 
			return self:set_page(1)
		end
	end
		
	if self.subviews.pages:getSelected() == 1 then
		if arg == 'ctrl_v' then
			self.subviews.pages.subviews.deities_panel.subviews.deity_list:setSelected(  self.subviews.pages.subviews.deities_panel.subviews.deity_list:getSelected() + 1)
			self:list_handler('deity_list', self.subviews.pages.subviews.deities_panel.subviews.deity_list:getSelected(), nil)
		elseif arg == 'ctrl_b' then
			self.subviews.pages.subviews.deities_panel.subviews.deity_list:setSelected(  self.subviews.pages.subviews.deities_panel.subviews.deity_list:getSelected() - 1)
			self:list_handler('deity_list', self.subviews.pages.subviews.deities_panel.subviews.deity_list:getSelected(), nil)
		elseif arg == 'ctrl_n' then
			self.subviews.pages.subviews.deities_panel.subviews.unit_list:setSelected(  self.subviews.pages.subviews.deities_panel.subviews.unit_list:getSelected() + 1)
			self:list_handler(nil, self.subviews.pages.subviews.deities_panel.subviews.unit_list:getSelected(), nil)
		elseif arg == 'ctrl_m' then
			self.subviews.pages.subviews.deities_panel.subviews.unit_list:setSelected(  self.subviews.pages.subviews.deities_panel.subviews.unit_list:getSelected() - 1)
			self:list_handler(nil, self.subviews.pages.subviews.deities_panel.subviews.unit_list:getSelected(), nil)
		end
	elseif self.subviews.pages:getSelected() == 2 then
		if arg == 'ctrl_v' then
			self.subviews.pages.subviews.religions_panel.subviews.religion_list:setSelected(  self.subviews.pages.subviews.religions_panel.subviews.religion_list:getSelected() + 1)
			self:list_handler('religion_list', self.subviews.pages.subviews.religions_panel.subviews.religion_list:getSelected(), nil)
		elseif	arg == 'ctrl_b' then
			self.subviews.pages.subviews.religions_panel.subviews.religion_list:setSelected(  self.subviews.pages.subviews.religions_panel.subviews.religion_list:getSelected() - 1)
			self:list_handler('religion_list', self.subviews.pages.subviews.religions_panel.subviews.religion_list:getSelected(), nil)
		elseif arg == 'ctrl_n' then
			self.subviews.pages.subviews.religions_panel.subviews.member_list:setSelected(  self.subviews.pages.subviews.religions_panel.subviews.member_list:getSelected() + 1)
			self:list_handler(nil, self.subviews.pages.subviews.religions_panel.subviews.member_list:getSelected(), nil)
		elseif arg == 'ctrl_m' then
			self.subviews.pages.subviews.religions_panel.subviews.member_list:setSelected(  self.subviews.pages.subviews.religions_panel.subviews.member_list:getSelected() - 1)
			self:list_handler(nil, self.subviews.pages.subviews.religions_panel.subviews.member_list:getSelected(), nil)
		end
	end
	
end

EnableguiScreen = defclass(EnableguiScreen, gui.ZScreen)
EnableguiScreen.ATTRS {
    focus_path='enable-gui-screen',
}

function EnableguiScreen:init()
    self:addviews{Enablegui{}}
end

function EnableguiScreen:onDismiss()
    view = nil
end



--[[ -- want to draw panel divisors, but this is chinese to me.

local function paint_horizontal_border(rect)

	local pen = dfhack.pen.parse{ch=196, fg=COLOR_ORANGE, bg=COLOR_BLACK}
	
    local panel_height = 6
    local x1, x2 = rect.x1, rect.x2
    local v_border_x = x2 - (10 + 2)
    local y = rect.y1 + panel_height
	--dfhack.screen.paintTile(LEFT_SPLIT_PEN, x1, y)
    --dfhack.screen.paintTile(RIGHT_SPLIT_PEN, v_border_x, y)
    for x=x1+1,v_border_x-1 do
        dfhack.screen.paintTile(pen, 50, 50)
    end
end

function Enablegui:onRenderFrame()

	
	paint_horizontal_border(rect)
	--dfhack.screen.paintTile(pen, 50, 50)
    --dfhack.screen.paintTile(LEFT_SPLIT_PEN, x1, y)
    --dfhack.screen.paintTile(RIGHT_SPLIT_PEN, v_border_x, y)
end
--]]


-- execution

createCivList();
filterActiveUnits();
createDeityList();
createWorshippperList();
createReligionList();
createMemberList();
if printstate == true then
cultPrint();
end
if nogui == false then
	view = view and view:raise() or EnableguiScreen{}:show()
end
