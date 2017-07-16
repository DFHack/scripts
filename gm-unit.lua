-- Interface powered, user friendly, unit editor

--[====[

gui/gm-unit
===========
An editor for various unit attributes.

]====]
local gui = require 'gui'
local dialog = require 'gui.dialogs'
local widgets =require 'gui.widgets'
local guiScript = require 'gui.script'
local utils = require 'utils'
local args={...}


local target
--TODO: add more ways to guess what unit you want to edit
if args[1]~= nil then
    target=df.units.find(args[1])
else
    target=dfhack.gui.getSelectedUnit(true)
end

if target==nil then
    qerror("No unit to edit") --TODO: better error message
end
local editors={}
function add_editor(editor_class)
    table.insert(editors,{text=editor_class.ATTRS.frame_title,on_submit=function ( unit )
        editor_class{target_unit=unit}:show()
    end})
end
-------------------------------various subeditors---------
--TODO set local sould or better yet skills vector to reduce long skill list access typing
editor_skills=defclass(editor_skills,gui.FramedScreen)
editor_skills.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Skill editor",
    target_unit = DEFAULT_NIL,
    learned_only= false,
}
function list_skills(unit,learned_only)
    local s_=df.job_skill
    local u_skills=unit.status.current_soul.skills
    local ret={}
    for i,v in ipairs(s_) do
        if i>=0 then
            local u_skill=utils.binsearch(u_skills,i,"id")
            if u_skill or not learned_only then
                if not u_skill then
                    u_skill={rating=-1,experience=0}
                end

                local rating
                if u_skill.rating >=0 then
                    rating=df.skill_rating.attrs[u_skill.rating]
                else
                    rating={caption="<unlearned>",xp_threshold=0}
                end

                local text=string.format("%s: %s %d %d/%d",df.job_skill.attrs[i].caption,rating.caption,u_skill.rating,u_skill.experience,rating.xp_threshold)
                table.insert(ret,{text=text,id=i})
            end
        end
    end
    return ret
end
function editor_skills:update_list(no_save_place)
    local skill_list=list_skills(self.target_unit,self.learned_only)
    if no_save_place then
        self.subviews.skills:setChoices(skill_list)
    else
        self.subviews.skills:setChoices(skill_list,self.subviews.skills:getSelected())
    end
end
function editor_skills:init( args )
    if self.target_unit.status.current_soul==nil then
        qerror("Unit does not have soul, can't edit skills")
    end

    local skill_list=list_skills(self.target_unit,self.learned_only)

    self:addviews{
    widgets.FilteredList{
        choices=skill_list,
        frame = {t=0, b=1,l=1},
        view_id="skills",
    },
    widgets.Label{
                frame = { b=0,l=1},
                text ={{text= ": exit editor ",
                    key  = "LEAVESCREEN",
                    on_activate= self:callback("dismiss")
                    },
                    {text=": remove level ",
                    key = "SECONDSCROLL_UP",
                    on_activate=self:callback("level_skill",-1)},
                    {text=": add level ",
                    key = "SECONDSCROLL_DOWN",
                    on_activate=self:callback("level_skill",1)}
                    ,
                    {text=": show learned only ",
                    key = "CHANGETAB",
                    on_activate=function ()
                        self.learned_only=not self.learned_only
                        self:update_list(true)
                    end}
                    }
            },
        }
end
function editor_skills:get_cur_skill()
    local list_wid=self.subviews.skills
    local _,choice=list_wid:getSelected()
    if choice==nil then
        qerror("Nothing selected")
    end
    local u_skill=utils.binsearch(self.target_unit.status.current_soul.skills,choice.id,"id")
    return choice,u_skill
end
function editor_skills:level_skill(lvl)
    local sk_en,sk=self:get_cur_skill()
    if lvl >0 then
        local rating

        if sk then
            rating=sk.rating+lvl
        else
            rating=lvl-1
        end

        utils.insert_or_update(self.target_unit.status.current_soul.skills, {new=true, id=sk_en.id, rating=rating}, 'id') --TODO set exp?
    elseif sk and sk.rating==0 and lvl<0 then
        utils.erase_sorted_key(self.target_unit.status.current_soul.skills,sk_en.id,"id")
    elseif sk and lvl<0 then
        utils.insert_or_update(self.target_unit.status.current_soul.skills, {new=true, id=sk_en.id, rating=sk.rating+lvl}, 'id') --TODO set exp?
    end
    self:update_list()
end
function editor_skills:remove_rust(skill)
    --TODO
end
add_editor(editor_skills)
------- civ editor
RaceBox = defclass(RaceBox, dialog.ListBox)
RaceBox.focus_path = 'RaceBox'

RaceBox.ATTRS{
    format_name="$NAME ($TOKEN)",
    with_filter=true,
    allow_none=false,
}
function RaceBox:format_creature(creature_raw)
    local t = {NAME=creature_raw.name[0],TOKEN=creature_raw.creature_id}
    return string.gsub(self.format_name, "%$(%w+)", t)
end
function RaceBox:preinit(info)
    self.format_name=RaceBox.ATTRS.format_name or info.format_name -- preinit does not have ATTRS set yet
    local choices={}
    if RaceBox.ATTRS.allow_none or info.allow_none then
        table.insert(choices,{text="<none>",num=-1})
    end
    for i,v in ipairs(df.global.world.raws.creatures.all) do
        local text=self:format_creature(v)
        table.insert(choices,{text=text,raw=v,num=i,search_key=text:lower()})
    end
    info.choices=choices
end
function showRacePrompt(title, text, tcolor, on_select, on_cancel, min_width,allow_none)
    RaceBox{
        frame_title = title,
        text = text,
        text_pen = tcolor,
        on_select = on_select,
        on_cancel = on_cancel,
        frame_width = min_width,
        allow_none = allow_none,
    }:show()
end
CivBox = defclass(CivBox,dialog.ListBox)
CivBox.focus_path = "CivBox"

CivBox.ATTRS={
    format_name="$NAME ($ENGLISH):$ID",
    format_no_name="<unnamed>:$ID",
    name_other="<other(-1)>",
    with_filter=true,
    allow_other=false,
}

function civ_name(id,format_name,format_no_name,name_other,name_invalid)
    if id==-1 then
        return name_other or "<other (-1)>"
    end
    local civ
    if type(id)=='userdata' then
        civ=id
    else
        civ=df.historical_entity.find(id)
        if civ==nil then
            return name_invalid or "<invalid>"
        end
    end
    local t={NAME=dfhack.TranslateName(civ.name),ENGLISH=dfhack.TranslateName(civ.name,true),ID=civ.id} --TODO race?, maybe something from raws?
    if t.NAME=="" then
        return string.gsub(format_no_name or "<unnamed>:$ID", "%$(%w+)", t)
    end
    return string.gsub(format_name or "$NAME ($ENGLISH):$ID", "%$(%w+)", t)
end
function CivBox:update_choices()
    local choices={}
    if self.allow_other then
        table.insert(choices,{text=self.name_other,num=-1})
    end

    for i,v in ipairs(df.global.world.entities.all) do
        if not self.race_filter or (v.race==self.race_filter) then --TODO filter type
            local text=civ_name(v,self.format_name,self.format_no_name,self.name_other,self.name_invalid)
            table.insert(choices,{text=text,raw=v,num=i})
        end
    end
    self.choices=choices
    if self.subviews.list then
        self.subviews.list:setChoices(self.choices)
    end
end
function CivBox:update_race_filter(id)
    local raw=df.creature_raw.find(id)
    if raw then
        self.subviews.race_label:setText(": "..raw.name[0])
        self.race_filter=id
    else
        self.subviews.race_label:setText(": <none>")
        self.race_filter=nil
    end

    self:update_choices()
end
function CivBox:choose_race()
    showRacePrompt("Choose race","Select new race:",nil,function (id,choice)
        self:update_race_filter(choice.num)
    end,nil,nil,true)
end
function CivBox:init(info)
    self.subviews.list.frame={t=3,r=0,l=0}
    self:addviews{
        widgets.Label{frame={t=1,l=0},text={
        {text="Filter race ",key="CUSTOM_CTRL_A",key_sep="()",on_activate=self:callback("choose_race")},
        }},
        widgets.Label{frame={t=1,l=21},view_id="race_label",
        text=": <none>",
        }
    }
    self:update_choices()
end
function showCivPrompt(title, text, tcolor, on_select, on_cancel, min_width,allow_other)
    CivBox{
        frame_title = title,
        text = text,
        text_pen = tcolor,
        on_select = on_select,
        on_cancel = on_cancel,
        frame_width = min_width,
        allow_other = allow_other,
    }:show()
end

editor_civ=defclass(editor_civ,gui.FramedScreen)
editor_civ.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Civilization editor",
    target_unit = DEFAULT_NIL,
    }

function editor_civ:update_curren_civ()
    self.subviews.civ_name:setText("Currently: "..civ_name(self.target_unit.civ_id))
end
function editor_civ:init( args )
    if self.target_unit==nil then
        qerror("invalid unit")
    end

    self:addviews{
    widgets.Label{view_id="civ_name",frame = { t=1,l=1}, text="Currently: "..civ_name(self.target_unit.civ_id)},
    widgets.Label{frame = { t=2,l=1}, text={{text=": set to other (-1, usually enemy)",key="CUSTOM_N",
        on_activate= function() self.target_unit.civ_id=-1;self:update_curren_civ() end}}},
    widgets.Label{frame = { t=3,l=1}, text={{text=": set to current civ("..df.global.ui.civ_id..")",key="CUSTOM_C",
        on_activate= function() self.target_unit.civ_id=df.global.ui.civ_id;self:update_curren_civ() end}}},
    widgets.Label{frame = { t=4,l=1}, text={{text=": manually enter",key="CUSTOM_E",
        on_activate=function ()
         dialog.showInputPrompt("Civ id","Enter new civ id:",COLOR_WHITE,
            tostring(self.target_unit.civ_id),function(new_value)
                self.target_unit.civ_id=new_value
                self:update_curren_civ()
            end)
        end}}
        },
    widgets.Label{frame= {t=5,l=1}, text={{text=": select from list",key="CUSTOM_L",
        on_activate=function (  )
            showCivPrompt("Choose civilization", "Select units civilization",nil,function ( id,choice )
                self.target_unit.civ_id=choice.num
                self:update_curren_civ()
            end,nil,nil,true)
        end
        }}},
    widgets.Label{
                frame = { b=0,l=1},
                text ={{text= ": exit editor ",
                    key  = "LEAVESCREEN",
                    on_activate= self:callback("dismiss")
                    },
                    }
            },
        }
end
add_editor(editor_civ)
------- counters editor
editor_counters=defclass(editor_counters,gui.FramedScreen)
editor_counters.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Counters editor",
    target_unit = DEFAULT_NIL,
    counters1={
    "think_counter",
    "job_counter",
    "swap_counter",
    "winded",
    "stunned",
    "unconscious",
    "suffocation",
    "webbed",
    "soldier_mood_countdown",
    "soldier_mood", --todo enum,
    "pain",
    "nausea",
    "dizziness",
    },
    counters2={
    "paralysis",
    "numbness",
    "fever",
    "exhaustion",
    "hunger_timer",
    "thirst_timer",
    "sleepiness_timer",
    "stomach_content",
    "stomach_food",
    "vomit_timeout",
    "stored_fat" --TODO what to reset to?
    }
}
function editor_counters:fill_counters()
    local ret={}
    local u=self.target_unit
    for i,v in ipairs(self.counters1) do
        table.insert(ret,{f=u.counters:_field(v),name=v})
    end
    for i,v in ipairs(self.counters2) do
        table.insert(ret,{f=u.counters2:_field(v),name=v})
    end
    return ret
end
function editor_counters:update_counters()
    for i,v in ipairs(self.counter_list) do
        v.text=string.format("%s:%d",v.name,v.f.value)
    end
    self.subviews.counters:setChoices(self.counter_list)
end
function editor_counters:set_cur_counter(value,index,choice)
    choice.f.value=value
    self:update_counters()
end
function editor_counters:choose_cur_counter(index,choice)
    dialog.showInputPrompt(choice.name,"Enter new value:",COLOR_WHITE,
            tostring(choice.f.value),function(new_value)
                self:set_cur_counter(new_value,index,choice)
            end)
end
function editor_counters:init( args )
    if self.target_unit==nil then
        qerror("invalid unit")
    end

    self.counter_list=self:fill_counters()


    self:addviews{
    widgets.FilteredList{
        choices=self.counter_list,
        frame = {t=0, b=1,l=1},
        view_id="counters",
        on_submit=self:callback("choose_cur_counter"),
        on_submit2=self:callback("set_cur_counter",0),--TODO some things need to be set to different defaults
    },
    widgets.Label{
                frame = { b=0,l=1},
                text ={{text= ": exit editor ",
                    key  = "LEAVESCREEN",
                    on_activate= self:callback("dismiss")
                    },
                    {text=": reset counter ",
                    key = "SEC_SELECT",
                    },
                    {text=": set counter ",
                    key = "SELECT",
                    }
                   
                    }
            },
        }
    self:update_counters()
end
add_editor(editor_counters)
--------------------
editor_attributes=defclass(editor_attributes,gui.FramedScreen)
editor_attributes.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Attributes editor",
    target_unit = DEFAULT_NIL,
    physical_attrs={
    "STRENGTH",
    "AGILITY",
    "TOUGHNESS",
    "ENDURANCE",
    "RECUPERATION",
    "DISEASE_RESISTANCE",
    },
    mental_attrs={
    "ANALYTICAL_ABILITY",
    "FOCUS",
    "WILLPOWER",
    "CREATIVITY",
    "INTUITION",
    "PATIENCE",
    "MEMORY",
    "LINGUISTIC_ABILITY",
    "SPATIAL_SENSE",
    "MUSICALITY",
    "KINESTHETIC_SENSE",
    "EMPATHY",
    "SOCIAL_AWARENESS"
    }
}
function editor_attributes:fill_attributes()
    local ret={}
    local u=self.target_unit
    for i,v in ipairs(self.physical_attrs) do
        table.insert(ret,{f=u.body.physical_attrs:_field(v),name=v})
    end
    for i,v in ipairs(self.mental_attrs) do
        table.insert(ret,{f=u.status.current_soul.mental_attrs:_field(v),name=v})
    end
    return ret
end
function editor_attributes:update_attributes()
    for i,v in ipairs(self.attributes_list) do
        v.text=string.format("%s:%d/%d",v.name,v.f.value,v.f.max_value)
    end
    self.subviews.attributes:setChoices(self.attributes_list)
end
function editor_attributes:set_cur_attribute(value,index,choice)
    choice.f.value=value
    choice.f.max_value=value*2
    self:update_attributes()
end
function editor_attributes:choose_cur_attribute(index,choice)
    dialog.showInputPrompt(choice.name,"Enter new value:",COLOR_WHITE,
            tostring(choice.f.value),function(new_value)
                self:set_cur_attribute(new_value,index,choice)
            end)
end
function editor_attributes:step_value(dir)
    local index, choice = self.subviews.attributes:getSelected()
    local newVal
    if dir > 0 then --positive direction
        newVal = choice.f.value+dir
    else
        newVal = choice.f.value+dir
    end
    self:set_cur_attribute(newVal, index, choice)
end

function editor_attributes:init( args )
    if self.target_unit==nil then
        qerror("invalid unit")
    end

    self.attributes_list=self:fill_attributes()

    self:addviews{
    widgets.FilteredList{
        choices=self.attributes_list,
        frame = {t=0, b=1,l=1},
        view_id="attributes",
        on_submit=self:callback("choose_cur_attribute"),
        on_submit2=self:callback("set_cur_attribute"),--TODO some things need to be set to different defaults
    },
    widgets.Label{
                frame = { b=0,l=1},
                text ={
           {text= ": exit editor ",
                     key  = "LEAVESCREEN",
                     on_activate= self:callback("dismiss")
                    },
            {text=": +1000 ",
                     key = "SECONDSCROLL_UP",
                     on_activate=self:callback("step_value",1000)
            },
           {text=": -1000 ",
                     key = "SECONDSCROLL_DOWN",
                     on_activate=self:callback("step_value",-1000)
            },
                   {text=": set value ",
                     key = "SELECT",
                    }
                }
            },
        }
    self:update_attributes()
end
add_editor(editor_attributes)
---
wound_creator=defclass(wound_creator,gui.FramedScreen)
wound_creator.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Wound creator",
    target_wound = DEFAULT_NIL,
    --filter
}
function wound_creator:init( args )
    if self.target_wound==nil then
        qerror("invalid wound")
    end
   

    self:addviews{
    widgets.List{
       
        frame = {t=0, b=1,l=1},
        view_id="fields",
        on_submit=self:callback("edit_cur_wound"),
        on_submit2=self:callback("delete_current_wound")
    },
    widgets.Label{
                frame = { b=0,l=1},
                text ={{text= ": exit editor ",
                    key  = "LEAVESCREEN",
                    on_activate= self:callback("dismiss")},

                    {text=": edit wound ",
                    key = "SELECT"},

                    {text=": delete wound ",
                    key = "SEC_SELECT"},
                    {text=": create wound ",
                    key = "CUSTOM_CTRL_I",
                    on_activate= self:callback("create_new_wound")},

                    }
            },
        }
    self:update_wounds()
end
-------------------
editor_wounds=defclass(editor_wounds,gui.FramedScreen)
editor_wounds.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Wound editor",
    target_unit = DEFAULT_NIL,
    --filter
}
function is_scar( wound_part )
    return wound_part.flags1.scar_cut or wound_part.flags1.scar_smashed or
        wound_part.flags1.scar_edged_shake1 or wound_part.flags1.scar_blunt_shake1
end
function format_flag_name( fname )
    return fname:sub(1,1):upper()..fname:sub(2):gsub("_"," ")
end
function name_from_flags( wp )
    for i,v in ipairs(wp.flags1) do
        if v then
            return format_flag_name(df.wound_damage_flags1[i])
        end
    end
    for i,v in ipairs(wp.flags2) do
        if v then
            return format_flag_name(df.wound_damage_flags2[i])
        end
    end
    return "<unnamed wound>"
end
function format_wound( list_id,wound, unit)

    local name="<unnamed wound>"
    if #wound.parts>0 and #wound.parts[0].effect_type>0 then --try to make wound name by effect...
        name=tostring(df.wound_effect_type[wound.parts[0].effect_type[0]])
        if #wound.parts>1 then --cheap and probably incorrect...
            name=name.."s"
        end
    elseif #wound.parts>0 and is_scar(wound.parts[0]) then
        name="Scar"
    elseif #wound.parts>0 then
        local wp=wound.parts[0]
        name=name_from_flags(wp)
    end

    return string.format("%d. %s id=%d",list_id,name,wound.id)
end
function editor_wounds:update_wounds()
    local ret={}
    for i,v in ipairs(self.trg_wounds) do
        table.insert(ret,{text=format_wound(i,v,self.target_unit),wound=v})
    end
    self.subviews.wounds:setChoices(ret)
    self.wound_list=ret
end
function editor_wounds:dirty_unit()
    print("todo: implement unit status recalculation")
end
function editor_wounds:get_cur_wound()
    local list_wid=self.subviews.wounds
    local _,choice=list_wid:getSelected()
    if choice==nil then
        qerror("Nothing selected")
    end
    local ret_wound=utils.binsearch(self.trg_wounds,choice.id,"id")
    return choice,ret_wound
end
function editor_wounds:delete_current_wound(index,choice)
   
    utils.erase_sorted(self.trg_wounds,choice.wound,"id")
    choice.wound:delete()
    self:dirty_unit()
    self:update_wounds()
end
function editor_wounds:create_new_wound()
    print("Creating")
end
function editor_wounds:edit_cur_wound(index,choice)
   
end
function editor_wounds:init( args )
    if self.target_unit==nil then
        qerror("invalid unit")
    end
    self.trg_wounds=self.target_unit.body.wounds

    self:addviews{
    widgets.List{
       
        frame = {t=0, b=1,l=1},
        view_id="wounds",
        on_submit=self:callback("edit_cur_wound"),
        on_submit2=self:callback("delete_current_wound")
    },
    widgets.Label{
                frame = { b=0,l=1},
                text ={{text= ": exit editor ",
                    key  = "LEAVESCREEN",
                    on_activate= self:callback("dismiss")},

                    {text=": edit wound ",
                    key = "SELECT"},

                    {text=": delete wound ",
                    key = "SEC_SELECT"},
                    {text=": create wound ",
                    key = "CUSTOM_CTRL_I",
                    on_activate= self:callback("create_new_wound")},

                    }
            },
        }
    self:update_wounds()
end
add_editor(editor_wounds)

------ Body editor
modifier_selector = defclass(modifier_selector, gui.FramedScreen)

function modifierString(mod)
    local out = df.appearance_modifier_type[mod.type]
    out = out:lower() --Make lowercase
    out = out:gsub("_", " ") --Replace underscores with spaces
    out = out:gsub("^%l", string.upper) --capitalises first letter
    
    return out
end

function showModifierScreen(data)
    modifier_selector{
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Select a modifier",
    target_unit = DEFAULT_NIL,
    data = data
    }:show()
end

function modifier_selector:set_value(value,index,choice)
    for i,v in ipairs(choice.changes) do
        self.changeType[v] = value
    end
    self:update_features()
end

function modifier_selector:on_select(index, choice)
    dialog.showInputPrompt(modifierString(choice.mod),"Enter new value:",COLOR_WHITE,
            tostring(self.changeType[choice.changes[1]]),function(new_value)
                self:set_value(new_value,index,choice)
            end)
end

function modifier_selector:update_features()
    local out = {}
    for i, v in ipairs(self.partPicked.modList) do
        table.insert(out, {text = (modifierString(v.modifier) .. ": " .. self.changeType[v.changes[1]]), mod = v.modifier, changes = v.changes})
    end
    self.subviews.modifiers:setChoices(out)
end

--The following function was written on a day I couldn't brain. There's probably a simpler way to implement this but this way made sense to me at the time - Atkana
function modifier_selector:step_value(dir)
    local index, choice = self.subviews.modifiers:getSelected()
    if not choice then --It's possible this gets called when there isn't actually anything selected because of how filtered lists work
        return
    end
    local ranges = {} --Records the value at every step of the description range
    for i, v in ipairs(choice.mod.desc_range) do
        if #ranges == 0 or v > ranges[#ranges] then --Don't bother adding any entries if the same as the previous
            table.insert(ranges, v)
        end
    end
    
    local cur --The index for ranges that the current modifier lies on
    local curValue = self.changeType[choice.changes[1]]
    for i, v in ipairs(ranges) do
        if ranges[i+1] then --If there's a next entry
            if curValue < ranges[i+1] then --If the current value is less than the next entry
                cur = i
                break
            end
        else --This is the last entry
            cur = i
        end
    end
    
    local newVal --New value the chosen modifier will be set to
    if dir > 0 then --positive direction
        newVal = ranges[cur+dir] or ranges[#ranges]
    else
        newVal = ranges[cur+dir] or ranges[1]
    end
    
    self:set_value(newVal, index, choice)
end

function modifier_selector:init( info )
    self.partPicked = info.data.choice --The part that was picked in editor_body

    if info.data.choice.isPart then
        self.changeType = target.appearance.bp_modifiers
    else
        self.changeType = target.appearance.body_modifiers
    end
    
    self:addviews{
    widgets.FilteredList{
        frame = {t=0, b=1,l=1},
        view_id="modifiers",
        on_submit=self:callback("on_select")
    },
    widgets.Label{
                frame = { b=0,l=1},
                text ={{text= ": back to part selector ",
                    key  = "LEAVESCREEN",
                    on_activate= self:callback("dismiss")
                    },
                    {text=": edit modifier ",
                    key = "SELECT",
                    },
                    {text=": raise ",
                    --key = "SECONDSCROLL_DOWN",
                    key = "STANDARDSCROLL_RIGHT",
                    on_activate=self:callback("step_value",1)},
                    {text=": reduce ",
                    --key = "SECONDSCROLL_UP",
                    key = "STANDARDSCROLL_LEFT",
                    on_activate=self:callback("step_value",-1)},
                    }
            },
        }
    
    self:update_features()
end


editor_body=defclass(editor_body,gui.FramedScreen)
editor_body.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Body modifier editor",
    target_unit = DEFAULT_NIL,
}

function editor_body:bp_links()
    local out = {}
    local uc = self.ucaste
    for i,v in ipairs(uc.bp_appearance.part_idx) do
        out[i] = {["modId"] = uc.bp_appearance.modifier_idx[i], ["partId"] = uc.bp_appearance.part_idx[i]}
    end    

    return out
end

--Following is a relic from my original change-appearance script. There's probably a more efficient way of doing this, but I'm not in the mood to be redesigning ;P
function editor_body:make_bplist()
    local ret = {}
    local bpm = self.ucaste.bp_appearance.modifiers
    local links = self:bp_links()
    local point = {}
    
    for i, v in ipairs(bpm) do
        local mod = v
        
        local bpmname
        if #mod.noun > 0 then
            bpmname = mod.noun
        else
            bpmname = self.ucaste.body_info.body_parts[mod.body_parts[0]].name_singular[0].value
        end
        
        local changes = {}
        for i2, v2 in ipairs(mod.body_parts) do
            local partId = v2
            for i3, v3 in ipairs(links) do
                if v3.modId == i and v3.partId == partId then
                    table.insert(changes, i3) --?
                end
            end
        end
        
        if point[bpmname] then
            table.insert(ret[point[bpmname]].modList, {["modifier"] = mod, ["changes"] = changes})
        else
            table.insert(ret, {["name"] = bpmname, ["modList"] = {[1] = {["modifier"] = mod, ["changes"] = changes}}})
            point[bpmname] = #ret --Stores the index of the name for future additions
        end        
    end
    return ret
end

function editor_body:make_bodmodlist() --Version of make_bplist() to make a spoof version for body so it can be treated the same. Only makes modList
    local ret = {}
    local bm = self.ucaste.body_appearance_modifiers
    
    for i, v in ipairs(bm) do
        table.insert(ret, {["modifier"] = v, ["changes"] = {[1] = i}})
    end
    
    return ret
end

function editor_body:update_features()
    self.bplist = self:make_bplist()
    local out = {}
    local uc = self.ucaste
    self.bodmodlist = self:make_bodmodlist()
    
    --Special case of body
    --First check to discover if there are any body mods
    if #uc.body_appearance_modifiers > 0 then
        table.insert(out, {text = "Body", modList = self.bodmodlist})
    end
    
    for i,v in ipairs(self.bplist) do
        table.insert(out, {text = v.name:gsub("^%l", string.upper), modList = v.modList, isPart = true})
    end
    
    self.subviews.body:setChoices(out)
end

function editor_body:choose_cur_bp(index, choice)
    local data = {["choice"] = choice}

    showModifierScreen(data)
end


function editor_body:init( args )
    if self.target_unit==nil then
        qerror("invalid unit")
    end

    self.urace = self.target_unit.race
    self.ucritter = df.creature_raw.find(self.urace)
    self.ucaste = self.ucritter.caste[self.target_unit.caste]

    self:addviews{
    widgets.FilteredList{
        choices=self.features_list,
        frame = {t=0, b=1,l=1},
        view_id="body",
        on_submit=self:callback("choose_cur_bp")
    },
    widgets.Label{
                frame = { b=0,l=1},
                text ={{text= ": exit editor ",
                    key  = "LEAVESCREEN",
                    on_activate= self:callback("dismiss")
                    },
                    {text=": select feature ",
                    key = "SELECT",
                    }
                   
                    }
            },
        }
    
    self:update_features()
end
add_editor(editor_body)

------ Colors editor
ColorBox = defclass(ColorBox, dialog.ListBox)
ColorBox.focus_path = 'ColorBox'

ColorBox.ATTRS{
    with_filter = true,
    allow_none = false,
}

function showColorPrompt(title, text, tcolor, on_select, on_cancel, min_width,allow_other, data)
    ColorBox{
        frame_title = title,
        text = text,
        text_pen = tcolor,
        on_select = on_select,
        on_cancel = on_cancel,
        frame_width = min_width,
        allow_other = allow_other,
        data = data
    }:show()
end

function ColorBox:update_choices()
    local choices = {}
    for i,v in ipairs(self.mod.pattern_index) do
        table.insert(choices, {text=patternString(self.mod.pattern_index[i]), index = i})
    end
    
    self.choices = choices
    if self.subviews.list then
        self.subviews.list:setChoices(self.choices)
    end
end

function ColorBox:init(info)
    self.mod = info.data.mod

    self.target_unit = target
    self:update_choices()
end

editor_colors=defclass(editor_colors,gui.FramedScreen)
editor_colors.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Colors editor",
    target_unit = DEFAULT_NIL,
}

function getColor(id)
    return df.descriptor_color.find(id)
end

function getPattern(id)
    return df.descriptor_pattern.find(id)
end

function patternString(id)
    local pattern = getPattern(id)
    local prefix
    if pattern.pattern == 0 then --Monochrome
        return getColor(pattern.colors[0]).name
    elseif pattern.pattern == 1 then --Stripes
        prefix = "striped"
    elseif pattern.pattern == 2 then --Iris_eye
        return getColor(pattern.colors[2]).name .. " eyes"
    elseif pattern.pattern == 3 then --Spots
        prefix = "spotted" --that's a guess
    elseif pattern.pattern == 4 then --Pupil_eye
        return getColor(pattern.colors[2]).name .. " eyes"
    elseif pattern.pattern == 5 then --mottled
        prefix = "mottled"
    end
    local out = prefix .. " "
    for i=0, #pattern.colors-1 do
        if i == #pattern.colors-1 then
            out = out .. "and " .. getColor(pattern.colors[i]).name
        elseif i == #pattern.colors-2 then
            out = out .. getColor(pattern.colors[i]).name .. " "
        else
            out = out .. getColor(pattern.colors[i]).name .. ", "
        end
    end
    return out
end

function editor_colors:change_color(index,patternId)
    self.target_unit.appearance.colors[index] = patternId
end

function editor_colors:update_features()
    local uc = self.ucaste
    local out = {}
    for i,v in ipairs(uc.color_modifiers) do
        table.insert(out, {text=uc.color_modifiers[i].part:gsub("^%l", string.upper), mod = uc.color_modifiers[i], index = i})
    end
    self.subviews.colors:setChoices(out)
end

function editor_colors:choose_cur_feature(index,choice)
    self.chosenFeature = choice
    local data = {ucaste = self.ucaste, mod = choice.mod} --data to pass to color prompt
    showColorPrompt("Choose color", "Select features color",nil,function ( id,choice )
                self:change_color(self.chosenFeature.index, choice.index)
            end,nil,nil,true, data)
end


function editor_colors:init( args )
    if self.target_unit==nil then
        qerror("invalid unit")
    end

    self.urace = self.target_unit.race
    self.ucritter = df.creature_raw.find(self.urace)
    self.ucaste = self.ucritter.caste[self.target_unit.caste]

    self:addviews{
    widgets.FilteredList{
        choices=self.features_list,
        frame = {t=0, b=1,l=1},
        view_id="colors",
        on_submit=self:callback("choose_cur_feature")
    },
    widgets.Label{
                frame = { b=0,l=1},
                text ={{text= ": exit editor ",
                    key  = "LEAVESCREEN",
                    on_activate= self:callback("dismiss")
                    },
                    {text=": select feature ",
                    key = "SELECT",
                    }
                   
                    }
            },
        }
    
    self:update_features()
end
add_editor(editor_colors)

------ Values (/beliefs)
editor_beliefs=defclass(editor_beliefs,gui.FramedScreen)
editor_beliefs.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Beliefs editor",
    target_unit = DEFAULT_NIL,
}

function editor_beliefs:buildPointers()
    local out = {}
    for i, v in ipairs(self.target_unit.status.current_soul.personality.values) do
        out[v.type] = i
    end
    self.pointers = out
end

function editor_beliefs:getCurBeliefValue(unit, beliefId)
    local upers = unit.status.current_soul.personality
    if self.pointers[beliefId] then
        return upers.values[self.pointers[beliefId]].strength, false
    elseif upers.cultural_identity ~= -1 then
        return df.cultural_identity.find(upers.cultural_identity).values[beliefId], true
    else
        return 0, true --outsiders have no culture
    end    
end

function editor_beliefs:update_choices()
    self:buildPointers()
    local out = {}
    for i, v in ipairs(df.value_type) do
        local niceText = v
        niceText = niceText:lower()
        niceText = niceText:gsub("_", " ")
        niceText = niceText:gsub("^%l", string.upper)
        
        local strength, isCulture = self:getCurBeliefValue(self.target_unit, i)
        local numAddition = strength
        if isCulture then
            numAddition = numAddition .. "*"
        end
        table.insert(out, {["text"] = niceText .. ": " .. numAddition, ["beliefId"] = i, ["strength"] = strength, ["name"] = niceText})
    end
    self.subviews.beliefs:setChoices(out)
end

function editor_beliefs:set_belief(new_value, index, choice)
    dfhack.run_script("modtools/set-belief", table.unpack({"-value", '\\' .. new_value,"-target",tostring(self.target_unit.id), "-belief", tostring(choice.beliefId)}))
    self:update_choices()
end

function editor_beliefs:step_belief(dir)
    local index, choice = self.subviews.beliefs:getSelected()
    if not choice then
        return
    end
    dfhack.run_script("modtools/set-belief", table.unpack({"-target",tostring(self.target_unit.id), "-belief", tostring(choice.beliefId), "-step", "\\" .. dir}))
    self:update_choices()
end

function editor_beliefs:edit_belief(index, choice)
    dialog.showInputPrompt(choice.name,"Enter new value:",COLOR_WHITE,
            tostring(choice.strength),function(new_value)
                self:set_belief(new_value,index,choice)
            end)
    --This one causes choices to flicker for some reason
end

function editor_beliefs:default_belief(index, choice)
    dfhack.run_script("modtools/set-belief", table.unpack({"-target",tostring(self.target_unit.id), "-belief", tostring(choice.beliefId), "-default"}))
    self:update_choices()
end

function editor_beliefs:init( args )
    if self.target_unit==nil then
        qerror("invalid unit")
    end
    
    self:addviews{
        widgets.FilteredList{
            frame = {t=0, b=2,l=1},
            view_id="beliefs",
            on_submit=self:callback("edit_belief"),
            on_submit2=self:callback("default_belief")
        },
        widgets.Label{
                    frame = {b=1, l=1},
                    text ={{text= ": exit editor ",
                        key  = "LEAVESCREEN",
                        on_activate= self:callback("dismiss")
                        },
                        {text=": edit value ",
                        key = "SELECT",
                        },
                        {text=": raise ",
                        key = "STANDARDSCROLL_RIGHT",
                        on_activate=self:callback("step_belief",1)},
                        {text=": reduce ",
                        key = "STANDARDSCROLL_LEFT",
                        on_activate=self:callback("step_belief",-1)},
                        }
                },
        widgets.Label{
            frame = {b=0, l=1},
            text = {
                {
                    text = "* denotes cultural default  "
                },
                {
                    text=": set to cultural default ",
                    key = "SEC_SELECT",
                },
            }
        
        
        
        },
    }
    
    self:update_choices()
end
add_editor(editor_beliefs)

------ Personality
editor_pers=defclass(editor_pers,gui.FramedScreen)
editor_pers.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Personality editor",
    target_unit = DEFAULT_NIL,
}

function editor_pers:getCurTraitValue(unit, traitId)
    return unit.status.current_soul.personality.traits[traitId]
end

function editor_pers:update_choices()
    local out = {}
    for i, v in ipairs(df.personality_facet_type) do
        local niceText = v
        niceText = niceText:lower()
        niceText = niceText:gsub("_", " ")
        niceText = niceText:gsub("^%l", string.upper)

        local strength = self:getCurTraitValue(self.target_unit, i)
        
        table.insert(out, {["text"] = niceText .. ": " .. strength, ["traitId"] = i, ["strength"] = strength, ["name"] = niceText})
    end
    self.subviews.traits:setChoices(out)
end

function editor_pers:set_trait(new_value, index, choice)
    dfhack.run_script("modtools/set-personality", table.unpack({"-value", '\\' .. new_value,"-target",tostring(self.target_unit.id), "-trait", tostring(choice.traitId)}))
    self:update_choices()
end

function editor_pers:step_trait(dir)
    local index, choice = self.subviews.traits:getSelected()
    if not choice then
        return
    end
    dfhack.run_script("modtools/set-personality", table.unpack({"-target",tostring(self.target_unit.id), "-trait", tostring(choice.traitId), "-step", "\\" .. dir}))
    self:update_choices()
end

function editor_pers:edit_trait(index, choice)
    dialog.showInputPrompt(choice.name,"Enter new value:",COLOR_WHITE,
            tostring(choice.strength),function(new_value)
                self:set_trait(new_value,index,choice)
            end)
end

function editor_pers:average_trait(index, choice)
    dfhack.run_script("modtools/set-personality", table.unpack({"-target",tostring(self.target_unit.id), "-trait", tostring(choice.traitId), "-average"}))
    self:update_choices()
end

function editor_pers:init( args )
    if self.target_unit==nil then
        qerror("invalid unit")
    end

    self:addviews{
        widgets.FilteredList{
            frame = {t=0, b=2,l=1},
            view_id="traits",
            on_submit=self:callback("edit_trait"),
            on_submit2=self:callback("average_trait")
        },
        widgets.Label{
                    frame = {b=1, l=1},
                    text ={{text= ": exit editor ",
                        key  = "LEAVESCREEN",
                        on_activate= self:callback("dismiss")
                        },
                        {text=": edit value ",
                        key = "SELECT",
                        },
                        {text=": raise ",
                        key = "STANDARDSCROLL_RIGHT",
                        on_activate=self:callback("step_trait",1)},
                        {text=": reduce ",
                        key = "STANDARDSCROLL_LEFT",
                        on_activate=self:callback("step_trait",-1)},
                        }
                },
        widgets.Label{
            frame = {b=0, l=1},
            text = {
                {
                    text=": set to caste average",
                    key = "SEC_SELECT",
                },
            }
        
        
        
        },
    }
    
    self:update_choices()
end
add_editor(editor_pers)


-------------------------------main window----------------
unit_editor = defclass(unit_editor, gui.FramedScreen)
unit_editor.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "GameMaster's unit editor",
    target_unit = DEFAULT_NIL,
    }


function unit_editor:init(args)

    self:addviews{
    widgets.FilteredList{
        choices=editors,
        on_submit=function (idx,choice)
            if choice.on_submit then
                choice.on_submit(self.target_unit)
            end
        end
    },
    widgets.Label{
                frame = { b=0,l=1},
                text ={{text= ": exit editor",
                    key  = "LEAVESCREEN",
                    on_activate= self:callback("dismiss")
                    },
                    }
            },
        }
end


unit_editor{target_unit=target}:show()
