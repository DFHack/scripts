-- event logic for the nestboxes
--@ module = true
local utils = require("utils")
local nestboxes_common = reqscript("internal/nestboxes/common")
local print_local = nestboxes_common.print_local
local print_details = nestboxes_common.print_details
local handle_error = nestboxes_common.handle_error
---------------------------------------------------------------------------------------------------
--ITEM_CREATED event handling functions
local function copy_egg_fields(source_egg, target_egg)
    print_details("start copy_egg_fields")
    target_egg.incubation_counter = source_egg.incubation_counter
    print_details("incubation_counter done")
    target_egg.egg_flags = utils.clone(source_egg.egg_flags, true)
    target_egg.hatchling_flags1 = utils.clone(source_egg.hatchling_flags1, true)
    target_egg.hatchling_flags2 = utils.clone(source_egg.hatchling_flags2, true)
    target_egg.hatchling_flags3 = utils.clone(source_egg.hatchling_flags3, true)
    target_egg.hatchling_flags4 = utils.clone(source_egg.hatchling_flags4, true)
    print_details("flags done")
    target_egg.hatchling_training_level = utils.clone(source_egg.hatchling_training_level, true)
    utils.assign(target_egg.hatchling_animal_population, source_egg.hatchling_animal_population)
    print_details("hatchling_animal_population done")
    target_egg.hatchling_mother_id = source_egg.hatchling_mother_id
    print_details("hatchling_mother_id done")
    target_egg.mother_hf = source_egg.mother_hf
    target_egg.father_hf = source_egg.mother_hf
    print_details("mother_hf father_hf done")
    target_egg.mothers_caste = source_egg.mothers_caste
    target_egg.fathers_caste = source_egg.fathers_caste
    print_details("mothers_caste fathers_caste done")
    target_egg.mothers_genes = source_egg.mothers_genes
    target_egg.fathers_genes = source_egg.fathers_genes
    print_details("mothers_genes fathers_genes done")
    target_egg.hatchling_civ_id = source_egg.hatchling_civ_id
    print_details("hatchling_civ_id done")
    print_details("end copy_egg_fields")
end
---------------------------------------------------------------------------------------------------
local function resize_egg_stack(egg_stack, new_stack_size)
    print_details("start resize_egg_stack")
    egg_stack.stack_size = new_stack_size
    --TODO check if weight or size need adjustment
    print_details("end resize_egg_stack")
end
---------------------------------------------------------------------------------------------------
local function create_new_egg_stack(original_eggs, new_stack_count)
    print_details("start create_new_egg_stack")
    print_details("about to split create new egg stack")
    print_details(("type= %s"):format(original_eggs:getType()))
    print_details(("creature= %s"):format(original_eggs.race))
    print_details(("caste= %s "):format(original_eggs.caste))
    print_details(("stack size for new eggs = %s "):format(new_stack_count))

    local created_items =
        dfhack.items.createItem(
        df.unit.find(original_eggs.hatchling_mother_id),
        original_eggs:getType(),
        -1,
        original_eggs.race,
        original_eggs.caste
    )
    print_details("created new egg stack")
    local created_egg_stack = created_items[0] or created_items[1]
    print_details(df.creature_raw.find(created_egg_stack.race).creature_id)
    print_details("about to copy fields from orginal eggs")
    copy_egg_fields(original_eggs, created_egg_stack)

    print_details("about to resize new egg stack")
    resize_egg_stack(created_egg_stack, new_stack_count)

    print_details("about to move new stack to nestbox")
    if dfhack.items.moveToBuilding(created_egg_stack, dfhack.items.getHolderBuilding(original_eggs)) then
        print_details("moved new egg stack to nestbox")
    else
        print_local("move of separated eggs to nestbox failed")
    end
    print_details("end create_new_egg_stack")
end
---------------------------------------------------------------------------------------------------
local function split_egg_stack(source_egg_stack, to_be_left_in_source_stack)
    print_details("start split_egg_stack")
    local egg_count_in_new_stack_size = source_egg_stack.stack_size - to_be_left_in_source_stack
    if egg_count_in_new_stack_size > 0 then
        create_new_egg_stack(source_egg_stack, egg_count_in_new_stack_size)
        resize_egg_stack(source_egg_stack, to_be_left_in_source_stack)
    else
        print_details("nothing to do, wrong egg_count_in_new_stack_size")
    end
    print_details("end split_egg_stack")
end
---------------------------------------------------------------------------------------------------
local function count_forbidden_eggs_for_race_in_claimed_nestobxes(race)
    print_details(("start count_forbidden_eggs_for_race_in_claimed_nestobxes"))
    local eggs_count = 0
    for _, nestbox in ipairs(df.global.world.buildings.other.NEST_BOX) do
        if nestbox.claimed_by ~= -1 then
            print_details(("Found claimed nextbox"))
            for _, nestbox_contained_item in ipairs(nestbox.contained_items) do
                if nestbox_contained_item.use_mode == df.building_item_role_type.TEMP then
                    print_details(("Found claimed nextbox containing items"))
                    if df.item_type.EGG == nestbox_contained_item.item:getType() then
                        print_details(("Found claimed nextbox containing items that are eggs"))
                        if nestbox_contained_item.item.egg_flags.fertile and nestbox_contained_item.item.flags.forbid then
                            print_details(("Eggs are fertile and forbidden"))
                            if nestbox_contained_item.item.race == race then
                                print_details(("Eggs belong to %s"):format(race))
                                print_details(
                                    ("eggs_count %s + new %s"):format(
                                        eggs_count,
                                        nestbox_contained_item.item.stack_size
                                    )
                                )
                                eggs_count = eggs_count + nestbox_contained_item.item.stack_size
                                print_details(("eggs_count after adding current nestbox %s "):format(eggs_count))
                            end
                        end
                    end
                end
            end
        end
    end
    print_details(("end count_forbidden_eggs_for_race_in_claimed_nestobxes"))
    return eggs_count
end
---------------------------------------------------------------------------------------------------
local function is_valid_animal(unit)
    return unit and dfhack.units.isActive(unit) and dfhack.units.isAnimal(unit) and dfhack.units.isFortControlled(unit) and
        dfhack.units.isTame(unit) and
        not dfhack.units.isDead(unit)
end
---------------------------------------------------------------------------------------------------
local function count_live_animals(race, count_children, count_adults)
    print_details(("start count_live_animals"))
    if count_adults then
        print_details(("we are counting adults for %s"):format(race))
    end
    if count_children then
        print_details(("we are counting children and babies for %s"):format(race))
    end

    local count = 0
    if not count_adults and not count_children then
        print_details(("end 1 count_live_animals"))
        return count
    end

    for _, unit in ipairs(df.global.world.units.active) do
        if
            race == unit.race and is_valid_animal(unit) and
                ((count_adults and dfhack.units.isAdult(unit)) or
                    (count_children and (dfhack.units.isChild(unit) or dfhack.units.isBaby(unit))))
         then
            count = count + 1
        end
    end
    print_details(("found %s life animals"):format(count))
    print_details(("end 2 count_live_animals"))
    return count
end
---------------------------------------------------------------------------------------------------
function validate_eggs(eggs)
    if not eggs.egg_flags.fertile then
        print_details("Newly laid eggs are not fertile, do nothing")
        return false
    end

    local should_be_nestbox = dfhack.items.getHolderBuilding(eggs)
    if should_be_nestbox ~= nil then
        for _, nestbox in ipairs(df.global.world.buildings.other.NEST_BOX) do
            if nestbox == should_be_nestbox then
                print_details("Found nestbox, continue with egg handling")
                return true
            end
        end
        print_details("Newly laid eggs are in building different than nestbox, we were to late")
        return false
    else
        print_details("Newly laid eggs are not in building, we were to late")
        return false
    end
    return true
end
---------------------------------------------------------------------------------------------------
function handle_eggs(eggs, race_config, split_stacks)
    print_details(("start handle_eggs"))

    local race = eggs.race
    local max_eggs = race_config[1]
    local count_children = race_config[2]
    local count_adults = race_config[3]
    local ignore = race_config[4]

    if ignore then
        print_details(("race is ignored, nothing to do here"))
        return
    end

    print_details(("max_eggs %s "):format(max_eggs))
    print_details(("count_children %s "):format(count_children))
    print_details(("count_adults %s "):format(count_adults))

    local current_eggs = eggs.stack_size

    local total_count = current_eggs
    total_count = total_count + count_forbidden_eggs_for_race_in_claimed_nestobxes(race)

    if total_count - current_eggs < max_eggs then
        print_details(
            ("Total count for %s only existing eggs is %s, about to count life animals if enabled"):format(
                race,
                total_count - current_eggs
            )
        )
        total_count = total_count + count_live_animals(race, count_children, count_adults)
    else
        print_details(
            ("Total count for %s eggs only is %s greater than maximum %s, no need to count life animals"):format(
                race,
                total_count,
                max_eggs
            )
        )
        print_details(("end 1 handle_eggs"))
        return
    end

    print_details(("Total count for %s eggs is %s"):format(race, total_count))

    if total_count - current_eggs < max_eggs then
        local egg_count_to_leave_in_source_stack = current_eggs
        if split_stacks and total_count > max_eggs then
            egg_count_to_leave_in_source_stack = max_eggs - total_count + current_eggs
            split_egg_stack(eggs, egg_count_to_leave_in_source_stack)
        end

        eggs.flags.forbid = true

        if eggs.flags.in_job then
            local job_ref = dfhack.items.getSpecificRef(eggs, df.specific_ref_type.JOB)
            if job_ref then
                print_details(("About to remove job related to egg(s)"))
                dfhack.job.removeJob(job_ref.data.job)
                eggs.flags.in_job = false
            end
        end
        print_local(
            ("Previously existing %s egg(s) is %s lower than maximum %s , forbidden %s egg(s) out of %s new"):format(
                race,
                total_count - current_eggs,
                max_eggs,
                egg_count_to_leave_in_source_stack,
                current_eggs
            )
        )
    else
        print_local(
            ("Total count for %s egg(s) is %s over maximum %s, newly laid egg(s) %s , no action taken."):format(
                race,
                total_count,
                max_eggs,
                current_eggs
            )
        )
    end
    print_details(("end 2 handle_eggs"))
end
---------------------------------------------------------------------------------------------------
