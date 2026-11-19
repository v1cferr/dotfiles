---@diagnostic disable: undefined-global -- WoW API and Prat are globals of the game client
-- Prat Player Icons: class icon, then race icon, before each "[level:Name]" in Prat chat.
-- Prat writes the level and the name; this only fills one message section that sits before them.
local SECTION = "PLAYERICONS"
local SIZE = 14

-- GetPlayerInfoByGUID returns the race file name; a few differ from the atlas name.
local RACE_ATLAS = { scourge = "undead", zandalaritroll = "zandalari",
  highmountaintauren = "highmountain", lightforgeddraenei = "lightforged" }
local SEX = { [2] = "male", [3] = "female" }

local function secret(v) return issecretvalue and issecretvalue(v) end

local function atlas(name)
  if C_Texture.GetAtlasInfo(name) then return CreateAtlasMarkup(name, SIZE, SIZE, 0, -2) end
  return ""
end

local cache = {} -- GUID -> markup; a player's class, race and sex never change
local function icons(guid)
  if cache[guid] then return cache[guid] end
  local _, class, _, race, sex = GetPlayerInfoByGUID(guid)
  if not class or secret(class) or secret(race) or secret(sex) then return nil end
  local out = atlas(GetClassAtlas(class))
  if race and SEX[sex] then
    race = race:lower()
    out = out .. atlas(("raceicon-%s-%s"):format(RACE_ATLAS[race] or race, SEX[sex]))
  end
  cache[guid] = out
  return out
end

-- Before the "[" that opens the player link, so the icons stay outside the brackets.
Prat.RegisterMessageItem(SECTION, "pP", "before")

local handler = {}
function handler:Prat_FrameMessage(_, message)
  local guid = message.GUID
  if not guid or secret(guid) or guid == "" then return end
  local markup = icons(guid)
  if markup and markup ~= "" then message[SECTION] = markup .. " " end
end
Prat.RegisterChatEvent(handler, "Prat_FrameMessage")
