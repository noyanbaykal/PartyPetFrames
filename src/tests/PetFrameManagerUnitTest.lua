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
require('modules.PetFrameManager')

local ATTR_NEW = 'new'
local ATTR_SET = 'Set'
local ATTR_CLEAR = 'Clear'
local ATTR_IS_PET_CLASS = 'IsPetClass'
local ATTR_HIDE = 'Hide'
local ATTR_SHOW = 'Show'
local ATTR_FIX_FRAME_POSITION = 'FixFramePosition'
local ATTR_UPDATE = 'Update'
-- The attributes below do not exist in the PetPowerBar class, they are used here for convenience
local ATTR_ID = 'id'
local ATTR_INVOCATIONS = 'invocations'
local ATTR_PET_CLASS = 'petClass'
local ATTR_SET_SCRIPT = 'SetScript'
local ATTR_REGISTER_EVENT = 'RegisterEvent'
local ATTR_UNREGISTER_EVENT = 'UnregisterEvent'
local ATTR_ON_EVENT_FUNCTION = 'respond'
local ATTR_REGEN_CALLBACK = 'RegenCallback'

local ON_EVENT_HANDLER_STRING = 'OnEvent'
local INVOCATION_ARGUMENT_DELIMITER = ';'
local PLAYER_REFERENCE = PPF_C.REF_PARTY[1]
local TARGET_REFERENCE = 'target'
local INVALID_REFERENCE = 'party5'

local ERROR_INVALID_VARIABLE = function(expected, variable)
    return string.format('Expect to receive %s only! Got: %s', expected, variable)
end

local mockPetPowerBar
local mockedPowerBars
local mockFrame

local petFrameManager

TestPetFrameManager = {}

local function MockDependencies(onTaxi, partySize)
    UnitOnTaxi = function()
        return onTaxi
    end

    GetNumSubgroupMembers = function()
        return partySize
    end
end

local function MockFrame()
    local invocations = {}

    mockFrame = {}

    mockFrame[ATTR_SET_SCRIPT] = function(self, handler, func)
        if handler ~= ON_EVENT_HANDLER_STRING then
            error(ERROR_INVALID_VARIABLE(ON_EVENT_HANDLER_STRING, handler))
        end

        mockFrame[ATTR_ON_EVENT_FUNCTION] = func
        invocations[#invocations + 1] = ATTR_SET_SCRIPT
    end

    mockFrame[ATTR_REGISTER_EVENT] = function(self, event)
        luaUnit.assertEquals(PPF_C.EVENT_REGEN, event)
        invocations[#invocations + 1] = ATTR_REGISTER_EVENT
    end

    mockFrame[ATTR_UNREGISTER_EVENT] = function(self, event)
        luaUnit.assertEquals(PPF_C.EVENT_REGEN, event)
        invocations[#invocations + 1] = ATTR_UNREGISTER_EVENT
    end

    mockFrame[ATTR_HIDE] = function()
        invocations[#invocations + 1] = ATTR_HIDE
    end

    mockFrame[ATTR_INVOCATIONS] = invocations

    CreateFrame = function()
        return mockFrame
    end
end

local function BroadcastEvent(...)
    mockFrame[ATTR_ON_EVENT_FUNCTION](mockFrame, ...)
end

local function GetStringInvocationWithEvent(functionName, event)
    return string.format('%s%s%s', functionName, INVOCATION_ARGUMENT_DELIMITER, event) 
end

local function InitializeMockedPetPowerBar()
    local mockPetPowerBar = {}
    local invocations = {}
    
    mockPetPowerBar[ATTR_SET] = function(event)
        invocations[#invocations + 1] = GetStringInvocationWithEvent(ATTR_SET, event)
    end
    
    mockPetPowerBar[ATTR_CLEAR] = function()
        invocations[#invocations + 1] = ATTR_CLEAR
    end
    
    mockPetPowerBar[ATTR_IS_PET_CLASS] = function()
        invocations[#invocations + 1] = ATTR_IS_PET_CLASS

        return mockPetPowerBar[ATTR_PET_CLASS]
    end
    
    mockPetPowerBar[ATTR_HIDE] = function()
        invocations[#invocations + 1] = ATTR_HIDE
    end
    
    mockPetPowerBar[ATTR_SHOW] = function()
        invocations[#invocations + 1] = ATTR_SHOW
    end
    
    mockPetPowerBar[ATTR_FIX_FRAME_POSITION] = function()
        invocations[#invocations + 1] = ATTR_FIX_FRAME_POSITION
    end
    
    mockPetPowerBar[ATTR_UPDATE] = function(event)
        invocations[#invocations + 1] = GetStringInvocationWithEvent(ATTR_UPDATE, event)
    end

    mockPetPowerBar[ATTR_PET_CLASS] = false
    mockPetPowerBar[ATTR_INVOCATIONS] = invocations

    return mockPetPowerBar
end

function TestPetFrameManager:setUp()
    local onTaxi = false
    local partySize = 4

    mockedPowerBars = {}

    PetPowerBar = {}
    PetPowerBar[ATTR_NEW] = function(playerReference, regenCallback)
        luaUnit.assertNotEquals(regenCallback, nil)

        local mockedPetPowerBar = InitializeMockedPetPowerBar()
        mockedPetPowerBar[ATTR_ID] = playerReference
        mockedPetPowerBar[ATTR_REGEN_CALLBACK] = regenCallback

        mockedPowerBars[playerReference] = mockedPetPowerBar

        return mockedPetPowerBar
    end

    MockFrame()

    petFrameManager = PetFrameManager.new()

    MockDependencies(onTaxi, partySize)
end

function TestPetFrameManager:tearDown()
    petFrameManager = nil
    mockPetPowerBar = nil
    mockedPowerBars = nil
    mockFrame = nil
    CreateFrame = nil
    UnitOnTaxi = nil
    GetNumSubgroupMembers = nil
end

function TestPetFrameManager:testInitialization()
    local expectedFrameInvocationCount = 2

    luaUnit.assertNotEquals(petFrameManager, nil)

    for i = 1, PPF_C.REF_PARTY_SIZE do
        local powerBar = mockedPowerBars[PPF_C.REF_PARTY[i]] 

        luaUnit.assertNotEquals(powerBar, nil)
        luaUnit.assertEquals(powerBar[ATTR_ID], PPF_C.REF_PARTY[i])
    end

    local frameInvocations = mockFrame[ATTR_INVOCATIONS]
    luaUnit.assertEquals(#frameInvocations, expectedFrameInvocationCount)
end

function TestPetFrameManager:testHideAll()
    local partySize = 2
    GetNumSubgroupMembers = function()
        return partySize
    end

    petFrameManager.HideAll(PPF_C.EVENT_CVAR_UPDATE)

    for i = 1, PPF_C.REF_PARTY_SIZE do
        local powerBar = mockedPowerBars[PPF_C.REF_PARTY[i]]
        local invocations = powerBar[ATTR_INVOCATIONS]

        luaUnit.assertEquals(invocations[#invocations], ATTR_HIDE)
    end
end

function TestPetFrameManager:testHideAllInvalidEvent()
    petFrameManager.HideAll(PPF_C.EVENT_PARTY_SIZE)

    for i = 1, PPF_C.REF_PARTY_SIZE do
        local powerBar = mockedPowerBars[PPF_C.REF_PARTY[i]]
        local invocations = powerBar[ATTR_INVOCATIONS]

        luaUnit.assertEquals(invocations, {})
    end
end

local function PartyChangedTestHelper(partyMemberCount)
    GetNumSubgroupMembers = function()
        return partyMemberCount
    end

    petFrameManager.PartyChanged(PPF_C.EVENT_PARTY_UPDATE)

    local expectedSetString = GetStringInvocationWithEvent(ATTR_SET, PPF_C.EVENT_PARTY_UPDATE)
    for i = 1, partyMemberCount do
        local powerBar = mockedPowerBars[PPF_C.REF_PARTY[i]]
        local invocations = powerBar[ATTR_INVOCATIONS]

        luaUnit.assertEquals(invocations[#invocations], expectedSetString)
    end

    for i = partyMemberCount + 1, PPF_C.REF_PARTY_SIZE do
        local powerBar = mockedPowerBars[PPF_C.REF_PARTY[i]]
        local invocations = powerBar[ATTR_INVOCATIONS]

        luaUnit.assertEquals(invocations[#invocations], ATTR_CLEAR)
    end
end

function TestPetFrameManager:testPartyChanged0()
    local partyMemberCount = 0
    PartyChangedTestHelper(partyMemberCount)
end

function TestPetFrameManager:testPartyChanged1()
    local partyMemberCount = 1
    PartyChangedTestHelper(partyMemberCount)
end

function TestPetFrameManager:testPartyChanged2()
    local partyMemberCount = 2
    PartyChangedTestHelper(partyMemberCount)
end

function TestPetFrameManager:testPartyChanged3()
    local partyMemberCount = 3
    PartyChangedTestHelper(partyMemberCount)
end

function TestPetFrameManager:testPartyChanged4()
    local partyMemberCount = 4
    PartyChangedTestHelper(partyMemberCount)
end

function TestPetFrameManager:testPlayerToggledInvalidEvent()
    petFrameManager.PlayerToggled(PPF_C.EVENT_PARTY_UPDATE, PLAYER_REFERENCE)

    local powerBar = mockedPowerBars[PLAYER_REFERENCE]
    local invocations = powerBar[ATTR_INVOCATIONS]

    luaUnit.assertEquals(invocations, {})
end

function TestPetFrameManager:testPlayerToggledNotPetClassEnable()
    petFrameManager.PlayerToggled(PPF_C.EVENT_PARTY_ENABLE, PLAYER_REFERENCE)

    local powerBar = mockedPowerBars[PLAYER_REFERENCE]
    local invocations = powerBar[ATTR_INVOCATIONS]

    luaUnit.assertEquals(invocations[#invocations], ATTR_HIDE)
end

function TestPetFrameManager:testPlayerToggledNotPetClassDisable()
    petFrameManager.PlayerToggled(PPF_C.EVENT_PARTY_DISABLE, PLAYER_REFERENCE)

    local powerBar = mockedPowerBars[PLAYER_REFERENCE]
    local invocations = powerBar[ATTR_INVOCATIONS]

    luaUnit.assertEquals(invocations[#invocations], ATTR_HIDE)
end

function TestPetFrameManager:testPlayerToggledDisableEvent()
    local powerBar = mockedPowerBars[PLAYER_REFERENCE]
    powerBar[ATTR_PET_CLASS] = true

    petFrameManager.PlayerToggled(PPF_C.EVENT_PARTY_DISABLE, PLAYER_REFERENCE)

    local invocations = powerBar[ATTR_INVOCATIONS]

    luaUnit.assertEquals(invocations[(#invocations) - 1], ATTR_HIDE)
    luaUnit.assertEquals(invocations[#invocations], ATTR_FIX_FRAME_POSITION)
end

function TestPetFrameManager:testPlayerToggledOnTaxi()
    UnitOnTaxi = function()
        return true
    end

    local powerBar = mockedPowerBars[PLAYER_REFERENCE]
    powerBar[ATTR_PET_CLASS] = true

    petFrameManager.PlayerToggled(PPF_C.EVENT_PARTY_ENABLE, PLAYER_REFERENCE)

    local invocations = powerBar[ATTR_INVOCATIONS]

    luaUnit.assertEquals(invocations[(#invocations) - 1], ATTR_HIDE)
    luaUnit.assertEquals(invocations[#invocations], ATTR_FIX_FRAME_POSITION)
end

local function PlayerToggledTestHelper(playerIndex)
    local playerReference = PPF_C.REF_PARTY[playerIndex]
    local powerBar = mockedPowerBars[playerReference]
    powerBar[ATTR_PET_CLASS] = true

    petFrameManager.PlayerToggled(PPF_C.EVENT_PARTY_ENABLE, playerReference)

    for i = 1, playerIndex - 1 do
        local powerBar = mockedPowerBars[PPF_C.REF_PARTY[i]]
        local invocations = powerBar[ATTR_INVOCATIONS]

        luaUnit.assertEquals(invocations, {})
    end

    local invocations = powerBar[ATTR_INVOCATIONS]
    luaUnit.assertEquals(invocations[(#invocations) - 1], ATTR_SHOW)
    luaUnit.assertEquals(invocations[#invocations], ATTR_FIX_FRAME_POSITION)

    for i = playerIndex + 1, PPF_C.REF_PARTY_SIZE do
        local powerBar = mockedPowerBars[PPF_C.REF_PARTY[i]]
        local invocations = powerBar[ATTR_INVOCATIONS]

        luaUnit.assertEquals(invocations[#invocations], ATTR_FIX_FRAME_POSITION)
    end
end

function TestPetFrameManager:testPlayerToggled1()
    PlayerToggledTestHelper(1)
end

function TestPetFrameManager:testPlayerToggled2()
    PlayerToggledTestHelper(2)
end

function TestPetFrameManager:testPlayerToggled3()
    PlayerToggledTestHelper(3)
end

function TestPetFrameManager:testPlayerToggled4()
    PlayerToggledTestHelper(4)
end

local function UpdateInvalidReferenceTestHelper(event, reference)
    petFrameManager.UpdatePlayer(event, reference)

    for i = 1, PPF_C.REF_PARTY_SIZE do
        local powerBar = mockedPowerBars[PPF_C.REF_PARTY[i]]
        local invocations = powerBar[ATTR_INVOCATIONS]

        luaUnit.assertEquals(invocations, {})
    end
end

function TestPetFrameManager:testUpdatePartyPetEventTargetReference()
    UpdateInvalidReferenceTestHelper(PPF_C.EVENT_PARTY_PET, TARGET_REFERENCE)
end

function TestPetFrameManager:testUpdatePartyPetEventInvalidReference()
    UpdateInvalidReferenceTestHelper(PPF_C.EVENT_PARTY_PET, INVALID_REFERENCE)
end

function TestPetFrameManager:testUpdatePartyRenameEventTargetReference()
    UpdateInvalidReferenceTestHelper(PPF_C.EVENT_PARTY_RENAME, TARGET_REFERENCE)
end

function TestPetFrameManager:testUpdatePartyRenameEventInvalidReference()
    UpdateInvalidReferenceTestHelper(PPF_C.EVENT_PARTY_RENAME, INVALID_REFERENCE)
end

function TestPetFrameManager:testUpdatePartyPowerEventTargetReference()
    UpdateInvalidReferenceTestHelper(PPF_C.EVENT_PARTY_POWER, TARGET_REFERENCE)
end

function TestPetFrameManager:testUpdatePartyPowerEventInvalidReference()
    UpdateInvalidReferenceTestHelper(PPF_C.EVENT_PARTY_POWER, INVALID_REFERENCE)
end

function TestPetFrameManager:testUpdatePartyPowerMaxEventInvalidReference()
    UpdateInvalidReferenceTestHelper(PPF_C.EVENT_PARTY_MAXP, TARGET_REFERENCE)
end

function TestPetFrameManager:testUpdatePartyPowerMaxEventTargetReference()
    UpdateInvalidReferenceTestHelper(PPF_C.EVENT_PARTY_MAXP, INVALID_REFERENCE)
end

local function UpdateTestHelper(event, reference)
    if not reference then
        reference = PLAYER_REFERENCE
    end

    local expectedUpdateEventString = GetStringInvocationWithEvent(ATTR_UPDATE, event)

    petFrameManager.UpdatePlayer(event, reference)

    local powerBar = mockedPowerBars[PLAYER_REFERENCE]
    local invocations = powerBar[ATTR_INVOCATIONS]
    luaUnit.assertEquals(invocations[#invocations], expectedUpdateEventString)
end

function TestPetFrameManager:testUpdatePartyPetEvent()
    UpdateTestHelper(PPF_C.EVENT_PARTY_PET)
end

function TestPetFrameManager:testUpdatePartyRenameEvent()
    UpdateTestHelper(PPF_C.EVENT_PARTY_RENAME)
end

function TestPetFrameManager:testUpdatePartyPowerEvent()
    UpdateTestHelper(PPF_C.EVENT_PARTY_POWER)
end

function TestPetFrameManager:testUpdatePartyPowerMaxEvent()
    UpdateTestHelper(PPF_C.EVENT_PARTY_MAXP)
end

function TestPetFrameManager:testUpdatePartyPowerEventPetReference()
    UpdateTestHelper(PPF_C.EVENT_PARTY_POWER, PPF_C.REF_PARTY_PET_1)
end

function TestPetFrameManager:testUpdatePartyPowerMaxEventPetReference()
    UpdateTestHelper(PPF_C.EVENT_PARTY_MAXP, PPF_C.REF_PARTY_PET_1)
end

local function AwaitRegenRequestedTestHelper(index, expectedInvocationCount)
    local powerBar = mockedPowerBars[PPF_C.REF_PARTY[index]]

    powerBar[ATTR_REGEN_CALLBACK]()

    local frameInvocations = mockFrame[ATTR_INVOCATIONS]
    luaUnit.assertEquals(frameInvocations[#frameInvocations], ATTR_REGISTER_EVENT)
    luaUnit.assertEquals(expectedInvocationCount, #frameInvocations)
end

function TestPetFrameManager:testAwaitRegenRequested()
    local expectedInvocationCount = 3

    AwaitRegenRequestedTestHelper(1, expectedInvocationCount)
end

function TestPetFrameManager:testAwaitRegenRequestedDuplicate()
    local expectedInvocationCount = 3

    for i = 1, PPF_C.REF_PARTY_SIZE do
        AwaitRegenRequestedTestHelper(i, expectedInvocationCount)
    end
end

local function CheckPowerBarInvocations(expectedInvocationCount)
    for i = 1, PPF_C.REF_PARTY_SIZE do
        local powerBar = mockedPowerBars[PPF_C.REF_PARTY[i]]
        local invocations = powerBar[ATTR_INVOCATIONS]

        luaUnit.assertEquals(expectedInvocationCount, #invocations)
    end
end

function TestPetFrameManager:testRegenEnabled()
    local expectedManagerInvocationCount = 4
    local expectedPowerBarInvocationCountBefore = 0
    local expectedPowerBarInvocationCountAfter = expectedPowerBarInvocationCountBefore + 1

    local powerBar = mockedPowerBars[PPF_C.REF_PARTY[1]]
    powerBar[ATTR_REGEN_CALLBACK]()

    CheckPowerBarInvocations(expectedPowerBarInvocationCountBefore)

    BroadcastEvent(PPF_C.EVENT_REGEN)

    local frameInvocations = mockFrame[ATTR_INVOCATIONS]
    luaUnit.assertEquals(frameInvocations[#frameInvocations], ATTR_UNREGISTER_EVENT)
    luaUnit.assertEquals(expectedManagerInvocationCount, #frameInvocations)

    CheckPowerBarInvocations(expectedPowerBarInvocationCountAfter)
end

function TestPetFrameManager:testRegenRequestSecondPass()
    local expectedCountInitial = 2

    local frameInvocations = mockFrame[ATTR_INVOCATIONS]
    luaUnit.assertEquals(expectedCountInitial, #frameInvocations)

    local powerBar = mockedPowerBars[PPF_C.REF_PARTY[1]]
    powerBar[ATTR_REGEN_CALLBACK]()

    luaUnit.assertEquals(expectedCountInitial + 1, #frameInvocations)

    BroadcastEvent(PPF_C.EVENT_REGEN)

    luaUnit.assertEquals(expectedCountInitial + 2, #frameInvocations)

    powerBar[ATTR_REGEN_CALLBACK]()

    luaUnit.assertEquals(expectedCountInitial + 3, #frameInvocations)
end

os.exit(luaUnit.LuaUnit.run())
