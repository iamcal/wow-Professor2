local _VERSION = GetAddOnMetadata('Professor', 'version')

local addon	= LibStub("AceAddon-3.0"):NewAddon("Professor", "AceConsole-3.0", "AceEvent-3.0")
_G.Professor = addon

function addon:OnInitialize()
	addon:RegisterChatCommand("prof", "SlashProcessorFunction")
end


Professor.races = nil
Professor.detailedframe = {}

Professor.COLORS = {
    text   = '|cffaaaaaa';
    common = '|cffffffff';
    rare   = '|cff66ccff';
    total  = '|cffffffff';
}

Professor.Race = {}
Professor.Artifact = {}
function Professor.Race:new(id, name, icon, currency)
    local o = {
                id = id;
                name = name;
                icon = icon;
                currency = currency;

                totalCommon = 0;
                totalRare = 0;

                completedCommon = 0;
                completedRare = 0;
                totalSolves = 0;

                artifacts = {};

                GetString = function(self)
                    return string.format("|T%s:0:0:0:0:64:64:0:38:0:38|t %s%s|r", self.icon, _G['ORANGE_FONT_COLOR_CODE'], self.name)
                end;

                AddArtifact = function(self, name, icon, spellId, itemId, rare, fragments)
                    local anArtifact = Professor.Artifact:new(name, icon, spellId, itemId, rare, fragments)

                    if anArtifact.rare then
                        self.totalRare = self.totalRare + 1
                    else
                        self.totalCommon = self.totalCommon + 1
                    end


                    -- We can't identify artifacts by name, because in some locales the spell and artifact names are slightly different, and we can't use GetItemInfo because it's unreliable
                    self.artifacts[icon] = anArtifact
                end;

                UpdateHistory = function(self)
                    local artifactCount = GetNumArtifactsByRace(self.id)

                    local artifactIndex = 1
                    local done = false

                    self.completedCommon = 0
                    self.completedRare = 0
                    self.totalSolves = 0

                    repeat
                        local name, description, rarity, icon, spellDescription,  _, _, firstComletionTime, completionCount = GetArtifactInfoByRace(self.id, artifactIndex)

                        artifactIndex = artifactIndex + 1
                        if name then

                            if completionCount > 0 then
                                self.artifacts[icon].firstComletionTime = firstComletionTime
                                self.artifacts[icon].solves = completionCount

                                if rarity == 0 then
                                    self.completedCommon = self.completedCommon + 1
                                else
                                    self.completedRare = self.completedRare + 1
                                end

                                self.totalSolves = self.totalSolves + completionCount
                            end
                        else
                            done = true
                        end
                    until done
                end;
        }

    setmetatable(o, self)
    self.__index = self
    return o
end

function Professor.Artifact:new(name, icon, spellId, itemId, rare, fragments)

    local o = {
        name = name;
        icon = icon;
        spellId = spellId;
        itemId = itemId;
        rare = rare;
        fragments = fragments;

        firstComletionTime = nil;
        solves = 0;
    }

    setmetatable(o, self)
    self.__index = self
    return o
end



function addon:LoadRaces()
    local raceCount = GetNumArchaeologyRaces()
    self.races = {}

    currencies = {384, 398, 393, 394, 400, 397, 401, 385, 399}

    for raceIndex=1, raceCount do
        local raceName, raceTexture, _, _ = GetArchaeologyRaceInfo(raceIndex)

        local currencyId = currencies[raceIndex]

        if currencyId then
            local currencyName, _, currencyTexture = GetCurrencyInfo(currencyId)

            local currency = {
                id = currencyId;
                name = currencyName;
                icon = currencyTexture;
            }
            local aRace = Professor.Race:new(raceIndex, raceName, raceTexture, currency)

            for i, artifact in ipairs( Professor.artifactDB[aRace.currency.id] ) do
                local itemId, spellId, rarity, fragments = unpack(artifact)
                local name, _, icon = GetSpellInfo(spellId)
                aRace:AddArtifact(name, icon, spellId, itemId, (rarity == 1), fragments)
            end

            self.races[raceIndex] = aRace

        end
    end
end


function addon:UpdateHistory()

    for raceIndex, race in ipairs(self.races) do
        race:UpdateHistory()
    end
end



function addon:PrintDetailed(raceId)

    local race = self.races[raceId]

    print()
    print( race:GetString() )

    local incomplete, rare, therest = {}, {}, {}

    for icon, artifact in pairs(race.artifacts) do

        local link = GetSpellLink(artifact.spellId)

        if artifact.solves == 0 then
            table.insert(incomplete, "  |cffaa3333×|r  " .. link )
        elseif artifact.rare then
            table.insert(rare, "  |cff3333aa+|r  " .. link )
        else
            table.insert(therest, "  |cff33aa33+|r  " .. link .. self.COLORS.text .. "×" .. artifact.solves .. "|r" )
        end
    end

    for _, artifactString in ipairs(incomplete) do print(artifactString) end
    for _, artifactString in ipairs(rare) do print(artifactString) end
    for _, artifactString in ipairs(therest) do print(artifactString) end

end

function addon:PrintSummary()

	
	totalSolves = 0

    for id, race in ipairs(self.races) do
        if race.totalCommon > 0 or self.totalRare > 0 then

			-- Keep track of how many total we've solved
			totalSolves = race.totalSolves + totalSolves

            print( string.format("%s|r%s: %s%d%s/%s%d|r%s, %s%d%s/%s%d|r%s — %s%d|r%s total",

                race:GetString(),

                self.COLORS.text,

                self.COLORS.common, race.completedCommon,
                self.COLORS.text,
                self.COLORS.common, race.totalCommon,

                self.COLORS.text,

                self.COLORS.rare, race.completedRare,
                self.COLORS.text,
                self.COLORS.rare, race.totalRare,

                self.COLORS.text,

                self.COLORS.total, race.totalSolves, self.COLORS.text
            ) )
        end
    end

	print("Total Solves: " .. totalSolves)

end

function addon:OnHistoryReady(event, ...)
    if IsArtifactCompletionHistoryAvailable() then

        if not self.races then
            self:LoadRaces()
        end

        self:UpdateHistory()

        self:action()

        self:UnregisterEvent("ARTIFACT_HISTORY_READY");
    end
end


function addon:SlashProcessorFunction(input)

    local _, _, hasArchaeology = GetProfessions()
    if not hasArchaeology then
		print("You do not have Archaeology learned as a secondary profession.")
		return
	end

    self.action = Professor.PrintSummary

    local state = nil

    for token in string.gmatch(input, "[^%s]+") do

        if state == 'detailed' then
            local raceId = tonumber(token)
            self.action = function () self:PrintDetailed(raceId) end
        end

        if token == 'detailed' then state = 'detailed' end

    end

    self:RegisterEvent("ARTIFACT_HISTORY_READY", "OnHistoryReady");

    RequestArtifactCompletionHistory()

--GameTooltip:SetOwner(UIParent)
--GameTooltip:SetSpellByID(90608)
end





-- Exported from Wowhead. { [racialCurrencyId] = { { itemId, spellId, rarity, fragments }, ... }, ... }
Professor.artifactDB = {
     [384] = {
      { 64373, 90553, 1, 100 },  -- Chalice of the Mountain Kings
      { 64372, 90521, 1, 100 },  -- Clockwork Gnome
      { 64489, 91227, 1, 150 },  -- Staff of Sorcerer-Thane Thaurissan
      { 64488, 91226, 1, 150 },  -- The Innkeeper's Daughter

      { 63113, 88910, 0,  34 },  -- Belt Buckle with Anvilmar Crest
      { 64339, 90411, 0,  35 },  -- Bodacious Door Knocker
      { 63112, 86866, 0,  32 },  -- Bone Gaming Dice
      { 64340, 90412, 0,  34 },  -- Boot Heel with Scrollwork
      { 63409, 86864, 0,  35 },  -- Ceramic Funeral Urn
      { 64362, 90504, 0,  35 },  -- Dented Shield of Horuz Killcrow
      { 66054, 93440, 0,  30 },  -- Dwarven Baby Socks
      { 64342, 90413, 0,  35 },  -- Golden Chamber Pot
      { 64344, 90419, 0,  36 },  -- Ironstar's Petrified Shield
      { 64368, 90518, 0,  35 },  -- Mithril Chain of Angerforge
      { 63414, 89717, 0,  34 },  -- Moltenfist's Jeweled Goblet
      { 64337, 90410, 0,  35 },  -- Notched Sword of Tunadil the Redeemer
      { 63408, 86857, 0,  35 },  -- Pewter Drinking Cup
      { 64659, 91793, 0,  45 },  -- Pipe of Franclorn Forgewright
      { 64487, 91225, 0,  45 },  -- Scepter of Bronzebeard
      { 64367, 90509, 0,  35 },  -- Scepter of Charlga Razorflank
      { 64366, 90506, 0,  35 },  -- Scorched Staff of Shadow Priest Anund
      { 64483, 91219, 0,  45 },  -- Silver Kris of Korl
      { 63411, 88181, 0,  34 },  -- Silver Neck Torc
      { 64371, 90519, 0,  35 },  -- Skull Staff of Shadowforge
      { 64485, 91223, 0,  45 },  -- Spiked Gauntlets of Anvilrage
      { 63410, 88180, 0,  35 },  -- Stone Gryphon
      { 64484, 91221, 0,  45 },  -- Warmaul of Burningeye
      { 64343, 90415, 0,  35 },  -- Winged Helm of Corehammer
      { 63111, 88909, 0,  28 },  -- Wooden Whistle
      { 64486, 91224, 0,  45 },  -- Word of Empress Zoe
      { 63110, 86865, 0,  30 },  -- Worn Hunting Knife
    };
     [385] = {
      { 64377, 90608, 1, 150 },  -- Zin'rokh, Destroyer of Worlds
      { 69824, 98588, 1, 100 },  -- Voodoo Figurine
      { 69777, 98556, 1, 100 },  -- Haunted War Drum

      { 64348, 90429, 0,  35 },  -- Atal'ai Scepter
      { 64346, 90421, 0,  35 },  -- Bracelet of Jade and Coins
      { 63524, 89891, 0,  35 },  -- Cinnabar Bijou
      { 64375, 90581, 0,  35 },  -- Drakkari Sacrificial Knife
      { 63523, 89890, 0,  35 },  -- Eerie Smolderthorn Idol
      { 63413, 89711, 0,  34 },  -- Feathered Gold Earring
      { 63120, 88907, 0,  30 },  -- Fetish of Hir'eek
      { 66058, 93444, 0,  32 },  -- Fine Bloodscalp Dinnerware
      { 64347, 90423, 0,  35 },  -- Gahz'rilla Figurine
      { 63412, 89701, 0,  35 },  -- Jade Asp with Ruby Eyes
      { 63118, 88908, 0,  32 },  -- Lizard Foot Charm
      { 64345, 90420, 0,  35 },  -- Skull-Shaped Planter
      { 64374, 90558, 0,  35 },  -- Tooth with Gold Filling
      { 63115, 88262, 0,  27 },  -- Zandalari Voodoo Doll
    };
     [393] = {
      { 69764, 98533, 1, 150 },  -- Extinct Turtle Shell
      { 60955, 89693, 1,  85 },  -- Fossilized Hatchling
      { 60954, 90619, 1, 100 },  -- Fossilized Raptor
      { 69821, 98582, 1, 120 },  -- Pterrodax Hatchling
      { 69776, 98560, 1, 100 },  -- Ancient Amber

      { 64355, 90452, 0,  35 },  -- Ancient Shark Jaws
      { 63121, 88930, 0,  25 },  -- Beautiful Preserved Fern
      { 63109, 88929, 0,  31 },  -- Black Trilobite
      { 64349, 90432, 0,  35 },  -- Devilsaur Tooth
      { 64385, 90617, 0,  33 },  -- Feathered Raptor Arm
      { 64473, 91132, 0,  45 },  -- Imprint of a Kraken Tentacle
      { 64350, 90433, 0,  35 },  -- Insect in Amber
      { 64468, 91089, 0,  45 },  -- Proto-Drake Skeleton
      { 66056, 93442, 0,  30 },  -- Shard of Petrified Wood
      { 66057, 93443, 0,  35 },  -- Strange Velvet Worm
      { 63527, 89895, 0,  35 },  -- Twisted Ammonite Shell
      { 64387, 90618, 0,  35 },  -- Vicious Ancient Fish
    };
     [394] = {
      { 64646, 91761, 1, 150 },  -- Bones of Transformation
      { 64361, 90493, 1, 100 },  -- Druid and Priest Statue Set
      { 64358, 90464, 1, 100 },  -- Highborne Soul Mirror
      { 64383, 90614, 1,  98 },  -- Kaldorei Wind Chimes
      { 64643, 90616, 1, 100 },  -- Queen Azshara's Dressing Gown
      { 64645, 91757, 1, 150 },  -- Tyrande's Favorite Doll
      { 64651, 91773, 1, 150 },  -- Wisp Amulet

      { 64647, 91762, 0,  45 },  -- Carcanet of the Hundred Magi
      { 64379, 90610, 0,  34 },  -- Chest of Tiny Glass Animals
      { 63407, 89696, 0,  35 },  -- Cloak Clasp with Antlers
      { 63525, 89893, 0,  35 },  -- Coin from Eldre'Thalas
      { 64381, 90611, 0,  35 },  -- Cracked Crystal Vial
      { 64357, 90458, 0,  35 },  -- Delicate Music Box
      { 63528, 89896, 0,  35 },  -- Green Dragon Ring
      { 64356, 90453, 0,  35 },  -- Hairpin of Silver and Malachite
      { 63129, 89009, 0,  30 },  -- Highborne Pyxis
      { 63130, 89012, 0,  30 },  -- Inlaid Ivory Comb
      { 64354, 90451, 0,  35 },  -- Kaldorei Amphora
      { 66055, 93441, 0,  30 },  -- Necklace with Elune Pendant
      { 63131, 89014, 0,  30 },  -- Scandalous Silk Nightgown
      { 64382, 90612, 0,  35 },  -- Scepter of Xavius
      { 63526, 89894, 0,  35 },  -- Shattered Glaive
      { 64648, 91766, 0,  45 },  -- Silver Scroll Case
      { 64378, 90609, 0,  35 },  -- String of Small Pink Pearls
      { 64650, 91769, 0,  45 },  -- Umbra Crescent
    };
     [397] = {
      { 64644, 90843, 1, 130 },  -- Headdress of the First Shaman

      { 64436, 90831, 0,  45 },  -- Fiendish Whip
      { 64421, 90734, 0,  45 },  -- Fierce Wolf Figurine
      { 64418, 90728, 0,  45 },  -- Gray Candle Stub
      { 64417, 90720, 0,  45 },  -- Maul of Stone Guard Mur'og
      { 64419, 90730, 0,  45 },  -- Rusted Steak Knife
      { 64420, 90732, 0,  45 },  -- Scepter of Nekros Skullcrusher
      { 64438, 90833, 0,  45 },  -- Skull Drinking Cup
      { 64437, 90832, 0,  45 },  -- Tile of Glazed Clay
      { 64389, 90622, 0,  45 },  -- Tiny Bronze Scorpion
    };
     [398] = {
      { 64456, 90983, 1, 124 },  -- Arrival of the Naaru
      { 64457, 90984, 1, 130 },  -- The Last Relic of Argus

      { 64440, 90853, 0,  45 },  -- Anklet with Golden Bells
      { 64453, 90968, 0,  46 },  -- Baroque Sword Scabbard
      { 64442, 90860, 0,  45 },  -- Carved Harp of Exotic Wood
      { 64455, 90975, 0,  45 },  -- Dignified Portrait
      { 64454, 90974, 0,  44 },  -- Fine Crystal Candelabra
      { 64458, 90987, 0,  45 },  -- Plated Elekk Goad
      { 64444, 90864, 0,  46 },  -- Scepter of the Nathrezim
      { 64443, 90861, 0,  46 },  -- Strange Silver Paperweight
    };
     [399] = {
      { 64460, 90997, 1, 130 },  -- Nifflevar Bearded Axe
      { 69775, 98569, 1, 100 },  -- Vrykul Drinking Horn

      { 64464, 91014, 0,  45 },  -- Fanged Cloak Pin
      { 64462, 91012, 0,  45 },  -- Flint Striker
      { 64459, 90988, 0,  45 },  -- Intricate Treasure Chest Key
      { 64461, 91008, 0,  45 },  -- Scramseax
      { 64467, 91084, 0,  45 },  -- Thorned Necklace
    };
     [400] = {
      { 64481, 91214, 1, 140 },  -- Blessing of the Old God
      { 64482, 91215, 1, 140 },  -- Puzzle Box of Yogg-Saron

      { 64479, 91209, 0,  45 },  -- Ewer of Jormungar Blood
      { 64477, 91191, 0,  45 },  -- Gruesome Heart Box
      { 64476, 91188, 0,  45 },  -- Infested Ruby Ring
      { 64475, 91170, 0,  45 },  -- Scepter of Nezar'Azret
      { 64478, 91197, 0,  45 },  -- Six-Clawed Cornice
      { 64474, 91133, 0,  45 },  -- Spidery Sundial
      { 64480, 91211, 0,  45 },  -- Vizier's Scrawled Streamer
    };
     [401] = {
      { 60847, 92137, 1, 150 },  -- Crawling Claw
      { 64881, 92145, 1, 150 },  -- Pendant of the Scarab Storm
      { 64904, 92168, 1, 150 },  -- Ring of the Boy Emperor
      { 64883, 92148, 1, 150 },  -- Scepter of Azj'Aqir
      { 64885, 92163, 1, 150 },  -- Scimitar of the Sirocco
      { 64880, 92139, 1, 150 },  -- Staff of Ammunae

      { 64657, 91790, 0,  45 },  -- Canopic Jar
      { 64652, 91775, 0,  45 },  -- Castle of Sand
      { 64653, 91779, 0,  45 },  -- Cat Statue with Emerald Eyes
      { 64656, 91785, 0,  45 },  -- Engraved Scimitar Hilt
      { 64658, 91792, 0,  45 },  -- Sketch of a Desert Palace
      { 64654, 91780, 0,  45 },  -- Soapstone Scarab Necklace
      { 64655, 91782, 0,  45 },  -- Tiny Oasis Mosaic
    };
}
