-----------------------------------
-- Area: Chocobo Circuit
--  NPC: Racing Registrar
-- Handles chocobo race registration
-- !pos -61.238 -14.500 -125.318 70
-----------------------------------
---@type TNpcEntity
local entity = {}

entity.onTrade = function(player, npc, trade)
    -- Handle trading of special items like chocobo training gear
    if trade:hasItemQty(xi.item.CHOCOBO_FEED, 1) and trade:getItemCount() == 1 then
        player:messageSpecial(ID.text.CHOCOBO_FEELING_GREAT)
        player:addLocalVar("chocoboBoost", 5) -- Give a small stat boost for the next race
        player:tradeComplete()
    end
end

entity.onTrigger = function(player, npc)
    -- Open the race registration menu
    player:startEvent(225) -- Race registration menu
end

entity.onEventUpdate = function(player, csid, option, npc)
    if csid == 225 then
        -- Handle race registration menu options
        xi.chocoboRacing.onEventUpdate(player, csid, option, npc)
    end
end

entity.onEventFinish = function(player, csid, option, npc)
    if csid == 225 then
        -- Process race registration based on selected options
        if option == 1 then -- C1 race registration
            player:setLocalVar("raceRegistered", 1)
            player:setLocalVar("raceCategory", 1)
            player:setLocalVar("raceStartTime", os.time() + 30) -- Race starts in 30 seconds
            
            -- Notify the player
            player:messageSpecial(ID.text.RACE_WILL_BEGIN_SOON, 30)
            
            -- Schedule race start
            xi.chocoboRacing.scheduleRaceStart(player, 1)
        elseif option == 2 then -- C2 race registration
            player:setLocalVar("raceRegistered", 1)
            player:setLocalVar("raceCategory", 2)
            player:setLocalVar("raceStartTime", os.time() + 30)
            
            player:messageSpecial(ID.text.RACE_WILL_BEGIN_SOON, 30)
            xi.chocoboRacing.scheduleRaceStart(player, 2)
        elseif option == 3 then -- C3 race registration
            player:setLocalVar("raceRegistered", 1)
            player:setLocalVar("raceCategory", 3)
            player:setLocalVar("raceStartTime", os.time() + 30)
            
            player:messageSpecial(ID.text.RACE_WILL_BEGIN_SOON, 30)
            xi.chocoboRacing.scheduleRaceStart(player, 3)
        elseif option == 4 then -- C4 race registration
            player:setLocalVar("raceRegistered", 1)
            player:setLocalVar("raceCategory", 4)
            player:setLocalVar("raceStartTime", os.time() + 30)
            
            player:messageSpecial(ID.text.RACE_WILL_BEGIN_SOON, 30)
            xi.chocoboRacing.scheduleRaceStart(player, 4)
        end
    end
end

return entity 