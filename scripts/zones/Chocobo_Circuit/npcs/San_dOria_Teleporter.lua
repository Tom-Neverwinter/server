-----------------------------------
-- Area: Chocobo Circuit
--  NPC: Gate: Chocobo Circuit
-- Teleports players to Southern San d'Oria
-- !pos -130.000 -8.000 -90.000 70
-----------------------------------
---@type TNpcEntity
local entity = {}

entity.onTrade = function(player, npc, trade)
end

entity.onTrigger = function(player, npc)
    -- Event ID 246 is the teleport event back to Southern San d'Oria
    player:startEvent(246)
end

entity.onEventUpdate = function(player, csid, option, npc)
end

entity.onEventFinish = function(player, csid, option, npc)
    if csid == 246 and option == 1 then
        -- Teleport player to Southern San d'Oria
        player:setPos(-30.670, 0.300, -84.000, 0, 230) -- Southern San d'Oria coordinates from packet data
    end
end

return entity 