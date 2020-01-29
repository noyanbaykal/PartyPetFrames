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

-- This class is responsible for handling incoming party events and in some cases determining
-- the state of party pet frames.

local REF_PARTY_SIZE = PPF_C.REF_PARTY_SIZE
local REF_PARTY = PPF_C.REF_PARTY

local frameName = PPF_C.PPF_NAME..'FrameManager'

PetFrameManager = {}

PetFrameManager.new = function()
  local self = {}

  local frame = CreateFrame(PPF_C.UIOBJECT_TYPE, frameName, UIParent)
  frame:Hide()

  local registeredToRegenEvents = false -- to avoid registering multiple times

  -- This will be used as a callback by the powerBars to let us know that our state is dirty
  local RequestAwaitRegen = function()
    if not registeredToRegenEvents then
      frame:RegisterEvent(PPF_C.EVENT_REGEN)
      registeredToRegenEvents = true
    end
  end

  local function CombatEnded(event)
    frame:UnregisterEvent(PPF_C.EVENT_REGEN)
    self.PartyChanged(event)
    registeredToRegenEvents = false
  end

  frame:SetScript(PPF_C.ATTR_ON_EVENT, function(self, event, ...)
    if event == PPF_C.EVENT_REGEN then
      CombatEnded(event)
    end
  end)

  local powerBars = {}
  for i = 1, REF_PARTY_SIZE do
    powerBars[REF_PARTY[i]] = PetPowerBar.new(REF_PARTY[i], RequestAwaitRegen)
  end

  local function GetPartyMemberCount()
    local count = GetNumSubgroupMembers()
    if count < 0 then
      count = 0
    end

    return math.min(count, REF_PARTY_SIZE)
  end

  function self.PartyChanged(event)
    local memberCount = GetPartyMemberCount()

    for i = 1, memberCount do
      powerBars[REF_PARTY[i]].Set(event)
    end

    for i = memberCount + 1, REF_PARTY_SIZE do
      powerBars[REF_PARTY[i]].Clear()
    end
  end

  function self.PlayerToggled(event, reference)
    local disable = event == PPF_C.EVENT_PARTY_DISABLE
    local enable = event == PPF_C.EVENT_PARTY_ENABLE

    if reference == PPF_C.REF_TARGET or not powerBars[reference] or (not disable and not enable) then
      return
    end

    if powerBars[reference].IsPetClass() ~= true then
      powerBars[reference].Hide()
    else
      if disable or UnitOnTaxi(reference) then
        powerBars[reference].Hide()
      else
        powerBars[reference].Show()
      end

      local index = tonumber(string.sub(reference, -1))

      for i = index, GetPartyMemberCount() do
        powerBars[REF_PARTY[i]].FixFramePosition()
      end
    end
  end
  
  function self.UpdatePlayer(event, reference)
    local update = true

    if reference == PPF_C.REF_TARGET then
      update = false
    elseif (event == PPF_C.EVENT_PARTY_PET or event == PPF_C.EVENT_PARTY_RENAME) and
      not REF_PARTY[reference] then
      update = false
    elseif event == PPF_C.EVENT_OTHER_CHANGED or event == PPF_C.EVENT_PORTRAIT_UPDATE
        or event == PPF_C.EVENT_PARTY_POWER or event == PPF_C.EVENT_PARTY_MAXP then
      if PPF_C.REF_PARTY_PET[reference] then
        reference = REF_PARTY[reference]
      elseif not REF_PARTY[reference] then
        update = false
      end
    end

    if update then
      powerBars[reference].Update(event)
    end
  end

  function self.HideAll(event)
    if event == PPF_C.EVENT_CVAR_UPDATE then
      for i = 1, REF_PARTY_SIZE do
        powerBars[REF_PARTY[i]].Hide()
      end
    end
  end

  return self
end

return PetFrameManager
