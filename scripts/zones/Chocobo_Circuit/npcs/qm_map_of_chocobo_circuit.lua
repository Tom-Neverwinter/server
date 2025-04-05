-----------------------------------
-- Area: Chocobo Circuit
--  NPC: qm_map_of_chocobo_circuit (???)
-- Allows players to obtain the Map of the Chocobo Circuit
-- "Make your way to the center of the Chocobo Circuit, click ??? on central desk, choose to take a map."
-- !pos -330 -4 -400 70
-----------------------------------
local ID = zones[xi.zone.CHOCOBO_CIRCUIT]
-----------------------------------
---@type TNpcEntity
local entity = {}

entity.onTrade = function(player, npc, trade)
end

entity.onTrigger = function(player, npc)
    -- This is where the map is examined
    local hasMap = player:hasKeyItem(xi.ki.MAP_OF_THE_CHOCOBO_CIRCUIT)
    
    if hasMap then
        -- Show the map cutscene (csid 232)
        player:startEvent(232)
    else
        -- Give the player the map
        if npcUtil.giveKeyItem(player, xi.ki.MAP_OF_THE_CHOCOBO_CIRCUIT) then
            player:messageSpecial(ID.text.KEYITEM_OBTAINED, xi.ki.MAP_OF_THE_CHOCOBO_CIRCUIT)
        end
    end
end

entity.onEventUpdate = function(player, csid, option, npc)
    if csid == 232 then
        -- Get party members in the zone
        local partyMembers = {}
        local party = player:getAlliance()
        
        for i, member in ipairs(party) do
            if member:getZoneID() == player:getZoneID() then
                -- Get member position data
                local posX = member:getXPos()
                local posY = member:getYPos()
                local posZ = member:getZPos()
                
                -- Pack positions into update parameters
                -- We can only send 8 params, so we'll use them as follows:
                -- param1 = member1 ID
                -- param2 = member1 X position
                -- param3 = member1 Z position
                -- param4 = member2 ID
                -- param5 = member2 X position
                -- param6 = member2 Z position
                -- param7 = member3 ID
                -- param8 = member3 X position
                -- Due to packet limitations, we can only show 3 party members at once
                
                local slot = i - 1
                if slot < 3 then  -- Only handle first 3 party members
                    local param1Index = (slot * 3) + 1
                    partyMembers[param1Index] = member:getID()
                    partyMembers[param1Index + 1] = math.floor(posX * 10)  -- Scale position for better precision
                    partyMembers[param1Index + 2] = math.floor(posZ * 10)  -- Scale position for better precision
                end
            end
        end
        
        -- Send update with party member positions
        player:updateEvent(
            partyMembers[1] or 0,
            partyMembers[2] or 0,
            partyMembers[3] or 0,
            partyMembers[4] or 0,
            partyMembers[5] or 0,
            partyMembers[6] or 0,
            partyMembers[7] or 0,
            partyMembers[8] or 0
        )
    end
end

entity.onEventFinish = function(player, csid, option, npc)
    -- No special handling needed when closing the map
end

return entity 