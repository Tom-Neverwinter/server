-----------------------------------
-- Area: Chocobo Circuit
--  NPC: Race Track Manager
-- Handles chocobo race results and rewards
-- !pos -72.238 -14.500 -95.318 70
-----------------------------------
local ID = zones[xi.zone.CHOCOBO_CIRCUIT]
-----------------------------------
---@type TNpcEntity
local entity = {}

entity.onTrade = function(player, npc, trade)
    -- No trades handled by this NPC
end

entity.onTrigger = function(player, npc)
    local hasRaceHistory = player:getLocalVar("raceHistoryAvailable") == 1
    
    if hasRaceHistory then
        -- Show race history menu
        player:startEvent(228)
    else
        -- Show general information
        player:startEvent(229)
    end
end

entity.onEventUpdate = function(player, csid, option, npc)
    if csid == 228 then
        -- Handle race history menu
        xi.chocoboRacing.showRaceResults(player, csid, option, npc)
    end
end

entity.onEventFinish = function(player, csid, option, npc)
    if csid == 228 then
        -- Process race rewards if selected
        if option == 1 then
            -- Give currency rewards
            local currencyReward = player:getLocalVar("raceRewardCurrency")
            if currencyReward > 0 then
                player:addCurrency("chocobuck", currencyReward)
                player:messageSpecial(ID.text.OBTAINED_CHOCOBUCKS, currencyReward)
                player:setLocalVar("raceRewardCurrency", 0)
            end
            
            -- Check for special items
            local itemReward = player:getLocalVar("raceRewardItem")
            if itemReward > 0 then
                -- Check inventory space
                if player:getFreeSlotsCount() >= 1 then
                    player:addItem(itemReward)
                    player:messageSpecial(ID.text.ITEM_OBTAINED, itemReward)
                    player:setLocalVar("raceRewardItem", 0)
                else
                    player:messageSpecial(ID.text.ITEM_CANNOT_BE_OBTAINED)
                end
            end
            
            -- Clear race history flag
            player:setLocalVar("raceHistoryAvailable", 0)
        end
    end
end

return entity 