-- Fixes pets gifted to another unit in Adventure Mode
-- Fixes pets owned by companions missing from the companions list
local utils = require 'utils'

local function findPetOwnerOf(petNemesis)
    if petNemesis.figure then
        for _, link in ipairs(petNemesis.figure.histfig_links) do
            if link._type == df.histfig_hf_link_pet_ownerst then
                local target_hf = link.target_hf
                return df.nemesis_record.find(df.historical_figure.find(target_hf).nemesis_id)
            end
        end
    end
    return nil
end

local function findInParty(party, histfig_id)
    return utils.linear_index(party, histfig_id) ~= nil
end

local function fixMissingCompanionPets(nemesis)
    local party = df.global.adventure.interactions
    for _, nem_id in ipairs(nemesis.companions) do
        local pet_record = df.nemesis_record.find(nem_id)
        if findPetOwnerOf(pet_record) == nemesis and not findInParty(party.party_pets, pet_record.figure.id) then
            print("inserting pet "..pet_record.id.." of companion "..nemesis.id.." into the party!")
            party.party_pets:insert('#', pet_record.figure.id)
        end
    end
end


local function fixGiftedPet(pet_record, pet_owner_record)
    -- associate the unit relationships
    if pet_record.unit then
        pet_record.unit.relationship_ids.PetOwner = pet_owner_record.unit_id
        pet_record.unit.relationship_ids.GroupLeader = pet_owner_record.unit_id
        pet_record.group_leader_id = pet_owner_record.id
    end
    
    -- associate the site links
    local site_links = pet_owner_record.figure.site_links
    for _, link in ipairs(site_links) do
        if link._type == df.histfig_site_link_home_site_abstract_buildingst or
        link._type == df.histfig_site_link_home_site_realization_buildingst or
        link._type == df.histfig_site_link_lairst or
        link._type == df.histfig_site_link_home_site_realization_sulst or
        link._type == df.histfig_site_link_home_site_saved_civzones then
            -- Make a copy of the link
            local new_site_link = link:new()
            -- Insert that data into the pet's historical figure data
            pet_record.figure.site_links:insert('#', new_site_link)
        end
    end
end

local function adjustPetOwner(pet_owner_record, pet_record)
    local party = df.global.adventure.interactions
    local owner_in_party = findInParty(party.party_core_members, pet_owner_record.figure.id) or findInParty(party.party_extra_members, pet_owner_record.figure.id)
    if not owner_in_party then
        fixGiftedPet(pet_record, pet_owner_record)
        utils.erase_sorted(party.party_pets, pet_record.figure.id)
        return true
    else
        return false
    end
end

local function fixGiftedPets(nemesis)
    local queueCompanionErase = {}
    local party = df.global.adventure.interactions
    for _, nem_id in ipairs(nemesis.companions) do
        local companion_record = df.nemesis_record.find(nem_id)
        fixMissingCompanionPets(companion_record)

        if not findInParty(party.party_pets, companion_record.figure.id) then
            print("nemesis "..nem_id.." is present in nemesis record but not part of the adventurer's party, checking if it's a pet")
            local pet_owner_record = findPetOwnerOf(companion_record)
            if pet_owner_record then
                print("pet owner confirmed! Identified nemesis "..pet_owner_record.id.." as owner.")
                if adjustPetOwner(pet_owner_record, companion_record) then
                    print("the pet's owner is NOT a companion. We need to associate the pet with the owner correctly so the pet's unit is not inaccessible.")
                    queueCompanionErase[companion_record.id] = true
                else -- owner needed no adjusting, all that's missing is pet being attached to adventurer so fast travel pets work
                    print("the pet's owner is a companion! Added them to our adventurer party pets so they don't get lost in fast travel.")
                    party.party_pets:insert('#', companion_record.figure.id)
                end
            end
        end
    end

    for _, histfig_id in ipairs(party.party_pets) do
        local pet_figure = df.historical_figure.find(histfig_id)
        local pet_record = df.nemesis_record.find(pet_figure.nemesis_id)
        local pet_owner_record = findPetOwnerOf(pet_record)
        if pet_owner_record then
            print("pet owner confirmed! Identified nemesis "..pet_owner_record.id.." as owner.")
            adjustPetOwner(pet_owner_record, pet_record)
        end
    end

    for index = #nemesis.companions-1, 0, -1 do
        if queueCompanionErase[nemesis.companions[index]] then
            print("erasing bugged pet "..nemesis.companions[index].." from "..nemesis.id.."'s companions list")
            nemesis.companions:erase(index)
        end
    end
end

fixGiftedPets(df.nemesis_record.find(df.global.adventure.player_id))
