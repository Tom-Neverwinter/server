-----------------------------------
-- ID: 6046
-- Item: Anemohelix Schema
-- Teaches the black magic Anemohelix
-----------------------------------
require("scripts/globals/spell_data")
-----------------------------------
local itemObject = {}

itemObject.onItemCheck = function(target)
    return target:canLearnSpell(xi.magic.spell.ANEMOHELIX)
end

itemObject.onItemUse = function(target)
    target:addSpell(xi.magic.spell.ANEMOHELIX)
end

return itemObject
