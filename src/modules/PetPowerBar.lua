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

-- This class is responsible for determining whether a party member's pet frame should be shown
-- or hidden and drawing the party pet power bar.

local KEY_PET_CLASS = 'petClass'

local POWER_BAR_SUFFIX = 'PowerBar'

local PET_FRAME_ANCHOR_POINT = 'TOPLEFT'
local POWER_BAR_ANCHOR_POINT = 'LEFT'
local POWER_BAR_STRATA = 'LOW'
local POWER_BAR_TEXTURE_LAYER = 'BACKGROUND'
local POWER_BAR_ALPHA = 1
-- The bar offset is used to better position the power bar inside the existing StatusBar texture
local POWER_BAR_TEXTURE_OFFSET = 0.04
local PLAYER_FRAME_ANCHOR_POINT = 'TOPLEFT'
local PLAYER_FRAME_RELATIVE_POINT = 'BOTTOMLEFT'
local PLAYER_FRAME_OFFSET_X = -35
local PLAYER_FRAME_OFFSET_Y = -8
local PLAYER_FRAME_OFFSET_Y_UP = 15 -- This is used when the above pet frame is hidden
local PET_FRAME_OFFSET_X = 35
local PET_FRAME_OFFSET_Y = -53

PetPowerBar = {}

PetPowerBar.new = function(argPlayerRef, regenCallback)
  local self = {}
  
  -- Initialization
  -- Forward declaring the reference variables
  local petFrame, playerReference, playerIndex, petReference, petFrameReference,
    petHealthBarReference, powerBarFrameReference, RequestAwaitRegen

  local function PowerBarInitialize()
    petFrame = _G[petFrameReference]
    local healthBar = _G[petHealthBarReference]

    local frame = CreateFrame(PPF_C.UIOBJECT_TYPE, powerBarFrameReference, healthBar)
    frame:SetFrameStrata(POWER_BAR_STRATA)
    frame.texture = frame:CreateTexture(nil, POWER_BAR_TEXTURE_LAYER)
    frame:Show()

    return frame
  end

  -- These reference strings are tied to the party member index this frame corresponds to
  -- and won't be modified.
  playerReference = argPlayerRef
  playerIndex = tonumber(string.sub(playerReference, -1))
  petReference = playerReference..PPF_C.PET_SUFFIX
  petFrameReference = PPF_C.REF_PET_FRAME[playerReference]
  petHealthBarReference = petFrameReference..PPF_C.HEALTH_BAR_SUFFIX
  powerBarFrameReference = petFrameReference..POWER_BAR_SUFFIX

  RequestAwaitRegen = regenCallback

  local powerBar = PowerBarInitialize()
  -- ~Initialization

  -- Instead of calling protected functions in combat, we'll let the frame manager know
  -- that our state is dirty
  local function CheckCombat()
    if InCombatLockdown() then
      if RequestAwaitRegen ~= nil then
        RequestAwaitRegen()
      end

      return false
    end

    return true
  end

  -- Helper functions for displaying the power bar
  local function RoundToPixelCount(count)
    if count == 0 then
      return count
    elseif count > 0 and count < 1 then
      return 1
    else
      return math.floor(0.5 + count)
    end
  end
  
  local function GetPowerBarDrawWidth(power, powerMax, width, offset)
    if powerMax == nil or powerMax <= 0 or power == nil then
      return 0
    end
  
    local percentage = power * 100 / powerMax
    if percentage < 0 then
      percentage = 0
    elseif percentage > 100 then
      percentage = 100
    end
  
    return RoundToPixelCount((width - offset) * percentage / 100)
  end

  local function GetBoundedPowerValues()
    local petPower = UnitPower(petReference)
    local petPowerMax = UnitPowerMax(petReference)
  
    -- Avoid bad display values
    if not petPower or not petPowerMax or petPower < 0 or petPowerMax < 0 then
      petPower = 0
      petPowerMax = 100
    elseif petPower > petPowerMax then
      petPower = petPowerMax
    end

    return petPower, petPowerMax
  end

  local function GetPowerRGB()
    local petPowerType = UnitPowerType(petReference)
    local colors = PowerBarColor[petPowerType]
    if colors == nil then
      colors = PowerBarColor[0]
    end
  
    return colors.r, colors.g, colors.b
  end
  -- ~Helper functions for displaying the power bar

  function self.Show()
    if CheckCombat() then
      petFrame:Show()
    end
  end

  function self.Hide()
    if CheckCombat() then
      petFrame:Hide()
    end
  end

  local function Draw()
    local healthBar = _G[petHealthBarReference]
    local barWidth = healthBar:GetWidth()
    local barHeight = healthBar:GetHeight()
    local barOffset = barWidth * POWER_BAR_TEXTURE_OFFSET
    local petPower, petPowerMax = GetBoundedPowerValues()

    local drawWidth = GetPowerBarDrawWidth(petPower, petPowerMax, barWidth, barOffset)
    local r, g, b = GetPowerRGB()

    powerBar:SetSize(drawWidth, barHeight)
    powerBar:ClearAllPoints()
    powerBar:SetPoint(POWER_BAR_ANCHOR_POINT, 0, -1 * barHeight)
    powerBar.texture:SetColorTexture(r, g, b, POWER_BAR_ALPHA)
    powerBar.texture:SetAllPoints(powerBar)

    self:Show()
  end

  function self.IsPetClass()
    return PPF_C.PET_CLASSES[select(3, UnitClass(playerReference))] or false
  end

  local function SetPetClass()
    local classIndex = select(3, UnitClass(playerReference))
    if classIndex ~= nil then
      self[KEY_PET_CLASS] = PPF_C.PET_CLASSES[classIndex] or false
    end
  end

  local function CheckPresence()
    local player = UnitGUID(playerReference) and UnitExists(playerReference)
      and not UnitIsDeadOrGhost(playerReference)

    local pet = UnitGUID(petReference) and UnitExists(petReference)
    and not UnitIsDead(petReference)
    
    return player and pet
  end

  function self.Update(event)
    -- This redundant check is needed to handle cases where the UnitClass was not available during our Set() call.
    -- UnitClass may return nil if the player logs into the game and has party pets nearby.
    if self[KEY_PET_CLASS] == nil then
      SetPetClass()
    end

    -- The draw function is invoked with a pcall just to be safe in unexpected edge cases
    if event == PPF_C.EVENT_PARTY_DISABLE or not self[KEY_PET_CLASS] or UnitOnTaxi(playerReference) then
      self.Hide()
    elseif CheckPresence() then
      if not pcall(Draw) then
        self.Hide()
      end
    else
      self.Hide()
    end
  end

  function self.Set(event)
    SetPetClass()

    self.Update(event)
  end

  function self.Clear()
    self[KEY_PET_CLASS] = nil
    self.Hide()
  end

  return self
end

return PetPowerBar
