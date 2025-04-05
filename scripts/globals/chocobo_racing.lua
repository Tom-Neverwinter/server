-----------------------------------
-- Chocobo Racing System
-- 
-- Core implementation file for the chocobo racing system.
-- Includes circuit registration, race creation, AI control, and rewards.
-----------------------------------

-- Documentation for key packets used in chocobo racing system:
--
-- 0x05C - Race Progress Packet (Server → Client)
-- ----------------------------------------------
-- | Offset | Type   | Description                      |
-- |--------|--------|----------------------------------|
-- | 0x00   | uint8  | Packet ID (0x5C)                 |
-- | 0x01   | uint8  | Packet size (0x12)               |
-- | 0x02   | uint16 | Sequence ID                      |
-- | 0x04   | varies | Event-specific data              |
-- |        |        | Regular update: checkpoint ID     |
-- |        |        | Lap complete: 00 00 03 02        |
-- |        |        | Race complete: 64 10 16 16       |
-- |        |        | Race progress: 38 30 08 0B       |
-- | 0x0C   | uint32 | Current lap                      |
-- | 0x10   | uint32 | Total laps                       |
-- | 0x14   | uint32 | Chocobo ID                       |
-- | 0x20   | uint8  | Standard marker (0x80)           |
--
-- 0x05D - Race Competitors Packet (Server → Client)
-- ------------------------------------------------
-- | Offset | Type   | Description                      |
-- |--------|--------|----------------------------------|
-- | 0x00   | uint8  | Packet ID (0x5D)                 |
-- | 0x01   | uint8  | Packet size (0x34)               |
-- | 0x02   | uint16 | Sequence ID                      |
-- | 0x04   | uint32 | Race ID                          |
-- | 0x20+  | string | Chocobo names array (16b each)   |
--
-- 0x067 - Position Update Packet (Server → Client)
-- -----------------------------------------------
-- | Offset | Type   | Description                      |
-- |--------|--------|----------------------------------|
-- | 0x00   | uint8  | Packet ID (0x67)                 |
-- | 0x01   | uint8  | Packet size (0x0C or 0x14)       |
-- | 0x02   | uint16 | Sequence ID                      |
-- | 0x04   | uint8  | Type (0x03=Circuit, 0x02=Pos)    |
-- | 0x05+  | varies | Type-specific data               |
-- |        |        | Type 1: 05 C8 00 C8 60 04 01     |
-- |        |        | Type 2: 09 81 04 35 57 08 00     |
-- | 0x0C   | float  | X position (type 2 only)         |
-- | 0x10   | float  | Y position (type 2 only)         |
-- | 0x14   | float  | Z position (type 2 only)         |
-- | 0x1E   | uint8  | Animation state (0x63) (type 2)  |
-- | 0x1F   | uint8  | Movement flags (0x01) (type 2)   |
--
-- 0x069 - Race Status Packet (Server → Client)
-- -------------------------------------------
-- | Offset | Type   | Description                      |
-- |--------|--------|----------------------------------|
-- | 0x00   | uint8  | Packet ID (0x69)                 |
-- | 0x01   | uint8  | Packet size (0x64)               |
-- | 0x02   | uint16 | Sequence ID                      |
-- | 0x04   | uint8  | Mode (1-5)                       |
-- | 0x05   | uint8  | Submode                          |
-- | 0x06   | uint8  | Parameters flag                  |
-- | 0x07   | uint8  | Fixed value (0x01)               |
-- | 0x08+  | varies | Mode-specific data:              |
-- |        |        | Mode 1: Race initialization      |
-- |        |        | Mode 2: Chocobo attributes       |
-- |        |        | Mode 3: Race progress data       |
-- |        |        | Mode 4: Race results             |
-- |        |        | Mode 5: Weather effects          |
--
-- 0x0F4 - Animation Packet (Server → Client)
-- -----------------------------------------
-- | Offset | Type   | Description                      |
-- |--------|--------|----------------------------------|
-- | 0x00   | uint8  | Packet ID (0xF4)                 |
-- | 0x01   | uint8  | Packet size (0x0E)               |
-- | 0x02   | uint16 | Sequence ID                      |
-- | 0x04   | uint16 | Chocobo ID                       |
-- | 0x06   | uint8  | Fixed (0x00)                     |
-- | 0x07   | uint8  | Fixed (0x01)                     |
-- | 0x08   | uint8  | Animation type byte 1            |
-- | 0x09   | uint8  | Animation type byte 2            |
-- | 0x0A   | uint8  | Animation type byte 3            |
-- | 0x0B   | uint8  | Animation type byte 4            |
-- | 0x0C   | string | Chocobo name (12 bytes max)      |
--
-- 0x017 - Race Results Packet (Server → Client)
-- -------------------------------------------
-- Contains race results, finish times, and NPC messages

-- Update paths for required modules to match current LandSandBoat structure
require("scripts/enum/key_item") 
require("scripts/enum/item") 
require("scripts/globals/npc_util")
require("settings/default/main")
require("scripts/globals/utils")
require("scripts/enum/msg") 
require('scripts/globals/packet')
require('scripts/enum/weather') 
-- Remove this to break circular dependency
-- require('scripts/globals/chocobo_racing_names')
require("scripts/enum/status") 

-----------------------------------
xi = xi or {}
xi.chocoboRacing = xi.chocoboRacing or {}

-- Initialize active races table
xi.chocoboRacing.activeRaces = {}

-- FOR HEAVILY-IN-DEVELOPMET TESTING, you can force these setting:
-- TODO: When ready for release, publish these to main settings files.
xi.settings.main.ENABLE_CHOCOBO_RACING = false
xi.settings.main.DEBUG_CHOCOBO_RACING = false

-- Notes:
-- Since there is a timed element, packet elements, and a lot of data to fill in,
-- it makes sense to move pretty much everything apart from the CS handling down
-- into core. While developing, things can stay up here, but as this approaches
-- a stable state everything should be pushed down.

-- To Run:
-- !exec xi.chocoboRacing.startRace()

-----------------------------------
-- Racing Constants
-----------------------------------

-- Race Categories (used for registration and requirements)
xi.chocoboRacing.raceCategories = 
{
    C1 = 1,
    C2 = 2,
    C3 = 3,
    C4 = 4
}

-- Race Event IDs and Options (from packet analysis)
xi.chocoboRacing.events = 
{
    RACE_EVENT = 210,       -- Main race event ID
    SPECTATE_EVENT = 374,   -- Spectator mode event ID
    OPTIONS = 
    {
        INIT = 5,           -- Initialize race
        UPDATE = 274,       -- Update race status
        POSITION = 530,     -- Position update
        COMPLETE = 17       -- Race completion
    },
    PARAMS = 
    {
        INIT = 1,           -- Race initialization
        UPDATE_PROGRESS = {6, 8, 9, 11, 13}, -- Race progress updates
        POSITION_CHANGE = {67, 70, 73, 75},  -- Position changes
        LAP_COMPLETE = 10,  -- Lap completion
        RACE_COMPLETE = {66, 72}  -- Race completion
    }
}

-- Chocobo Colors (affects stats)
xi.chocoboRacing.chocoboColors = 
{
    YELLOW = 0, -- Balanced stats
    BLACK  = 2, -- Higher endurance, lower speed
    BLUE   = 4, -- Higher stamina, lower acceleration
    RED    = 6, -- Higher speed, lower control
    GREEN  = 8  -- Higher control, lower stamina
}

-- Weather Types for Racing
xi.chocoboRacing.weatherTypes = 
{
    CLEAR     = 0,  -- Normal conditions
    SUNSHINE  = 1,  -- Small speed bonus
    CLOUDY    = 2,  -- Small control penalty
    FOGGY     = 3,  -- Reduced visibility, harder to use items
    WINDY     = 4,  -- Random speed changes
    GLOOMY    = 5,  -- Reduced stamina recovery
    RAINY     = 6,  -- Reduced control, lower speed
    STORMY    = 7,  -- Severe control issues, stamina drains faster
    THUNDER   = 8,  -- Random stamina loss, speed bursts possible
    SANDSTORM = 9,  -- Reduced visibility, lower speed, stamina drains faster
    HEAT_WAVE = 10, -- Severe stamina drain
    SNOW      = 11  -- Reduced control, better speed
}

-- Weather effects on racing performance
xi.chocoboRacing.weatherEffects = 
{
    [xi.chocoboRacing.weatherTypes.CLEAR] = {
        speedMod = 1.0,
        controlMod = 1.0,
        staminaDrain = 1.0,
        description = "Clear conditions"
    },
    [xi.chocoboRacing.weatherTypes.SUNSHINE] = {
        speedMod = 1.05,
        controlMod = 1.0,
        staminaDrain = 1.1,
        description = "Sunny conditions grant a small speed bonus"
    },
    [xi.chocoboRacing.weatherTypes.CLOUDY] = {
        speedMod = 0.95,
        controlMod = 0.9,
        staminaDrain = 0.95,
        description = "Cloudy conditions reduce control slightly"
    },
    [xi.chocoboRacing.weatherTypes.FOGGY] = {
        speedMod = 0.9,
        controlMod = 0.85,
        staminaDrain = 1.0,
        description = "Foggy conditions reduce visibility and control"
    },
    [xi.chocoboRacing.weatherTypes.WINDY] = {
        speedMod = 1.0,
        controlMod = 0.8,
        staminaDrain = 1.1,
        description = "Windy conditions cause unpredictable speed changes"
    },
    [xi.chocoboRacing.weatherTypes.GLOOMY] = {
        speedMod = 0.95,
        controlMod = 0.9,
        staminaDrain = 1.2,
        description = "Gloomy conditions slow stamina recovery"
    },
    [xi.chocoboRacing.weatherTypes.RAINY] = {
        speedMod = 0.9,
        controlMod = 0.8,
        staminaDrain = 1.2,
        description = "Rainy conditions reduce control and speed"
    },
    [xi.chocoboRacing.weatherTypes.STORMY] = {
        speedMod = 0.85,
        controlMod = 0.7,
        staminaDrain = 1.3,
        description = "Stormy conditions severely impact control"
    },
    [xi.chocoboRacing.weatherTypes.THUNDER] = {
        speedMod = 0.9,
        controlMod = 0.75,
        staminaDrain = 1.25,
        description = "Thunder conditions cause random stamina loss with speed bursts"
    },
    [xi.chocoboRacing.weatherTypes.SANDSTORM] = {
        speedMod = 0.8,
        controlMod = 0.65,
        staminaDrain = 1.4,
        description = "Sandstorm conditions drastically reduce visibility and speed"
    },
    [xi.chocoboRacing.weatherTypes.HEAT_WAVE] = {
        speedMod = 0.85,
        controlMod = 0.8,
        staminaDrain = 1.5,
        description = "Heat wave conditions drain stamina rapidly"
    },
    [xi.chocoboRacing.weatherTypes.SNOW] = {
        speedMod = 0.85,
        controlMod = 0.9,
        staminaDrain = 1.1,
        description = "Snowy conditions reduce speed but improve control"
    }
}

-- Racing Items that can be used during races
xi.chocoboRacing.items = 
{
    STAMINA_APPLE   = 0x01, -- Restores stamina
    SPEED_APPLE     = 0x02, -- Temporary speed boost
    SHADOW_APPLE    = 0x03, -- Provides resistance to negative effects
    PEPPER_BISCUIT  = 0x04, -- Greatly reduces target's speed
    FIRE_BISCUIT    = 0x05, -- Greatly reduces target's stamina
    GYSAHL_BOMB     = 0x06, -- Area effect reducing speed
    SPORE_BOMB      = 0x07, -- Area effect reducing discernment (control)
    FAIRWEATHER_FETISH = 0x08, -- Improves weather conditions
    FOULWEATHER_FROG = 0x09, -- Worsens weather conditions
}

-- Racing Equipment (affects chocobo stats)
xi.chocoboRacing.equipment = 
{
    -- Saddles (affects control and speed)
    SADDLES = 
    {
        -- Generic saddle types (simplified model)
        BASIC_SADDLE    = 0x01, -- No bonuses
        JOCKEY_SADDLE   = 0x02, -- Better control
        RACING_SADDLE   = 0x03, -- Better speed
        CUSTOM_SADDLE   = 0x04, -- Balanced bonuses
        TRAINER_SADDLE  = 0x05, -- Better stamina
        
        -- Detailed retail saddles (mapped to generic types)
        -- Tier 1 saddles (basic)
        LAUAN_SADDLE = { id = 0x10, type = 0x01, tier = 1, nation = 0, description = "A standard model, stabilizes stride" },
        BRASS_SADDLE = { id = 0x11, type = 0x03, tier = 1, nation = 0, description = "Hefty, taxing on endurance but increases strength" },
        GRASS_SADDLE = { id = 0x12, type = 0x02, tier = 1, nation = 0, description = "Lightweight, improves performance but requires discernment" },
        RABBIT_HIDE_SADDLE = { id = 0x13, type = 0x05, tier = 1, nation = 0, description = "Improves performance but requires receptivity" },
        
        -- Tier 2 saddles (improved)
        ASH_SADDLE = { id = 0x20, type = 0x01, tier = 2, nation = 0, description = "A standard model, stabilizes stride and increases endurance" },
        SILVER_SADDLE = { id = 0x21, type = 0x03, tier = 2, nation = 0, description = "Hefty, taxing on endurance but increases strength" },
        COTTON_SADDLE = { id = 0x22, type = 0x02, tier = 2, nation = 0, description = "Lightweight, improves performance but requires discernment" },
        SHEEP_LEATHER_SADDLE = { id = 0x23, type = 0x05, tier = 2, nation = 0, description = "Improves performance but requires receptivity" },
        
        -- Tier 3 saddles (nation-specific, first-place only)
        ELM_SADDLE = { id = 0x30, type = 0x01, tier = 3, nation = 1, description = "First-place San d'Oria, stabilizes stride and increases endurance" },
        MYTHRIL_SADDLE = { id = 0x31, type = 0x03, tier = 3, nation = 2, description = "First-place Bastok, taxing on endurance but increases strength" },
        LINEN_SADDLE = { id = 0x32, type = 0x02, tier = 3, nation = 3, description = "First-place Windurst, improves performance but requires discernment" },
        BUFFALO_LEATHER_SADDLE = { id = 0x33, type = 0x05, tier = 3, nation = 0, description = "Nation-specific, improves performance but requires receptivity" }
    },
    
    -- Race Silks (provide stat bonuses)
    SILKS = 
    {
        RED_RACE_SILKS    = 0x01, -- Improves endurance by 1 rank (4 minutes)
        BLUE_RACE_SILKS   = 0x02, -- Improves control by 1 rank
        PURPLE_RACE_SILKS = 0x03, -- Improves speed by 1 rank (2.5%)
        GREEN_RACE_SILKS  = 0x04, -- Improves stamina by 1 rank
        BLACK_RACE_SILKS  = 0x05, -- Improves item effect by 1 rank
        GOLD_RACE_SILKS   = 0x06  -- Slight improvement to all stats
    },
    
    -- Racing Harnesses (affects chocobo attribute balance)
    HARNESSES = 
    {
        LIGHTWEIGHT_HARNESS = 0x01, -- Better acceleration
        BALANCED_HARNESS    = 0x02, -- Balanced attributes
        HEAVY_HARNESS       = 0x03, -- Better control, worse acceleration
        TRAINING_HARNESS    = 0x04  -- Better stamina, worse speed
    },
    
    -- Additional Racing Equipment (consumable buffs)
    -- These are items mentioned in retail descriptions
    ACCESSORIES = 
    {
        CHOCOBO_TAPING = { 
            id = 0x01, 
            description = "Slightly increases the strength of a chocobo", 
            effect = { stat = "strength", amount = 5 } 
        },
        CHOCOBO_BLINKERS = { 
            id = 0x02, 
            description = "Slightly increases the stamina of a chocobo", 
            effect = { stat = "stamina", amount = 5 } 
        },
        SHADOW_ROLL = { 
            id = 0x03, 
            description = "Slightly increases the discernment of a chocobo", 
            effect = { stat = "discernment", amount = 5 } 
        },
        CHOCOBO_HOOD = { 
            id = 0x04, 
            description = "Slightly increases the receptivity of a chocobo", 
            effect = { stat = "receptivity", amount = 5 } 
        }
    }
}

-- Racing Abilities that chocobos can learn
xi.chocoboRacing.abilities = 
{
    GALLOP       = 0x01, -- Increases speed by 1 rank (2.5%)
    CANTER       = 0x02, -- Increases endurance by 1 rank (4 minutes)
    BURROW       = 0x03, -- Can find special items while digging
    BORE         = 0x04, -- Can find rare items while digging
    DODGE        = 0x05, -- Chance to avoid item effects
    BREATHE      = 0x06, -- Regenerates stamina
    TREASURE     = 0x07, -- Increased chance of finding race items
    REGEN        = 0x08, -- Slowly regenerates health during race
    FOCUS        = 0x09, -- Better control in bad weather
    STAMINA      = 0x0A, -- Reduced stamina loss
    SPUR         = 0x0B, -- Short burst of high speed (active ability)
    STRIDER      = 0x0C, -- Better performance on certain track types
    ITEM_FINDER  = 0x0D  -- More likely to find items during race
}

-- Betting Information
xi.chocoboRacing.betting = 
{
    WIN      = 1, -- Chocobo must finish first
    PLACE    = 2, -- Chocobo must finish first or second
    SHOW     = 3, -- Chocobo must finish first, second, or third
    QUINELLA = 4, -- Predict first and second place finishers in any order
    EXACTA   = 5  -- Predict first and second place finishers in correct order
}

-- Race Track Types - Affects race characteristics and chocobo performance
xi.chocoboRacing.trackTypes = 
{
    STRAIGHT  = 1, -- Emphasis on speed and acceleration
    TECHNICAL = 2, -- Emphasis on control and cornering
    OVAL      = 3, -- Balanced track type
    ENDURANCE = 4  -- Emphasis on stamina management
}

-- Race NPC message IDs (from packet analysis)
xi.chocoboRacing.npcMessages = 
{
    RACE_START       = 9205, -- Race start announcement
    RACE_COUNTDOWN   = 9302, -- Countdown to race start
    LAP_COMPLETE     = 9304, -- Lap completion
    RACE_LEADER      = 9305, -- Race leader announcement
    POSITION_UPDATE  = 9306, -- Position update
    RACE_PROGRESS    = 9307, -- Race progress update
    RACE_FINISH      = 9308, -- Race finish
    WINNER_ANNOUNCE  = 9309, -- Winner announcement
    CROWD_CHEER      = 9201, -- Crowd cheer
    PRIZE_ANNOUNCE   = 9310, -- Prize announcement
    CLOSING          = 9311, -- Race closing
    
    -- Commentary messages
    COMMENTARY_SIGISWALD_1 = 9657, -- Sigiswald commentary
    COMMENTARY_SIGISWALD_2 = 9658, -- Sigiswald commentary
    COMMENTARY_PHEMILLE_1  = 9707, -- Phemille commentary
    COMMENTARY_PHEMILLE_2  = 9708  -- Phemille commentary
}

-- Item appearance rates during races
xi.chocoboRacing.itemRates = 
{
    -- Base appearance rates (out of 100)
    STAMINA_APPLE   = 30,
    SPEED_APPLE     = 20,
    SHADOW_APPLE    = 15,
    PEPPER_BISCUIT  = 10,
    FIRE_BISCUIT    = 10,
    GYSAHL_BOMB     = 7,
    SPORE_BOMB      = 5,
    FAIRWEATHER_FETISH = 2,
    FOULWEATHER_FROG = 1
}

-- Circuit Information (based on packet data)
xi.chocoboRacing.circuits = 
{
    -- Each circuit has segments with their own properties
    C1 = {
        NAME = "Crystal Stakes", -- C1 races
        SEGMENTS = 10,
        LAPS = 3,
        DIFFICULTY = 4,
        -- Segment parameters define circuit checkpoints and position markers
        -- Derived from retail packet analysis
        SEGMENT_PARAMS = {0x0C, 0x18, 0x24, 0x30, 0x3C, 0x48, 0x54, 0x60, 0x6C, 0x78},
        -- Performance attributes
        BASE_SPEED = 1.2,
        ITEM_FREQUENCY = 60, -- % chance to find items per segment
        WEATHER_CHANCE = 40  -- % chance of weather changes
    },
    C2 = {
        NAME = "San d'Oria Cup", -- C2 races
        SEGMENTS = 8,
        LAPS = 2,
        DIFFICULTY = 3,
        SEGMENT_PARAMS = {0x0C, 0x18, 0x24, 0x30, 0x3C, 0x48, 0x54, 0x60},
        BASE_SPEED = 1.1,
        ITEM_FREQUENCY = 50,
        WEATHER_CHANCE = 30
    },
    C3 = {
        NAME = "Bastok Cup", -- C3 races
        SEGMENTS = 8,
        LAPS = 2,
        DIFFICULTY = 2,
        SEGMENT_PARAMS = {0x0C, 0x18, 0x24, 0x30, 0x3C, 0x48, 0x54, 0x60},
        BASE_SPEED = 1.0,
        ITEM_FREQUENCY = 40,
        WEATHER_CHANCE = 20
    },
    C4 = {
        NAME = "Windurst Cup", -- C4 races (beginner)
        SEGMENTS = 6,
        LAPS = 2,
        DIFFICULTY = 1,
        SEGMENT_PARAMS = {0x0C, 0x18, 0x24, 0x30, 0x3C, 0x48},
        BASE_SPEED = 0.9,
        ITEM_FREQUENCY = 30,
        WEATHER_CHANCE = 10
    }
}

-- Get the weather for a race - independently from zone weather
-- Weather affects racing performance and can change during races
-- Consolidating previous getRaceWeather function with better implementation
xi.chocoboRacing.getRaceWeather = function(weatherChance)
    -- Default to clear weather
    local weatherType = xi.chocoboRacing.weatherTypes.CLEAR
    
    -- Check for weather change based on passed chance (default 10%)
    weatherChance = weatherChance or 10
    
    if math.random(1, 100) <= weatherChance then
        -- Random selection of weather types
        local weatherOptions = {
            xi.chocoboRacing.weatherTypes.CLEAR,
            xi.chocoboRacing.weatherTypes.SUNSHINE,
            xi.chocoboRacing.weatherTypes.CLOUDY,
            xi.chocoboRacing.weatherTypes.FOGGY,
            xi.chocoboRacing.weatherTypes.WINDY,
            xi.chocoboRacing.weatherTypes.RAINY
        }
        
        -- More extreme weather appears in tougher races
        if weatherChance >= 30 then
            table.insert(weatherOptions, xi.chocoboRacing.weatherTypes.STORMY)
            table.insert(weatherOptions, xi.chocoboRacing.weatherTypes.THUNDER)
        end
        
        if weatherChance >= 40 then
            table.insert(weatherOptions, xi.chocoboRacing.weatherTypes.GLOOMY)
            table.insert(weatherOptions, xi.chocoboRacing.weatherTypes.SANDSTORM)
        end
        
        if weatherChance >= 50 then
            table.insert(weatherOptions, xi.chocoboRacing.weatherTypes.HEAT_WAVE)
            table.insert(weatherOptions, xi.chocoboRacing.weatherTypes.SNOW)
        end
        
        weatherType = weatherOptions[math.random(1, #weatherOptions)]
    end
    
    return weatherType
end

-- Racing Items Implementation (corrected to match retail)
xi.chocoboRacing.itemEffects = 
{
    [xi.chocoboRacing.items.STAMINA_APPLE] = function(chocobo)
        -- Regenerates stamina
        return {staminaRestore = 30}
    end,
    
    [xi.chocoboRacing.items.SPEED_APPLE] = function(chocobo)
        -- Temporary speed boost
        return {speedBoost = 20, duration = 10}
    end,
    
    [xi.chocoboRacing.items.SHADOW_APPLE] = function(chocobo)
        -- Provides resistance to negative effects
        return {itemResistance = true, duration = 15}
    end,
    
    [xi.chocoboRacing.items.PEPPER_BISCUIT] = function(chocobo, target)
        -- Greatly reduces target's speed
        return {targetEffect = true, speedPenalty = 40, duration = 8}
    end,
    
    [xi.chocoboRacing.items.FIRE_BISCUIT] = function(chocobo, target)
        -- Greatly reduces target's stamina
        return {targetEffect = true, staminaDrain = 40, duration = 5}
    end,
    
    [xi.chocoboRacing.items.GYSAHL_BOMB] = function(chocobo)
        -- Area effect reducing speed
        return {areaEffect = true, speedPenalty = 25, range = 3, duration = 6}
    end,
    
    [xi.chocoboRacing.items.SPORE_BOMB] = function(chocobo)
        -- Area effect reducing discernment (control)
        return {areaEffect = true, controlPenalty = 30, range = 3, duration = 7}
    end,
    
    [xi.chocoboRacing.items.FAIRWEATHER_FETISH] = function(chocobo)
        -- Improves weather conditions
        return {weatherEffect = true, weatherImprove = true, duration = 12}
    end,
    
    [xi.chocoboRacing.items.FOULWEATHER_FROG] = function(chocobo)
        -- Worsens weather conditions
        return {weatherEffect = true, weatherWorsen = true, duration = 12}
    end
}

-- Dream Race item effects (special items not normally available to players)
xi.chocoboRacing.dreamItemEffects = 
{
    DREAM_APPLE = {
        id = 0xA1, 
        description = "Used by Sakura during the Dream Race to temporarily increase speed, stamina, and resistance",
        effects = {
            speedBoost = 25, 
            staminaRestore = 40,
            itemResistance = true,
            duration = 20
        }
    },
    
    DREAM_CRACKER = {
        id = 0xA2,
        description = "Used by Kayaki during the Dream Race to temporarily reduce the speed and stamina of all chocobos except Sakura and Kayaki",
        effects = {
            areaEffect = true,
            speedPenalty = 35,
            staminaDrain = 25,
            duration = 15,
            excludeNpcs = {"Sakura", "Kayaki"}
        }
    }
}

-- Debug logging function
local debug = function(player, ...)
    if xi.settings.main.DEBUG_CHOCOBO_RACING then
        local t = { ... }
        print(unpack(t))
        player:printToPlayer(table.concat(t, ' '), xi.msg.channel.SYSTEM_3, '')
    end
end

-- Generate and send the 0x069 packet for race data
local sendRacePacket = function(player, mode, raceData)
    local packet = {}
    
    -- Packet Header - ID 0x069
    packet[1] = 0x69
    packet[2] = 0x00
    packet[3] = mode  -- Mode determines packet structure
    packet[4] = 0x00
    
    -- Add race data based on mode
    if mode == 1 then -- Race Parameters
        packet[5] = 0x08
        packet[6] = 0x01
        packet[7] = raceData.category or 0x00
        packet[8] = raceData.raceID or 0x00
        
        -- Weather and conditions
        packet[9] = 0x00
        packet[10] = 0x00
        packet[11] = 0x00
        packet[12] = 0x00
        
        -- Standard parameters
        packet[13] = 0x00
        packet[14] = 0x00
        packet[15] = 0x80
        
    elseif mode == 2 then -- Chocobo Parameters
        packet[5] = 0x60
        packet[6] = 0x00
        
        -- Add chocobo data for up to 8 chocobos
            local races = { 0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7 }
        local colors = { 0x0, 0x2, 0x4, 0x6, 0x8 }
        local equipment = { 0x1, 0x2, 0x3, 0x4 }
        
        for i, offset in ipairs({ 0x0C, 0x18, 0x24, 0x30, 0x3C, 0x48, 0x54, 0x60 }) do
            local chocobo = raceData.chocobos and raceData.chocobos[i] or nil
            
            -- Use provided data or generate random stats if not available
            local race = chocobo and chocobo.race or utils.randomEntry(races)
            local color = chocobo and chocobo.color or utils.randomEntry(colors)
            local equip = chocobo and chocobo.equipment or utils.randomEntry(equipment)
            
            -- Standard values from packet analysis
                packet[offset + 0 + 1] = 0x0E
                packet[offset + 1 + 1] = 0x0C
                packet[offset + 2 + 1] = 0x60
                packet[offset + 3 + 1] = 0x80
                packet[offset + 4 + 1] = 0x00
                packet[offset + 5 + 1] = 0x00
                packet[offset + 6 + 1] = 0x08
                packet[offset + 7 + 1] = bit.lshift(race, 4) + color
                packet[offset + 8 + 1] = 0x41
                packet[offset + 9 + 1] = 0x00
                packet[offset + 10 + 1] = 0x00
                packet[offset + 11 + 1] = 0x00
            packet[offset + 12 + 1] = equip
        end
        
    elseif mode == 3 then -- Section Parameters
        -- Packet structure for section data
        packet[5] = 0xC0
        packet[6] = 0x00
        
        -- Circuit segments - derived from packet analysis
        local segments = xi.chocoboRacing.circuits[raceData.category or "C1"].SEGMENT_PARAMS
        
        -- Fill section data with appropriate parameters
        for i = 1, 192 do
            packet[i + 6] = 0x00
        end
        
        -- Populate specific segment markers
        for i, segment in ipairs(segments) do
            packet[segment + 7] = 0x80 + i
        end
    
    elseif mode == 4 then -- Result Parameters
        packet[5] = 0x04
        packet[6] = 0x00
        
        -- Race result ID and parameters
        packet[7] = raceData.resultID or 0x34
        packet[8] = raceData.resultParam or 0x16
        
        -- Fill remaining data
        for i = 9, 200 do
            packet[i] = 0x00
        end
        
    elseif mode == 5 then -- System Ready Flag
        packet[5] = 0x00
        packet[6] = 0x00
        
        -- Final parameters
        packet[7] = 0x65
        packet[8] = 0x00
        
        -- Fill remaining data
        for i = 9, 200 do
            packet[i] = 0x00
        end
    end
    
    -- Pad packet to full length
    for i = #packet + 1, 200 do
        packet[i] = 0x00
    end
    
    -- Send packet to player
    player:queuePacket(packet)
end

-- Generate race progress update events
local sendRaceProgressUpdate = function(player, raceData, eventParam)
    -- Construct and send 0x05C packet
    local packet = {}
    
    -- Packet header - ID 0x05C
    packet[1] = 0x5C
    packet[2] = 0x12
    
    -- Sync ID
    packet[3] = 0x00
    packet[4] = 0x00
    
    -- Event parameter - determines update type
    packet[5] = eventParam
    
    -- Fill with zeros
    for i = 6, 22 do
        packet[i] = 0x00
    end
    
    -- Event-specific data
    if utils.contains(xi.chocoboRacing.events.PARAMS.RACE_COMPLETE, eventParam) then
        -- Race completion parameters
        packet[9] = raceData.finishTime or 0x00
        packet[10] = 0x00
    elseif utils.contains(xi.chocoboRacing.events.PARAMS.POSITION_CHANGE, eventParam) then
        -- Position change parameters
        packet[9] = 0x07 -- Player position data
        packet[10] = 0x00
    elseif eventParam == xi.chocoboRacing.events.PARAMS.LAP_COMPLETE then
        -- Lap completion parameters
        packet[9] = raceData.currentLap or 0x01
        packet[10] = 0x00
    end
    
    -- Send packet to player
    player:queuePacket(packet)
end

-- Send appropriate NPC messages for race events
local sendRaceMessage = function(player, messageID, npcID)
    -- Default NPC IDs for racing circuit
    npcID = npcID or 17064035 -- Default announcer NPC
    
    -- Send chat message from NPC
    player:chatMessage(npcID, messageID)
end

-- Generate a random race results
local generateRaceResults = function(raceData)
    local results = {}
    local positions = {1, 2, 3, 4, 5, 6, 7, 8}
    
    -- Weighted selection based on chocobo attributes
    for i = 1, 8 do
        local totalWeight = 0
        local weights = {}
        
        for j, pos in ipairs(positions) do
            local weight = 100
            local chocobo = raceData.chocobos[pos]
            
            -- Better stats give better chance of being selected earlier
            if chocobo then
                weight = weight + (chocobo.attributes.speed * 2)
                weight = weight + chocobo.attributes.stamina
                weight = weight + chocobo.attributes.endurance
                weight = weight + (chocobo.attributes.intelligence / 2)
                
                -- Apply weather effects
                if raceData.weather then
                    local weatherEffect = xi.chocoboRacing.weatherEffects[raceData.weather]
                    if weatherEffect then
                        weight = weight * weatherEffect.speedMod
                    end
                end
                
                -- Adjust for abilities
                if chocobo.abilities then
                    for _, ability in pairs(chocobo.abilities) do
                        if ability == xi.chocoboRacing.abilities.GALLOP then
                            weight = weight * 1.1
                        elseif ability == xi.chocoboRacing.abilities.CANTER then
                            weight = weight * 1.05
                        end
                    end
                end
            end
            
            weights[j] = weight
            totalWeight = totalWeight + weight
        end
        
        -- Select chocobo for this position
        local roll = math.random() * totalWeight
        local cumulative = 0
        local selectedIdx = 1
        
        for j, weight in ipairs(weights) do
            cumulative = cumulative + weight
            if roll <= cumulative then
                selectedIdx = j
                break
            end
        end

        -- Add to results and remove from positions
        table.insert(results, positions[selectedIdx])
        table.remove(positions, selectedIdx)
    end
    
    return results
end

-- Timer for race updates
local setTimer = function(player, npcId)
    player:timer(400, function(playerArg)
        playerArg:sendEmptyEntityUpdateToPlayer(GetNPCByID(npcId))
        setTimer(playerArg, npcId)
    end)
end

-- Handle player interaction with race NPCs
xi.chocoboRacing.onRacingNPCTrigger = function(player, npc)
    local npcID = npc:getID()
    
    -- Different handlers based on NPC
    if npcID == 17064120 then -- Sigiswald - Registration NPC
        player:startEvent(362, 1, 4, 10, 60920, 3700, 1017344, 680546492, 662703750)
    elseif npcID == 17064124 then -- Maik - Spectator NPC
        player:startEvent(374, 1, 2, 100, 58496, 0, 0, 0, 4)
    elseif npcID == 17064125 then -- Phemille - Betting NPC
        player:startEvent(377, 1, 4, 100, 85663, 0, 0, 0, 0)
    else
        -- Generic handling for other race-related NPCs
        player:startEvent(210)
    end
end

-- Enhanced Race Configuration and Circuit Details
xi.chocoboRacing.circuitConfig = 
{
    -- Standard Race Configurations
    [xi.chocoboRacing.raceCategories.C1] = {
        name = "Novice Cup",
        fee = 100,
        laps = 1,
        minRank = 0,
        maxRank = 2,
        segmentCount = 8,
        itemFrequency = 30, -- % chance to find items
        npcDifficulty = 0.8, -- NPC skill factor
        baseSpeed = 0.9,
        messageID = 9280,
        weatherChance = 10, -- % chance for weather changes
    },
    
    [xi.chocoboRacing.raceCategories.C2] = {
        name = "Intermediate Cup",
        fee = 200,
        laps = 1,
        minRank = 1,
        maxRank = 3,
        segmentCount = 8,
        itemFrequency = 40,
        npcDifficulty = 0.9,
        baseSpeed = 1.0,
        messageID = 9281,
        weatherChance = 20,
    },
    
    [xi.chocoboRacing.raceCategories.C3] = {
        name = "Advanced Cup",
        fee = 300,
        laps = 1,
        minRank = 2,
        maxRank = 4,
        segmentCount = 8,
        itemFrequency = 50,
        npcDifficulty = 1.0,
        baseSpeed = 1.1,
        messageID = 9282,
        weatherChance = 30,
    },
    
    [xi.chocoboRacing.raceCategories.C4] = {
        name = "Expert Cup",
        fee = 500,
        laps = 1,
        minRank = 3,
        maxRank = 5,
        segmentCount = 8,
        itemFrequency = 60,
        npcDifficulty = 1.1,
        baseSpeed = 1.2,
        messageID = 9283,
        weatherChance = 40,
    },
    
    -- Special Hidden Multi-Lap Race Configuration (not advertised in-game)
    -- Access via GM command: !exec xi.chocoboRacing.startSpecialRace(player, laps)
    [99] = {
        name = "Mythril Cup", -- Hidden special race
        fee = 1000,
        laps = 3, -- Multi-lap race!
        minRank = 0, -- Available to all
        maxRank = 10,
        segmentCount = 8,
        itemFrequency = 70,
        npcDifficulty = 1.0,
        baseSpeed = 1.1,
        messageID = 9283, -- Reusing expert cup message
        weatherChance = 60, -- Frequent weather changes for extra challenge
    },
}

-- Race Data Structure (storing active races)
xi.chocoboRacing.activeRaces = xi.chocoboRacing.activeRaces or {}

-- Enhanced Race Packet Generation
xi.chocoboRacing.generateRacePacket = function(player, mode, raceData)
    -- Call the local sendRacePacket function with the provided parameters
    sendRacePacket(player, mode, raceData)
end

xi.chocoboRacing.generateRacePackets = function(player, raceData)
    -- Race category determines parameters
    local category = raceData.category or xi.chocoboRacing.raceCategories.C1
    local config = xi.chocoboRacing.circuitConfig[category]
    
    -- Mode 1: Racing Parameters
    local mode1Data = {
        category = category,
        weatherType = raceData.weatherType or xi.chocoboRacing.weatherTypes.CLEAR,
        laps = config.laps,
    }
    xi.chocoboRacing.generateRacePacket(player, 1, mode1Data)
    
    -- Mode 2: Chocobo Parameters
    local mode2Data = {
        chocobos = raceData.chocobos or {}
    }
    xi.chocoboRacing.generateRacePacket(player, 2, mode2Data)
    
    -- Mode 3: Section Parameters
    local mode3Data = {
        category = category,
        segmentCount = config.segmentCount
    }
    xi.chocoboRacing.generateRacePacket(player, 3, mode3Data)
    
    -- Mode 5: System Ready
    xi.chocoboRacing.generateRacePacket(player, 5, {})
    
    return true
end

-- Start a Race
xi.chocoboRacing.startRace = function(player, category)
    -- Default to C1 if not specified
    category = category or xi.chocoboRacing.raceCategories.C1
    
    -- Get race configuration
    local config = xi.chocoboRacing.circuitConfig[category]
    if not config then
    return false
end

    -- Generate a unique race ID
    local raceId = os.time() + player:getID()
    player:setLocalVar("raceId", raceId)
    player:setLocalVar("raceActive", 1)
    player:setLocalVar("raceCategory", category)
    player:setLocalVar("raceLaps", config.laps)
    
    -- Initialize race data
    xi.chocoboRacing.activeRaces[raceId] = {
        id = raceId,
        category = category,
        startTime = os.time(),
        chocobos = {},
        weather = xi.chocoboRacing.getRaceWeather(config.weatherChance),
        finished = false,
        lapCount = config.laps,
        currentLap = 0,
        segmentCount = config.segmentCount,
        participants = {}
    }
    
    -- Add player to race participants
    table.insert(xi.chocoboRacing.activeRaces[raceId].participants, player:getID())
    
    -- Setup player chocobo
    local playerEntityId = 0x400 + (player:getID() % 256)
    player:setLocalVar("raceEntityId", playerEntityId)
    
    -- Get player chocobo stats
    local chocoboName = player:getLocalVar("chocoboName") or "Player's Chocobo"
    local chocoboAttrs = {
        speed = player:getLocalVar("chocoboSpeed") or (30 + math.random(0, 10)),
        stamina = player:getLocalVar("chocoboStamina") or (30 + math.random(0, 10)),
        endurance = player:getLocalVar("chocoboEndurance") or (30 + math.random(0, 10)),
        intelligence = player:getLocalVar("chocoboIntelligence") or (30 + math.random(0, 10))
    }
    
    -- Add player chocobo to race
    xi.chocoboRacing.activeRaces[raceId].chocobos[playerEntityId] = {
        id = playerEntityId,
        owner = player:getName(),
        name = chocoboName,
        isPlayer = true,
        attributes = chocoboAttrs,
        currentLap = 0,
        currentSegment = 0,
        position = 1,
        finished = false,
        finishTime = 0,
        items = {},
        effects = {}
    }
    
    -- Create NPC chocobos based on difficulty
    for i = 1, 7 do
        local npcEntityId = 0x410 + i
        
        -- Get random name and jockey from the names module
        local chocoboNames = xi.chocoboRacing.names.getRandomChocoboNames(7, category)
        local jockeyInfo = xi.chocoboRacing.names.getRandomJockeyName(category)
        local jockeyName = jockeyInfo and jockeyInfo[1] or "NPC Jockey"
        
        -- Scale stats based on difficulty and apply slight randomization
        local diffFactor = config.npcDifficulty
        local minNpcStat = 25 * diffFactor
        local maxNpcStat = 40 * diffFactor
        
        -- Add NPC chocobo with scaled stats
        xi.chocoboRacing.activeRaces[raceId].chocobos[npcEntityId] = {
            id = npcEntityId,
            owner = jockeyName,
            name = chocoboNames[i],
            isPlayer = false,
            attributes = {
                speed = minNpcStat + math.random(0, maxNpcStat - minNpcStat),
                stamina = minNpcStat + math.random(0, maxNpcStat - minNpcStat),
                endurance = minNpcStat + math.random(0, maxNpcStat - minNpcStat),
                intelligence = minNpcStat + math.random(0, maxNpcStat - minNpcStat)
            },
            currentLap = 0,
            currentSegment = 0,
            position = i + 1,
            finished = false,
            finishTime = 0,
            items = {},
            effects = {}
        }
    end
    
    -- Generate race data packets and send to player
    local raceData = {
        category = category,
        weatherType = xi.chocoboRacing.activeRaces[raceId].weather,
        chocobos = xi.chocoboRacing.activeRaces[raceId].chocobos
    }
    
    xi.chocoboRacing.generateRacePackets(player, raceData)
    
    -- Start race event
    player:startEvent(xi.chocoboRacing.events.RACE_EVENT, 3993159, 3993159, category, 61001, 3731017, -1, 2, 1)
    
    -- Setup race update timer for lap tracking
    xi.chocoboRacing.setupRaceUpdateTimer(player, raceId)
    
    -- Special message for multi-lap race
    if config.laps > 1 then
        -- Let the player know this is a special race
        player:messageSpecial(zones[xi.zone.CHOCOBO_CIRCUIT].text.SPECIAL_RACE, config.laps)
    end
    
    -- Send initial NPC messages
    sendRaceMessage(player, xi.chocoboRacing.npcMessages.RACE_START)
    
    debug(player, "Started race ID " .. raceId .. " with category " .. category .. " (" .. config.laps .. " laps)")
    
    return true
end

-- Start a Special Multi-Lap Race (Admin/GM function)
xi.chocoboRacing.startSpecialRace = function(player, laps)
    -- Default to 3 laps if not specified
    laps = laps or 3
    
    -- Validate lap count
    if laps < 1 or laps > 10 then
        laps = 3 -- Safety cap
    end
    
    -- Set up special race configuration
    xi.chocoboRacing.circuitConfig[99].laps = laps
    
    -- Start race with special category
    return xi.chocoboRacing.startRace(player, 99)
end

-- Setup Race Update Timer
xi.chocoboRacing.setupRaceUpdateTimer = function(player, raceId)
    local race = xi.chocoboRacing.activeRaces[raceId]
    if not race then return end
    
    local config = xi.chocoboRacing.circuitConfig[race.category]
    
    -- Setup timer to update race state every 500ms
    player:timer(500, function(playerArg)
        -- Check if race still exists and is active
        if not xi.chocoboRacing.activeRaces[raceId] or 
           xi.chocoboRacing.activeRaces[raceId].finished then
            return false
        end
        
        -- Update race positions
        xi.chocoboRacing.updateRacePositions(raceId)
        
        -- Update player position
        local playerEntityId = playerArg:getLocalVar("raceEntityId")
        local chocobo = race.chocobos[playerEntityId]
        
        if chocobo then
            -- Check for lap completion
            if chocobo.currentSegment >= config.segmentCount and 
               chocobo.currentLap < config.laps then
                -- Complete a lap
                chocobo.currentLap = chocobo.currentLap + 1
                chocobo.currentSegment = 0
                
                -- Only send message on player lap completion
                if playerEntityId == playerArg:getLocalVar("raceEntityId") then
                    -- Update client with lap information
                    playerArg:updateEvent(75, 0, 4, chocobo.currentLap, 607130998, -1, 2, -5)
                    
                    -- Multi-lap race messages
                    if config.laps > 1 then
                        if chocobo.currentLap < config.laps then
                            -- Lap completion message (X of Y)
                            playerArg:messageSpecial(zones[xi.zone.CHOCOBO_CIRCUIT].text.LAP_COMPLETE, 
                                                  chocobo.currentLap, config.laps)
                        else
                            -- Final lap message
                            playerArg:messageSpecial(zones[xi.zone.CHOCOBO_CIRCUIT].text.FINAL_LAP)
                        end
                    end
                    
                    -- Send race NPC message
                    sendRaceMessage(playerArg, xi.chocoboRacing.npcMessages.LAP_COMPLETE)
                end
                
                -- Random weather change on lap completion
                if math.random(1, 100) <= config.weatherChance then
                    local newWeather = xi.chocoboRacing.getRaceWeather(config.weatherChance)
                    if newWeather ~= race.weather then
                        race.weather = newWeather
                        xi.chocoboRacing.applyWeatherEffects(playerArg, newWeather)
                        
                        -- Weather change message
                        playerArg:messageSpecial(zones[xi.zone.CHOCOBO_CIRCUIT].text.WEATHER_CHANGE, newWeather)
                    end
        end
    end
    
            -- Check for race completion
            if chocobo.currentLap >= config.laps and not chocobo.finished then
                -- Mark chocobo as finished
                chocobo.finished = true
                chocobo.finishTime = os.time() - race.startTime
                
                -- Check if this is the player chocobo
                if playerEntityId == playerArg:getLocalVar("raceEntityId") then
                    -- Race completion update
                    playerArg:updateEvent(72, 0, 4, 1, 607130998, -1, 2, -5)
                    
                    -- Send race finish message
                    sendRaceMessage(playerArg, xi.chocoboRacing.npcMessages.RACE_FINISH)
                    
                    -- Calculate player position and rewards
                    local position = xi.chocoboRacing.getChocoboPosition(raceId, playerEntityId)
                    local reward = xi.chocoboRacing.calculateRaceReward(race.category, position)
                    
                    -- Award gil and chocobucks
                    if reward.gil > 0 then
                        playerArg:addGil(reward.gil)
                        playerArg:messageSpecial(zones[xi.zone.CHOCOBO_CIRCUIT].text.RACE_WINNINGS, reward.gil)
                    end
                    
                    if reward.chocobucks > 0 then
                        -- Add chocobucks (server implementation may vary)
                        playerArg:setLocalVar("chocobucks", (playerArg:getLocalVar("chocobucks") or 0) + reward.chocobucks)
                        playerArg:messageSpecial(zones[xi.zone.CHOCOBO_CIRCUIT].text.CHOCOBUCKS_RECEIVED, reward.chocobucks)
                    end
                    
                    -- Process any bets
                    if playerArg:getLocalVar("raceBetType") > 0 then
                        local winnings = xi.chocoboRacing.calculateWinnings(playerArg, xi.chocoboRacing.getFinalPositions(raceId))
                        if winnings > 0 then
                            playerArg:addGil(winnings)
                            playerArg:messageSpecial(zones[xi.zone.CHOCOBO_CIRCUIT].text.BET_WINNINGS, winnings)
    end
end

                    -- Clean up race variables
                    playerArg:setLocalVar("raceActive", 0)
                    playerArg:setLocalVar("raceCategory", 0)
                    playerArg:setLocalVar("raceLaps", 0)
                    
                    -- For multi-lap races, add a special achievement if player placed in top 3
                    if config.laps > 1 and position <= 3 then
                        playerArg:messageSpecial(zones[xi.zone.CHOCOBO_CIRCUIT].text.MULTILAP_ACHIEVEMENT, position)
                        -- Could award a special item or title here
        end
    end
end

            -- Continue timer if race is still active
            return not xi.chocoboRacing.areAllChocobosFinished(raceId)
        end
        
        return false
    end)
end

-- Calculate Race Rewards
xi.chocoboRacing.calculateRaceReward = function(category, position)
    local config = xi.chocoboRacing.circuitConfig[category]
    local rewards = {
        gil = 0,
        chocobucks = 0,
        items = {}
    }
    
    -- Base gil rewards by position
    local gilRewards = {
        [1] = config.fee * 3,    -- 1st place
        [2] = config.fee * 2,    -- 2nd place
        [3] = config.fee * 1.5,  -- 3rd place
        [4] = config.fee * 1,    -- 4th place
        [5] = math.floor(config.fee * 0.5), -- 5th place
        [6] = 0, -- No gil for 6th place
        [7] = 0, -- No gil for 7th place
        [8] = 0  -- No gil for 8th place
    }
    
    -- Base chocobuck rewards by position
    local chocobuckRewards = {
        [1] = 30, -- 1st place
        [2] = 20, -- 2nd place
        [3] = 15, -- 3rd place
        [4] = 10, -- 4th place
        [5] = 8,  -- 5th place
        [6] = 6,  -- 6th place
        [7] = 4,  -- 7th place
        [8] = 2   -- 8th place (consolation)
    }
    
    -- Scale rewards by race category
    local categoryMultiplier = {
        [xi.chocoboRacing.raceCategories.C1] = 1.0,
        [xi.chocoboRacing.raceCategories.C2] = 1.5,
        [xi.chocoboRacing.raceCategories.C3] = 2.0,
        [xi.chocoboRacing.raceCategories.C4] = 3.0,
        [99] = 5.0 -- Hidden multi-lap race has biggest rewards
    }
    
    -- Calculate rewards
    rewards.gil = math.floor(gilRewards[position] * (categoryMultiplier[category] or 1.0))
    rewards.chocobucks = math.floor(chocobuckRewards[position] * (categoryMultiplier[category] or 1.0))
    
    -- Special rewards for multi-lap races
    if category == 99 and position <= 3 then
        -- Additional bonus for top 3 finishers in special races
        rewards.gil = rewards.gil * 2
        rewards.chocobucks = rewards.chocobucks * 2
        
        -- Add special items (server implementation may vary)
        table.insert(rewards.items, {id = 5570, name = "Chocobo Whistle"}) -- Example item
    end
    
    return rewards
end

-- Update Race Positions
xi.chocoboRacing.updateRacePositions = function(raceId)
    local race = xi.chocoboRacing.activeRaces[raceId]
    if not race then return end
    
    -- Calculate current positions based on laps and segments
    local positions = {}
    for entityId, chocobo in pairs(race.chocobos) do
        table.insert(positions, {
            entityId = entityId,
            progress = (chocobo.currentLap * 1000) + chocobo.currentSegment,
            finished = chocobo.finished,
            finishTime = chocobo.finishTime
        })
    end
    
    -- Sort by race progress
    table.sort(positions, function(a, b)
        if a.finished and not b.finished then
            return true
        elseif not a.finished and b.finished then
            return false
        elseif a.finished and b.finished then
            return a.finishTime < b.finishTime
        else
            return a.progress > b.progress
        end
    end)
    
    -- Update position in race data
    for position, data in ipairs(positions) do
        if race.chocobos[data.entityId] then
            race.chocobos[data.entityId].position = position
        end
    end
    
    return positions
end

-- Get Chocobo Position
xi.chocoboRacing.getChocoboPosition = function(raceId, entityId)
    local race = xi.chocoboRacing.activeRaces[raceId]
    if not race or not race.chocobos[entityId] then
        return 0
    end
    
    return race.chocobos[entityId].position or 0
end

-- Get Final Positions
xi.chocoboRacing.getFinalPositions = function(raceId)
    local race = xi.chocoboRacing.activeRaces[raceId]
    if not race then
        return {}
    end
    
    -- Update positions one final time
    xi.chocoboRacing.updateRacePositions(raceId)
    
    -- Extract final ordering
    local finalPositions = {}
    for entityId, chocobo in pairs(race.chocobos) do
        finalPositions[chocobo.position] = entityId
    end
    
    return finalPositions
end

-- Check if all chocobos have finished the race
xi.chocoboRacing.areAllChocobosFinished = function(raceId)
    local race = xi.chocoboRacing.activeRaces[raceId]
    if not race then
        return true
    end
    
    -- Check if all chocobos are finished
    for _, chocobo in pairs(race.chocobos) do
        if not chocobo.finished then
            return false
        end
    end
    
    -- Mark race as finished
    race.finished = true
    
            return true
        end
        
-- Enhanced Multi-Lap Support for the Secret Race Feature
xi.chocoboRacing.handleMultiLapRace = function(player)
    if not player then
        return false
    end
    
    -- Get race info
    local raceId = player:getLocalVar("raceId")
    local entityId = player:getLocalVar("raceEntityId")
    
    if not raceId or not xi.chocoboRacing.activeRaces[raceId] then
        return false
    end
    
    local race = xi.chocoboRacing.activeRaces[raceId]
    if not race.chocobos or not race.chocobos[entityId] then
        return false
    end
    
    local chocobo = race.chocobos[entityId]
    local config = xi.chocoboRacing.circuitConfig[race.category]
    
    -- Check if this is a multi-lap race
    if config.laps <= 1 then
        return false
    end
    
    -- Complete current segment/lap
    if chocobo.currentSegment >= config.segmentCount then
        -- Get previous lap
        local previousLap = chocobo.currentLap
        
        -- Lap completed
        chocobo.currentLap = chocobo.currentLap + 1
        chocobo.currentSegment = 0
        
        -- Send lap completion
        xi.chocoboRacing.sendLapUpdate(player, chocobo.currentLap, config.laps)
        
        -- SPECIAL FEATURE: Give player a free item for completing each lap after the first
        -- Only for the secret race mode (category 99)
        if race.category == 99 and chocobo.currentLap > 1 and chocobo.currentLap < config.laps then
            -- Define which items can be received on each lap
            local itemPool = {}
            
            -- Lap 2 items - standard racing items
            if chocobo.currentLap == 2 then
                itemPool = {
                    xi.chocoboRacing.items.STAMINA_APPLE,
                    xi.chocoboRacing.items.SPEED_APPLE,
                    xi.chocoboRacing.items.SHADOW_APPLE,
                    xi.chocoboRacing.items.PEPPER_BISCUIT,
                    xi.chocoboRacing.items.FIRE_BISCUIT
                }
            -- Lap 3+ items - include better/rare items
            else
                itemPool = {
                    xi.chocoboRacing.items.GYSAHL_BOMB,
                    xi.chocoboRacing.items.SPORE_BOMB,
                    xi.chocoboRacing.items.FAIRWEATHER_FETISH,
                    xi.chocoboRacing.items.FOULWEATHER_FROG
                }
            end
            
            -- Select a random item from the appropriate pool
            local randomItem = itemPool[math.random(1, #itemPool)]
            
            -- Determine if player already has an item
            local currentItem = player:getLocalVar("raceItem")
            
            -- Store the new item for later use if player doesn't have one
            if currentItem == 0 then
                player:setLocalVar("raceItem", randomItem)
                
                -- Get item name for display
                local itemNames = {
                    [xi.chocoboRacing.items.STAMINA_APPLE] = "Stamina Apple",
                    [xi.chocoboRacing.items.SPEED_APPLE] = "Speed Apple",
                    [xi.chocoboRacing.items.SHADOW_APPLE] = "Shadow Apple",
                    [xi.chocoboRacing.items.PEPPER_BISCUIT] = "Pepper Biscuit",
                    [xi.chocoboRacing.items.FIRE_BISCUIT] = "Fire Biscuit",
                    [xi.chocoboRacing.items.GYSAHL_BOMB] = "Gysahl Bomb",
                    [xi.chocoboRacing.items.SPORE_BOMB] = "Spore Bomb",
                    [xi.chocoboRacing.items.FAIRWEATHER_FETISH] = "Fairweather Fetish",
                    [xi.chocoboRacing.items.FOULWEATHER_FROG] = "Foulweather Frog"
                }
                
                -- Send special message for lap completion bonus
                local zone = GetZone(xi.zone.CHOCOBO_CIRCUIT)
                if zone and zone.text and zone.text.SPECIAL_RACE_BONUS then
                    player:messageSpecial(zone.text.SPECIAL_RACE_BONUS, itemNames[randomItem] or "Racing Item", chocobo.currentLap)
                end
            else
                -- Store the bonus item in a special "backup" slot
                if not race.bonusItems then
                    race.bonusItems = {}
                end
                if not race.bonusItems[entityId] then
                    race.bonusItems[entityId] = {}
                end
                
                table.insert(race.bonusItems[entityId], randomItem)
                
                -- Let player know they'll get the item after using their current one
                local itemNames = {
                    [xi.chocoboRacing.items.STAMINA_APPLE] = "Stamina Apple",
                    [xi.chocoboRacing.items.SPEED_APPLE] = "Speed Apple",
                    [xi.chocoboRacing.items.SHADOW_APPLE] = "Shadow Apple",
                    [xi.chocoboRacing.items.PEPPER_BISCUIT] = "Pepper Biscuit",
                    [xi.chocoboRacing.items.FIRE_BISCUIT] = "Fire Biscuit",
                    [xi.chocoboRacing.items.GYSAHL_BOMB] = "Gysahl Bomb",
                    [xi.chocoboRacing.items.SPORE_BOMB] = "Spore Bomb",
                    [xi.chocoboRacing.items.FAIRWEATHER_FETISH] = "Fairweather Fetish",
                    [xi.chocoboRacing.items.FOULWEATHER_FROG] = "Foulweather Frog"
                }
                
                player:messageSpecial(zones[xi.zone.CHOCOBO_CIRCUIT].text.SPECIAL_RACE_BONUS_STORED, 
                    itemNames[randomItem] or "Racing Item", chocobo.currentLap)
            end
        end
        
        -- Check for weather changes between laps
        if math.random(1, 100) <= config.weatherChance then
            local newWeather = xi.chocoboRacing.getRaceWeather(config.weatherChance)
            if newWeather ~= race.weather then
                race.weather = newWeather
                
                -- Send weather update packet
                local weatherPacket = {}
                -- Weather packet should be implemented based on captures
                
                -- Send weather message
                local zone = GetZone(xi.zone.CHOCOBO_CIRCUIT)
                if zone and zone.text and zone.text.WEATHER_CHANGE then
                    player:messageSpecial(zone.text.WEATHER_CHANGE, newWeather)
                end
            end
        end
        
        -- Send messages for lap progress
        if chocobo.currentLap < config.laps then
            -- Regular lap message
            local zone = GetZone(xi.zone.CHOCOBO_CIRCUIT)
            if zone and zone.text and zone.text.LAP_COMPLETE then
                player:messageSpecial(zone.text.LAP_COMPLETE, chocobo.currentLap, config.laps)
            end
            
            -- Send race commentary message
            xi.chocoboRacing.sendRaceMessage(player, xi.chocoboRacing.npcMessages.LAP_COMPLETE)
        else
            -- Final lap message
            local zone = GetZone(xi.zone.CHOCOBO_CIRCUIT)
            if zone and zone.text and zone.text.FINAL_LAP then
                player:messageSpecial(zone.text.FINAL_LAP)
            end
            
            -- Special commentary for final lap
            xi.chocoboRacing.sendRaceMessage(player, xi.chocoboRacing.npcMessages.RACE_FINISH)
        end
        
        -- Check for race completion (all laps done)
        if chocobo.currentLap >= config.laps then
            chocobo.finished = true
            chocobo.finishTime = os.time() - race.startTime
            
            -- Calculate final position
            local position = xi.chocoboRacing.getChocoboPosition(raceId, entityId)
            
            -- Race completion update
            local progressPacket = {}
            -- This should be implemented based on captures
            
            -- Calculate rewards based on final position
            local rewards = xi.chocoboRacing.calculateRaceReward(race.category, position)
            
            -- Award rewards
            if rewards.gil > 0 then
                player:addGil(rewards.gil)
                local zone = GetZone(xi.zone.CHOCOBO_CIRCUIT)
                if zone and zone.text and zone.text.RACE_WINNINGS then
                    player:messageSpecial(zone.text.RACE_WINNINGS, rewards.gil)
                end
            end
            
            if rewards.chocobucks > 0 then
                player:setLocalVar("chocobucks", (player:getLocalVar("chocobucks") or 0) + rewards.chocobucks)
                local zone = GetZone(xi.zone.CHOCOBO_CIRCUIT)
                if zone and zone.text and zone.text.CHOCOBUCKS_RECEIVED then
                    player:messageSpecial(zone.text.CHOCOBUCKS_RECEIVED, rewards.chocobucks)
                end
            end
            
            -- Process any bets
            if player:getLocalVar("raceBetType") > 0 then
                local winnings = xi.chocoboRacing.calculateWinnings(player, xi.chocoboRacing.getFinalPositions(raceId))
                if winnings > 0 then
                    player:addGil(winnings)
                    local zone = GetZone(xi.zone.CHOCOBO_CIRCUIT)
                    if zone and zone.text and zone.text.BET_WINNINGS then
                        player:messageSpecial(zone.text.BET_WINNINGS, winnings)
                    end
                end
            end
            
            -- Multi-lap race achievement for top positions
            if position <= 3 then
                local zone = GetZone(xi.zone.CHOCOBO_CIRCUIT)
                if zone and zone.text and zone.text.MULTILAP_ACHIEVEMENT then
                    player:messageSpecial(zone.text.MULTILAP_ACHIEVEMENT, position)
                end
            end
            
            -- Clean up race variables
            player:setLocalVar("raceActive", 0)
            player:setLocalVar("raceCategory", 0)
            player:setLocalVar("raceLaps", 0)
            
            return true
        end
    end
    
    return false
end

-- Enhanced Item Usage System
xi.chocoboRacing.useRacingItem = function(player, itemId, targetId)
    if not xi.settings.main.ENABLE_CHOCOBO_RACING then
        return false
    end
    
    -- Get race ID
    local raceId = player:getLocalVar("raceId")
    if not raceId or not xi.chocoboRacing.activeRaces[raceId] then
        return false
    end
    
    -- Get player's entity ID
    local entityId = player:getLocalVar("raceEntityId")
    
    -- Check if item is available to use
    if player:getLocalVar("raceItem") ~= itemId then
        return false
    end
    
    -- Determine target based on item type
    local race = xi.chocoboRacing.activeRaces[raceId]
    local chocobo = race.chocobos[entityId]
    
    -- Handle targeting logic based on item type
    if not targetId then
        if itemId == xi.chocoboRacing.items.PEPPER_BISCUIT or 
           itemId == xi.chocoboRacing.items.FIRE_BISCUIT then
            -- Target chocobo in front (if any)
            for i, otherChocobo in pairs(race.chocobos) do
                if otherChocobo.position == chocobo.position - 1 then
                    targetId = i
                    break
                end
            end
        elseif itemId == xi.chocoboRacing.items.GYSAHL_BOMB or 
               itemId == xi.chocoboRacing.items.SPORE_BOMB then
            -- Default to self for area effects (targets calculated server-side)
            targetId = entityId
        else
            -- Self-targeted items
            targetId = entityId
        end
    end
    
    -- Create packet based on captured structure
    local packet = {}
    
    -- Packet Header - ID 0x01A
    packet[1] = 0x1A
    packet[2] = 0x0E
    
    -- Dynamic sync ID
    local syncId = math.random(0, 255)
    packet[3] = syncId
    packet[4] = 0x00
    
    -- Target entity ID
    packet[5] = targetId % 256
    packet[6] = math.floor(targetId / 256) % 256
    packet[7] = 0x04
    packet[8] = 0x01
    
    -- Set target ID LSB (duplicate)
    packet[9] = targetId % 256
    
    -- Rest of packet filled with zeros
    for i = 10, 22 do
        packet[i] = 0x00
    end
    
    -- Process item effect and apply to appropriate targets
    xi.chocoboRacing.processItemEffect(raceId, entityId, targetId, itemId)
    
    -- Remove item after use
    player:setLocalVar("raceItem", 0)
    
    -- Determine chance for new item based on position
    local config = xi.chocoboRacing.circuitConfig[race.category]
    local itemChance = config.itemFrequency or 30
    
    -- Adjust item chance based on position (higher chance when behind)
    local positionMod = math.min(chocobo.position - 1, 3) * 10
    itemChance = itemChance + positionMod
    
    -- Try to give a new item
    if math.random(1, 100) <= itemChance then
        local newItem = xi.chocoboRacing.getRacingItem(
            chocobo.position,
            chocobo.currentLap
        )
        player:setLocalVar("raceItem", newItem)
        
        -- Notify player
        local zone = GetZone(xi.zone.CHOCOBO_CIRCUIT)
        if zone and zone.text and zone.text.FOUND_ITEM then
            player:messageSpecial(zone.text.FOUND_ITEM, newItem)
        end
    end
    
    -- Broadcast packet to all race participants
    xi.chocoboRacing.broadcastPacket(raceId, packet)
    
    return true
end

-- Command for GMs to start a special multi-lap race
function onTrigger(player, args)
    -- Usage: !race <laps>
    -- Default to 3 laps if not specified
    local laps = tonumber(args[1]) or 3
    
    -- Start special race
    if xi.settings.main.ENABLE_CHOCOBO_RACING then
        if xi.chocoboRacing.startSpecialRace(player, laps) then
            player:printToPlayer("Started special multi-lap race with " .. laps .. " laps.")
        else
            player:printToPlayer("Failed to start race.")
        end
    else
        player:printToPlayer("Chocobo racing is disabled.")
    end
end

-- Enhanced Race Results Display (based on 0x074 packet analysis)
xi.chocoboRacing.sendRaceResults = function(player, raceId)
    if not player then
        return false
    end
    
    -- Get race data
    if not raceId or not xi.chocoboRacing.activeRaces[raceId] then
        return false
    end
    
    local race = xi.chocoboRacing.activeRaces[raceId]
    
    -- Create 0x074 packet for race results (based on captures)
    local packet = {}
    
    -- Packet header
    packet[1] = 0x74
    packet[2] = 0x5A  -- Size from captures
    
    -- Sequence ID
    local seqId = os.time() % 0xFFFF
    packet[3] = seqId % 256
    packet[4] = math.floor(seqId / 256) % 256
    
    -- Packet flags (from captures)
    packet[5] = 0x02
    packet[6] = 0x00
    packet[7] = 0x00
    packet[8] = 0x00
    
    -- Additional flags (from captures)
    for i = 9, 16 do
        packet[i] = 0x00
    end
    
    -- Create subpacket 1 - Race parameters
    -- This indicates it's subpacket 1
    packet[17] = 0x01
    packet[18] = 0x00
    
    -- Race settings based on category
    local categoryParams = {
        [1] = {0x08, 0x00, 0x28}, -- C1 (Crystal Stakes)
        [2] = {0x06, 0x00, 0x24}, -- C2
        [3] = {0x04, 0x00, 0x20}, -- C3
        [4] = {0x02, 0x00, 0x1C}, -- C4
    }
    
    -- Default to C4 if no category specified
    local params = categoryParams[race.category] or categoryParams[4]
    
    -- Race settings
    packet[19] = params[1]
    packet[20] = params[2]
    packet[21] = params[3]
    packet[22] = 0x00
    packet[23] = 0x00
    packet[24] = 0x00
    packet[25] = 0x02
    packet[26] = 0x00
    packet[27] = 0x00
    packet[28] = 0xC0
    
    -- Fill rest with zeros (from captures)
    for i = 29, 48 do
        packet[i] = 0x00
    end
    
    -- Send first part to player
    player:queuePacket(packet)
    
    -- Create subpacket 2 - Race results attributes
    packet[17] = 0x02
    packet[18] = 0x00
    
    -- Race attributes (from captures)
    packet[19] = 0x60
    packet[20] = 0x00
    packet[21] = 0x51
    packet[22] = 0x00
    packet[23] = 0x00
    packet[24] = 0x00
    
    -- Set race circuit parameters and chocobo stats
    -- Process the race results to build the attributes
    local chocoboIndex = 1
    for entityId, chocobo in pairs(race.chocobos) do
        if chocobo and chocoboIndex <= 8 then
            -- Calculate offset for this chocobo's data
            local offset = 24 + (chocoboIndex - 1) * 3
            
            -- Set attributes based on real chocobo performance
            -- Byte 1: Speed attribute (0-255)
            packet[offset + 1] = math.min(255, math.floor((chocobo.speed or 40) * 2.5))
            
            -- Byte 2: Attribute flags
            -- Bit 0-1: Player (0x01) or NPC (0x00)
            -- Bit 2-3: Weather vulnerability (0x04)
            -- Bit 4-5: Stamina flags (0x10, 0x20)
            -- Bit 6-7: Reserved (0x40, 0x80)
            local flags = 0x00
            if chocobo.isPlayer then
                flags = flags + 0x01
            end
            if chocobo.weatherVulnerable then
                flags = flags + 0x04
            end
            if chocobo.stamina and chocobo.stamina < 40 then
                flags = flags + 0x10
            elseif chocobo.stamina and chocobo.stamina >= 80 then
                flags = flags + 0x20
            end
            packet[offset + 2] = flags
            
            -- Byte 3: Finishing position
            local position = 0
            if race.finishOrder then
                for i, id in ipairs(race.finishOrder) do
                    if id == entityId then
                        position = i
                        break
                    end
                end
            end
            packet[offset + 3] = position
            
            chocoboIndex = chocoboIndex + 1
        end
    end
    
    -- Fill any remaining chocobo slots with zeros
    for i = 24 + chocoboIndex * 3, 48 do
        packet[i] = 0x00
    end
    
    -- Send second part to player
    player:queuePacket(packet)
    
    -- Create subpacket 3 - Race results chocobo names
    packet[17] = 0x03
    packet[18] = 0x00
    
    -- Fixed offset for names section
    packet[19] = 0xA0
    packet[20] = 0x00
    
    -- Clear previous data
    for i = 21, 48 do
        packet[i] = 0x00
    end
    
    -- Add chocobo names
    local nameOffset = 21
    for entityId, chocobo in pairs(race.chocobos) do
        if chocobo.name and chocobo.name ~= "" and nameOffset <= 45 then
            -- Add name with zero padding
            local nameBytes = {}
            for i = 1, #chocobo.name do
                table.insert(nameBytes, string.byte(chocobo.name:sub(i, i)))
            end
            
            -- Ensure name doesn't exceed buffer
            for i = 1, math.min(16, #nameBytes) do
                packet[nameOffset] = nameBytes[i]
                nameOffset = nameOffset + 1
            end
            
            -- Zero pad to 16 bytes
            while nameOffset % 16 ~= 5 do
                packet[nameOffset] = 0x00
                nameOffset = nameOffset + 1
            end
        end
    end
    
    -- Send third part to player
    player:queuePacket(packet)
    
    -- Create subpacket 4 - Race statistics
    packet[17] = 0x04
    packet[18] = 0x00
    
    -- Statistics header
    packet[19] = 0x70
    packet[20] = 0x00
    packet[21] = 0x36
    packet[22] = 0x00
    
    -- Clear previous data
    for i = 23, 48 do
        packet[i] = 0x00
    end
    
    -- Generate race statistics
    -- Total race time in seconds
    if race.startTime and race.endTime then
        local totalTime = race.endTime - race.startTime
        packet[23] = totalTime % 256
        packet[24] = math.floor(totalTime / 256) % 256
        packet[25] = 0x00
        packet[26] = 0x00
    end
    
    -- Weather conditions during race
    packet[27] = race.weatherCount and race.weatherCount.CLEAR or 0x05
    packet[28] = race.weatherCount and race.weatherCount.RAIN or 0x02
    packet[29] = race.weatherCount and race.weatherCount.HEAT or 0x01
    packet[30] = race.weatherCount and race.weatherCount.SNOW or 0x00
    
    -- Total items used in race
    local totalItems = 0
    for _, chocobo in pairs(race.chocobos) do
        totalItems = totalItems + (chocobo.itemsUsed or 0)
    end
    packet[31] = totalItems
    
    -- Send fourth part to player
    player:queuePacket(packet)
    
    -- Create subpacket 5 - End of results marker
    packet[17] = 0x05
    packet[18] = 0x00
    
    -- End marker (from captures)
    packet[19] = 0xE0
    packet[20] = 0x00
    
    -- Clear all remaining data
    for i = 21, 48 do
        packet[i] = 0x00
    end
    
    -- Send fifth/final part to player
    player:queuePacket(packet)
    
    -- Also send betting results if applicable
    if race.bets and #race.bets > 0 then
        xi.chocoboRacing.sendBettingResults(player, raceId)
    end
    
    return true
end

-- Send the betting results to player
xi.chocoboRacing.sendBettingResults = function(player, raceId)
    if not player or not raceId then
        return false
    end
    
    local race = xi.chocoboRacing.activeRaces[raceId]
    if not race then
        return false
    end
    
    -- Look for player's bet
    local playerBet = nil
    for _, bet in ipairs(race.bets or {}) do
        if bet.playerId == player:getID() then
            playerBet = bet
            break
        end
    end
    
    if not playerBet then
        return false -- No bet placed
    end
    
    -- Create 0x017 packet for bet results
    local packet = packets.new('incoming', 0x017)
    
    -- Set packet type for bet results
    packet:setUInt8(0x04, 0x22)
    
    -- Calculate winnings
    local winnings = 0
    local won = false
    
    -- Create result string based on bet type and results
    local resultString = string.format(
        "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",
        race.id or 0,
        playerBet.type or 0,
        playerBet.chocoboId or 0,
        playerBet.chocoboId2 or 0,
        playerBet.amount or 0,
        winnings,
        won and 1 or 0,
        0, -- Reserved
        0, -- Reserved
        0  -- Reserved
    )
    
    -- Set payload in packet
    packet:setData(0x18, resultString)
    
    -- Queue packet to player
    player:queuePacket(packet)
    
    return true
end

-- Enhanced Betting System (based on event analysis)
xi.chocoboRacing.placeBet = function(player, betType, chocoboId, amount)
    -- Forward to our enhanced implementation
    return xi.chocoboRacing.betting.placeBet(player, betType, chocoboId, amount)
end

-- Calculate Winnings
xi.chocoboRacing.calculateWinnings = function(player, finalPositions)
    -- Forward to our enhanced implementation
    return xi.chocoboRacing.betting.calculateWinnings(player, finalPositions)
end

-- Enhanced Spectating System (based on packet analysis)
xi.chocoboRacing.startSpectating = function(player, raceId)
    if not player or not raceId then
        return false
    end
    
    -- Check if race exists
    if not xi.chocoboRacing.activeRaces[raceId] then
        return false
    end
    
    -- Set player as a spectator for this race
    player:setLocalVar("spectatingRaceId", raceId)
    
    -- Start the spectator event
    player:startEvent(xi.chocoboRacing.events.SPECTATE_EVENT, 1, 2, 100, 58496, 0, 0, 0, 4)
    
    -- After event completes, we'll forward race packets to this player
    -- This would be handled in the event completion callback
    
    return true
end

-- Race Data Packet for Spectators
xi.chocoboRacing.sendRaceDataToSpectators = function(raceId, packet)
    if not raceId or not xi.chocoboRacing.activeRaces[raceId] then
        return false
    end
    
    -- Get zone players
    local zone = GetZone(xi.zone.CHOCOBO_CIRCUIT)
    if not zone then
        return false
    end
    
    local players = zone:getPlayers()
    for _, player in ipairs(players) do
        -- Check if player is spectating this race
        if player:getLocalVar("spectatingRaceId") == raceId then
            -- Forward the race packet
            player:queuePacket(packet)
        end
    end
    
    return true
end

-- Handle Race Animation Updates (based on 0x0F4 packet analysis)
xi.chocoboRacing.sendRaceAnimationUpdate = function(player, chocoboId, animationType, chocoboName)
    -- Animation Packet (0x0F4)
    -- Server → Client packet for chocobo animations and movement states
    --
    -- Key Fields:
    -- - Chocobo ID
    -- - Animation type (START, GALLOP, STUMBLE, FINISH)
    -- - Chocobo name (displayed in UI)
    if not player then
        return false
    end
    
    local packet = packets.new('incoming', 0x0F4)
    
    -- Set packet size
    packet:setUInt8(0x01, 0x0E) -- Size from captures
    
    -- Set entity ID
    packet:setUInt16(0x04, chocoboId or 0)
    
    -- Set animation parameters from retail captures
    packet:setUInt8(0x06, 0x00)
    packet:setUInt8(0x07, 0x01) -- Fixed value from captures
    
    -- Animation type values (based on retail captures)
    if animationType == "START" then
        packet:setUInt8(0x08, 0xFE)
        packet:setUInt8(0x09, 0xFF)
        packet:setUInt8(0x0A, 0xF9)
        packet:setUInt8(0x0B, 0xFF)
    elseif animationType == "GALLOP" then
        packet:setUInt8(0x08, 0x00)
        packet:setUInt8(0x09, 0x00)
        packet:setUInt8(0x0A, 0xF8)
        packet:setUInt8(0x0B, 0xFF)
    elseif animationType == "STUMBLE" then
        packet:setUInt8(0x08, 0xF7)
        packet:setUInt8(0x09, 0xFF)
        packet:setUInt8(0x0A, 0xFC)
        packet:setUInt8(0x0B, 0xFF)
    elseif animationType == "FINISH" then
        packet:setUInt8(0x08, 0xF6)
        packet:setUInt8(0x09, 0xFF)
        packet:setUInt8(0x0A, 0xF5)
        packet:setUInt8(0x0B, 0xFF)
    elseif animationType == "IDLE" then
        packet:setUInt8(0x08, 0xFF)
        packet:setUInt8(0x09, 0xFF)
        packet:setUInt8(0x0A, 0xFF)
        packet:setUInt8(0x0B, 0xFF)
    end
    
    -- Set chocobo name (if provided, otherwise use default)
    local name = chocoboName or ""
    if name == "" then
        -- If name is not provided, try to get it from the race data
        if player:getLocalVar("chocoboRaceId") then
            local raceId = player:getLocalVar("chocoboRaceId")
            local race = xi.chocoboRacing.activeRaces[raceId]
            if race and race.chocobos and race.chocobos[chocoboId] then
                name = race.chocobos[chocoboId].name or "Chocobo"
            else
                name = "Chocobo"
            end
        else
            name = "Chocobo"
        end
    end
    
    -- Set the name in the packet (max 12 characters, null terminated)
    packet:setString(0x0C, name:sub(1, 12))
    
    -- Send the animation packet
    player:queuePacket(packet)
    
    return true
end

-- Enhanced Race Statistics Update (based on 0x073 packet analysis)
xi.chocoboRacing.sendRaceStatisticsUpdate = function(player, raceId)
    if not player then
        return false
    end
    
    -- Check if race exists
    if not raceId or not xi.chocoboRacing.activeRaces[raceId] then
        return false
    end
    
    local race = xi.chocoboRacing.activeRaces[raceId]
    
    -- Create 0x073 packet based on captures
    local packet = {}
    
    -- Packet header
    packet[1] = 0x73
    packet[2] = 0x24  -- Size from captures
    
    -- Sequence ID
    local seqId = os.time() % 0xFFFF
    packet[3] = seqId % 256
    packet[4] = math.floor(seqId / 256) % 256
    
    -- Race flags
    packet[5] = 0x02
    packet[6] = 0x00
    packet[7] = 0x00
    packet[8] = 0x00
    
    -- Race ID
    packet[9] = 0x29
    packet[10] = 0xEE
    packet[11] = 0x34
    packet[12] = 0x00
    
    -- Reserved fields
    for i = 13, 16 do
        packet[i] = 0x00
    end
    
    -- Statistics data (simplified - in real implementation this would be calculated)
    -- These values represent performance data for each chocobo
    for i = 17, 36 do
        packet[i] = 0x50
        packet[i+1] = 0xC3
        i = i + 1
    end
    
    -- Send packet to player
    player:queuePacket(packet)
    
    return true
end

-- Implement 0x05C race progress packet
xi.chocoboRacing.sendRaceProgressPacket = function(race, chocobo, eventType)
    -- Race Progress Packet (0x05C)
    -- Server → Client packet for race progress updates
    -- 
    -- Tracks race progression with different event types:
    -- - Regular updates (checkpoints, position)
    -- - Lap completion
    -- - Race completion
    local packet = packets.new('incoming', 0x05C)
    
    -- Standard header fields are set automatically
    
    -- Set event-specific patterns based on retail packet captures
    if eventType == "REGULAR_UPDATE" then
        -- Standard update packet (checkpoint/position update)
        packet:setUInt32(0x04, chocobo.currentCheckpoint or 0) -- Current checkpoint ID
        packet:setUInt32(0x0C, chocobo.currentLap or 1)        -- Current lap
        packet:setUInt32(0x10, race.rank and race.rank.laps or 3) -- Total laps
        packet:setUInt32(0x14, chocobo.id or 0)                -- Chocobo ID
        
    elseif eventType == "LAP_COMPLETE" then
        -- Lap completion pattern (0x00 00 03 02...)
        packet:setUInt8(0x04, 0x00)
        packet:setUInt8(0x05, 0x00)
        packet:setUInt8(0x06, 0x03)
        packet:setUInt8(0x07, 0x02)
        packet:setUInt32(0x08, 0x00)
        packet:setUInt32(0x0C, chocobo.currentLap or 1)
        packet:setUInt32(0x14, chocobo.id or 0)
        
    elseif eventType == "RACE_COMPLETE" then
        -- Race completion pattern (0x64 10 16 16...)
        packet:setUInt8(0x04, 0x64)
        packet:setUInt8(0x05, 0x10)
        packet:setUInt8(0x06, 0x16)
        packet:setUInt8(0x07, 0x16)
        packet:setUInt8(0x08, 0x00)
        packet:setUInt8(0x09, 0x00)
        packet:setUInt8(0x0A, 0x00)
        packet:setUInt8(0x0B, 0x60)
        packet:setUInt32(0x14, chocobo.id or 0)
        packet:setUInt8(0x1C, 0x03) -- Race finish marker
        
    elseif eventType == "RACE_PROGRESS" then
        -- Race progress update pattern (0x38 30 08 0B...)
        packet:setUInt8(0x04, 0x38)
        packet:setUInt8(0x05, 0x30)
        packet:setUInt8(0x06, 0x08)
        packet:setUInt8(0x07, 0x0B)
        packet:setUInt8(0x08, 0x88)
        packet:setUInt8(0x09, 0x00)
        packet:setUInt8(0x0A, 0x08)
        packet:setUInt8(0x0B, 0x11)
        packet:setUInt32(0x0C, chocobo.currentLap or 1)
        packet:setUInt32(0x14, chocobo.id or 0)
    end
    
    -- Set the 0x80 marker at offset 0x20 (seen in all packet types)
    packet:setUInt8(0x20, 0x80)
    
    -- Send packet to player
    if chocobo.isPlayer then
        local player = GetPlayerByID(chocobo.id)
        if player then
            player:queuePacket(packet)
            
            -- If this is a race completion event, also send the names packet
            if eventType == "RACE_COMPLETE" then
                xi.chocoboRacing.sendRaceCompetitorsPacket(race)
            end
        end
    end
    
    -- Also send to spectators
    for _, spectatorId in ipairs(race.spectators or {}) do
        local spectator = GetPlayerByID(spectatorId)
        if spectator then
            spectator:queuePacket(packet)
            
            -- If this is a race completion event, also send the names packet
            if eventType == "RACE_COMPLETE" then
                xi.chocoboRacing.sendRaceCompetitorsPacket(race)
            end
        end
    end
    
    return true
end

-- Implement 0x067 position update packet
xi.chocoboRacing.sendPositionUpdatePacket = function(race, chocobo, packetType)
    -- Position Update Packet (0x067)
    -- Server → Client packet for detailed position information
    -- 
    -- Supports two packet types based on retail captures:
    -- Type 1: Circuit announcement (0x03 05 C8 00 C8 60 04 01...)
    -- Type 2: Position update (0x02 09 81 04 35 57 08 00...)
    
    local packet = packets.new('incoming', 0x067)
    
    if packetType == "CIRCUIT_ANNOUNCEMENT" then
        -- Type 1: Circuit announcement/system message
        packet:setUInt8(0x02, 0x0C) -- packet size
        packet:setUInt8(0x04, 0x03)
        packet:setUInt8(0x05, 0x05)
        packet:setUInt8(0x06, 0xC8)
        packet:setUInt8(0x07, 0x00)
        packet:setUInt8(0x08, 0xC8)
        packet:setUInt8(0x09, 0x60)
        packet:setUInt8(0x0A, 0x04)
        packet:setUInt8(0x0B, 0x01)
        
        -- Zero remaining fields
        for i = 0x0C, 0x18 do
            packet:setUInt8(i, 0x00)
        end
        
    else -- Default to position update
        -- Type 2: Position update with detailed movement
        packet:setUInt8(0x02, 0x14) -- packet size
        packet:setUInt8(0x04, 0x02)
        packet:setUInt8(0x05, 0x09)
        packet:setUInt8(0x06, 0x81)
        packet:setUInt8(0x07, 0x04)
        
        -- Set racing status parameters from retail captures
        packet:setUInt8(0x08, chocobo.currentCheckpoint or 0x35)
        packet:setUInt8(0x09, chocobo.currentSegment or 0x57)
        packet:setUInt8(0x0A, 0x08)
        packet:setUInt8(0x0B, 0x00)
        
        -- Set position coordinates
        if chocobo and chocobo.position then
            packet:setFloat(0x0C, chocobo.position.x or 0)
            packet:setFloat(0x10, chocobo.position.y or 0)
            packet:setFloat(0x14, chocobo.position.z or 0)
        end
        
        -- Set animation and movement flags (from captures)
        -- Animation states: 0x63 (gallop), 0x65 (stumble), 0x67 (tired)
        local animState = 0x63 -- Default gallop
        
        -- Adjust animation based on chocobo state
        if chocobo.hasEffect and chocobo.hasEffect("TIRED") then
            animState = 0x67 -- Tired animation
        elseif chocobo.hasEffect and chocobo.hasEffect("STUMBLE") then
            animState = 0x65 -- Stumble animation
        elseif chocobo.speed and chocobo.speed > chocobo.maxSpeed * 0.9 then
            animState = 0x64 -- Fast gallop
        end
        
        packet:setUInt8(0x1E, animState)
        packet:setUInt8(0x1F, 0x01)  -- Movement flags (0x01: normal, 0x02: dashing)
    end
    
    -- Send packet to all race participants and spectators
    for _, raceChocobo in pairs(race.chocobos or {}) do
        if raceChocobo.isPlayer then
            local player = GetPlayerByID(raceChocobo.id)
            if player then
                player:queuePacket(packet)
            end
        end
    end
    
    -- Send to spectators
    for _, spectatorId in ipairs(race.spectators or {}) do
        local spectator = GetPlayerByID(spectatorId)
        if spectator then
            spectator:queuePacket(packet)
        end
    end
    
    return true
end

-- Implement 0x069 race status update
xi.chocoboRacing.sendRaceStatusPacket = function(race)
    -- Race Status Packet (0x069)
    -- Server → Client packet with different modes for race state
    -- 
    -- Multiple packet modes provide complete race information:
    -- - Mode 1: Race initialization with basic parameters
    -- - Mode 2: Chocobo attributes and stats
    -- - Mode 3: Real-time race progress data
    -- - Mode 4: Race results parameters
    -- - Mode 5: Weather effects and modifiers
    
    -- Mode 1: Race initialization
    local packet1 = packets.new('incoming', 0x069)
    packet1:setUInt8(0x01, 0x64) -- Packet size from captures
    packet1:setUInt8(0x04, 0x01) -- Mode 1
    packet1:setUInt8(0x05, 0x00) -- Submode
    packet1:setUInt8(0x06, 0x08) -- Parameters flag from captures
    packet1:setUInt8(0x07, 0x01) -- Fixed value from captures
    
    -- Set race parameters - race ID and circuit category
    packet1:setUInt32(0x08, race.id or 0x24)
    
    -- Circuit category parameters - based on retail captures
    local circuitParams = {
        [1] = 0x30600000, -- C1 (Crystal Stakes)
        [2] = 0x20480000, -- C2
        [3] = 0x18400000, -- C3 
        [4] = 0x10320000, -- C4
    }
    packet1:setUInt32(0x0C, circuitParams[race.category or 4])
    
    -- Set initialization flag (required for client to process race)
    packet1:setUInt8(0x30, 0x01)
    
    -- Mode 2: Chocobo attributes
    local packet2 = packets.new('incoming', 0x069)
    packet2:setUInt8(0x01, 0x64) -- Packet size from captures
    packet2:setUInt8(0x04, 0x02) -- Mode 2
    packet2:setUInt8(0x05, 0x00) -- Submode
    packet2:setUInt8(0x06, 0x60) -- Parameters flag from captures
    packet2:setUInt8(0x07, 0x01) -- Fixed value from captures
    
    -- Set up chocobo attributes for each participant
    local chocoboCount = 0
    local attributeOffset = 0x0C
    
    -- Process each chocobo in the race
    for _, chocobo in pairs(race.chocobos) do
        chocoboCount = chocoboCount + 1
        
        -- Set chocobo ID and parameters at the appropriate offset
        packet2:setUInt8(0x08 + chocoboCount - 1, chocobo.position or chocoboCount)
        
        -- Set attributes at the calculated offset
        -- Each chocobo takes 4 bytes of attributes
        local baseOffset = attributeOffset + (chocoboCount - 1) * 4
        
        -- Speed, Stamina, Intelligence, Cunning
        packet2:setUInt8(baseOffset, chocobo.speed or 0x38)
        packet2:setUInt8(baseOffset + 1, chocobo.stamina or 0x30)
        packet2:setUInt8(baseOffset + 2, chocobo.intelligence or 0x08)
        packet2:setUInt8(baseOffset + 3, chocobo.cunning or 0x0B)
    end
    
    -- Mode 3: Race progress data
    local packet3 = packets.new('incoming', 0x069)
    packet3:setUInt8(0x01, 0x64) -- Packet size from captures
    packet3:setUInt8(0x04, 0x03) -- Mode 3
    packet3:setUInt8(0x05, 0x00) -- Submode
    packet3:setUInt8(0x06, 0xC0) -- Parameters flag from captures
    packet3:setUInt8(0x07, 0x01) -- Fixed value from captures
    
    -- Circuit segments - derived from packet analysis
    local segments = xi.chocoboRacing.circuits[race.category or "C1"].SEGMENT_PARAMS
    
    -- Add position data from captures
    -- Marker pattern for key circuit segments
    for i, segment in ipairs(segments) do
        packet3:setUInt8(segment + 7, 0x80 + i)  -- Segment marker
    end
    
    -- Mode 4: Race results
    local packet4 = packets.new('incoming', 0x069)
    packet4:setUInt8(0x01, 0x64) -- Packet size from captures
    packet4:setUInt8(0x04, 0x04) -- Mode 4
    packet4:setUInt8(0x05, 0x00) -- Submode
    packet4:setUInt8(0x06, 0x04) -- Parameters flag from captures
    packet4:setUInt8(0x07, 0x01) -- Fixed value from captures
    
    -- Race result parameters
    if race.state == "FINISHED" and race.finishOrder then
        -- Set specific result parameters for the player
        local playerChocobo = nil
        for _, chocobo in pairs(race.chocobos) do
            if chocobo.isPlayer then
                playerChocobo = chocobo
                break
            end
        end
        
        if playerChocobo then
            local placement = 0
            for i, chocoboId in ipairs(race.finishOrder) do
                if chocoboId == playerChocobo.id then
                    placement = i
                    break
                end
            end
            
            -- Result parameters based on placement
            packet4:setUInt8(0x08, placement)  -- Place indicator
            packet4:setUInt8(0x09, 0x10)  -- Result code
        else
            -- Default result parameters
            packet4:setUInt8(0x08, 0x23)  -- Default place indicator
            packet4:setUInt8(0x09, 0x10)  -- Default result code
        end
    else
        -- Default result parameters for non-finished race
        packet4:setUInt8(0x08, 0x00)  -- No result yet
        packet4:setUInt8(0x09, 0x00)  -- No code yet
    end
    
    packet4:setUInt8(0x0A, 0xFF)  -- Fixed value from captures
    packet4:setUInt8(0x0B, 0xFF)  -- Fixed value from captures
    
    -- Set flag to 1 at offset 0x30
    packet4:setUInt8(0x30, 0x01)
    
    -- Mode 5: Weather effects
    local packet5 = packets.new('incoming', 0x069)
    packet5:setUInt8(0x01, 0x64) -- Packet size from captures
    packet5:setUInt8(0x04, 0x05) -- Mode 5
    packet5:setUInt8(0x05, 0x00) -- Submode
    packet5:setUInt8(0x06, 0x00) -- Parameters flag from captures
    packet5:setUInt8(0x07, 0x01) -- Fixed value from captures
    
    -- Set weather parameters based on race weather
    packet5:setUInt8(0x08, race.weather and race.weather.id or 0x01)
    
    -- Send all packets to players and spectators
    for _, chocobo in pairs(race.chocobos or {}) do
        if chocobo.isPlayer then
            local player = GetPlayerByID(chocobo.id)
            if player then
                player:queuePacket(packet1)
                player:queuePacket(packet2)
                player:queuePacket(packet3)
                player:queuePacket(packet4)
                player:queuePacket(packet5)
            end
        end
    end
    
    for _, spectatorId in ipairs(race.spectators or {}) do
        local spectator = GetPlayerByID(spectatorId)
        if spectator then
            spectator:queuePacket(packet1)
            spectator:queuePacket(packet2)
            spectator:queuePacket(packet3)
            spectator:queuePacket(packet4)
            spectator:queuePacket(packet5)
        end
    end
    
    return true
end

-- Implement 0x017 race results packet
xi.chocoboRacing.sendRaceResultsPacket = function(race)
    -- Create packet structure for race results (based on 0x017 format)
    local packet = packets.new('incoming', 0x017)
    
    -- Set packet type for race results
    packet:setUInt8(0x04, 0x21)
    
    -- Process finish order and times
    local payload = ""
    for i, chocoboId in ipairs(race.finishOrder) do
        local chocobo = race.chocobos[chocoboId]
        
        -- Add result entry for each chocobo
        payload = payload .. string.format(
            "0a,%04X,000000b,%08X,%08X,%08X,%08X,",
            i <= 3 and 0x0220 + i - 1 or 0x0220, -- Win/Place/Show based on position
            chocobo.id,       -- Chocobo ID
            chocobo.finishTime, -- Finish time
            chocobo.isPlayer and 0x4a or 0x00, -- Player flag
            -- Various statistics about the race
            chocobo.itemsUsed or 0
        )
    end
    
    -- Set payload in packet
    packet:setData(0x18, payload)
    
    -- Send to all race participants and spectators
    for _, chocobo in pairs(race.chocobos) do
        if chocobo.isPlayer then
            local player = GetPlayerByID(chocobo.id)
            if player then
                player:queuePacket(packet)
            end
        end
    end
    
    for _, spectatorId in ipairs(race.spectators) do
        local spectator = GetPlayerByID(spectatorId)
        if spectator then
            spectator:queuePacket(packet)
        end
    end
    
    -- Process betting payouts after sending results
    xi.chocoboRacing.processBetPayouts(race)
end

-- Process betting payouts
xi.chocoboRacing.processBetPayouts = function(race)
    -- Get final race positions
    local positions = {}
    for i, chocoboId in ipairs(race.finishOrder) do
        positions[chocoboId] = i
    end
    
    -- Process each bet
    for _, bet in ipairs(race.bets) do
        local player = GetPlayerByID(bet.playerId)
        if not player then
            goto continue
        end
        
        local won = false
        local payout = 0
        
        -- Check different bet types
        if bet.type == 0x0220 then -- Win
            won = (positions[bet.chocoboId] == 1)
            if won then
                local chocobo = race.chocobos[bet.chocoboId]
                payout = math.floor(bet.amount * chocobo.odds)
            end
        elseif bet.type == 0x0221 then -- Place
            won = (positions[bet.chocoboId] <= 2)
            if won then
                local chocobo = race.chocobos[bet.chocoboId]
                payout = math.floor(bet.amount * (chocobo.odds * 0.6))
            end
        elseif bet.type == 0x0222 then -- Show
            won = (positions[bet.chocoboId] <= 3)
            if won then
                local chocobo = race.chocobos[bet.chocoboId]
                payout = math.floor(bet.amount * (chocobo.odds * 0.3))
            end
        elseif bet.type == 0x0223 then -- Exacta
            won = (positions[bet.chocoboId] == 1 and positions[bet.chocoboId2] == 2)
            if won then
                local chocobo1 = race.chocobos[bet.chocoboId]
                local chocobo2 = race.chocobos[bet.chocoboId2]
                payout = math.floor(bet.amount * (chocobo1.odds * chocobo2.odds * 0.8))
            end
        elseif bet.type == 0x0225 then -- Quinella
            won = ((positions[bet.chocoboId] == 1 and positions[bet.chocoboId2] == 2) or
                   (positions[bet.chocoboId] == 2 and positions[bet.chocoboId2] == 1))
            if won then
                local chocobo1 = race.chocobos[bet.chocoboId]
                local chocobo2 = race.chocobos[bet.chocoboId2]
                payout = math.floor(bet.amount * ((chocobo1.odds + chocobo2.odds) * 0.5))
            end
        end
        
        -- Pay the player if they won
        if won and payout > 0 then
            player:addGil(payout)
            player:messageSpecial(xi.chocoboRacing.messages.BETTING.WINNING_BET, payout)
            
            -- Send special result packet for won bets
            local betResultPacket = packets.new('incoming', 0x017)
            betResultPacket:setUInt8(0x04, bit.band(bet.type, 0xFF))
            betResultPacket:setUInt16(0x06, payout)
            player:queuePacket(betResultPacket)
        else
            player:messageSpecial(xi.chocoboRacing.messages.BETTING.LOSING_BET)
        end
        
        ::continue::
    end
end

-- Stamina System for Racing
xi.chocoboRacing.updateStamina = function(chocobo, deltaTime)
    -- Calculate stamina drain based on current speed
    local speedFactor = chocobo.currentSpeed / chocobo.topSpeed
    local baseDrainRate = 1.0 -- Base drain per second
    
    -- Apply weather effects to stamina drain
    local weather = chocobo.race.weather or xi.chocoboRacing.weatherTypes.CLEAR
    local weatherEffect = xi.chocoboRacing.weatherEffects[weather]
    local weatherDrainMod = weatherEffect and weatherEffect.staminaDrain or 1.0
    
    -- Higher speeds drain stamina faster (quadratic relationship)
    local speedDrainMod = speedFactor * speedFactor
    
    -- Calculate final drain amount
    local staminaDrain = baseDrainRate * speedDrainMod * weatherDrainMod * deltaTime
    
    -- Apply abilities that affect stamina drain
    if chocobo.abilities and chocobo.abilities[xi.chocoboRacing.abilities.STAMINA] then
        staminaDrain = staminaDrain * 0.8 -- 20% reduction
    end
    if chocobo.abilities and chocobo.abilities[xi.chocoboRacing.abilities.BREATHE] then
        -- Breathe actually regenerates some stamina
        staminaDrain = staminaDrain - (0.3 * deltaTime)
    end
    
    -- Update chocobo stamina
    chocobo.currentStamina = math.max(0, chocobo.currentStamina - staminaDrain)
    
    -- If stamina is depleted, reduce to lowest speed
    if chocobo.currentStamina <= 0 then
        chocobo.currentSpeed = chocobo.topSpeed * 0.4 -- 40% of top speed when exhausted
    end
    
    return chocobo.currentStamina
end

-- AI Chocobo Implementation
-- These functions handle AI behavior during races when slots aren't filled by players

-----------------------------------
-- AI Chocobo Constants
-----------------------------------
xi.chocoboRacing.aiDifficulty = 
{
    BEGINNER = 1,    -- Easier AI for C4 races
    STANDARD = 2,    -- Normal AI for C2-C3 races
    ADVANCED = 3,    -- More challenging AI for C1 races
    EXPERT = 4       -- Very challenging AI for special events
}

-- AI personality types that influence behavior
xi.chocoboRacing.aiPersonality = 
{
    CONSERVATIVE = 1,  -- Focuses on consistent pace, less item usage
    AGGRESSIVE = 2,    -- Uses items frequently, pushes speed limits
    TACTICAL = 3,      -- Focuses on positioning and timing item usage
    BALANCED = 4       -- Balanced approach to racing
}

-----------------------------------
-- AI Chocobo Main Functions
-----------------------------------

-- Creates an AI chocobo for an unfilled race slot
xi.chocoboRacing.createAIChocobo = function(race, position)
    -- Check if this should be a special chocobo
    local specialChocobo = xi.chocoboRacing.names.getSpecialChocobo(race.category)
    
    -- Base profile for AI chocobo
    local aiChocobo = {
        name = specialChocobo and specialChocobo.name or xi.chocoboRacing.names.getRandomChocoboName(race.category),
        jockey = specialChocobo and specialChocobo.jockey or xi.chocoboRacing.names.getRandomJockeyName(race.category)[1],
        isAI = true,
        position = position,
        race = race,
        stats = specialChocobo and specialChocobo.attributes or xi.chocoboRacing.generateAIStats(race.category),
        personality = specialChocobo and specialChocobo.personality or xi.chocoboRacing.getAIPersonalityForRace(race.category),
        difficulty = xi.chocoboRacing.getAIDifficultyForRace(race.category),
        currentSpeed = 0,
        maxSpeed = 0,
        currentStamina = 100,
        maxStamina = 100,
        items = {},
        racePosition = position,
        currentSegment = 1,
        lap = 1,
        itemCooldown = 0,
        lastDecisionTime = 0,
        nextActionTime = 0
    }
    
    -- Set AI-specific racing attributes based on circuit category
    if specialChocobo then
        aiChocobo.maxSpeed = specialChocobo.attributes.speed * 0.5
    elseif race.category == xi.chocoboRacing.raceCategories.C1 then
        aiChocobo.maxSpeed = 50 + math.random(10)
    elseif race.category == xi.chocoboRacing.raceCategories.C2 then
        aiChocobo.maxSpeed = 45 + math.random(10)
    elseif race.category == xi.chocoboRacing.raceCategories.C3 then
        aiChocobo.maxSpeed = 40 + math.random(10)
    else -- C4
        aiChocobo.maxSpeed = 35 + math.random(10)
    end
    
    -- Give AI chocobo some random items based on race category
    xi.chocoboRacing.giveAIItems(aiChocobo)
    
    return aiChocobo
end

-- Fill empty race slots with AI chocobos
xi.chocoboRacing.fillRaceWithAI = function(race)
    local playerCount = #race.racers
    local totalSlots = race.slots or 8
    
    -- If race is already full, don't add AI
    if playerCount >= totalSlots then
        return
    end
    
    -- Fill remaining slots with AI chocobos
    for i = playerCount + 1, totalSlots do
        local aiChocobo = xi.chocoboRacing.createAIChocobo(race, i)
        table.insert(race.racers, aiChocobo)
        
        if xi.settings.main.DEBUG_CHOCOBO_RACING then
            printf("[Chocobo Racing] Added AI chocobo %s to race %d (position %d)", 
                   aiChocobo.name, race.id, i)
        end
    end
end

-- Generate appropriate AI stats based on race category
xi.chocoboRacing.generateAIStats = function(category)
    local stats = {
        speed = 0,
        stamina = 0,
        endurance = 0,
        intelligence = 0,
        cunning = 0
    }
    
    -- Base stats vary by race category
    local baseValue = 30
    if category == xi.chocoboRacing.raceCategories.C1 then
        baseValue = 60
    elseif category == xi.chocoboRacing.raceCategories.C2 then
        baseValue = 50
    elseif category == xi.chocoboRacing.raceCategories.C3 then
        baseValue = 40
    end
    
    -- Generate stats with some randomness
    stats.speed = baseValue + math.random(-5, 10)
    stats.stamina = baseValue + math.random(-5, 10)
    stats.endurance = baseValue + math.random(-5, 10)
    stats.intelligence = baseValue + math.random(-5, 10)
    stats.cunning = baseValue + math.random(-5, 10)
    
    return stats
end

-- Randomly select an AI personality type based on race category
xi.chocoboRacing.getAIPersonalityForRace = function(category)
    local personalities = {
        xi.chocoboRacing.aiPersonality.CONSERVATIVE,
        xi.chocoboRacing.aiPersonality.AGGRESSIVE,
        xi.chocoboRacing.aiPersonality.TACTICAL,
        xi.chocoboRacing.aiPersonality.BALANCED
    }
    
    -- Higher-tier races have more aggressive personalities
    if category == xi.chocoboRacing.raceCategories.C1 then
        -- C1 races have more aggressive and tactical AIs
        return personalities[math.random(2, 4)]
    elseif category == xi.chocoboRacing.raceCategories.C4 then
        -- C4 races have more conservative AIs
        return personalities[math.random(1, 2)]
    else
        -- C2/C3 races have fully random personalities
        return personalities[math.random(1, 4)]
    end
end

-- Select AI difficulty based on race category
xi.chocoboRacing.getAIDifficultyForRace = function(category)
    if category == xi.chocoboRacing.raceCategories.C1 then
        return xi.chocoboRacing.aiDifficulty.ADVANCED
    elseif category == xi.chocoboRacing.raceCategories.C2 then
        return xi.chocoboRacing.aiDifficulty.STANDARD
    elseif category == xi.chocoboRacing.raceCategories.C3 then
        return xi.chocoboRacing.aiDifficulty.STANDARD
    else -- C4
        return xi.chocoboRacing.aiDifficulty.BEGINNER
    end
end

-- Generate a random name for an AI chocobo from the pool of NPC jockeys
xi.chocoboRacing.getAIChocoboName = function(category)
    -- Get a retail-accurate name for the chocobo
    return xi.chocoboRacing.names.getRandomChocoboName(category)
end

-- Give AI chocobos items based on race category
xi.chocoboRacing.giveAIItems = function(aiChocobo)
    local itemCount = 0
    
    -- Higher difficulty AIs get more items
    if aiChocobo.difficulty == xi.chocoboRacing.aiDifficulty.EXPERT then
        itemCount = 3
    elseif aiChocobo.difficulty == xi.chocoboRacing.aiDifficulty.ADVANCED then
        itemCount = 2
    elseif aiChocobo.difficulty == xi.chocoboRacing.aiDifficulty.STANDARD then
        itemCount = math.random(1, 2)
    else -- BEGINNER
        itemCount = math.random(0, 1)
    end
    
    -- Available items based on race category
    local availableItems = {
        xi.chocoboRacing.items.STAMINA_APPLE,
        xi.chocoboRacing.items.SPEED_APPLE
    }
    
    -- More advanced categories get more item options
    if aiChocobo.race.category <= xi.chocoboRacing.raceCategories.C3 then
        table.insert(availableItems, xi.chocoboRacing.items.PEPPER_BISCUIT)
        table.insert(availableItems, xi.chocoboRacing.items.SHADOW_APPLE)
    end
    
    if aiChocobo.race.category <= xi.chocoboRacing.raceCategories.C2 then
        table.insert(availableItems, xi.chocoboRacing.items.FIRE_BISCUIT)
        table.insert(availableItems, xi.chocoboRacing.items.GYSAHL_BOMB)
    end
    
    if aiChocobo.race.category == xi.chocoboRacing.raceCategories.C1 then
        table.insert(availableItems, xi.chocoboRacing.items.SPORE_BOMB)
        table.insert(availableItems, xi.chocoboRacing.items.FAIRWEATHER_FETISH)
        table.insert(availableItems, xi.chocoboRacing.items.FOULWEATHER_FROG)
    end
    
    -- Add random items to AI inventory
    for i = 1, itemCount do
        local randomItem = availableItems[math.random(1, #availableItems)]
        table.insert(aiChocobo.items, randomItem)
    end
end

-----------------------------------
-- AI Chocobo Decision Making Functions
-----------------------------------

-- Main update function for AI chocobos - called during race updates
xi.chocoboRacing.updateAIChocobo = function(aiChocobo, raceTime)
    -- Skip if not an AI
    if not aiChocobo.isAI then
        return
    end
    
    -- Only make decisions periodically (varies by difficulty)
    local decisionInterval = 5 -- seconds
    if aiChocobo.difficulty == xi.chocoboRacing.aiDifficulty.EXPERT then
        decisionInterval = 2
    elseif aiChocobo.difficulty == xi.chocoboRacing.aiDifficulty.ADVANCED then
        decisionInterval = 3
    elseif aiChocobo.difficulty == xi.chocoboRacing.aiDifficulty.STANDARD then
        decisionInterval = 4
    end
    
    -- Check if it's time to make a decision
    if (raceTime - aiChocobo.lastDecisionTime) < decisionInterval then
        return
    end
    
    -- Update decision time
    aiChocobo.lastDecisionTime = raceTime
    
    -- Consider using an item
    if #aiChocobo.items > 0 and aiChocobo.itemCooldown <= 0 then
        xi.chocoboRacing.aiConsiderUseItem(aiChocobo)
    end
    
    -- Update speed and stamina based on AI personality
    xi.chocoboRacing.aiUpdateSpeed(aiChocobo)
end

-- AI item usage decision making
xi.chocoboRacing.aiConsiderUseItem = function(aiChocobo)
    -- Determine if AI should use an item now
    local shouldUseItem = false
    local race = aiChocobo.race
    
    -- Different personalities have different item usage patterns
    if aiChocobo.personality == xi.chocoboRacing.aiPersonality.AGGRESSIVE then
        -- Aggressive chocobos use items frequently
        shouldUseItem = (math.random(100) < 70)
    elseif aiChocobo.personality == xi.chocoboRacing.aiPersonality.TACTICAL then
        -- Tactical chocobos use items based on race position
        if aiChocobo.racePosition > 1 and aiChocobo.racePosition <= 3 then
            shouldUseItem = (math.random(100) < 60)
        elseif aiChocobo.racePosition > 3 then
            shouldUseItem = (math.random(100) < 80)
        else
            shouldUseItem = (math.random(100) < 30) -- Less likely if in first
        end
    elseif aiChocobo.personality == xi.chocoboRacing.aiPersonality.CONSERVATIVE then
        -- Conservative chocobos use items sparingly
        shouldUseItem = (math.random(100) < 30)
        
        -- More likely if stamina is low
        if aiChocobo.currentStamina < 30 then
            shouldUseItem = (math.random(100) < 70)
        end
    else -- BALANCED
        -- Balanced approach
        shouldUseItem = (math.random(100) < 50)
    end
    
    -- If decision is to use an item, select which one
    if shouldUseItem and #aiChocobo.items > 0 then
        local itemIdx = math.random(1, #aiChocobo.items)
        local itemId = aiChocobo.items[itemIdx]
        
        -- Remove the item from inventory
        table.remove(aiChocobo.items, itemIdx)
        
        -- Use the item
        xi.chocoboRacing.aiUseItem(aiChocobo, itemId)
        
        -- Set cooldown for item usage
        aiChocobo.itemCooldown = 10 -- 10 seconds cooldown
    end
end

-- AI actually uses the selected item
xi.chocoboRacing.aiUseItem = function(aiChocobo, itemId)
    local race = aiChocobo.race
    
    -- Choose a target based on item and AI personality
    local targetChocobo = nil
    
    -- Determine if the item is beneficial or harmful
    local isBeneficial = (itemId == xi.chocoboRacing.items.STAMINA_APPLE or
                          itemId == xi.chocoboRacing.items.SPEED_APPLE or
                          itemId == xi.chocoboRacing.items.SHADOW_APPLE or
                          itemId == xi.chocoboRacing.items.FAIRWEATHER_FETISH)
    
    if isBeneficial then
        -- Beneficial items target self
        targetChocobo = aiChocobo
    else
        -- Harmful items target opponents, preferably those ahead
        -- Find all chocobos ahead of this AI
        local possibleTargets = {}
        for _, chocobo in pairs(race.racers) do
            if chocobo.racePosition < aiChocobo.racePosition then
                table.insert(possibleTargets, chocobo)
            end
        end
        
        -- If no one is ahead (AI is in first), target random opponent
        if #possibleTargets == 0 then
            for _, chocobo in pairs(race.racers) do
                if chocobo ~= aiChocobo then
                    table.insert(possibleTargets, chocobo)
                end
            end
        end
        
        -- Choose a random target from possibilities
        if #possibleTargets > 0 then
            targetChocobo = possibleTargets[math.random(1, #possibleTargets)]
        else
            -- Fallback to self if somehow no targets available
            targetChocobo = aiChocobo
        end
    end
    
    if targetChocobo then
        -- Create packet to use item - this mimics what a player would send
        local itemPacket = xi.packet.new("CHOCOBO_RACING_ACTION")
        itemPacket:setAction(0x02) -- Use Item action
        itemPacket:setRaceId(race.id)
        itemPacket:setItemId(itemId)
        itemPacket:setTargetIndex(targetChocobo.position)
        
        -- Process the item action directly
        xi.chocoboRacing.onRaceAction(aiChocobo, itemPacket)
        
        if xi.settings.main.DEBUG_CHOCOBO_RACING then
            printf("[Chocobo Racing] AI %s used item %d on target position %d", 
                  aiChocobo.name, itemId, targetChocobo.position)
        end
    end
end

-- Update AI chocobo speed based on personality and race conditions
xi.chocoboRacing.aiUpdateSpeed = function(aiChocobo)
    local race = aiChocobo.race
    local baseSpeed = aiChocobo.maxSpeed
    local speedModifier = 1.0
    
    -- Different personalities adjust speed differently
    if aiChocobo.personality == xi.chocoboRacing.aiPersonality.AGGRESSIVE then
        -- Aggressive chocobos prefer higher speeds
        speedModifier = 0.9 + (math.random() * 0.2) -- 0.9-1.1
    elseif aiChocobo.personality == xi.chocoboRacing.aiPersonality.TACTICAL then
        -- Tactical chocobos adjust speed based on race position
        if aiChocobo.racePosition > 1 and aiChocobo.racePosition <= 3 then
            speedModifier = 0.85 + (math.random() * 0.3) -- 0.85-1.15
        elseif aiChocobo.racePosition > 3 then
            speedModifier = 0.9 + (math.random() * 0.3) -- 0.9-1.2
        else
            speedModifier = 0.7 + (math.random() * 0.3) -- 0.7-1.0
        end
    elseif aiChocobo.personality == xi.chocoboRacing.aiPersonality.CONSERVATIVE then
        -- Conservative chocobos preserve stamina
        speedModifier = 0.6 + (math.random() * 0.4) -- 0.6-1.0
        
        -- Adjust based on stamina
        if aiChocobo.currentStamina > 70 then
            speedModifier = speedModifier + 0.1
        elseif aiChocobo.currentStamina < 30 then
            speedModifier = speedModifier - 0.1
        end
    else -- BALANCED
        -- Balanced approach
        speedModifier = 0.7 + (math.random() * 0.3) -- 0.7-1.0
    end
    
    -- Adjust for stamina
    if aiChocobo.currentStamina < 20 then
        speedModifier = speedModifier * 0.7
    elseif aiChocobo.currentStamina < 50 then
        speedModifier = speedModifier * 0.85
    end
    
    -- Adjust for weather
    local weatherEffect = xi.chocoboRacing.weatherEffects[race.weather]
    if weatherEffect and weatherEffect.speedModifier then
        speedModifier = speedModifier * weatherEffect.speedModifier
    end
    
    -- Calculate final speed
    aiChocobo.currentSpeed = baseSpeed * speedModifier
    
    -- Reduce stamina based on speed
    local staminaLoss = (speedModifier > 0.8) and 2 or 1
    aiChocobo.currentStamina = math.max(0, aiChocobo.currentStamina - staminaLoss)
    
    -- If stamina is depleted, apply severe speed penalty
    if aiChocobo.currentStamina <= 0 then
        aiChocobo.currentSpeed = aiChocobo.currentSpeed * 0.3
    end
end

-- Add hook to the existing updateRace function to handle AI updates
-- This should be integrated into the existing updateRace function
local oldUpdateRace = xi.chocoboRacing.updateRace
xi.chocoboRacing.updateRace = function(race, deltaTime)
    -- Call original function
    oldUpdateRace(race, deltaTime)
    
    -- Update all AI chocobos
    for _, chocobo in pairs(race.racers) do
        if chocobo.isAI then
            -- Decrement item cooldown
            if chocobo.itemCooldown > 0 then
                chocobo.itemCooldown = chocobo.itemCooldown - deltaTime
            end
            
            -- Update AI behavior
            xi.chocoboRacing.updateAIChocobo(chocobo, race.elapsedTime)
        end
    end
end

-- Modify the race start function to fill with AI opponents when needed
local oldStartRace = xi.chocoboRacing.startRace
xi.chocoboRacing.startRace = function(raceId)
    local race = xi.chocoboRacing.activeRaces[raceId]
    if race then
        -- Fill race with AI chocobos before starting
        xi.chocoboRacing.fillRaceWithAI(race)
    end
    
    -- Call original function
    return oldStartRace(raceId)
end

-- Add this to initialize the race schedule when the server starts
xi.chocoboRacing.initSchedule = function()
    if xi.settings.main.ENABLE_CHOCOBO_RACING then
        -- Initialize race schedule
        xi.chocoboRacing.scheduleRaces()
        
        -- Set up the periodic update check (every game hour)
        local nextHourCheck = os.time() + (60 * 60) -- 1 hour
        SetServerVariable("ChocRaceNextHourCheck", nextHourCheck)
        print("[Chocobo Racing] Schedule initialized")
    end
end

-- Add this to call from the server's onGameHour event
xi.chocoboRacing.onGameHour = function(hour)
    if not xi.settings.main.ENABLE_CHOCOBO_RACING then
        return
    end
    
    local currentTime = os.time()
    local nextCheck = GetServerVariable("ChocRaceNextHourCheck") or 0
    
    -- Only check once per hour to avoid excessive processing
    if currentTime >= nextCheck then
        -- Update the race schedule
        xi.chocoboRacing.updateSchedule()
        
        -- Schedule next check
        SetServerVariable("ChocRaceNextHourCheck", currentTime + (60 * 60))
        
        -- Announce team standings every 3 hours
        if hour % 3 == 0 then
            local zone = GetZone(xi.zone.CHOCOBO_CIRCUIT)
            if zone then
                xi.chocoboRacing.announceTeamStandings(zone)
            end
        end
    end
end

-- Add a function to calculate team bonuses based on standings
xi.chocoboRacing.getTeamBonus = function(teamId)
    local bonusPercent = 0
    
    if teamId == xi.chocoboRacing.raceTeams.SANDORIA then
        local standing = GetServerVariable("ChocTeamSanDoria") or xi.chocoboRacing.teamStandings.MINIMAL
        bonusPercent = (standing - 1) * 5 -- 0% for MINIMAL, 5% for MINOR, 10% for MAJOR, 15% for DOMINANT
    elseif teamId == xi.chocoboRacing.raceTeams.BASTOK then
        local standing = GetServerVariable("ChocTeamBastok") or xi.chocoboRacing.teamStandings.MINIMAL
        bonusPercent = (standing - 1) * 5
    elseif teamId == xi.chocoboRacing.raceTeams.WINDURST then
        local standing = GetServerVariable("ChocTeamWindurst") or xi.chocoboRacing.teamStandings.MINIMAL
        bonusPercent = (standing - 1) * 5
    end
    
    return bonusPercent
end

-- When a race is created, make sure to load the AI behavior module
local oldCreateRace = xi.chocoboRacing.createRace
xi.chocoboRacing.createRace = function(player, category)
    local raceId = oldCreateRace(player, category)
    
    -- Make sure races always have the minimum number of chocobos
    local race = xi.chocoboRacing.activeRaces[raceId]
    if race and #race.racers < race.slots then
        xi.chocoboRacing.fillRaceWithAI(race)
    end
    
    return raceId
end

-- Get a racing item based on position and track progress
xi.chocoboRacing.getRacingItem = function(position, lapProgress)
    -- Adjust item chances based on race position
    local itemRates = {}
    
    -- Copy base rates
    for item, rate in pairs(xi.chocoboRacing.itemRates) do
        itemRates[item] = rate
    end
    
    -- Trailing positions get better items
    if position > 4 then
        -- Increase offensive item chances for trailing positions
        if itemRates.PEPPER_BISCUIT then itemRates.PEPPER_BISCUIT = itemRates.PEPPER_BISCUIT + 10 end
        if itemRates.FIRE_BISCUIT then itemRates.FIRE_BISCUIT = itemRates.FIRE_BISCUIT + 5 end
        if itemRates.GYSAHL_BOMB then itemRates.GYSAHL_BOMB = itemRates.GYSAHL_BOMB + 2 end
    end
    
    -- Leading positions get defensive items
    if position <= 2 then
        if itemRates.SHADOW_APPLE then itemRates.SHADOW_APPLE = itemRates.SHADOW_APPLE + 5 end
    end
    
    -- Adjust based on lap progress (final lap gets better items)
    if lapProgress and lapProgress > 0.5 then
        -- More aggressive items in second half of race
        if itemRates.SPEED_APPLE then itemRates.SPEED_APPLE = itemRates.SPEED_APPLE + 5 end
    end
    
    -- Build weighted table
    local weightedItems = {}
    local totalWeight = 0
    
    for item, weight in pairs(itemRates) do
        totalWeight = totalWeight + weight
        table.insert(weightedItems, {item = item, weight = totalWeight})
    end
    
    -- Random selection
    local roll = math.random(1, totalWeight)
    for _, entry in ipairs(weightedItems) do
        if roll <= entry.weight then
            return entry.item
        end
    end
    
    -- Default fallback
    return xi.chocoboRacing.items.STAMINA_APPLE
end

-- Enhanced betting system
xi.chocoboRacing.betting = {
    -- Betting types
    WIN      = 1, -- Chocobo must finish first
    PLACE    = 2, -- Chocobo must finish first or second
    SHOW     = 3, -- Chocobo must finish first, second, or third
    QUINELLA = 4, -- Predict first and second place finishers in any order
    EXACTA   = 5, -- Predict first and second place finishers in correct order
    
    -- Process a bet placed on a race
    placeBet = function(player, betType, chocoboId, amount)
        -- Validate bet amount
        if amount <= 0 or amount > 10000 then
            return false, "Invalid bet amount"
        end
        
        -- Validate player has enough gil
        if player:getGil() < amount then
            return false, "Not enough gil"
        end
        
        -- Take gil from player
        player:delGil(amount)
        
        -- Store bet information - this would be saved to player vars in a real implementation
        player:setLocalVar("raceBetType", betType)
        player:setLocalVar("raceBetChocobo", chocoboId)
        player:setLocalVar("raceBetAmount", amount)
        
        -- Set flag for special NPC dialogue
        if amount >= 1000 then
            player:setLocalVar("raceBigBet", 1)
        end
        
        return true, "Bet placed successfully"
    end,
    
    -- Calculate race odds for each chocobo
    calculateOdds = function(chocobos)
        local odds = {}
        
        for i, chocobo in ipairs(chocobos) do
            local baseOdds = 3 -- Default 3:1 odds
            
            -- Adjust odds based on chocobo stats
            if chocobo.attributes then
                local statSum = chocobo.attributes.speed + chocobo.attributes.stamina + 
                               chocobo.attributes.endurance + chocobo.attributes.intelligence
                
                -- Better stats = lower odds (more likely to win)
                baseOdds = math.max(2, math.min(10, 12 - (statSum / 20)))
            end
            
            -- Factor in chocobo's past performance if available
            if chocobo.pastRaces and chocobo.pastRaces > 0 then
                if chocobo.wins and chocobo.wins > 0 then
                    local winRate = chocobo.wins / chocobo.pastRaces
                    baseOdds = baseOdds * (1 - (winRate * 0.5))
                end
            end
            
            -- Round to nearest 0.5
            odds[i] = math.floor(baseOdds * 2 + 0.5) / 2
        end
        
        return odds
    end,
    
    -- Calculate winnings based on race results
    calculateWinnings = function(player, results)
        local betType = player:getLocalVar("raceBetType")
        local chocoboId = player:getLocalVar("raceBetChocobo")
        local betAmount = player:getLocalVar("raceBetAmount")
        
        local winnings = 0
        local odds = 0
        
        -- Calculate odds based on chocobo and bet type
        if betType == xi.chocoboRacing.betting.WIN then
            -- Win bet pays if chocobo finishes first
            if results[1] == chocoboId then
                odds = 5 -- 5:1 odds for WIN
                winnings = betAmount * odds
            end
        elseif betType == xi.chocoboRacing.betting.PLACE then
            -- Place bet pays if chocobo finishes first or second
            if results[1] == chocoboId or results[2] == chocoboId then
                odds = 3 -- 3:1 odds for PLACE
                winnings = betAmount * odds
            end
        elseif betType == xi.chocoboRacing.betting.SHOW then
            -- Show bet pays if chocobo finishes in top three
            if results[1] == chocoboId or results[2] == chocoboId or results[3] == chocoboId then
                odds = 2 -- 2:1 odds for SHOW
                winnings = betAmount * odds
            end
        elseif betType == xi.chocoboRacing.betting.QUINELLA then
            -- Quinella bet pays if chosen chocobos finish first and second in any order
            local chocobo1 = math.floor(chocoboId / 10)
            local chocobo2 = chocoboId % 10
            
            if (results[1] == chocobo1 and results[2] == chocobo2) or 
               (results[1] == chocobo2 and results[2] == chocobo1) then
                odds = 10 -- 10:1 odds for QUINELLA
                winnings = betAmount * odds
            end
        elseif betType == xi.chocoboRacing.betting.EXACTA then
            -- Exacta bet pays if chosen chocobos finish first and second in correct order
            local chocobo1 = math.floor(chocoboId / 10)
            local chocobo2 = chocoboId % 10
            
            if results[1] == chocobo1 and results[2] == chocobo2 then
                odds = 15 -- 15:1 odds for EXACTA
                winnings = betAmount * odds
            end
        end
        
        -- Clear bet information
        player:setLocalVar("raceBetType", 0)
        player:setLocalVar("raceBetChocobo", 0)
        player:setLocalVar("raceBetAmount", 0)
        player:setLocalVar("raceBigBet", 0)
        
        -- Store winnings for payout
        player:setLocalVar("raceWinnings", winnings)
        
        return winnings
    end
}

-- Get the current active race ID (utility function)
xi.chocoboRacing.getActiveRaceId = function()
    -- This would normally get the currently scheduled race
    -- For simplicity during development, we'll just return the first active race
    for raceId, race in pairs(xi.chocoboRacing.activeRaces) do
        if not race.finished then
            return raceId
        end
    end
    
    -- No active races
    return nil
end

-- Apply weather effects to a chocobo race
xi.chocoboRacing.applyWeatherEffects = function(player, weatherType)
    -- Get race ID
    local raceId = player:getLocalVar("raceId")
    if not raceId or not xi.chocoboRacing.activeRaces[raceId] then
        return
    end
    
    local race = xi.chocoboRacing.activeRaces[raceId]
    
    -- Update race weather
    race.weather = weatherType
    
    -- Get weather effects data
    local effects = xi.chocoboRacing.weatherEffects[weatherType]
    if not effects then
        return
    end
    
    -- Send weather update packet to player
    local weatherPacket = {}
    weatherPacket[1] = 0x57
    weatherPacket[2] = 0x08
    weatherPacket[3] = 0x00
    weatherPacket[4] = 0x00
    weatherPacket[5] = weatherType
    weatherPacket[6] = 0x00
    weatherPacket[7] = 0x00
    weatherPacket[8] = 0x00
    
    player:queuePacket(weatherPacket)
    
    -- Display weather effect message
    player:messageSpecial(zones[xi.zone.CHOCOBO_CIRCUIT].text.WEATHER_CHANGE or 7000, weatherType)
    
    -- Broadcast weather effects message to explain the impact
    if effects.description then
        player:messageText(player, effects.description, xi.msg.channel.SYSTEM_3)
    end
    
    return true
end

-- Implement 0x05D race competitors packet (sent after race completion events)
xi.chocoboRacing.sendRaceCompetitorsPacket = function(race)
    -- Race Competitors Packet (0x05D)
    -- Server → Client packet for race competitor names
    -- 
    -- Contains names of all chocobos in the race
    -- Sent in conjunction with 0x05C race completion packet
    local packet = packets.new('incoming', 0x05D)
    
    -- Set basic packet parameters
    packet:setUInt32(0x04, race.id)
    
    -- Set up the names array, starting at offset 0x20 (byte 32)
    local nameOffset = 0x20
    
    -- Add racer names (player and NPCs)
    for i, chocoboId in ipairs(race.entryOrder) do
        local chocobo = race.chocobos[chocoboId]
        if chocobo then
            -- Create name string (16 bytes max, zero padded)
            local name = chocobo.name or "Chocobo"
            name = name:sub(1, 16)
            
            -- Add name to packet with zero padding
            packet:setString(nameOffset, name)
            nameOffset = nameOffset + 16
        end
    end
    
    -- Send packet to all race participants and spectators
    for _, chocobo in pairs(race.chocobos) do
        if chocobo.isPlayer then
            local player = GetPlayerByID(chocobo.id)
            if player then
                player:queuePacket(packet)
            end
        end
    end
    
    for _, spectatorId in ipairs(race.spectators) do
        local spectator = GetPlayerByID(spectatorId)
        if spectator then
            spectator:queuePacket(packet)
        end
    end
    
    return true
end

-- Process item effects during a race
xi.chocoboRacing.processItemEffect = function(raceId, entityId, targetId, itemId)
    -- Validate parameters
    if not raceId or not entityId or not itemId then
        return false
    end
    
    -- Get race data
    local race = xi.chocoboRacing.activeRaces[raceId]
    if not race then
        return false
    end
    
    -- Get chocobo data
    local chocobo = race.chocobos[entityId]
    if not chocobo then
        return false
    end
    
    -- Verify chocobo has the item
    local hasItem = false
    for i, item in ipairs(chocobo.items or {}) do
        if item == itemId then
            hasItem = true
            -- Remove item from inventory
            table.remove(chocobo.items, i)
            break
        end
    end
    
    -- Cannot use an item you don't have
    if not hasItem and not chocobo.isAI then
        return false
    end
    
    -- Get target chocobo for targeted effects
    local targetChocobo = nil
    if targetId then
        targetChocobo = race.chocobos[targetId]
    end
    
    -- Process specific item effects
    local itemEffect = nil
    
    -- Check for item effect function
    if xi.chocoboRacing.itemEffects[itemId] then
        -- Get effect data
        if targetChocobo then
            itemEffect = xi.chocoboRacing.itemEffects[itemId](chocobo, targetChocobo)
        else
            itemEffect = xi.chocoboRacing.itemEffects[itemId](chocobo)
        end
    end
    
    if not itemEffect then
        return false
    end
    
    -- Apply the effect based on its type
    
    -- Track that this chocobo used an item
    chocobo.itemsUsed = (chocobo.itemsUsed or 0) + 1
    
    -- STAMINA_APPLE - restores stamina
    if itemId == xi.chocoboRacing.items.STAMINA_APPLE then
        chocobo.currentStamina = math.min(chocobo.maxStamina, chocobo.currentStamina + itemEffect.staminaRestore)
        
        -- Announce the item use
        for _, raceChocobo in pairs(race.chocobos or {}) do
            if raceChocobo.isPlayer then
                local player = GetPlayerByID(raceChocobo.id)
                if player then
                    player:chatMessage(0, string.format("%s used a Stamina Apple!", chocobo.name))
                end
            end
        end
    
    -- SPEED_APPLE - temporary speed boost
    elseif itemId == xi.chocoboRacing.items.SPEED_APPLE then
        -- Add speed boost effect
        chocobo.effects = chocobo.effects or {}
        
        -- Record effect duration and amount
        table.insert(chocobo.effects, {
            type = "SPEED_BOOST",
            amount = itemEffect.speedBoost,
            duration = itemEffect.duration,
            endTime = os.time() + itemEffect.duration
        })
        
        -- Apply immediate speed boost
        chocobo.currentSpeed = chocobo.currentSpeed + itemEffect.speedBoost
        
        -- Announce the item use
        for _, raceChocobo in pairs(race.chocobos or {}) do
            if raceChocobo.isPlayer then
                local player = GetPlayerByID(raceChocobo.id)
                if player then
                    player:chatMessage(0, string.format("%s used a Speed Apple!", chocobo.name))
                end
            end
        end
    
    -- SHADOW_APPLE - resist negative effects
    elseif itemId == xi.chocoboRacing.items.SHADOW_APPLE then
        -- Add resistance effect
        chocobo.effects = chocobo.effects or {}
        
        -- Record effect duration
        table.insert(chocobo.effects, {
            type = "ITEM_RESISTANCE",
            duration = itemEffect.duration,
            endTime = os.time() + itemEffect.duration
        })
        
        -- Announce the item use
        for _, raceChocobo in pairs(race.chocobos or {}) do
            if raceChocobo.isPlayer then
                local player = GetPlayerByID(raceChocobo.id)
                if player then
                    player:chatMessage(0, string.format("%s used a Shadow Apple!", chocobo.name))
                end
            end
        end
    
    -- PEPPER_BISCUIT - reduce target's speed
    elseif itemId == xi.chocoboRacing.items.PEPPER_BISCUIT then
        if targetChocobo then
            -- Check if target has resistance
            local isResistant = false
            if targetChocobo.effects then
                for _, effect in ipairs(targetChocobo.effects) do
                    if effect.type == "ITEM_RESISTANCE" and effect.endTime > os.time() then
                        isResistant = true
                        break
                    end
                end
            end
            
            -- Apply effect if not resistant
            if not isResistant then
                -- Add slow effect
                targetChocobo.effects = targetChocobo.effects or {}
                
                -- Record effect duration and amount
                table.insert(targetChocobo.effects, {
                    type = "SPEED_PENALTY",
                    amount = itemEffect.speedPenalty,
                    duration = itemEffect.duration,
                    endTime = os.time() + itemEffect.duration
                })
                
                -- Apply immediate speed reduction
                targetChocobo.currentSpeed = math.max(targetChocobo.topSpeed * 0.3, 
                                                   targetChocobo.currentSpeed - itemEffect.speedPenalty)
                
                -- Announce successful effect
                for _, raceChocobo in pairs(race.chocobos or {}) do
                    if raceChocobo.isPlayer then
                        local player = GetPlayerByID(raceChocobo.id)
                        if player then
                            player:chatMessage(0, string.format("%s used a Pepper Biscuit on %s!", 
                                             chocobo.name, targetChocobo.name))
                        end
                    end
                end
            else
                -- Announce resistance
                for _, raceChocobo in pairs(race.chocobos or {}) do
                    if raceChocobo.isPlayer then
                        local player = GetPlayerByID(raceChocobo.id)
                        if player then
                            player:chatMessage(0, string.format("%s's Shadow Apple protected it from the Pepper Biscuit!", 
                                             targetChocobo.name))
                        end
                    end
                end
            end
        end
    
    -- FIRE_BISCUIT - drain target's stamina
    elseif itemId == xi.chocoboRacing.items.FIRE_BISCUIT then
        if targetChocobo then
            -- Check if target has resistance
            local isResistant = false
            if targetChocobo.effects then
                for _, effect in ipairs(targetChocobo.effects) do
                    if effect.type == "ITEM_RESISTANCE" and effect.endTime > os.time() then
                        isResistant = true
                        break
                    end
                end
            end
            
            -- Apply effect if not resistant
            if not isResistant then
                -- Add stamina drain effect
                targetChocobo.effects = targetChocobo.effects or {}
                
                -- Record effect duration and amount
                table.insert(targetChocobo.effects, {
                    type = "STAMINA_DRAIN",
                    amount = itemEffect.staminaDrain,
                    duration = itemEffect.duration,
                    endTime = os.time() + itemEffect.duration
                })
                
                -- Apply immediate stamina drain
                targetChocobo.currentStamina = math.max(0, targetChocobo.currentStamina - itemEffect.staminaDrain)
                
                -- Announce successful effect
                for _, raceChocobo in pairs(race.chocobos or {}) do
                    if raceChocobo.isPlayer then
                        local player = GetPlayerByID(raceChocobo.id)
                        if player then
                            player:chatMessage(0, string.format("%s used a Fire Biscuit on %s!", 
                                             chocobo.name, targetChocobo.name))
                        end
                    end
                end
            else
                -- Announce resistance
                for _, raceChocobo in pairs(race.chocobos or {}) do
                    if raceChocobo.isPlayer then
                        local player = GetPlayerByID(raceChocobo.id)
                        if player then
                            player:chatMessage(0, string.format("%s's Shadow Apple protected it from the Fire Biscuit!", 
                                             targetChocobo.name))
                        end
                    end
                end
            end
        end
    
    -- GYSAHL_BOMB - area speed penalty
    elseif itemId == xi.chocoboRacing.items.GYSAHL_BOMB then
        -- Get all chocobos within range
        local affectedChocobos = {}
        local bomberPosition = chocobo.currentCheckpoint or 0
        
        -- Area effect applies to chocobos in similar positions
        for id, targetChocobo in pairs(race.chocobos) do
            if id ~= entityId then -- Don't affect the user
                local targetPosition = targetChocobo.currentCheckpoint or 0
                
                -- Check if in range (simple proximity check based on checkpoints)
                if math.abs(targetPosition - bomberPosition) <= itemEffect.range then
                    -- Check resistance
                    local isResistant = false
                    if targetChocobo.effects then
                        for _, effect in ipairs(targetChocobo.effects) do
                            if effect.type == "ITEM_RESISTANCE" and effect.endTime > os.time() then
                                isResistant = true
                                break
                            end
                        end
                    end
                    
                    if not isResistant then
                        -- Add to affected list
                        table.insert(affectedChocobos, targetChocobo)
                    end
                end
            end
        end
        
        -- Apply effects to affected chocobos
        for _, targetChocobo in ipairs(affectedChocobos) do
            -- Add slow effect
            targetChocobo.effects = targetChocobo.effects or {}
            
            -- Record effect duration and amount
            table.insert(targetChocobo.effects, {
                type = "SPEED_PENALTY",
                amount = itemEffect.speedPenalty,
                duration = itemEffect.duration,
                endTime = os.time() + itemEffect.duration
            })
            
            -- Apply immediate speed reduction
            targetChocobo.currentSpeed = math.max(targetChocobo.topSpeed * 0.4, 
                                               targetChocobo.currentSpeed - itemEffect.speedPenalty)
        end
        
        -- Announce the item use
        for _, raceChocobo in pairs(race.chocobos or {}) do
            if raceChocobo.isPlayer then
                local player = GetPlayerByID(raceChocobo.id)
                if player then
                    player:chatMessage(0, string.format("%s used a Gysahl Bomb!", chocobo.name))
                end
            end
        end
    
    -- SPORE_BOMB - area control penalty
    elseif itemId == xi.chocoboRacing.items.SPORE_BOMB then
        -- Get all chocobos within range
        local affectedChocobos = {}
        local bomberPosition = chocobo.currentCheckpoint or 0
        
        -- Area effect applies to chocobos in similar positions
        for id, targetChocobo in pairs(race.chocobos) do
            if id ~= entityId then -- Don't affect the user
                local targetPosition = targetChocobo.currentCheckpoint or 0
                
                -- Check if in range (simple proximity check based on checkpoints)
                if math.abs(targetPosition - bomberPosition) <= itemEffect.range then
                    -- Check resistance
                    local isResistant = false
                    if targetChocobo.effects then
                        for _, effect in ipairs(targetChocobo.effects) do
                            if effect.type == "ITEM_RESISTANCE" and effect.endTime > os.time() then
                                isResistant = true
                                break
                            end
                        end
                    end
                    
                    if not isResistant then
                        -- Add to affected list
                        table.insert(affectedChocobos, targetChocobo)
                    end
                end
            end
        end
        
        -- Apply effects to affected chocobos
        for _, targetChocobo in ipairs(affectedChocobos) do
            -- Add control penalty effect
            targetChocobo.effects = targetChocobo.effects or {}
            
            -- Record effect duration and amount
            table.insert(targetChocobo.effects, {
                type = "CONTROL_PENALTY",
                amount = itemEffect.controlPenalty,
                duration = itemEffect.duration,
                endTime = os.time() + itemEffect.duration
            })
            
            -- Apply stumble effect which appears temporarily
            targetChocobo.hasEffect = targetChocobo.hasEffect or function(effect) 
                return effect == "STUMBLE"; 
            end
        end
        
        -- Announce the item use
        for _, raceChocobo in pairs(race.chocobos or {}) do
            if raceChocobo.isPlayer then
                local player = GetPlayerByID(raceChocobo.id)
                if player then
                    player:chatMessage(0, string.format("%s used a Spore Bomb!", chocobo.name))
                end
            end
        end
    
    -- FAIRWEATHER_FETISH - improve weather
    elseif itemId == xi.chocoboRacing.items.FAIRWEATHER_FETISH then
        -- Improve weather conditions
        if race.weather then
            -- Shift to better weather temporarily
            local previousWeather = race.weather
            
            -- Apply weather improvement - clear any negative weather
            if race.weather == xi.chocoboRacing.weatherTypes.HEAVY_RAIN or
               race.weather == xi.chocoboRacing.weatherTypes.SANDSTORM or
               race.weather == xi.chocoboRacing.weatherTypes.HEAT_WAVE then
                
                -- Change to light rain or clouds
                race.weather = xi.chocoboRacing.weatherTypes.LIGHT_RAIN
            elseif race.weather == xi.chocoboRacing.weatherTypes.LIGHT_RAIN or
                   race.weather == xi.chocoboRacing.weatherTypes.SNOW then
                
                -- Change to clear weather
                race.weather = xi.chocoboRacing.weatherTypes.CLEAR
            end
            
            -- Create temporary effect to revert weather later
            race.weatherEffects = race.weatherEffects or {}
            table.insert(race.weatherEffects, {
                previousWeather = previousWeather,
                endTime = os.time() + itemEffect.duration
            })
            
            -- Weather change requires sending updated packet
            xi.chocoboRacing.sendRaceStatusPacket(race)
        end
        
        -- Announce the item use
        for _, raceChocobo in pairs(race.chocobos or {}) do
            if raceChocobo.isPlayer then
                local player = GetPlayerByID(raceChocobo.id)
                if player then
                    player:chatMessage(0, string.format("%s used a Fairweather Fetish!", chocobo.name))
                end
            end
        end
    
    -- FOULWEATHER_FROG - worsen weather
    elseif itemId == xi.chocoboRacing.items.FOULWEATHER_FROG then
        -- Worsen weather conditions
        if race.weather then
            -- Shift to worse weather temporarily
            local previousWeather = race.weather
            
            -- Apply weather worsening
            if race.weather == xi.chocoboRacing.weatherTypes.CLEAR then
                -- Change to light rain
                race.weather = xi.chocoboRacing.weatherTypes.LIGHT_RAIN
            elseif race.weather == xi.chocoboRacing.weatherTypes.LIGHT_RAIN then
                -- Change to heavy rain
                race.weather = xi.chocoboRacing.weatherTypes.HEAVY_RAIN
            elseif race.weather == xi.chocoboRacing.weatherTypes.SNOW then
                -- Change to heavy snow
                race.weather = xi.chocoboRacing.weatherTypes.HEAVY_RAIN
            end
            
            -- Create temporary effect to revert weather later
            race.weatherEffects = race.weatherEffects or {}
            table.insert(race.weatherEffects, {
                previousWeather = previousWeather,
                endTime = os.time() + itemEffect.duration
            })
            
            -- Weather change requires sending updated packet
            xi.chocoboRacing.sendRaceStatusPacket(race)
        end
        
        -- Announce the item use
        for _, raceChocobo in pairs(race.chocobos or {}) do
            if raceChocobo.isPlayer then
                local player = GetPlayerByID(raceChocobo.id)
                if player then
                    player:chatMessage(0, string.format("%s used a Foulweather Frog!", chocobo.name))
                end
            end
        end
    end
    
    -- Send animation update packet for item use
    if chocobo.isPlayer then
        -- Send appropriate animation based on item type
        local animationType = "ITEM_USE"
        
        xi.chocoboRacing.sendRaceAnimationUpdate(GetPlayerByID(entityId), entityId, animationType, chocobo.name)
    end
    
    return true
end

-- Apply saddle effects to chocobo stats
xi.chocoboRacing.applySaddleEffects = function(chocobo, saddleId)
    -- If we have a detailed saddle ID (0x10 or higher), map it to generic type
    local saddleData = nil
    local saddleType = saddleId
    
    -- Check if this is a detailed saddle ID
    if saddleId >= 0x10 then
        -- Lookup the saddle data
        for name, data in pairs(xi.chocoboRacing.equipment.SADDLES) do
            if type(data) == "table" and data.id == saddleId then
                saddleData = data
                saddleType = data.type -- Map to generic type
                break
            end
        end
        
        -- If not found, default to basic saddle
        if not saddleData then
            saddleType = xi.chocoboRacing.equipment.SADDLES.BASIC_SADDLE
        end
    end
    
    -- Apply effects based on generic saddle type
    local saddleEffects = {
        [xi.chocoboRacing.equipment.SADDLES.BASIC_SADDLE] = function(c)
            -- No adjustments for basic saddle
            return c
        end,
        [xi.chocoboRacing.equipment.SADDLES.JOCKEY_SADDLE] = function(c)
            -- Better control
            c.control = c.control + 5 + (saddleData and saddleData.tier or 0) * 2
            return c
        end,
        [xi.chocoboRacing.equipment.SADDLES.RACING_SADDLE] = function(c)
            -- Better speed, worse control
            c.speed = c.speed + 5 + (saddleData and saddleData.tier or 0) * 2
            c.control = c.control - 5
            return c
        end,
        [xi.chocoboRacing.equipment.SADDLES.CUSTOM_SADDLE] = function(c)
            -- Balanced stat improvements
            c.speed = c.speed + 2 + (saddleData and saddleData.tier or 0)
            c.control = c.control + 2 + (saddleData and saddleData.tier or 0)
            c.stamina = c.stamina + 2 + (saddleData and saddleData.tier or 0)
            return c
        end,
        [xi.chocoboRacing.equipment.SADDLES.TRAINER_SADDLE] = function(c)
            -- Better stamina, may have receptivity requirement in retail
            c.stamina = c.stamina + 5 + (saddleData and saddleData.tier or 0) * 3
            
            -- Apply tier-specific improvements
            if saddleData and saddleData.tier > 1 then
                c.control = c.control + (saddleData.tier - 1) * 2
            end
            
            return c
        end
    }
    
    -- Apply the appropriate effect function
    if saddleEffects[saddleType] then
        chocobo = saddleEffects[saddleType](chocobo)
    end
    
    -- Apply nation bonuses for tier 3 saddles
    if saddleData and saddleData.tier == 3 and saddleData.nation > 0 then
        -- Nation-specific bonus (extra 5% to primary stat)
        if saddleType == xi.chocoboRacing.equipment.SADDLES.JOCKEY_SADDLE then
            chocobo.control = chocobo.control * 1.05
        elseif saddleType == xi.chocoboRacing.equipment.SADDLES.RACING_SADDLE then
            chocobo.speed = chocobo.speed * 1.05
        elseif saddleType == xi.chocoboRacing.equipment.SADDLES.TRAINER_SADDLE then
            chocobo.stamina = chocobo.stamina * 1.05
        end
    end
    
    -- TODO: Check for minimum stat requirements mentioned in retail descriptions
    -- This would require checking chocobo.discernment/receptivity values
    
    return chocobo
end

-- Add a getter function for active races
xi.chocoboRacing.getActiveRaces = function()
    local activeRacesList = {}
    
    -- Collect active races
    for raceId, race in pairs(xi.chocoboRacing.activeRaces or {}) do
        if race and not race.finished then
            table.insert(activeRacesList, race)
        end
    end
    
    return activeRacesList
end

-- Add event handlers for Chocobo Racing
xi.chocoboRacing.onEventUpdate = function(player, csid, option, npc)
    -- Handle event updates for Chocobo Racing
    if xi.settings.main.DEBUG_CHOCOBO_RACING then
        printf("[Chocobo Racing] Event Update - CSID: %d, Option: %d", csid, option)
    end
    
    -- Handle different event types
    if csid == xi.chocoboRacing.events.RACE_EVENT then
        -- Race event updates
        local race = nil
        local raceId = player:getLocalVar("raceId")
        
        if raceId > 0 then
            race = xi.chocoboRacing.activeRaces[raceId]
        end
        
        -- Update race status based on option
        if race then
            -- Different options indicate race progress updates
            -- This is a stub - implement actual race updates as needed
        end
    elseif csid == xi.chocoboRacing.events.SPECTATE_EVENT then
        -- Spectator event updates
        -- This is a stub - implement spectator updates as needed
    end
end

xi.chocoboRacing.onEventFinish = function(player, csid, option, npc)
    -- Handle event completions for Chocobo Racing
    if xi.settings.main.DEBUG_CHOCOBO_RACING then
        printf("[Chocobo Racing] Event Finish - CSID: %d, Option: %d", csid, option)
    end
    
    -- Handle different event types
    if csid == xi.chocoboRacing.events.RACE_EVENT then
        -- Race event completions
        local race = nil
        local raceId = player:getLocalVar("raceId")
        
        if raceId > 0 then
            race = xi.chocoboRacing.activeRaces[raceId]
        end
        
        -- Handle race completion based on option
        if race then
            -- Different options indicate different race completion states
            -- This is a stub - implement actual race completion handling as needed
        end
    elseif csid == xi.chocoboRacing.events.SPECTATE_EVENT then
        -- Spectator event completions
        -- This is a stub - implement spectator completions as needed
    end
end
