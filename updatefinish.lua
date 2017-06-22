--Alter the date which the updating region process finishes at.
local gui = require 'gui'
local widgets = require 'gui.widgets'
local vw = df.global.gview.view.child
local yr
local mn
local dy


updater=defclass(updater,gui.Screen)
updater.focus_path = 'updatefinish'
function updater:init()
	if not df.viewscreen_update_regionst:is_instance(vw) then
		self:dismiss()
		qerror("This has to be used on the updating region screen!")		
	end
	self:addviews{
		widgets.Label{
		view_id="mainLabel",
		frame = {xalign=0,yalign=0},
		text={
		{id="cmd", text=" Left/Right: Day, Up/Down: Week, Fast: Month/3 Months, Enter/Esc: To "},
		{id="yr", text=self:callback("getYear")},{text="/"}, {id="mn", text=self:callback("getMonth")},{text="/"}, {id="dy", text=self:callback("getDay")},{text=" "}}
				}
			}
end

function updater:getYear()
	if df.viewscreen_update_regionst:is_instance(vw) then
		yr = vw.year
	else
		yr = df.global.cur_year
	end
	return yr
end

function updater:getMonth()
	if df.viewscreen_update_regionst:is_instance(vw) then
		if vw.year_tick>=33600 then
			mn = math.floor(vw.year_tick/33600)+1
		else
			mn = 1
		end
	else
		mn = math.floor(df.global.cur_year_tick/33600)+1
	end
	return mn
end

function updater:getDay()
	if df.viewscreen_update_regionst:is_instance(vw) then
		local mf = (mn-1)*28
		local yf = math.floor(vw.year_tick/1200)
			if vw.year_tick>=1200 then
				dy = (yf-mf)+1
			else
				dy = 1
			end
	else
		mf = (math.floor(df.global.cur_year_tick/33600))*28
		yf = math.floor(df.global.cur_year_tick/1200)
			dy = (yf-mf)+1
	end
	return dy
end

function updater:onInput(keys)
	if df.viewscreen_update_regionst:is_instance(vw) then
		if keys.LEAVESCREEN or keys.SELECT then
		 	self:dismiss()
		end
		if keys.CURSOR_RIGHT then
			if vw.year_tick>=402000 then
				vw.year = vw.year+1
				vw.year_tick = 0
			else
				vw.year_tick = vw.year_tick+1200
			end
		elseif keys.CURSOR_RIGHT_FAST then
			if vw.year_tick>=369600 then
				vw.year = vw.year+1
				vw.year_tick = 0
			else
				vw.year_tick = vw.year_tick+33600
			end
		elseif keys.CURSOR_LEFT then
			if vw.year_tick<=1200 then
				vw.year = vw.year-1
				vw.year_tick = 402000
			else
				vw.year_tick = vw.year_tick-1200
			end
		elseif keys.CURSOR_LEFT_FAST then
			if vw.year_tick<=33600 then
				vw.year = vw.year-1
				vw.year_tick = 369600
			else
				vw.year_tick = vw.year_tick-33600
			end
		elseif keys.CURSOR_UP then
			if vw.year_tick<=8400 then
				vw.year = vw.year-1
				vw.year_tick = vw.year_tick+394800
			else
				vw.year_tick = vw.year_tick-8400
			end
		elseif keys.CURSOR_UP_FAST then
			if vw.year_tick<=100800 then
				vw.year = vw.year-1
				vw.year_tick = vw.year_tick+302400
			else
				vw.year_tick = vw.year_tick-100800
			end
		elseif keys.CURSOR_DOWN then
			if vw.year_tick>=394800 then
				vw.year = vw.year+1
				vw.year_tick = vw.year_tick-394800
			else
				vw.year_tick = vw.year_tick+8400
			end
		elseif keys.CURSOR_DOWN_FAST then
			if vw.year_tick>=302400 then
				vw.year = vw.year+1
				vw.year_tick = vw.year_tick-302400
			else
				vw.year_tick = vw.year_tick+100800
			end
		end
	end
	self.super.onInput(self,keys)
end

function updater:onRenderBody(dc)
	self._native.parent:render()
end

updater():show()