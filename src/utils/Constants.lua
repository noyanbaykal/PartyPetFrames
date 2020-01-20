--[[
PartyPetFrames is a World of Warcraft addon that manages party pet frames.

Copyright (C) 2019  Melik Noyan Baykal

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]

-- All addons share the global namespace and global name conflicts are possible.
-- Bundling all constants in a single object to avoid possible conflicts.
PPF_C = {}

PPF_C.PPF_COMMAND = '/ppf'
PPF_C.PPF_NAME = 'PartyPetFrames'
PPF_C.PPF_COMMAND_LINE_NAME = string.upper(PPF_C.PPF_NAME)

PPF_C.UIOBJECT_TYPE = 'Frame'
PPF_C.ATTR_ON_EVENT = 'OnEvent'

-- We'll map state strings to integers that represent addon state
PPF_C.STATE_ON = 'enable' -- These will be used in slash commands too
PPF_C.STATE_OFF = 'disable'

PPF_C.ENUM_STATES = {
  [PPF_C.STATE_OFF] = 0,
  [PPF_C.STATE_ON] = 1
}

-- SavedVariables
PPF_C.SV_GetIsEnabled = function()
  return PPF_IsEnabled
end

PPF_C.SV_SetIsEnabled = function(int)
  PPF_IsEnabled = int
end
-- ~SavedVariables

-- Console variables
-- The party pet frames are hidden behind this cVar. It defaults to 0 and can only be set by an addon.
-- This cvar can not be set in combat.
PPF_C.CVAR_SHOW_PARTY_PETS = 'showPartyPets'
PPF_C.EVENT_SHOW_PARTY_PETS = 'SHOW_PARTY_PETS'

PPF_C.GetShowPartyPets = function()
  return 1 == tonumber(GetCVar(PPF_C.CVAR_SHOW_PARTY_PETS))
end

-- The caller is responsible for ensuring we're out of combat when invoking this
PPF_C.SetShowPartyPets = function(newValue, silent)
  silent = silent or false

  if silent == true then
    SetCVar(PPF_C.CVAR_SHOW_PARTY_PETS, newValue)
  else
    SetCVar(PPF_C.CVAR_SHOW_PARTY_PETS, newValue, PPF_C.EVENT_SHOW_PARTY_PETS)
  end
end

-- We won't be showing anything if the raid style party frames are being used.
PPF_C.CVAR_USE_COMPACT_PARTY_FRAMES = 'useCompactPartyFrames'
-- ~Console variables

-- These indices correspond to the indices returned by UnitClass.
-- Based on https://wowwiki.fandom.com/wiki/API_UnitClass
PPF_C.CLASS_HUNTER = 3
PPF_C.CLASS_WARLOCK = 9

PPF_C.PET_CLASSES = {
  [PPF_C.CLASS_HUNTER] = true,
  [PPF_C.CLASS_WARLOCK] = true,
}

-- These reference strings are used for accessing units
PPF_C.REF_PLAYER = 'player'
PPF_C.REF_PARTY = 'party'
PPF_C.REF_TARGET = 'target'

PPF_C.REF_PARTY_SIZE = 4

-- Party pet references
PPF_C.REF_PARTY_PET_1 = 'partypet1'
PPF_C.REF_PARTY_PET_2 = 'partypet2'
PPF_C.REF_PARTY_PET_3 = 'partypet3'
PPF_C.REF_PARTY_PET_4 = 'partypet4'

PPF_C.REF_PARTY_PET = {
  [PPF_C.REF_PARTY_PET_1] = true,
  [PPF_C.REF_PARTY_PET_2] = true,
  [PPF_C.REF_PARTY_PET_3] = true,
  [PPF_C.REF_PARTY_PET_4] = true,
}
-- ~Party pet references

-- Party member references
PPF_C.REF_PARTY_1 = 'party1'
PPF_C.REF_PARTY_2 = 'party2'
PPF_C.REF_PARTY_3 = 'party3'
PPF_C.REF_PARTY_4 = 'party4'

PPF_C.REF_PARTY = {
  [PPF_C.REF_PARTY_1] = true,
  [PPF_C.REF_PARTY_2] = true,
  [PPF_C.REF_PARTY_3] = true,
  [PPF_C.REF_PARTY_4] = true,
}

-- We'll want to be able to iterate over the party members with an index
PPF_C.REF_PARTY[1] = PPF_C.REF_PARTY_1
PPF_C.REF_PARTY[2] = PPF_C.REF_PARTY_2
PPF_C.REF_PARTY[3] = PPF_C.REF_PARTY_3
PPF_C.REF_PARTY[4] = PPF_C.REF_PARTY_4

-- We'll map party pet references to player references
PPF_C.REF_PARTY[PPF_C.REF_PARTY_PET_1] = PPF_C.REF_PARTY_1
PPF_C.REF_PARTY[PPF_C.REF_PARTY_PET_2] = PPF_C.REF_PARTY_2
PPF_C.REF_PARTY[PPF_C.REF_PARTY_PET_3] = PPF_C.REF_PARTY_3
PPF_C.REF_PARTY[PPF_C.REF_PARTY_PET_4] = PPF_C.REF_PARTY_4
-- ~Party member references

PPF_C.REF_PARTY_FRAME = {
  [PPF_C.REF_PARTY[1]] = 'PartyMemberFrame1',
  [PPF_C.REF_PARTY[2]] = 'PartyMemberFrame2',
  [PPF_C.REF_PARTY[3]] = 'PartyMemberFrame3',
  [PPF_C.REF_PARTY[4]] = 'PartyMemberFrame4',
}

PPF_C.REF_PET_FRAME = {
  [PPF_C.REF_PARTY[1]] = 'PartyMemberFrame1PetFrame',
  [PPF_C.REF_PARTY[2]] = 'PartyMemberFrame2PetFrame',
  [PPF_C.REF_PARTY[3]] = 'PartyMemberFrame3PetFrame',
  [PPF_C.REF_PARTY[4]] = 'PartyMemberFrame4PetFrame',
}

PPF_C.PET_SUFFIX = 'pet'
PPF_C.HEALTH_BAR_SUFFIX = 'HealthBar'
PPF_C.PET_NAME_SUFFIX = 'Name'

-- We'll listen to any changes to this setting during the game.
PPF_C.EVENT_RAID_FRAMES_SETTING = 'USE_RAID_STYLE_PARTY_FRAMES'

-- We'll handle listening to the variable update events separately from the others
PPF_C.EVENT_CVAR_UPDATE = 'CVAR_UPDATE'

PPF_C.EVENT_LOADED = 'ADDON_LOADED'

PPF_C.EVENT_REGEN = 'PLAYER_REGEN_ENABLED'

PPF_C.EVENTS_ADDON = {
  ['loaded'] =        PPF_C.EVENT_LOADED
}

PPF_C.EVENT_PARTY_FORMED =    'GROUP_FORMED'
PPF_C.EVENT_PARTY_JOINED =    'GROUP_JOINED'
PPF_C.EVENT_PARTY_UPDATE =    'GROUP_ROSTER_UPDATE'
PPF_C.EVENT_PARTY_SIZE =      'INSTANCE_GROUP_SIZE_CHANGED'
PPF_C.EVENT_UPDATE_BF =       'UPDATE_ACTIVE_BATTLEFIELD'
PPF_C.EVENT_PARTY_LEFT =      'GROUP_LEFT'
PPF_C.EVENT_ENTERING_WORLD =  'PLAYER_ENTERING_WORLD'
PPF_C.EVENT_PARTY_DISABLE =   'PARTY_MEMBER_DISABLE'
PPF_C.EVENT_PARTY_ENABLE =    'PARTY_MEMBER_ENABLE'
PPF_C.EVENT_OTHER_CHANGED =   'UNIT_OTHER_PARTY_CHANGED'
PPF_C.EVENT_PORTRAIT_UPDATE = 'UNIT_PORTRAIT_UPDATE'
PPF_C.EVENT_PARTY_PET =       'UNIT_PET'
PPF_C.EVENT_PARTY_RENAME =    'LOCALPLAYER_PET_RENAMED'
PPF_C.EVENT_PARTY_POWER =     'UNIT_POWER_UPDATE'
PPF_C.EVENT_PARTY_MAXP =      'UNIT_MAXPOWER'

PPF_C.EVENTS_PARTY = {
  ['gFormed'] =         PPF_C.EVENT_PARTY_FORMED,
  ['gJoined'] =         PPF_C.EVENT_PARTY_JOINED,
  ['gUpdate'] =         PPF_C.EVENT_PARTY_UPDATE,
  ['gSize'] =           PPF_C.EVENT_PARTY_SIZE,
  ['updateBf'] =        PPF_C.EVENT_UPDATE_BF,
  ['gLeft'] =           PPF_C.EVENT_PARTY_LEFT,
  ['enterWorld'] =      PPF_C.EVENT_ENTERING_WORLD,
  ['gDisable'] =        PPF_C.EVENT_PARTY_DISABLE,
  ['gEnable'] =         PPF_C.EVENT_PARTY_ENABLE,
  ['otherChanged'] =    PPF_C.EVENT_OTHER_CHANGED,
  ['portraitUpdate'] =  PPF_C.EVENT_PORTRAIT_UPDATE,
  ['petEvent'] =        PPF_C.EVENT_PARTY_PET,
  ['petRename'] =       PPF_C.EVENT_PARTY_RENAME,
  ['powerEvent'] =      PPF_C.EVENT_PARTY_POWER,
  ['powerMaxEvent'] =   PPF_C.EVENT_PARTY_MAXP,
}

PPF_C.EVENTS_COMBAT = {
  ['regen'] = PPF_C.EVENT_REGEN,
}

-- Registration helpers
local function RegisterEvents(events, frame)
  for enum, event in pairs(events) do
    frame:RegisterEvent(event)
  end
end

local function UnregisterEvents(events, frame)
  for enum, event in pairs(events) do
    frame:UnregisterEvent(event)
  end
end

PPF_C.RegisterAddonEvents = function(frame)
  RegisterEvents(PPF_C.EVENTS_ADDON, frame)
end

PPF_C.RegisterPartyEvents = function(frame)
  RegisterEvents(PPF_C.EVENTS_PARTY, frame)
end

PPF_C.RegisterCombatEvents = function(frame)
  RegisterEvents(PPF_C.EVENTS_COMBAT, frame)
end

PPF_C.UnregisterCombatEvents = function(frame)
  UnregisterEvents(PPF_C.EVENTS_COMBAT, frame)
end
-- ~Registration helpers

return PPF_C
