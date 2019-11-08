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

luaUnit = require('luaunit')

package.path = package.path .. ";../?.lua"
require('utils.Constants')
require('modules.PetPowerBar')

local ATTR_SHOW = 'Show'
local ATTR_HIDE = 'Hide'
local ATTR_GET_WIDTH = 'GetWidth'
local ATTR_GET_HEIGHT = 'GetHeight'
local ATTR_SET_COLOR_TEXTURE = 'SetColorTexture'
local ATTR_SET_ALL_POINTS = 'SetAllPoints'
local ATTR_SET_FRAME_STRATA = 'SetFrameStrata'
local ATTR_CREATE_TEXTURE = 'CreateTexture'
local ATTR_SET_SIZE = 'SetSize'
local ATTR_CLEAR_ALL_POINTS = 'ClearAllPoints'
local ATTR_SET_POINT = 'SetPoint'
local ATTR_IS_VISIBLE = 'IsVisible'

local PLAYER_INDEX = 1
local PLAYER_REFERENCE = PPF_C.REF_PARTY[1]
local PET_REFERENCE = PLAYER_REFERENCE..PPF_C.PET_SUFFIX

local MOCK_VARIABLE_WAS_ACCESSED = 187 -- Random value used for very simple assertions

local MOCK_HEALTH_BAR_FRAME_WIDTH = 75
local MOCK_HEALTH_BAR_FRAME_HEIGHT = 20
local MOCK_POWER_MAX = 100
local MOCK_POWER_TYPE = 0
local MOCK_POWER_COLOR = {['r'] = 0, ['g'] = 0, ['b'] = 1}

local mockPetFrame
local mockHealthBar
local mockNameFrame
local mockPowerBarFrame
local mockPlayerFrame
local mockPetFrameAbove
local mockDrawFunctionCalled -- This array will be used to track function invocations made by
-- the PowerBar.Draw method

-- These simple mocks are meant to track that the expected functions are called once
-- and once only. If the functions we expected to be called were called, they will
-- have changed into pointing to the MOCK_VARIABLE_WAS_ACCESSED value and we can
-- assert on this conversion. Setups for more complicated asserts will be done separately
-- in individual test cases.
local function MockPetFrame(mockDrawDependencies)
    local petFrame = {}

    petFrame[ATTR_SHOW] = function()
        if mockDrawDependencies then
            mockDrawFunctionCalled[#mockDrawFunctionCalled + 1] = ATTR_SHOW
        else
            petFrame[ATTR_SHOW] = MOCK_VARIABLE_WAS_ACCESSED
        end
    end

    petFrame[ATTR_HIDE] = function()
        if mockDrawDependencies then
            mockDrawFunctionCalled[#mockDrawFunctionCalled + 1] = ATTR_HIDE
        else
            petFrame[ATTR_HIDE] = MOCK_VARIABLE_WAS_ACCESSED
        end
    end

    petFrame[ATTR_CLEAR_ALL_POINTS] = function()
        petFrame[ATTR_CLEAR_ALL_POINTS] = MOCK_VARIABLE_WAS_ACCESSED
    end

    petFrame[ATTR_SET_POINT] = function()
        petFrame[ATTR_SET_POINT] = MOCK_VARIABLE_WAS_ACCESSED
    end

    return petFrame
end

local function MockPetNameFrame()
    local petNameFrame = {}

    petNameFrame[ATTR_SHOW] = function()
        petNameFrame[ATTR_SHOW] = MOCK_VARIABLE_WAS_ACCESSED
    end

    return petNameFrame
end

local function MockPowerBarFrame(mockDrawDependencies)
    local frame = {}
    local texture = {}

    frame[ATTR_SET_FRAME_STRATA] = function()
        frame[ATTR_SET_FRAME_STRATA] = MOCK_VARIABLE_WAS_ACCESSED
    end

    frame[ATTR_CREATE_TEXTURE] = function()
        frame[ATTR_CREATE_TEXTURE] = MOCK_VARIABLE_WAS_ACCESSED

        return texture
    end

    frame[ATTR_SHOW] = function()
        frame[ATTR_SHOW] = MOCK_VARIABLE_WAS_ACCESSED
    end

    if mockDrawDependencies then
        texture[ATTR_SET_COLOR_TEXTURE] = function()
            mockDrawFunctionCalled[#mockDrawFunctionCalled + 1] = ATTR_SET_COLOR_TEXTURE
        end
    
        texture[ATTR_SET_ALL_POINTS] = function()
            mockDrawFunctionCalled[#mockDrawFunctionCalled + 1] = ATTR_SET_ALL_POINTS
        end

        frame[ATTR_SET_SIZE] = function()
            mockDrawFunctionCalled[#mockDrawFunctionCalled + 1] = ATTR_SET_SIZE
        end

        frame[ATTR_CLEAR_ALL_POINTS] = function()
            mockDrawFunctionCalled[#mockDrawFunctionCalled + 1] = ATTR_CLEAR_ALL_POINTS
        end

        frame[ATTR_SET_POINT] = function()
            mockDrawFunctionCalled[#mockDrawFunctionCalled + 1] = ATTR_SET_POINT
        end
    end

    return frame
end

local function MockHealthBarFrame()
    local healthBarFrame = {}

    healthBarFrame[ATTR_GET_WIDTH] = function()
        mockDrawFunctionCalled[#mockDrawFunctionCalled + 1] = ATTR_GET_WIDTH
        return MOCK_HEALTH_BAR_FRAME_WIDTH
    end

    healthBarFrame[ATTR_GET_HEIGHT] = function()
        mockDrawFunctionCalled[#mockDrawFunctionCalled + 1] = ATTR_GET_HEIGHT
        return MOCK_HEALTH_BAR_FRAME_HEIGHT
    end

    return healthBarFrame
end

local function MockPlayerFrame()
    local playerFrame = {}

    playerFrame[ATTR_CLEAR_ALL_POINTS] = function()
        playerFrame[ATTR_CLEAR_ALL_POINTS] = MOCK_VARIABLE_WAS_ACCESSED
    end

    playerFrame[ATTR_SET_POINT] = function()
        playerFrame[ATTR_SET_POINT] = MOCK_VARIABLE_WAS_ACCESSED
    end

    return playerFrame
end

local function MockPetFrameAbove()
    local petFrameAbove = {}

    petFrameAbove[ATTR_IS_VISIBLE] = function()
        petFrameAbove[ATTR_IS_VISIBLE] = MOCK_VARIABLE_WAS_ACCESSED
    end

    return petFrameAbove
end

local function SetupInitializationMocks(index, mockDrawDependencies, responseBuffer)
    local expectedPetFrameReference = PPF_C.REF_PET_FRAME[PPF_C.REF_PARTY[index]]
    local expectedPetHealthBarReference = expectedPetFrameReference .. PPF_C.HEALTH_BAR_SUFFIX
    local expectedPetNameReference = expectedPetFrameReference .. PPF_C.PET_NAME_SUFFIX

    if not responseBuffer then
        responseBuffer = {}
    end

    mockPetFrame = MockPetFrame(mockDrawDependencies)
    mockNameFrame = MockPetNameFrame()
    mockPowerBarFrame = MockPowerBarFrame(mockDrawDependencies)

    responseBuffer[expectedPetFrameReference] = mockPetFrame
    responseBuffer[expectedPetNameReference] = mockNameFrame

    if mockDrawDependencies then
        mockDrawFunctionCalled = {}
        mockHealthBar = MockHealthBarFrame()
        responseBuffer[expectedPetHealthBarReference] = mockHealthBar
    end

    CreateFrame = function()
        return mockPowerBarFrame
    end

    if index > 1 then
        local expectedPartyFrameReference = PPF_C.REF_PARTY_FRAME[PPF_C.REF_PARTY[index]]
        local expectedPetFrameAboveReference = PPF_C.REF_PET_FRAME[PPF_C.REF_PARTY[index - 1]]

        mockPlayerFrame = MockPlayerFrame()
        mockPetFrameAbove = MockPetFrameAbove()

        responseBuffer[expectedPartyFrameReference] = mockPlayerFrame
        responseBuffer[expectedPetFrameAboveReference] = mockPetFrameAbove
    end

    return responseBuffer
end

local function MockUnitCalls(playerReference, petReference, playerPresent, petPresent)
    local mockPresenceFunction = function(reference)
        if reference == playerReference then
            return playerPresent
        elseif reference == petReference then
            return petPresent
        else
            return nil
        end
    end

    UnitGUID = mockPresenceFunction
    UnitExists = mockPresenceFunction

    UnitIsDeadOrGhost = function(reference)
        if reference == playerReference then
            return playerPresence
        else
            return nil
        end
    end

    UnitIsDead = function(reference)
        if reference == petReference then
            return petPresence
        else
            return nil
        end
    end
end

local function MockUnitOnTaxi(isOnTaxi, playerReference)
    if playerReference == nil then
        playerReference = PLAYER_REFERENCE
    end

    UnitOnTaxi = function(reference)
        if reference == playerReference then
            return isOnTaxi
        else
            return false
        end
    end
end

local function MockPowerCalls(petReference)
    local function AssertAndReturn(returnValue)
        return function(reference) 
            luaUnit.assertEquals(reference, petReference)
            return returnValue
        end
    end

    UnitPower = AssertAndReturn(MOCK_POWER_MAX)
    UnitPowerMax = AssertAndReturn(MOCK_POWER_MAX)
    UnitPowerType = AssertAndReturn(MOCK_POWER_TYPE)
    PowerBarColor = { [MOCK_POWER_TYPE] = MOCK_POWER_COLOR }
end

local function ClearAllMocks()
    mockPetFrame = nil
    mockHealthBar = nil
    mockNameFrame = nil
    mockPowerBarFrame = nil
    mockPlayerFrame = nil
    mockPetFrameAbove = nil
    mockDrawFunctionCalled = nil
    _G = nil
    CreateFrame = nil
    UnitClass = nil
    UnitGUID = nil
    UnitExists = nil
    UnitIsDeadOrGhost = nil
    UnitIsDead = nil
    UnitOnTaxi = nil
    UnitPower = nil
    UnitPowerMax = nil
    UnitPowerType = nil
    PowerBarColor = nil
end

TestPetPowerBar = {}

function TestPetPowerBar:setUp()
    _G = SetupInitializationMocks(PLAYER_INDEX)

    UnitClass = function()
        return _, _, PPF_C.CLASS_WARLOCK
    end
end

function TestPetPowerBar:tearDown()
    ClearAllMocks()
end

function TestPetPowerBar:testInitialization()
    local powerBar = PetPowerBar.new(PLAYER_REFERENCE)

    luaUnit.assertEquals(mockPowerBarFrame[ATTR_SET_FRAME_STRATA], MOCK_VARIABLE_WAS_ACCESSED)
    luaUnit.assertEquals(mockPowerBarFrame[ATTR_CREATE_TEXTURE], MOCK_VARIABLE_WAS_ACCESSED)
    luaUnit.assertEquals(mockPowerBarFrame[ATTR_SHOW], MOCK_VARIABLE_WAS_ACCESSED)

    luaUnit.assertEquals(mockNameFrame[ATTR_SHOW], MOCK_VARIABLE_WAS_ACCESSED)
end

function TestPetPowerBar:testShow()
    local powerBar = PetPowerBar.new(PLAYER_REFERENCE)

    powerBar.Show()

    luaUnit.assertEquals(mockPetFrame[ATTR_SHOW], MOCK_VARIABLE_WAS_ACCESSED)
end

function TestPetPowerBar:testHide()
    local powerBar = PetPowerBar.new(PLAYER_REFERENCE)

    powerBar.Hide()

    luaUnit.assertEquals(mockPetFrame[ATTR_HIDE], MOCK_VARIABLE_WAS_ACCESSED)
end

function TestPetPowerBar:testSetUnitClassUnavailable()
    local expectedUnitClassCallCount = 2

    local unitClassCallCount = 0
    UnitClass = function()
        unitClassCallCount = unitClassCallCount + 1
        return nil
    end

    local powerBar = PetPowerBar.new(PLAYER_REFERENCE)

    powerBar.Set(nil)

    luaUnit.assertEquals(mockPetFrame[ATTR_CLEAR_ALL_POINTS], MOCK_VARIABLE_WAS_ACCESSED)
    luaUnit.assertEquals(mockPetFrame[ATTR_SET_POINT], MOCK_VARIABLE_WAS_ACCESSED)
    luaUnit.assertEquals(mockPetFrame[ATTR_HIDE], MOCK_VARIABLE_WAS_ACCESSED)
    luaUnit.assertNotEquals(mockPetFrame[ATTR_SHOW], MOCK_VARIABLE_WAS_ACCESSED)

    luaUnit.assertEquals(unitClassCallCount, expectedUnitClassCallCount)
end

function TestPetPowerBar:testFixFramePosition2()
    local playerIndex = 2
    local playerReference = PPF_C.REF_PARTY[playerIndex]

    UnitClass = function()
        return nil
    end

    _G = SetupInitializationMocks(playerIndex)

    local powerBar = PetPowerBar.new(playerReference)

    powerBar.Set(nil)

    luaUnit.assertEquals(mockPlayerFrame[ATTR_CLEAR_ALL_POINTS], MOCK_VARIABLE_WAS_ACCESSED)
    luaUnit.assertEquals(mockPlayerFrame[ATTR_SET_POINT], MOCK_VARIABLE_WAS_ACCESSED)

    luaUnit.assertEquals(mockPetFrameAbove[ATTR_IS_VISIBLE], MOCK_VARIABLE_WAS_ACCESSED)

    luaUnit.assertEquals(mockPetFrame[ATTR_CLEAR_ALL_POINTS], MOCK_VARIABLE_WAS_ACCESSED)
    luaUnit.assertEquals(mockPetFrame[ATTR_SET_POINT], MOCK_VARIABLE_WAS_ACCESSED)
    luaUnit.assertEquals(mockPetFrame[ATTR_HIDE], MOCK_VARIABLE_WAS_ACCESSED)
end

function TestPetPowerBar:testClear()
    local powerBar = PetPowerBar.new(PLAYER_REFERENCE)

    powerBar.Clear()

    luaUnit.assertEquals(mockPetFrame[ATTR_HIDE], MOCK_VARIABLE_WAS_ACCESSED)
end

function TestPetPowerBar:testIsPetClassWarrior()
    UnitClass = function()
        return _, _, 1
    end

    local powerBar = PetPowerBar.new(PLAYER_REFERENCE)
    
    luaUnit.assertFalse(powerBar.IsPetClass())
end

function TestPetPowerBar:testIsPetClassHunter()
    UnitClass = function()
        return _, _, PPF_C.CLASS_HUNTER
    end

    local powerBar = PetPowerBar.new(PLAYER_REFERENCE)

    luaUnit.assertTrue(powerBar.IsPetClass())
end

function TestPetPowerBar:testIsPetClassWarlock()
    UnitClass = function()
        return _, _, PPF_C.CLASS_WARLOCK
    end

    local powerBar = PetPowerBar.new(PLAYER_REFERENCE)

    luaUnit.assertTrue(powerBar.IsPetClass())
end

function TestPetPowerBar:testUpdateNotPetClass()
    local expectedUnitClassCallCount = 1

    local unitClassCallCount = 0
    UnitClass = function()
        unitClassCallCount = unitClassCallCount + 1
        return _, _, 2
    end

    local powerBar = PetPowerBar.new(PLAYER_REFERENCE)

    powerBar.Set(PPF_C.EVENT_PARTY_FORMED)

    luaUnit.assertNotEquals(mockPetFrame[ATTR_SHOW], MOCK_VARIABLE_WAS_ACCESSED)
    luaUnit.assertEquals(mockPetFrame[ATTR_HIDE], MOCK_VARIABLE_WAS_ACCESSED)

    luaUnit.assertEquals(unitClassCallCount, expectedUnitClassCallCount)
end

local function NoPetClassTestHelper(unitClassIndex, updateEvent, expectedPetFrameHideCallCount)
    UnitClass = function()
        return _, _, unitClassIndex
    end

    local petFrameHideCallCount = 0
    mockPetFrame[ATTR_HIDE] = function()
        petFrameHideCallCount = petFrameHideCallCount + 1
    end

    local powerBar = PetPowerBar.new(PLAYER_REFERENCE)

    powerBar.Set(PPF_C.EVENT_PARTY_FORMED)

    luaUnit.assertEquals(petFrameHideCallCount, expectedPetFrameHideCallCount - 1)

    powerBar.Update(updateEvent)

    luaUnit.assertEquals(petFrameHideCallCount, expectedPetFrameHideCallCount)
    luaUnit.assertNotEquals(mockPetFrame[ATTR_SHOW], MOCK_VARIABLE_WAS_ACCESSED)
end

function TestPetPowerBar:testUpdateDisableEventNotPetClass()
    local unitClassIndex = 4
    local updateEvent = PPF_C.EVENT_PARTY_DISABLE
    local expectedPetFrameHideCallCount = 2

    NoPetClassTestHelper(unitClassIndex, updateEvent, expectedPetFrameHideCallCount)
end

function TestPetPowerBar:testUpdateEnableEventNotPetClass()
    local unitClassIndex = 5
    local updateEvent = PPF_C.EVENT_PARTY_ENABLE
    local expectedPetFrameHideCallCount = 2

    NoPetClassTestHelper(unitClassIndex, updateEvent, expectedPetFrameHideCallCount)
end

function TestPetPowerBar:testUpdateOnTaxiNotPetClass()
    local unitClassIndex = 6
    local updateEvent = PPF_C.EVENT_PARTY_SIZE
    local expectedPetFrameHideCallCount = 2
    local playerOnTaxi = true

    MockUnitOnTaxi(playerOnTaxi)

    NoPetClassTestHelper(unitClassIndex, updateEvent, expectedPetFrameHideCallCount)
end

TestPetPowerBarDraw = {}

function TestPetPowerBarDraw:setUp()
    _G = SetupInitializationMocks(PLAYER_INDEX, true)

    UnitClass = function()
        return _, _, PPF_C.CLASS_WARLOCK
    end
end

function TestPetPowerBarDraw:tearDown()
    ClearAllMocks()
end

local function InitialUpdateShowsTestHelper(playerPresence, petPresence, playerOnTaxi)
    MockUnitCalls(PLAYER_REFERENCE, PET_REFERENCE, playerPresence, petPresence)
    MockUnitOnTaxi(playerOnTaxi)
    MockPowerCalls(PET_REFERENCE)

    local powerBar = PetPowerBar.new(PLAYER_REFERENCE)

    powerBar.Set(PPF_C.EVENT_PARTY_FORMED)

    luaUnit.assertEquals(mockDrawFunctionCalled[#mockDrawFunctionCalled], ATTR_SHOW)

    return powerBar
end

function TestPetPowerBarDraw:testUpdateDisableEvent()
    local playerPresence = true
    local petPresence = true
    local playerOnTaxi = false

    local powerBar = InitialUpdateShowsTestHelper(playerPresence, petPresence, playerOnTaxi)

    powerBar.Update(PPF_C.EVENT_PARTY_DISABLE)

    luaUnit.assertEquals(mockDrawFunctionCalled[#mockDrawFunctionCalled], ATTR_HIDE)
end

function TestPetPowerBarDraw:testUpdateOnTaxi()
    local playerPresence = true
    local petPresence = true
    local playerOnTaxi = false

    local powerBar = InitialUpdateShowsTestHelper(playerPresence, petPresence, playerOnTaxi)

    MockUnitOnTaxi(not playerOnTaxi)

    powerBar.Update(PPF_C.EVENT_PARTY_SIZE)

    luaUnit.assertEquals(mockDrawFunctionCalled[#mockDrawFunctionCalled], ATTR_HIDE)
end

function TestPetPowerBarDraw:testUpdateEnableEvent()
    local playerPresence = true
    local petPresence = true
    local playerOnTaxi = false

    local powerBar = InitialUpdateShowsTestHelper(playerPresence, petPresence, playerOnTaxi)

    MockUnitCalls(PLAYER_REFERENCE, PET_REFERENCE, playerPresence, petPresence)

    powerBar.Update(PPF_C.EVENT_PARTY_ENABLE)

    luaUnit.assertEquals(mockDrawFunctionCalled[#mockDrawFunctionCalled], ATTR_SHOW)
end

function TestPetPowerBarDraw:testUpdateEnableEventPetDoesntExist()
    local playerPresence = true
    local petPresence = true
    local playerOnTaxi = false

    local powerBar = InitialUpdateShowsTestHelper(playerPresence, petPresence, playerOnTaxi)

    MockUnitCalls(PLAYER_REFERENCE, PET_REFERENCE, playerPresence, not petPresence)

    powerBar.Update(PPF_C.EVENT_PARTY_ENABLE)

    luaUnit.assertEquals(mockDrawFunctionCalled[#mockDrawFunctionCalled], ATTR_HIDE)
end

function TestPetPowerBarDraw:testUpdateNearby()
    local playerPresence = true
    local petPresence = true
    local playerOnTaxi = false

    local powerBar = InitialUpdateShowsTestHelper(playerPresence, petPresence, playerOnTaxi)

    powerBar.Update(PPF_C.EVENT_PARTY_SIZE)

    luaUnit.assertEquals(mockDrawFunctionCalled[#mockDrawFunctionCalled], ATTR_SHOW)
end

local function UpdateTestHelper(playerPresence, petPresence)
    local playerOnTaxi = false

    MockUnitCalls(PLAYER_REFERENCE, PET_REFERENCE, playerPresence, petPresence)
    MockUnitOnTaxi(playerOnTaxi)

    return PetPowerBar.new(PLAYER_REFERENCE)
end

function TestPetPowerBarDraw:testUpdatePetAway()
    local playerPresence = true
    local petPresence = false

    local powerBar = UpdateTestHelper(playerPresence, petPresence)

    powerBar.Update(PPF_C.EVENT_PARTY_SIZE)

    luaUnit.assertEquals(mockDrawFunctionCalled[#mockDrawFunctionCalled], ATTR_HIDE)
end

function TestPetPowerBarDraw:testUpdatePlayerAway()
    local playerPresence = false
    local petPresence = true

    local powerBar = UpdateTestHelper(playerPresence, petPresence)

    powerBar.Update(PPF_C.EVENT_PARTY_SIZE)

    luaUnit.assertEquals(mockDrawFunctionCalled[#mockDrawFunctionCalled], ATTR_HIDE)
end

function TestPetPowerBarDraw:testUpdateBothAway()
    local playerPresence = false
    local petPresence = false

    local powerBar = UpdateTestHelper(playerPresence, petPresence)

    powerBar.Update(PPF_C.EVENT_PARTY_SIZE)

    luaUnit.assertEquals(mockDrawFunctionCalled[#mockDrawFunctionCalled], ATTR_HIDE)
end

os.exit(luaUnit.LuaUnit.run())
