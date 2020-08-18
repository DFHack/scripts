# convenient way to ban cooking categories of food
=begin

ban-cooking
===========
A more convenient way to ban cooking various categories of foods than the
kitchen interface.  Usage:  ``ban-cooking <type>``.  Valid types are ``booze``,
``honey``, ``tallow``, ``oil``, ``seeds`` (non-tree plants with seeds),
``brew``, ``fruit``, ``mill``, ``thread``, and ``milk``.

=end

# Create a dictionary/hash table to store what items are already banned.
already_banned = {}

# Just create a shorthand reference to the kitchen object
kitchen = df.ui.kitchen

# Store our list of banned items in the dictionary/hash table
kitchen.item_types.length.times { |i|
    if kitchen.exc_types[i] == :Cook
        already_banned[[kitchen.mat_types[i], kitchen.mat_indices[i], kitchen.item_types[i], kitchen.item_subtypes[i]]] = true
    end
}

# The function for actually banning cooking of an item.
# -- subtype was added to the arguments list from the original script, as
#  the original script defaulted subtype to -1, which doesn't support tree
#  fruit items
# -- item names was added to the front of the arguments list, as the
#  original script ran silently, and during debugging it was found to be
#  more useful to print the banned item names than picking through the
#  kitchen menu in game
ban_cooking = lambda { |print_name, mat_type, mat_index, type, subtype|
    key = [mat_type, mat_index, type, subtype]
    # Skip adding a new entry further below, if the item is already banned.
    if already_banned[key]
        return
    end
    # The item hasn't already been banned, so we do that here by appending its values to the various arrays
    puts(print_name + ' has been banned!')
    # grab the length of the array now, before it's appended to, so that we don't have to subtract one for the index value to be correct after appending is done.
    length = df.ui.kitchen.mat_types.length
    df.ui.kitchen.mat_types     << mat_type
    df.ui.kitchen.mat_indices   << mat_index
    df.ui.kitchen.item_types    << type
    df.ui.kitchen.item_subtypes << subtype
    df.ui.kitchen.exc_types     << :Cook
    already_banned[key] = true
}

$script_args.each do |arg|
    case arg
    # ban the cooking of plant based alcohol
    #  -- targets creature based alcohol, of which I'm not sure if any exists, but it should be banned too if it does, I guess (forgotten beasts maybe?)
    when 'booze'
        df.world.raws.plants.all.each_with_index do |p, i|
            p.material.each_with_index do |m, j|
                if m.flags[:ALCOHOL] and m.flags[:EDIBLE_COOKED]
                    ban_cooking[p.name + ' ' + m.id, j + DFHack::MaterialInfo::PLANT_BASE, i, :DRINK, -1]
                end
            end
        end
        df.world.raws.creatures.all.each_with_index do |c, i|
            c.material.each_with_index do |m, j|
                if m.flags[:ALCOHOL] and m.flags[:EDIBLE_COOKED]
                    ban_cooking[c.name[0] + ' ' + m.id, j + DFHack::MaterialInfo::CREATURE_BASE, i, :DRINK, -1]
                end
            end
        end

    # Mmmm.... mead.  For those days when you want to savor the labor of thousands of semi-willingly enslaved workers.
    # Bans only honey bee honey... technically dwarves could collect bumble bee honey from wild nests, I think...
    when 'honey'
        # hard-coded in the raws of the mead reaction
        honey = df.decode_mat('CREATURE:HONEY_BEE:HONEY')
        ban_cooking['honey bee honey', honey.mat_type, honey.mat_index, :LIQUID_MISC, -1]

    # Gotta have that cat soap somehow...
    # Just wait until explosives are implemented...
    # Bans all tallow from creatures
    when 'tallow'
        df.world.raws.creatures.all.each_with_index do |c, i|
            c.material.each_with_index do |m, j|
                if m.flags[:EDIBLE_COOKED] and m.reaction_product.id.include?('SOAP_MAT')
                    ban_cooking[c.name[0] + ' ' + m.id, j + DFHack::MaterialInfo::CREATURE_BASE, i, :GLOB, -1]
                end
            end
        end

    # Too bad adding this to meals doesn't alter the bone fracture mechanics (both healing and damage taking)
    # Ban milk from cooking, so that cheese can be produced
    # -- Not the best of ideas, as currently milk lasts forever, and cheese rots.
    # -- Technically hard cheeses never go "bad", they just grow a nasty mold layer that can be cut off
    when 'milk'
        df.world.raws.creatures.all.each_with_index do |c, i|
            c.material.each_with_index do |m, j|
                if m.flags[:EDIBLE_COOKED] and m.reaction_product.id.include?('CHEESE_MAT')
                    ban_cooking[c.name[0] + ' ' + m.id, j + DFHack::MaterialInfo::CREATURE_BASE, i, :LIQUID_MISC, -1]
                end
            end
        end

    # Don't be an elf...
    # Ban all plant based oils from cooking
    when 'oil'
        df.world.raws.plants.all.each_with_index do |p, i|
            p.material.each_with_index do |m, j|
                if  m.flags[:EDIBLE_COOKED] and m.reaction_product.id.include?('SOAP_MAT')
                    ban_cooking[p.name + ' ' + m.id, j + DFHack::MaterialInfo::PLANT_BASE, i, :LIQUID_MISC, -1]
                end
            end
        end

    # Ban seeds, and the plant parts that produce the seeds from being cooked
    # -- Doesn't ban seeds that can't be farmed (trees), as well as those that can't be brewed,
    #    as gaining seeds from dwarves eating the food raw is too time consuming.
    when 'seeds'
        df.world.raws.plants.all.each_with_index do |p, i|
            # skip over plants without seeds and tree seeds (as you can't currently farm trees with their seeds)
            if p.material_defs.type[:Seed] != -1 and p.material_defs.idx[:Seed] != -1 and not p.flags.inspect.include?('TREE')
                # Bans the seeds themselves
                ban_cooking[p.name + ' seeds', p.material_defs.type[:Seed], p.material_defs.idx[:Seed], :SEEDS, -1]
                # This section handles banning the structural plant parts that produce seeds.
                # -- There's no guarantee I can find that the STRUCTURAL material will be array item zero in the materials array
                #  thus I'm playing it safe with a possibly wasteful loop here
                p.material.each_with_index do |m, j|
                    # only operate here on STRUCTURAL materials, as the rest will be :PLANT_GROWTH, instead of just :PLANT
                    # which then means that the subtype won't be -1
                    if m.id == "STRUCTURAL" and m.flags[:EDIBLE_COOKED] and m.reaction_product.id.include?('SEED_MAT') and m.reaction_product.id.include?('DRINK_MAT')
                        ban_cooking[p.name + ' ' + m.id, j + DFHack::MaterialInfo::PLANT_BASE, i, :PLANT, -1]
                    end
                end
                # This section handles banning the plant growths that produce seeds
                p.growths.each_with_index do |g, r|
                    m = df.decode_mat(g).material
                    if m.flags[:EDIBLE_COOKED] and m.reaction_product.id.include?('SEED_MAT') and m.reaction_product.id.include?('DRINK_MAT')
                        p.material.each_with_index do |s, j|
                            if m.id == s.id
                                ban_cooking[p.name + ' ' + m.id, j + DFHack::MaterialInfo::PLANT_BASE, i, :PLANT_GROWTH, r]
                            end
                        end
                    end
                end
            end
        end

    # Bans cooking of alcohol producing plant parts
    when 'brew'
        df.world.raws.plants.all.each_with_index do |p, i|
            # skip over any plants that don't have an alcohol listed
            if p.material_defs.type[:Drink] != -1 and p.material_defs.idx[:Drink] != -1
                p.material.each_with_index do |m, j|
                    # only operate here on STRUCTURAL materials, as the rest will be :PLANT_GROWTH, instead of just :PLANT
                    # which then means that the subtype won't be -1
                    if m.id == "STRUCTURAL" and m.flags[:EDIBLE_COOKED] and m.reaction_product.id.include?('DRINK_MAT')
                        ban_cooking[p.name + ' ' + m.id, j + DFHack::MaterialInfo::PLANT_BASE, i, :PLANT, -1]
                    end
                end
                # This section handles banning the plant growths that produce alcohol
                p.growths.each_with_index do |g, r|
                    m = df.decode_mat(g).material
                    if m.flags[:EDIBLE_COOKED] and m.reaction_product.id.include?('DRINK_MAT')
                        p.material.each_with_index do |s, j|
                            if m.id == s.id
                                ban_cooking[p.name + ' ' + m.id, j + DFHack::MaterialInfo::PLANT_BASE, i, :PLANT_GROWTH, r]
                            end
                        end
                    end
                end
            end
        end

    # Should work, but I don't think there are any millable plants that are cookable
    when 'mill'
        df.world.raws.plants.all.each_with_index do |p, i|
            # skip over plants that don't have a millable part listed
            if p.material_defs.idx[:Mill] != -1
                p.material.each_with_index do |m, j|
                    if m.id == "STRUCTURAL" and m.flags[:EDIBLE_COOKED]
                        ban_cooking[p.name + ' ' + m.id, j + DFHack::MaterialInfo::PLANT_BASE, i, :PLANT, -1]
                    end
                end
                # No plant growths are targeted for milling, as I can't find a flag that would indicate that a growth
                # was used for milling.  Thus, I can only assume that only the STRUCTURAL plant object can be used
                # in the milling process.
            end
        end

    # Should work, but I don't think there are any thread convertable plants that are cookable
    when 'thread'
        df.world.raws.plants.all.each_with_index do |p, i|
            # skip over plants that don't have a threadable part listed
            if p.material_defs.idx[:Thread] != -1
                p.material.each_with_index do |m, j|
                    # only operate here on STRUCTURAL materials, as the rest will be :PLANT_GROWTH, instead of just :PLANT
                    # which then means that the subtype won't be -1
                    if m.id == "STRUCTURAL" and m.flags[:EDIBLE_COOKED] and m.reaction_product.str.include?('THREAD')
                        ban_cooking[p.name + ' ' + m.id, j + DFHack::MaterialInfo::PLANT_BASE, i, :PLANT, -1]
                    end
                end
                # This section handles banning the plant growths that produce thread... not that there are any now, that I'm aware of...
                p.growths.each_with_index do |g, r|
                    m = df.decode_mat(g).material
                    if m.flags[:EDIBLE_COOKED] and m.reaction_product.str.include?('THREAD')
                        p.material.each_with_index do |s, j|
                            if m.id == s.id
                                ban_cooking[p.name + ' ' + m.id, j + DFHack::MaterialInfo::PLANT_BASE, i, :PLANT_GROWTH, r]
                            end
                        end
                    end
                end
            end
        end

    # Bans fruits that produce alcohol
    when 'fruit'
        df.world.raws.plants.all.each_with_index do |p, i|
            p.growths.each_with_index do |g, r|
                # Get the material item from the growth data
                m = df.decode_mat(g).material
                # ensure that we're only targetting fruits that can be cooked as solids (that's the :LEAF_MAT flag)
                # in the kitchen, which can also be brewed into alcohol
                if m.id == "FRUIT" and m.flags[:EDIBLE_COOKED] and m.flags[:LEAF_MAT] and m.reaction_product.id.include?('DRINK_MAT')
                    p.material.each_with_index do |s, j|
                        if m.id == s.id
                            ban_cooking[p.name + ' ' + m.id, j + DFHack::MaterialInfo::PLANT_BASE, i, :PLANT_GROWTH, r]
                        end
                    end
                end
            end
        end

    # The below function outputs a pipe seperated list of the banned cooking ingredients
    # The list isn't intended to be readable from the console, as I used it for validating
    # the methods I was using to select, and ban cooking items.  Mostly this was for the
    # tree fruit items, as the item subtype number wasn't immediately obvious to be used
    # as a reference pointer to the growths array.
    when 'show'
        # First put together a dictionary/hash table
        type_list = {}
        # cycle through all plants
        df.world.raws.plants.all.each_with_index do |p, i|
            # The below three if statements initialize the dictionary/hash tables for their respective (cookable) plant/drink/seed
            # And yes, this will create and then overwrite an entry when there is no (cookable) plant/drink/seed item for a specific plant,
            # but since the -1 type and -1 index can't be added to the ban list, it's inconsequential to check for non-existent (cookable) plant/drink/seed items here
            if not type_list[[p.material_defs.type[:BasicMat], p.material_defs.idx[:BasicMat]]]
                type_list[[p.material_defs.type[:BasicMat], p.material_defs.idx[:BasicMat]]] = {}
            end
            if not type_list[[p.material_defs.type[:Drink], p.material_defs.idx[:Drink]]]
                type_list[[p.material_defs.type[:Drink], p.material_defs.idx[:Drink]]] = {}
            end
            if not type_list[[p.material_defs.type[:Seed], p.material_defs.idx[:Seed]]]
                type_list[[p.material_defs.type[:Seed], p.material_defs.idx[:Seed]]] = {}
            end
            type_list[[p.material_defs.type[:BasicMat], p.material_defs.idx[:BasicMat]]]['text'] = p.name + ' basic'
            # basic materials for plants always appear to use the :PLANT item type tag
            type_list[[p.material_defs.type[:BasicMat], p.material_defs.idx[:BasicMat]]]['type'] = :PLANT
            # item subtype of :PLANT types appears to always be -1, as there is no growth array entry for the :PLANT
            type_list[[p.material_defs.type[:BasicMat], p.material_defs.idx[:BasicMat]]]['subtype'] = -1
            type_list[[p.material_defs.type[:Drink], p.material_defs.idx[:Drink]]]['text'] = p.name + ' drink'
            # drink materials for plants always appear to use the :DRINK item type tag
            type_list[[p.material_defs.type[:Drink], p.material_defs.idx[:Drink]]]['type'] = :DRINK
            # item subtype of :DRINK types appears to always be -1, as there is no growth array entry for the :DRINK
            type_list[[p.material_defs.type[:Drink], p.material_defs.idx[:Drink]]]['subtype'] = -1
            type_list[[p.material_defs.type[:Seed], p.material_defs.idx[:Seed]]]['text'] = p.name + ' seed'
            # seed materials for plants always appear to use the :SEEDS item type tag
            type_list[[p.material_defs.type[:Seed], p.material_defs.idx[:Seed]]]['type'] = :SEEDS
            # item subtype of :SEEDS types appears to always be -1, as there is no growth array entry for the :SEEDS
            type_list[[p.material_defs.type[:Seed], p.material_defs.idx[:Seed]]]['subtype'] = -1
            p.growths.each_with_index do |g, r|
                m = df.decode_mat(g).material
                # Search only growths that are cookable (:EDIBLE_COOKED), and listed as :LEAF_MAT,
                # as that appears to be the tag required to allow cooking as a solid/non-liquid item in the kitchen
                if m.flags[:EDIBLE_COOKED] and m.flags[:LEAF_MAT]
                    # Sift through the materials array to find the matching entry for our growths array entry
                    p.material.each_with_index do |s, j|
                        if m.id == s.id
                            if not type_list[[j + DFHack::MaterialInfo::PLANT_BASE, i]]
                                type_list[[j + DFHack::MaterialInfo::PLANT_BASE, i]] = {}
                            end
                            type_list[[j + DFHack::MaterialInfo::PLANT_BASE, i]]['text'] = p.name + ' ' + m.id + ' growth'
                            # item type for plant materials listed in the growths array appear to always use the :PLANT_GROWTH item type tag
                            type_list[[j + DFHack::MaterialInfo::PLANT_BASE, i]]['type'] = :PLANT_GROWTH
                            # item subtype is equal to the array index of the cookable item in the growths table
                            type_list[[j + DFHack::MaterialInfo::PLANT_BASE, i]]['subtype'] = r
                        end
                    end
                end
            end
        end
        # cycle through all creatures
        df.world.raws.creatures.all.each_with_index do |c, i|
            c.material.each_with_index do |m, j|
                if m.reaction_product and m.reaction_product.id and m.reaction_product.id.include?('CHEESE_MAT')
                    if not type_list[[j + DFHack::MaterialInfo::CREATURE_BASE, i]]
                        type_list[[j + DFHack::MaterialInfo::CREATURE_BASE, i]] = {}
                    end
                    type_list[[j + DFHack::MaterialInfo::CREATURE_BASE, i]]['text'] = c.name[0] + ' milk'
                    # item type for milk appears to use the :LIQUID_MISC tag
                    type_list[[j + DFHack::MaterialInfo::CREATURE_BASE, i]]['type'] = :LIQUID_MISC
                    type_list[[j + DFHack::MaterialInfo::CREATURE_BASE, i]]['subtype'] = -1
                end
                if m.reaction_product and m.reaction_product.id and m.reaction_product.id.include?('SOAP_MAT')
                    if not type_list[[j + DFHack::MaterialInfo::CREATURE_BASE, i]]
                        type_list[[j + DFHack::MaterialInfo::CREATURE_BASE, i]] = {}
                    end
                    type_list[[j + DFHack::MaterialInfo::CREATURE_BASE, i]]['text'] = c.name[0] + ' tallow'
                    # item type for tallow appears to use the :GLOB tag
                    type_list[[j + DFHack::MaterialInfo::CREATURE_BASE, i]]['type'] = :GLOB
                    type_list[[j + DFHack::MaterialInfo::CREATURE_BASE, i]]['subtype'] = -1
                end
            end
        end
        already_banned.each_with_index do |b, i|
            # initialize our output string with the array entry position (largely stays the same for each item on successive runs, except when items are added/removed)
            output = i.inspect + ': '
            # initialize our key for accessing our stored items info
            key = [b[0][0], b[0][1]]
            # It shouldn't be possible for there to not be a matching key entry by this point, but we'll be kinda safe here
            if type_list[key]
                # Add the item name to the first part of the string
                output += '|' + type_list[key]['text'] + ' |type '
                if type_list[key]['type'] == b[0][2]
                    # item type expected vs. actual is a match, so we print that it's a match, as well as the item type
                    output += 'match: ' + type_list[key]['type'].inspect
                else
                    # Aw crap.  The item type we EXpected doesn't match up with the ACtual item type.
                    output += 'error: ex;' + type_list[key]['type'].inspect + '/ac;' + b[0][2].inspect
                end
                output += '|subtype '
                if type_list[key]['subtype'] == b[0][3]
                    # item sub type is a match, so we print that it's a match, as well as the item subtype index number (-1 means there is no subtype for this item)
                    output += 'match: ' + type_list[key]['subtype'].inspect
                else
                    # Something went wrong, and the EXpected item subtype index value doesn't match the ACtual index value
                    output += 'error: ex;' + type_list[key]['subtype'].inspect + '/ac;' + b[0][3].inspect
                end
            else
                # There's no entry for this item in our calculated list of cookable items.  So, it's not a plant, alcohol, tallow, or milk.  It's likely that it's a meat that has been banned.
                output += '|"' + key.inspect + ' unknown banned material type (meat?) " ' + '|item type: "' +  b[0][2].inspect + '"|item subtype: "' + b[0][3].inspect
            end
            puts output
        end
    else
        puts "ban-cooking booze  - bans cooking of drinks"
        puts "ban-cooking honey  - bans cooking of honey bee honey"
        puts "ban-cooking tallow - bans cooking of tallow"
        puts "ban-cooking milk   - bans cooking of creature liquids that can be turned into cheese"
        puts "ban-cooking oil    - bans cooking of oil"
        puts "ban-cooking seeds  - bans cooking of plants that have farmable seeds and that can be brewed into alcohol (eating raw plants to get seeds is rather slow)"
        puts "ban-cooking brew   - bans cooking of all plants (fruits too) that can be brewed into alcohol"
        puts "ban-cooking fruit  - bans cooking of only fruits that can be brewed into alcohol"
        puts "ban-cooking mill   - bans cooking of plants that can be milled into powder -- should any actually exist"
        puts "ban-cooking thread - bans cooking of plants that can be spun into thread -- should any actually exist"
        puts "ban-cooking show   - list known items that are banned in a pipe seperated format (if you ban meat(s) or fish(es) you'll get unknown listings!)"
    end
end
