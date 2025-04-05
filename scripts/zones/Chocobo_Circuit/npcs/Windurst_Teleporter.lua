-----------------------------------
-- Area: Chocobo Circuit
--  NPC: Gate: Chocobo Circuit
-- Teleports players to Windurst Woods
-- !pos -65.000 -8.000 -150.000 70
-----------------------------------
---@type TNpcEntity
local entity = {}

entity.onTrade = function(player, npc, trade)
end

entity.onTrigger = function(player, npc)
    -- Event ID 247 is the teleport event back to Windurst Woods
    player:startEvent(247)
end

entity.onEventUpdate = function(player, csid, option, npc)
end

entity.onEventFinish = function(player, csid, option, npc)
    if csid == 247 and option == 1 then
        -- Teleport player to Windurst Woods
        player:setPos(115.000, -6.699, -140.580, 0, 241) -- Windurst Woods coordinates from packet data
    end
end

return entity 