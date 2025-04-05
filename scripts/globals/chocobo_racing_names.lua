-----------------------------------
-- Chocobo Racing Names
-- Official retail chocobo and jockey names for racing
-----------------------------------
require("settings/default/main")
require("scripts/enum/status")

xi = xi or {}
xi.chocoboRacing = xi.chocoboRacing or {}
xi.chocoboRacing.names = xi.chocoboRacing.names or {}

-- Define race categories here to avoid dependency issues
if not xi.chocoboRacing.raceCategories then
    xi.chocoboRacing.raceCategories = {
        C1 = 1,
        C2 = 2,
        C3 = 3,
        C4 = 4
    }
end

-- Define AI personality types if they don't exist
if not xi.chocoboRacing.aiPersonality then
    xi.chocoboRacing.aiPersonality = {
        CONSERVATIVE = 1,  -- Focuses on consistent pace, less item usage
        AGGRESSIVE = 2,    -- Uses items frequently, pushes speed limits
        TACTICAL = 3,      -- Focuses on positioning and timing item usage
        BALANCED = 4       -- Balanced approach to racing
    }
end

-- Retail Chocobo Names grouped by categories
xi.chocoboRacing.names.chocoboNames = {
    -- C1 Elite Racing Chocobos (Professional Circuit)
    C1 = {
        -- Famous retail chocobos from C1 races
        "Alpha", "MeteorBrian", "InvincibleLeg", "StarOnion", "TwinRidill", 
        "Musashi", "Goldregen", "SpoonyBard", "Tekiro", "LunarHarvester",
        "LahmeEnte", "RasenderBlitz", "Cerulean", "Ecarlate", "YellowFog",
        "Ikezuki", "Hermes", "MegaFlare", "Mercury", "Koloss",
        "Silbernes", "ShilverChariot", "NebulousHarmony", "Turbo", "Orage",
        "Sternenschweif", "Tausendsassa", "Blitzer", "Incarnate", "Unicorn",
        "Atreall", "MalevolentJack", "Majesty", "Shooter", "Cuivre",
        "Vengeur", "Nebula", "Tournesol", "Raiden", "Diamant",
        "Koloss", "Capucine", "Celeste", "Blazing", "Heldin",
        "Gruener", "Typhoon", "Crest", "Vega", "Fury"
    },
    
    -- C2 Intermediate Racing Chocobos
    C2 = {
        -- Strong retail chocobo names for C2 races
        "Boko", "Black", "Gruener", "Duchesse", "Capucine", 
        "Coureur", "Flinke", "Celeste", "Citron", "Bleue", 
        "Frozen", "Highland", "Gagnante", "Rich", "Roughie",
        "Vengeur", "Brave", "Kaiser", "Dream", "Diamant",
        "Craft", "Orageuse", "Grand", "Haru", "Orageux",
        "JoliePouliche", "PlumeauVif", "Arashi", "Audacieux", "Pomme",
        "Beau", "Kluger", "Candide", "Dandy", "Granat",
        "Flora", "Gutes", "Daring", "Silver", "Vive",
        "Good", "Highland", "Positive", "Iris", "Reine",
        "Ace", "Line", "Rhapsody", "Purete", "PouletValliant"
    },
    
    -- C3 Novice Racing Chocobos
    C3 = {
        -- Middle-tier retail chocobo names
        "Rieuse", "RosseMutine", "Shadow", "Natsu", "Held", 
        "Rain", "Frost", "Gale", "Blauer", "Vive", 
        "Fox", "Crete", "Pony", "Feu", "Ninja",
        "Beauty", "Heldin", "Blue", "Premium", "Drafter",
        "Rudolf", "Million", "Grenat", "Purete", "Prodigue",
        "Fubuki", "TurboPiaf", "Typhoon", "Friend", "Tranquille",
        "Nana", "Pretty", "Iron", "Jack", "Mama",
        "Caramel", "Fatty", "Gagnante", "Road", "Pers",
        "Pure", "Ruby", "Sea", "Smalt", "Vert",
        "Wind", "Thunder", "Fer", "Sage", "Soar"
    },
    
    -- C4 Beginner Racing Chocobos
    C4 = {
        -- More common retail chocobo names for beginner races
        "Wing", "Trot", "Sautante", "Mama", "Caramel", 
        "Summer", "Soar", "Breeze", "Rhapsody", "Pretty", 
        "Ace", "Zippy", "Beau", "Positive", "Jack",
        "Crest", "Line", "Flora", "Iris", "Iron",
        "Thunder", "Passer", "Gutes", "Kluger", "Shooter",
        "PouletValliant", "ColonelSaunders", "Rosinante", "Smalt", "Raiden",
        "Cry", "Amber", "Edel", "Fatty", "Lady",
        "Lily", "Luna", "Noir", "Nova", "Pony",
        "Rose", "Ruby", "Snow", "Star", "Tail",
        "Wave", "Wild", "Wing", "Zero", "Gale"
    }
}

-- Additional rare/special/promotional chocobos that occasionally appear in races
xi.chocoboRacing.names.specialChocoboNames = {
    "RapidWing", "Hyperion", "GoldenFeather", "StellarGust", "CrystalTide",
    "EmeraldWind", "ObsidianTalon", "SilverStreak", "CosmicRunner", "PhoenixFlame",
    "ShadowSprint", "FrostFlyer", "TempestRider", "SunChaser", "MoonRunner",
    "DiamondDust", "OpalDash", "AzureFlash", "CrimsonGale", "VerdigrisTalon"
}

-- Retail Jockey Names with race information
-- Race IDs: 1=Hume(M), 2=Hume(F), 3=Elvaan(M), 4=Elvaan(F), 5=Tarutaru(M), 6=Tarutaru(F), 7=Mithra, 8=Galka
xi.chocoboRacing.names.jockeyNames = {
    -- C1 Professional Jockeys
    C1 = {
        {"Fendogg", 8},      {"Vortexstorm", 1},   {"Raxicore", 3},     {"Alraune", 4},
        {"Marberge", 2},     {"Chantou", 7},       {"Morangeart", 3},   {"Pemmelle", 6},
        {"Rebiaque", 4},     {"Moncomble", 8},     {"Bellegrime", 4},   {"Jonomaux", 1},
        {"Faustin", 3},      {"Sharzalion", 1},    {"Rungaga", 5},      {"Stethkopf", 8},
        {"Vilerose", 2},     {"Shredder", 8},      {"Loubashir", 3},    {"Etoilazure", 4},
        {"Delorion", 1},     {"Purrgis", 7},       {"Yatapotam", 5},    {"Champarnaud", 3}
    },
    
    -- C2 Intermediate Jockeys
    C2 = {
        {"Guyenne", 2},      {"Molbert", 1},       {"Boulbous", 6},     {"Yapasou", 5},
        {"Doremile", 7},     {"Bourdieu", 8},      {"Chalsant", 1},     {"Gustavson", 8},
        {"Ferrine", 2},      {"Phippouloux", 3},   {"Raimbault", 1},    {"Laulavin", 4},
        {"Trumote", 5},      {"Pouchkine", 7},     {"Vontadour", 3},    {"Brugiere", 2},
        {"Mallemont", 1},    {"Costepierre", 3},   {"Pillifourche", 5}, {"Grimaudet", 4},
        {"Tigerclaw", 7},    {"Stonefist", 8},     {"Gazeuse", 2},      {"Tortilleur", 1}
    },
    
    -- C3 Novice Jockeys
    C3 = {
        {"Couchant", 1},     {"Katatata", 5},      {"Saloiste", 8},     {"Rubillelle", 4},
        {"Zutrix", 7},       {"Simonault", 1},     {"Farcluze", 2},     {"Menaibuc", 3},
        {"Vaucouront", 3},   {"Poulbas", 8},       {"Trieste", 4},      {"Ouflaiche", 6},
        {"Biroquet", 5},     {"Deslandes", 2},     {"Arable", 7},       {"Pautrain", 1},
        {"Vendelice", 2},    {"Batigoleur", 1},    {"Rondepierre", 3},  {"Mistigri", 7},
        {"Puislavie", 6},    {"Roulaboul", 8},     {"Charmeuse", 4},    {"Grenouillet", 5}
    },
    
    -- C4 Beginner Jockeys
    C4 = {
        {"Fildieu", 1},      {"Vistance", 2},      {"Nillienne", 7},    {"Plustot", 3},
        {"Robel", 8},        {"Coquelicot", 6},    {"Fontaurel", 4},    {"Galbalaix", 5},
        {"Dutruel", 1},      {"Halmontout", 2},    {"Burumba", 8},      {"Saucisson", 4},
        {"Minitrix", 6},     {"Ventdegire", 3},    {"Pourpier", 7},     {"Fauvio", 5},
        {"Trepignou", 1},    {"Camemberte", 2},    {"Gricheux", 5},     {"Malotru", 3},
        {"Pucerose", 7},     {"Florimont", 4},     {"Krapoto", 6},      {"Gronibart", 8}
    }
}

-- Historical records of the most famous jockeys
xi.chocoboRacing.names.legendaryJockeys = {
    -- Format: {name, race, record}
    {"Fendogg", 8, "Most C1 Race Wins (Season 3)"},
    {"Marberge", 2, "All-time TwinRidill Record Holder"},
    {"Rebiaque", 4, "Triple Crown Winner (Season 5)"},
    {"Vortexstorm", 1, "Highest Speed Record (Season 2)"},
    {"Chantou", 7, "Most Consecutive Wins (Season 4)"}
}

-- Retail NPC Chocobos with special stats
xi.chocoboRacing.names.specialChocobos = {
    -- Special chocobos that appear in specific races (usually with very high stats)
    METEORBRIAN = {
        name = "MeteorBrian",
        jockey = "Rebiaque", -- Elvaan Female
        category = xi.chocoboRacing.raceCategories.C1,
        attributes = {
            speed = 120,
            stamina = 115,
            endurance = 110,
            intelligence = 105
        },
        personality = xi.chocoboRacing.aiPersonality.AGGRESSIVE
    },
    
    INVINCIBLELEG = {
        name = "InvincibleLeg",
        jockey = "Moncomble", -- Galka
        category = xi.chocoboRacing.raceCategories.C1,
        attributes = {
            speed = 115,
            stamina = 110,
            endurance = 120,
            intelligence = 105
        },
        personality = xi.chocoboRacing.aiPersonality.TACTICAL
    },
    
    STARONION = {
        name = "StarOnion",
        jockey = "Boulbous", -- Tarutaru Female
        category = xi.chocoboRacing.raceCategories.C1,
        attributes = {
            speed = 110,
            stamina = 120,
            endurance = 105,
            intelligence = 115
        },
        personality = xi.chocoboRacing.aiPersonality.BALANCED
    },
    
    TWINRIDILL = {
        name = "TwinRidill",
        jockey = "Marberge", -- Hume Female
        category = xi.chocoboRacing.raceCategories.C1,
        attributes = {
            speed = 110,
            stamina = 105,
            endurance = 115,
            intelligence = 120
        },
        personality = xi.chocoboRacing.aiPersonality.TACTICAL
    },
    
    GOLDREGEN = {
        name = "Goldregen",
        jockey = "Fendogg", -- Galka
        category = xi.chocoboRacing.raceCategories.C1,
        attributes = {
            speed = 105,
            stamina = 115,
            endurance = 120,
            intelligence = 110
        },
        personality = xi.chocoboRacing.aiPersonality.CONSERVATIVE
    },
    
    LUNARHARVESTER = {
        name = "LunarHarvester",
        jockey = "Chantou", -- Mithra
        category = xi.chocoboRacing.raceCategories.C1,
        attributes = {
            speed = 120,
            stamina = 110,
            endurance = 105,
            intelligence = 115
        },
        personality = xi.chocoboRacing.aiPersonality.AGGRESSIVE
    },
    
    MALEVOLENTJACK = {
        name = "MalevolentJack",
        jockey = "Vortexstorm", -- Hume Male
        category = xi.chocoboRacing.raceCategories.C1,
        attributes = {
            speed = 125,
            stamina = 100,
            endurance = 105,
            intelligence = 115
        },
        personality = xi.chocoboRacing.aiPersonality.AGGRESSIVE
    },
    
    SPOONYBIRD = {
        name = "SpoonyBard",
        jockey = "Sharzalion", -- Hume Male
        category = xi.chocoboRacing.raceCategories.C1,
        attributes = {
            speed = 115,
            stamina = 115,
            endurance = 110,
            intelligence = 115
        },
        personality = xi.chocoboRacing.aiPersonality.BALANCED
    },
    
    COLONELSAUNDERS = {
        name = "ColonelSaunders",
        jockey = "Stethkopf", -- Galka
        category = xi.chocoboRacing.raceCategories.C1,
        attributes = {
            speed = 110,
            stamina = 125,
            endurance = 110,
            intelligence = 100
        },
        personality = xi.chocoboRacing.aiPersonality.CONSERVATIVE
    },
    
    NEBULOUSHARMONY = {
        name = "NebulousHarmony",
        jockey = "Loubashir", -- Elvaan Male
        category = xi.chocoboRacing.raceCategories.C1,
        attributes = {
            speed = 115,
            stamina = 110,
            endurance = 110,
            intelligence = 125
        },
        personality = xi.chocoboRacing.aiPersonality.TACTICAL
    }
}

-- Get a random retail chocobo name for an appropriate race category
xi.chocoboRacing.names.getRandomChocoboName = function(category)
    local categoryTable = xi.chocoboRacing.names.chocoboNames[category] or xi.chocoboRacing.names.chocoboNames.C4
    
    -- Small chance (5%) to use a special promotional name instead
    if math.random(1, 100) <= 5 then
        return xi.chocoboRacing.names.specialChocoboNames[math.random(1, #xi.chocoboRacing.names.specialChocoboNames)]
    end
    
    return categoryTable[math.random(1, #categoryTable)]
end

-- Get a random retail jockey name for an appropriate race category
xi.chocoboRacing.names.getRandomJockeyName = function(category)
    local categoryTable = xi.chocoboRacing.names.jockeyNames[category] or xi.chocoboRacing.names.jockeyNames.C4
    return categoryTable[math.random(1, #categoryTable)]
end

-- Decide whether to use a special chocobo and return its data if chosen
xi.chocoboRacing.names.getSpecialChocobo = function(category)
    -- Special chocobos only appear in C1 races or rarely in C2
    if category ~= xi.chocoboRacing.raceCategories.C1 and category ~= xi.chocoboRacing.raceCategories.C2 then
        return nil
    end
    
    -- 15% chance to include a special chocobo in C1 races, 5% in C2
    local chance = (category == xi.chocoboRacing.raceCategories.C1) and 15 or 5
    if math.random(100) <= chance then
        local specialChocoboKeys = {
            "METEORBRIAN", "INVINCIBLELEG", "STARONION", "TWINRIDILL", 
            "GOLDREGEN", "LUNARHARVESTER", "MALEVOLENTJACK", "SPOONYBIRD",
            "COLONELSAUNDERS", "NEBULOUSHARMONY"
        }
        local selectedKey = specialChocoboKeys[math.random(1, #specialChocoboKeys)]
        return xi.chocoboRacing.names.specialChocobos[selectedKey]
    end
    
    return nil
end

-- Get a random selection of chocobo names for a race
xi.chocoboRacing.names.getRandomChocoboNames = function(count, category)
    -- Default to C4 if no category specified
    category = category or "C4"
    
    -- Select from the appropriate category
    local namePool = xi.chocoboRacing.names.chocoboNames[category] or xi.chocoboRacing.names.chocoboNames.C4
    
    -- Occasionally add a special chocobo name
    if math.random(1, 100) <= 10 then
        -- 10% chance to include a special chocobo
        local specialNames = xi.chocoboRacing.names.specialChocoboNames
        if #specialNames > 0 then
            local specialName = specialNames[math.random(1, #specialNames)]
            -- Replace a random name in the pool with the special name
            local replaceIndex = math.random(1, #namePool)
            namePool[replaceIndex] = specialName
        end
    end
    
    -- Return a random selection of names
    local names = {}
    local indices = {}
    
    -- Create a list of available indices
    for i = 1, #namePool do
        table.insert(indices, i)
    end
    
    -- Select random names
    for i = 1, math.min(count, #namePool) do
        local idx = math.random(1, #indices)
        table.insert(names, namePool[indices[idx]])
        table.remove(indices, idx)
    end
    
    return names
end

-- Get a random jockey name for a race
xi.chocoboRacing.names.getRandomJockeyName = function(category)
    -- Default to C4 if no category specified
    category = category or "C4"
    
    -- Select from the appropriate category
    local jockeyPool = xi.chocoboRacing.names.jockeyNames[category] or xi.chocoboRacing.names.jockeyNames.C4
    
    -- Select a random jockey
    return jockeyPool[math.random(1, #jockeyPool)]
end

-- Get a special chocobo for a race
xi.chocoboRacing.names.getSpecialChocobo = function(category)
    -- Only include special chocobos in appropriate categories
    if category ~= xi.chocoboRacing.raceCategories.C1 then
        -- Very low chance to include special chocobo in lower ranks
        if math.random(1, 100) > 5 then
            return nil
        end
    end
    
    -- Get all special chocobos
    local specialChocobos = {}
    for _, chocobo in pairs(xi.chocoboRacing.names.specialChocobos) do
        if chocobo.category == category then
            table.insert(specialChocobos, chocobo)
        end
    end
    
    -- Return a random special chocobo if available
    if #specialChocobos > 0 then
        return specialChocobos[math.random(1, #specialChocobos)]
    end
    
    return nil
end

return xi.chocoboRacing.names 