local dialogs = require('gui.dialogs')
local utils = require('utils')

function addCivToEmbarkList(info)
   local viewscreen = dfhack.gui.getDFViewscreen(true)

   viewscreen.start_civ:insert ('#', info.civ)
   viewscreen.start_civ_nem_num:insert ('#', info.nemeses)
   viewscreen.start_civ_entpop_num:insert ('#', info.pops)
   viewscreen.start_civ_site_num:insert ('#', info.sites)
end

function embarkAnyone()
   local viewscreen = dfhack.gui.getDFViewscreen(true)
   local choices, existing_civs = {}, {}

   for _,existing_civ in ipairs(viewscreen.start_civ) do
      existing_civs[existing_civ.id] = true
   end

   if viewscreen._type ~= df.viewscreen_choose_start_sitest then
      qerror("This script can only be used on the embark screen!")
   end

   for i, civ in ipairs (df.global.world.entities.all) do
      -- Test if entity is a civ
      if civ.type ~= df.historical_entity_type.Civilization then goto continue end
      -- Test if entity is already in embark list
      if existing_civs[civ.id] then goto continue end

      local sites = 0
      local pops = 0
      local nemeses = 0
      local histfigs = 0
      local label = ''

      -- Civs keep links to sites they no longer hold, so check owner
      -- We also take the opportunity to count population
      for j, link in ipairs(civ.site_links) do
         local site = df.world_site.find(link.target)
         if site ~= nil and site.civ_id == civ.id then
            sites = sites + 1

            -- DF stores population info as an array of groups of residents (?).
            -- Inspecting these further could give a more accurate count.
            for _, group in ipairs(site.populace.inhabitants) do
               pops = pops + group.count
            end
         end

         -- Count living nemeses
         for _, nem_id in ipairs (civ.nemesis_ids) do
            local nem = df.nemesis_record.find(nem_id)
            if nem ~= nil and nem.figure.died_year == -1 then
               nemeses = nemeses + 1
            end
         end

         -- Count living histfigs
         -- Used for death detection. May be redundant.
         for _, fig_id in ipairs (civ.histfig_ids) do
            local fig = df.historical_figure.find(fig_id)
            if fig ~= nil and fig.died_year == -1 then
               histfigs = histfigs + 1
            end
         end
      end

      -- Find the civ's name, or come up with one
      if civ.name.has_name then
         label = dfhack.TranslateName(civ.name, true) .. "\n"
      else
         label = "Unnamed " ..
            dfhack.units.getRaceReadableNameById(civ.race) ..
            " civilisation\n"
      end

      -- Add species
      label = label .. dfhack.units.getRaceNamePluralById(civ.race) .. "\n"

      -- Add pop & site count or mark civ as dead.
      if histfigs == 0 and pops == 0 then
         label = label .. "Dead"
      else
         label = label .. "Pop: " .. (pops + nemeses) .. " Sites: " .. sites
      end

      table.insert(choices, {text = label,
                             info = {civ = civ, pops = pops, sites = sites,
                                     nemeses = nemeses}})

      ::continue::
   end

   if #choices > 0 then
      dialogs.ListBox{
         frame_title = 'Embark Anyone',
         text = 'Select a civilization to add to the list of origin civs:',
         text_pen = COLOR_WHITE,
         choices = choices,
         on_select = function(id, choice)
            addCivToEmbarkList(choice.info)
         end,
         with_filter = true,
         row_height = 4,
      }:show()
   else
      dialogs.MessageBox{
         frame_title = 'Embark Anyone',
         text = 'No additional civilizations found.'
      }:show()
   end

end

embarkAnyone()
