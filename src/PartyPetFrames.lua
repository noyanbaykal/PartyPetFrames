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

-- This is the main class of the addon. It listens to & propagates events and manages the
-- ShowPartyPets console variable.

-- Forward declaring main variables
local PartyPetFrames, frameManager

-- State
local STATE_ON = PPF_C.STATE_ON
local STATE_OFF = PPF_C.STATE_OFF
local ENUM_STATES = PPF_C.ENUM_STATES

-- Used by delayed first time setup, not available as a slash command
local STATE_DELAYED_SETUP = -1

local function ChangeState(event, newState)
  if newState == ENUM_STATES[STATE_ON] then
    frameManager.PartyChanged(event)
  elseif newState == ENUM_STATES[STATE_OFF] then
    frameManager.HideAll(event)
  end
end

-- Start listening to combat events to be notified when we can run the given command
local function DeferCommand(state)
  if PartyPetFrames.deferredState ~= nil then
    DEFAULT_CHAT_FRAME:AddMessage(PPF_L.TXT_WONT_DEFER)
    return
  end

  if state ~= STATE_DELAYED_SETUP then
    DEFAULT_CHAT_FRAME:AddMessage(PPF_L.TXT_WILL_DEFER)
  end

  PartyPetFrames.deferredState = state
  PPF_C.RegisterCombatEvents(PartyPetFrames)
end

-- Sets the savedVariable and the showPartyPet console variable.
-- If in combat, will have to defer the command because the cvar can't be changed in combat.
local function VisibilityChangeRequested(newState)
  if newState == nil or PPF_C.SV_GetIsEnabled() == newState then
    return
  end

  PPF_C.SV_SetIsEnabled(newState)

  if UnitAffectingCombat(PPF_C.REF_PLAYER) then
    DeferCommand(newState)
  else
    PPF_C.SetShowPartyPets(newState)
  end
end

local function UsingRaidStyle()
  return GetCVarBool(PPF_C.CVAR_USE_COMPACT_PARTY_FRAMES) == true
end

local function FinishLoading()
  local sv_isEnabled = PPF_C.SV_GetIsEnabled()

  -- We can listen to these now
  PPF_C.RegisterPartyEvents(PartyPetFrames)
  PartyPetFrames:RegisterEvent(PPF_C.EVENT_CVAR_UPDATE)

  if sv_isEnabled == ENUM_STATES[STATE_OFF] then
    DEFAULT_CHAT_FRAME:AddMessage(PPF_L.DISABLED(PPF_C.PPF_COMMAND, STATE_ON))
  else
    local onState = ENUM_STATES[STATE_ON]

    if sv_isEnabled == nil then
      PPF_C.SV_SetIsEnabled(onState)
    end
    
    DEFAULT_CHAT_FRAME:AddMessage(PPF_L.LOADED(PPF_C.PPF_COMMAND))

    PPF_C.SetShowPartyPets(onState)
  end
end

-- Not dead which eternal lie
-- Stranger eons death may die
local function ShouldShow()
  local inParty = IsInGroup() or IsInRaid()
  local raidStyle = UsingRaidStyle()
  local showPets = PPF_C.GetShowPartyPets()
  local isEnabled = PPF_C.SV_GetIsEnabled()

  return inParty and not raidStyle and showPets and isEnabled
end
-- ~State

-- Lifecycle functions
local function RegenEnabled(event)
  PPF_C.UnregisterCombatEvents(PartyPetFrames)
  
  local newState = PartyPetFrames.deferredState
  PartyPetFrames.deferredState = nil

  if newState == STATE_DELAYED_SETUP then
    FinishLoading(event)
  else
    PPF_C.SetShowPartyPets(newState)
  end
end

local function VariableUpdate(event, variable, value)
  local showPartyPetsChanged = variable == PPF_C.EVENT_SHOW_PARTY_PETS

  if event == nil or event ~= PPF_C.EVENT_CVAR_UPDATE or variable == nil then
    return
  elseif not showPartyPetsChanged and variable ~= PPF_C.EVENT_RAID_FRAMES_SETTING then
    return
  end

  local newState = ENUM_STATES[STATE_OFF]
  if ShouldShow() then
    newState = ENUM_STATES[STATE_ON];
  end

  ChangeState(event, newState)

  if showPartyPetsChanged then
    local numberValue = tonumber(value), message

    if numberValue == ENUM_STATES[STATE_ON] then
      message = PPF_L.ENABLED(PPF_C.PPF_COMMAND, STATE_OFF)
    elseif numberValue == ENUM_STATES[STATE_OFF] then
      message = PPF_L.DISABLED(PPF_C.PPF_COMMAND, STATE_ON)
    end

    DEFAULT_CHAT_FRAME:AddMessage(message)
  end
end

-- The ShowPartyPets console variable cannot be changed in combat. If this is called in combat,
-- we'll just wait until we are no longer in combat to finish initialization.
local function Loaded(event)
  PartyPetFrames:UnregisterEvent(PPF_C.EVENT_LOADED) -- No need to be called multiple times

  if UnitAffectingCombat(PPF_C.REF_PLAYER) then
    DeferCommand(STATE_DELAYED_SETUP)
  else
    FinishLoading(event)
  end
end
-- ~Lifecycle functions

-- Initialization
-- Events should be propagated to the frameManager only if the addon is enabled and displaying
-- party style frames
local function RouteEvent(functionToCall)
  return function(...)
    if PPF_C.SV_GetIsEnabled() == ENUM_STATES[STATE_ON] and not UsingRaidStyle() then
      functionToCall(...)
    end
  end
end

-- PartyPetFrame.PartyMemberFrame_UpdatePet displays the pet frames even when the pet's are too
-- far away. While in this state, the pet frame tooltip displays the pet's level as ??.
-- In addition, the positioning set by this function causes player debuff icons to overlap with
-- the pet frame.
-- The most reliable way to deal with these shortcomings is to posthook into this function. In terms of
-- long term stability, it is better to leave the function intact and have it call our update
-- function once it's done it's own thing.
local function HookIntoUpdatePet()
  local ogUpdatePet =  PartyMemberFrame_UpdatePet
  PartyMemberFrame_UpdatePet = function(...)
    ogUpdatePet(...)

    RouteEvent(frameManager.PartyChanged)()
  end
end

-- We'll map events to handler functions
local function InitializeEventMap(safe)
  safe = safe or false

  if safe and PartyPetFrames.eventHandler ~= nil then
    return -1;
  end

  local routePartyChanged = RouteEvent(frameManager.PartyChanged)
  local routePlayerToggled = RouteEvent(frameManager.PlayerToggled)
  local routeUpdatePlayer = RouteEvent(frameManager.UpdatePlayer)

  local eventHandler = {}
  eventHandler[PPF_C.EVENTS_ADDON.loaded] =           Loaded
  eventHandler[PPF_C.EVENT_CVAR_UPDATE] =             VariableUpdate
  eventHandler[PPF_C.EVENT_REGEN] =                   RegenEnabled

  eventHandler[PPF_C.EVENTS_PARTY.gFormed] =          routePartyChanged
  eventHandler[PPF_C.EVENTS_PARTY.gJoined] =          routePartyChanged
  eventHandler[PPF_C.EVENTS_PARTY.gUpdate] =          routePartyChanged
  eventHandler[PPF_C.EVENTS_PARTY.gSize] =            routePartyChanged
  eventHandler[PPF_C.EVENTS_PARTY.updateBf] =         routePartyChanged
  eventHandler[PPF_C.EVENTS_PARTY.gLeft] =            routePartyChanged
  eventHandler[PPF_C.EVENTS_PARTY.enterWorld] =       routePartyChanged
  eventHandler[PPF_C.EVENTS_PARTY.gDisable] =         routePlayerToggled
  eventHandler[PPF_C.EVENTS_PARTY.gEnable] =          routePlayerToggled
  eventHandler[PPF_C.EVENTS_PARTY.otherChanged] =     routeUpdatePlayer
  eventHandler[PPF_C.EVENTS_PARTY.portraitUpdate] =   routeUpdatePlayer
  eventHandler[PPF_C.EVENTS_PARTY.petEvent] =         routeUpdatePlayer
  eventHandler[PPF_C.EVENTS_PARTY.petRename] =        routeUpdatePlayer
  eventHandler[PPF_C.EVENTS_PARTY.powerEvent] =       routeUpdatePlayer
  eventHandler[PPF_C.EVENTS_PARTY.powerMaxEvent] =    routeUpdatePlayer

  PartyPetFrames.eventHandler = eventHandler
end

local function InitializeMainFrame()
  PartyPetFrames = CreateFrame(PPF_C.UIOBJECT_TYPE, PPF_C.PPF_NAME, UIParent)
  PartyPetFrames.deferredState = nil

  frameManager = PetFrameManager.new()

  InitializeEventMap()

  PartyPetFrames:SetScript(PPF_C.ATTR_ON_EVENT, function(self, event, ...)
    if self.eventHandler[event] ~= nil then
      self.eventHandler[event](event, ...)
    end
  end)

  PPF_C.RegisterAddonEvents(PartyPetFrames)

  PartyPetFrames:Hide()

  HookIntoUpdatePet()
end

-- The addon entry is right here
local isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
if not isClassic then
  DEFAULT_CHAT_FRAME:AddMessage(PPF_L.TXT_NOT_CLASSIC)
  return
end

-- PartyPetFrames will have these variables set: eventHandler, deferredState
-- deferredState is used if we are in combat when the addon is loaded or when we receive a command.
InitializeMainFrame()
-- ~Initialization

-- Slash commands
local function HandleInputCommmands(arg1)
  if arg1 ~= nil then
    local lowercaseArg = string.lower(arg1)

    if ENUM_STATES[lowercaseArg] ~= nil then
      VisibilityChangeRequested(ENUM_STATES[lowercaseArg])
      return
    end
  end

  DEFAULT_CHAT_FRAME:AddMessage(PPF_L.COMMANDS(PPF_C.PPF_COMMAND, STATE_ON, STATE_OFF))
end

SLASH_PARTYPETFRAMES1 = PPF_C.PPF_COMMAND
SlashCmdList[PPF_C.PPF_COMMAND_LINE_NAME] = HandleInputCommmands
-- ~Slash commands
