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
require('locales.PartyPetFrames-enUS')
require('utils.Constants')

local STATE_ON = PPF_C.STATE_ON
local STATE_OFF = PPF_C.STATE_OFF
local ENUM_STATES = PPF_C.ENUM_STATES
local CVAR_SHOW_PARTY_PETS = PPF_C.CVAR_SHOW_PARTY_PETS
local EVENT_LOADED = PPF_C.EVENT_LOADED
local EVENT_REGEN = PPF_C.EVENT_REGEN
local PPF_COMMAND_LINE_NAME = PPF_C.PPF_COMMAND_LINE_NAME
local PPF_COMMAND = PPF_C.PPF_COMMAND

local TYPE_STRING = 'number'
local TYPE_TABLE = 'table'
local TYPE_NUMBER = 'number'

local ON_EVENT_HANDLER_STRING = 'OnEvent'

local ATTR_NEW = 'new'
local ATTR_PARTY_CHANGED = 'PartyChanged'
local ATTR_PLAYER_TOGGLED = 'PlayerToggled'
local ATTR_UPDATE_PLAYER = 'UpdatePlayer'
local ATTR_HIDE_ALL = 'HideAll'
local ATTR_HIDE = 'Hide'
local ATTR_SHOW = 'Show'
local ATTR_SET_SCRIPT = 'SetScript'
local ATTR_REGISTER_EVENT = 'RegisterEvent'
local ATTR_UNREGISTER_EVENT = 'UnregisterEvent'
-- These attributes do not exist in the PetFrameManager class, it is used here for convenience
local ATTR_INVOCATIONS = 'invocations'
local ATTR_ON_EVENT_FUNCTION = 'respond'

local ERROR_INVALID_VARIABLE = function(expected, variable)
    return string.format('Expect to receive %s only! Got: %s', expected, variable)
end

local ERROR_INVALID_VALUE = function(newValue, valueType)
    if newValue == nil then
        return 'Expect to receive an int of type number. Got nil!'
    else
        return 'Expect to receive an int of type number. Got: '..newValue..' of type: '..valueType
    end
end

local BUILD_VERSION = 11302
local INVALID_ARG = 'nonsenseArg'

local mockMainFrame
local mockPetFrameManager
local ogSetShowPartyPets
local ogUpdatePetCallCounter
local showPartyPetsSetCount
local registeredEvents
local unregisteredEvents
local mockInCombat
local mockInGroup
local mockInRaid
local mockCVarShowPartyPets -- This will be an integer
local mockCVarRaidStyle -- This will be a boolean

-- Setup functions
local function MockGlobals()
    WOW_PROJECT_ID = BUILD_VERSION
    WOW_PROJECT_CLASSIC = BUILD_VERSION
    PPF_IsEnabled = ENUM_STATES[STATE_ON]
    SlashCmdList = {}
    mockCVarShowPartyPets = ENUM_STATES[STATE_ON]
    mockCVarRaidStyle = false

    UnitAffectingCombat = function(reference)
        if reference ~= PPF_C.REF_PLAYER then
            error(ERROR_INVALID_VARIABLE(reference, PPF_C.REF_PLAYER))
        end

        return mockInCombat
    end

    IsInGroup = function()
        return mockInGroup
    end
    
    IsInRaid = function()
        return mockInRaid
    end

    mockInGroup = false
    mockInRaid = false
end

local function GetStringInvocationWithArguments(functionName, event, reference)
    return string.format('%s %s %s', functionName, event or '', reference or '')
end

local function MockPetFrameManager()
    mockPetFrameManager = {}
    mockPetFrameManager[ATTR_INVOCATIONS] = {}

    mockPetFrameManager[ATTR_PARTY_CHANGED] = function(event)
        local invocations = mockPetFrameManager[ATTR_INVOCATIONS]
        invocations[#invocations + 1] = GetStringInvocationWithArguments(ATTR_PARTY_CHANGED, event)
    end
    
    mockPetFrameManager[ATTR_PLAYER_TOGGLED] = function(event, reference)
        local invocations = mockPetFrameManager[ATTR_INVOCATIONS]
        invocations[#invocations + 1] = GetStringInvocationWithArguments(ATTR_PLAYER_TOGGLED, event, reference)
    end
    
    mockPetFrameManager[ATTR_UPDATE_PLAYER] = function(event, reference)
        local invocations = mockPetFrameManager[ATTR_INVOCATIONS]
        invocations[#invocations + 1] = GetStringInvocationWithArguments(ATTR_UPDATE_PLAYER, event, reference)
    end
    
    mockPetFrameManager[ATTR_HIDE_ALL] = function(event)
        local invocations = mockPetFrameManager[ATTR_INVOCATIONS]
        invocations[#invocations + 1] = GetStringInvocationWithArguments(ATTR_HIDE_ALL, event)
    end

    PetFrameManager = {}
    PetFrameManager[ATTR_NEW] = function()
        return mockPetFrameManager
    end
end

local function ProcessRegistration(buffer, event, addTarget)
    if addTarget then
        buffer[event] = true
    else
        buffer[event] = nil
    end
end

local function MockEventSystem(frame)
    local addTarget = true

    registeredEvents = {}
    unregisteredEvents = {}

    frame[ATTR_REGISTER_EVENT] = function(self, event)
        ProcessRegistration(registeredEvents, event, addTarget)
        ProcessRegistration(unregisteredEvents, event, not addTarget)
    end

    frame[ATTR_UNREGISTER_EVENT] = function(self, event)
        ProcessRegistration(registeredEvents, event, not addTarget)
        ProcessRegistration(unregisteredEvents, event, addTarget)
    end
end

local function BroadcastEvent(...)
    mockMainFrame[ATTR_ON_EVENT_FUNCTION](mockMainFrame, ...)
end

local function MockMainFrame()
    local invocations = {}

    mockMainFrame = {}

    mockMainFrame[ATTR_SET_SCRIPT] = function(self, handler, func)
        if handler ~= ON_EVENT_HANDLER_STRING then
            error(ERROR_INVALID_VARIABLE(ON_EVENT_HANDLER_STRING, handler))
        end

        mockMainFrame[ATTR_ON_EVENT_FUNCTION] = func
        invocations[#invocations + 1] = ATTR_SET_SCRIPT
    end

    mockMainFrame[ATTR_HIDE] = function()
        invocations[#invocations + 1] = ATTR_HIDE
    end
    
    mockMainFrame[ATTR_SHOW] = function()
        invocations[#invocations + 1] = ATTR_SHOW
    end

    MockEventSystem(mockMainFrame)
    mockMainFrame[ATTR_INVOCATIONS] = invocations

    CreateFrame = function()
        return mockMainFrame
    end
end

local function MockConsoleVariables()
    ogSetShowPartyPets = PPF_C.SetShowPartyPets
    showPartyPetsSetCount = 0

    PPF_C.SetShowPartyPets = function(...)
        showPartyPetsSetCount = showPartyPetsSetCount + 1
        ogSetShowPartyPets(...)
    end

    GetCVar = function(variable)
        if variable ~= CVAR_SHOW_PARTY_PETS then
            error(ERROR_INVALID_VARIABLE(CVAR_SHOW_PARTY_PETS, variable))
        end

        -- Replicating the actual function's return type
        return tostring(mockCVarShowPartyPets)
    end

    SetCVar = function(variable, newValue, broadcastArgument)
        local newValueType = type(newValue)

        if variable ~= CVAR_SHOW_PARTY_PETS then
            error(ERROR_INVALID_VARIABLE(CVAR_SHOW_PARTY_PETS, variable))
        elseif newValueType ~= TYPE_NUMBER then
            error(ERROR_INVALID_VALUE(newValue, newValueType))
        end

        mockCVarShowPartyPets = newValue
    end

    GetCVarBool = function(variable)
        if variable ~= PPF_C.CVAR_USE_COMPACT_PARTY_FRAMES then
            error(ERROR_INVALID_VARIABLE(PPF_C.CVAR_USE_COMPACT_PARTY_FRAMES, variable))
        end

        return mockCVarRaidStyle
    end
end

local function MockDefaultChatFrame()
    DEFAULT_CHAT_FRAME = {messages = {}}
    DEFAULT_CHAT_FRAME.AddMessage = function(self, message)
        DEFAULT_CHAT_FRAME.messages[#DEFAULT_CHAT_FRAME.messages + 1] = message
    end
end

local function MockPartyMemberFrame_UpdatePet()
    ogUpdatePetCallCounter = 0

    -- This function is post hooked into by PartyPetFrames. We won't be testing Blizzard's code but
    -- want to verify that this function is not being called by PartyPetFrames.
    PartyMemberFrame_UpdatePet = function()
        ogUpdatePetCallCounter = ogUpdatePetCallCounter + 1
    end
end

local function SetupAllMocks(lazyLoad)
    MockGlobals()
    MockPetFrameManager()
    MockMainFrame()
    MockConsoleVariables()
    MockDefaultChatFrame()
    MockPartyMemberFrame_UpdatePet()

    -- PartyPetFrames.lua needs to execute the addon initialization logic upon being read so we need to
    -- require it once we have mocked the external dependencies, instead of at the top of the file.
    if lazyLoad ~= true then
        require(PPF_C.PPF_NAME)
    end
end

local function TearDownHelper()
    WOW_PROJECT_ID = nil
    WOW_PROJECT_CLASSIC = nil
    PPF_IsEnabled = nil
    SlashCmdList = nil
    mockCVarShowPartyPets = ENUM_STATES[STATE_OFF]
    mockCVarRaidStyle = false
    PetFrameManager = nil
    mockPetFrameManager = nil
    CreateFrame = nil
    mockMainFrame = nil
    mockInCombat = nil
    mockInGroup = nil
    mockInRaid = nil
    registeredEvents = nil
    unregisteredEvents = nil
    GetCVar = nil
    SetCVar = nil
    DEFAULT_CHAT_FRAME = nil
    ogUpdatePetCallCounter = nil
    PPF_C.SetShowPartyPets = ogSetShowPartyPets
    showPartyPetsSetCount = nil

    -- We want require to load the class under test multiple times so the initialization logic will
    -- be run within every test case
    package.loaded[PPF_C.PPF_NAME] = nil
end
-- ~Setup functions

-- Client type check
TestPartyPetFramesClient = {}

function TestPartyPetFramesClient:setUp()
    SetupAllMocks(true)
    
    local mockBuildId = '-847'
    WOW_PROJECT_ID = mockBuildId
end

function TestPartyPetFramesClient:tearDown()
    TearDownHelper()
end

-- Check the message output when the addon is not loaded in a classic client
-- There should be no outgoing invocations and the not classic message should be displayed.
function TestPartyPetFramesClient:testIsNotClassic()
    local expectedCallCount = 0
    local expectedMessage = PPF_L.TXT_NOT_CLASSIC
    local expectedMessageCount = 1

    require(PPF_C.PPF_NAME)

    local messages = DEFAULT_CHAT_FRAME.messages
    local count = #messages
    luaUnit.assertEquals(count, expectedMessageCount)

    local lastMessage = messages[count]
    luaUnit.assertEquals(lastMessage, expectedMessage)

    local mainFrameInvocations = mockMainFrame[ATTR_INVOCATIONS]
    luaUnit.assertEquals(#mainFrameInvocations, expectedCallCount)
end
-- ~Client type check

-- These test suites represent the state permutations the addon might be in. In later tests there are also inParty and
-- inRaid variations as well. Each suite sets up a unique environment and then executes all applicable test cases.
-- The TestHelper functions are the actual test cases.

-- We won't have saved variables actually saved in the very first run. We will use these suites to verify that first time
-- setup doesn't cause any unexpected artifacts.
TestPpfFirstTime = {}
TestPpfRaidStyleFirstTime = {}
TestPpfInCombatFirstTime = {}
TestPpfInCombatRaidStyleFirstTime = {}


TestPpf = {} -- The 'enabled' saved variable is set to true
TestPpfRaidStyle = {} -- We will hide all party pet frames when raid style frames are activated

TestPpfDisabled = {} -- The 'enabled' saved variable is set to false
TestPpfRaidStyleDisabled = {}

TestPpfInCombat = {} -- Combat state must be tracked to ensure we will set the console variable
TestPpfInCombatDisabled = {}

TestPpfInCombatRaidStyle = {}
TestPpfInCombatRaidStyleDisabled = {}

-- FirstTime
function TestPpfFirstTime:setUp()
    SetupAllMocks()

    PPF_IsEnabled = nil
    mockInCombat = false
end

function TestPpfFirstTime:tearDown()
    TearDownHelper()
end
-- ~FirstTime

-- RaidStyle FirstTime
function TestPpfRaidStyleFirstTime:setUp()
    SetupAllMocks()

    PPF_IsEnabled = nil
    mockInCombat = false
    mockCVarRaidStyle = true
    mockCVarShowPartyPets = ENUM_STATES[STATE_OFF]
end

function TestPpfRaidStyleFirstTime:tearDown()
    TearDownHelper()
end
-- ~RaidStyle FirstTime

-- InCombat FirstTime
function TestPpfInCombatFirstTime:setUp()
    SetupAllMocks()

    PPF_IsEnabled = nil
    mockInCombat = true
end

function TestPpfInCombatFirstTime:tearDown()
    TearDownHelper()
end
-- ~InCombat FirstTime

-- InCombat RaidStyle FirstTime
function TestPpfInCombatRaidStyleFirstTime:setUp()
    SetupAllMocks()

    PPF_IsEnabled = nil
    mockInCombat = true
    mockCVarRaidStyle = true
    mockCVarShowPartyPets = ENUM_STATES[STATE_OFF]
end

function TestPpfInCombatRaidStyleFirstTime:tearDown()
    TearDownHelper()
end
-- ~InCombat RaidStyle FirstTime

-- Enabled
function TestPpf:setUp()
    SetupAllMocks()

    mockInCombat = false
end

function TestPpf:tearDown()
    TearDownHelper()
end
-- ~Enabled

-- RaidStyle
function TestPpfRaidStyle:setUp()
    SetupAllMocks()

    mockInCombat = false
    mockCVarRaidStyle = true
end

function TestPpfRaidStyle:tearDown()
    TearDownHelper()
end
-- ~RaidStyle

-- Disabled
function TestPpfDisabled:setUp()
    SetupAllMocks()

    PPF_IsEnabled = ENUM_STATES[STATE_OFF]
    mockInCombat = false
    mockCVarShowPartyPets = ENUM_STATES[STATE_OFF]
end

function TestPpfDisabled:tearDown()
    TearDownHelper()
end
-- ~Disabled

-- RaidStyle Disabled
function TestPpfRaidStyleDisabled:setUp()
    SetupAllMocks()

    PPF_IsEnabled = ENUM_STATES[STATE_OFF]
    mockInCombat = false
    mockCVarRaidStyle = true
    mockCVarShowPartyPets = ENUM_STATES[STATE_OFF]
end

function TestPpfRaidStyleDisabled:tearDown()
    TearDownHelper()
end
-- ~RaidStyle Disabled

-- InCombat
function TestPpfInCombat:setUp()
    SetupAllMocks()

    mockInCombat = true
end

function TestPpfInCombat:tearDown()
    TearDownHelper()
end
-- ~InCombat

-- InCombat RaidStyle
function TestPpfInCombatRaidStyle:setUp()
    SetupAllMocks()

    mockInCombat = true
    mockCVarRaidStyle = true
end

function TestPpfInCombatRaidStyle:tearDown()
    TearDownHelper()
end
-- ~InCombat RaidStyle

-- InCombat Disabled
function TestPpfInCombatDisabled:setUp()
    SetupAllMocks()

    PPF_IsEnabled = ENUM_STATES[STATE_OFF]
    mockInCombat = true
    mockCVarShowPartyPets = ENUM_STATES[STATE_OFF]
end

function TestPpfInCombatDisabled:tearDown()
    TearDownHelper()
end
-- ~InCombat Disabled

-- InCombat RaidStyle Disabled
function TestPpfInCombatRaidStyleDisabled:setUp()
    SetupAllMocks()

    PPF_IsEnabled = ENUM_STATES[STATE_OFF]
    mockInCombat = true
    mockCVarShowPartyPets = ENUM_STATES[STATE_OFF]
    mockCVarRaidStyle = true
end

function TestPpfInCombatRaidStyleDisabled:tearDown()
    TearDownHelper()
end
-- ~InCombat RaidStyle Disabled

-- ~Test suites

-- testInitialization
-- Verifies the initialization step of the startup, which is the code that will be run immediately when
-- the addon is loaded. 
-- CreateFrame should be called once for the event listening main frame and once for the frameManager.
-- Should start listening to addon loaded events and print the loaded message.
local function InitializationTestHelper()
    local expectedCallCount = 2
    local expectedMessageCount = 0

    luaUnit.assertNotEquals(mockMainFrame, nil)
    luaUnit.assertNotEquals(mockPetFrameManager, nil)

    local invocations = mockMainFrame[ATTR_INVOCATIONS]
    luaUnit.assertEquals(invocations[#invocations - 1], ATTR_SET_SCRIPT)
    luaUnit.assertEquals(invocations[#invocations], ATTR_HIDE)

    luaUnit.assertTrue(registeredEvents[EVENT_LOADED])

    local messages = DEFAULT_CHAT_FRAME.messages
    luaUnit.assertEquals(#messages, expectedMessageCount)
end

function TestPpfFirstTime:testInitialization()
    InitializationTestHelper()
end

function TestPpfRaidStyleFirstTime:testInitialization()
    InitializationTestHelper()
end

function TestPpfInCombatFirstTime:testInitialization()
    InitializationTestHelper()
end

function TestPpfInCombatRaidStyleFirstTime:testInitialization()
    InitializationTestHelper()
end
-- ~testInitialization

-- testLoaded
-- Initiate the second part of initialization which is run when receiving the addon
-- loaded event. Verify in / out combat setup, that party events have been registered to and the proper
-- message has been printed.
local function GetLoadDoneExpectedValues(isEnabled)
    local expectedMessage, expectedShowPartyPetsSetCount
    if isEnabled == false then
        expectedMessage = PPF_L.DISABLED(PPF_COMMAND, STATE_ON)
        expectedShowPartyPetsSetCount = 0

        luaUnit.assertEquals(PPF_IsEnabled, ENUM_STATES[STATE_OFF])
    else
        expectedMessage = PPF_L.LOADED(PPF_COMMAND)
        expectedShowPartyPetsSetCount = 1

        luaUnit.assertEquals(PPF_IsEnabled, ENUM_STATES[STATE_ON])
    end

    return expectedMessage, expectedShowPartyPetsSetCount
end

local function VerifyLoadDone(isEnabled)
    local expectedMessage, expectedShowPartyPetsSetCount = GetLoadDoneExpectedValues(isEnabled)
    local expectedMessageCount = 1

    local messages = DEFAULT_CHAT_FRAME.messages
    luaUnit.assertEquals(#messages, expectedMessageCount)
    luaUnit.assertEquals(messages[#messages], expectedMessage)

    luaUnit.assertEquals(showPartyPetsSetCount, expectedShowPartyPetsSetCount)
end

local function VerifyEventsAfterLoad()
    luaUnit.assertEquals(registeredEvents[EVENT_LOADED], nil)
    luaUnit.assertTrue(unregisteredEvents[EVENT_LOADED])

    luaUnit.assertTrue(registeredEvents[PPF_C.EVENT_CVAR_UPDATE])

    for key, event in pairs(PPF_C.EVENTS_PARTY) do
        luaUnit.assertTrue(registeredEvents[event])
    end
end

local function VerifyInCombatLoad()
    local expectedMessageCount = 0

    local messageCount = #DEFAULT_CHAT_FRAME.messages
    luaUnit.assertEquals(messageCount, expectedMessageCount)

    luaUnit.assertTrue(registeredEvents[EVENT_REGEN])

    BroadcastEvent(EVENT_REGEN)

    luaUnit.assertEquals(registeredEvents[EVENT_REGEN], nil)
    luaUnit.assertTrue(unregisteredEvents[EVENT_REGEN])
end

local function LoadedTestHelper(inCombat, isEnabled)
    BroadcastEvent(EVENT_LOADED)

    if inCombat then
        VerifyInCombatLoad()
    end

    VerifyEventsAfterLoad()

    VerifyLoadDone(isEnabled)
end

function TestPpfFirstTime:testLoaded()
    LoadedTestHelper(false, nil)
end

function TestPpfRaidStyleFirstTime:testLoaded()
    LoadedTestHelper(false, nil)
end

function TestPpfInCombatFirstTime:testLoaded()
    LoadedTestHelper(true, nil)
end

function TestPpfInCombatRaidStyleFirstTime:testLoaded()
    LoadedTestHelper(true, nil)
end

function TestPpf:testLoaded()
    LoadedTestHelper(false, true)
end

function TestPpfRaidStyle:testLoaded()
    LoadedTestHelper(false, true)
end

function TestPpfDisabled:testLoaded()
    LoadedTestHelper(false, false)
end

function TestPpfRaidStyleDisabled:testLoaded()
    LoadedTestHelper(false, false)
end

function TestPpfInCombat:testLoaded()
    LoadedTestHelper(true, true)
end

function TestPpfInCombatDisabled:testLoaded()
    LoadedTestHelper(true, false)
end

function TestPpfInCombatRaidStyle:testLoaded()
    LoadedTestHelper(true, true)
end

function TestPpfInCombatRaidStyleDisabled:testLoaded()
    LoadedTestHelper(true, false)
end
-- ~testLoaded

-- Slash commands
-- Verify that no-argument slash commands will result in a noOp.
local function SlashCommandsNoArgsTestHelper(inCombat, isEnabledInt, argument)
    BroadcastEvent(EVENT_LOADED)

    SlashCmdList[PPF_COMMAND_LINE_NAME](argument)

    local expectedMessage = PPF_L.COMMANDS(PPF_COMMAND, STATE_ON, STATE_OFF)
    local expectedMessageCount = 2
    if inCombat then
        expectedMessageCount = expectedMessageCount - 1
    end

    local messageCount = #DEFAULT_CHAT_FRAME.messages
    local lastMessage = DEFAULT_CHAT_FRAME.messages[messageCount]

    luaUnit.assertEquals(messageCount, expectedMessageCount)
    luaUnit.assertEquals(lastMessage, expectedMessage)

    luaUnit.assertEquals(PPF_IsEnabled, ENUM_STATES[isEnabledInt])
end

-- testSlashCommandsNoArgs
function TestPpf:testSlashCommandsNoArgs()
    SlashCommandsNoArgsTestHelper(false, STATE_ON)
end

function TestPpfRaidStyle:testSlashCommandsNoArgs()
    SlashCommandsNoArgsTestHelper(false, STATE_ON)
end

function TestPpfDisabled:testSlashCommandsNoArgs()
    SlashCommandsNoArgsTestHelper(false, STATE_OFF)
end

function TestPpfRaidStyleDisabled:testSlashCommandsNoArgs()
    SlashCommandsNoArgsTestHelper(false, STATE_OFF)
end

function TestPpfInCombat:testSlashCommandsNoArgs()
    SlashCommandsNoArgsTestHelper(true, STATE_ON)
end

function TestPpfInCombatDisabled:testSlashCommandsNoArgs()
    SlashCommandsNoArgsTestHelper(true, STATE_OFF)
end

function TestPpfInCombatRaidStyle:testSlashCommandsNoArgs()
    SlashCommandsNoArgsTestHelper(true, STATE_ON)
end

function TestPpfInCombatRaidStyleDisabled:testSlashCommandsNoArgs()
    SlashCommandsNoArgsTestHelper(true, STATE_OFF)
end
-- ~testSlashCommandsNoArgs

-- testSlashCommandsInvalidArg
-- Verify that slash commands with invalid arugments will result in a noOp.
function TestPpf:testSlashCommandsInvalidArg()
    SlashCommandsNoArgsTestHelper(false, STATE_ON, INVALID_ARG)
end

function TestPpfRaidStyle:testSlashCommandsInvalidArg()
    SlashCommandsNoArgsTestHelper(false, STATE_ON, INVALID_ARG)
end

function TestPpfDisabled:testSlashCommandsInvalidArg()
    SlashCommandsNoArgsTestHelper(false, STATE_OFF, INVALID_ARG)
end

function TestPpfRaidStyleDisabled:testSlashCommandsInvalidArg()
    SlashCommandsNoArgsTestHelper(false, STATE_OFF, INVALID_ARG)
end

function TestPpfInCombat:testSlashCommandsInvalidArg()
    SlashCommandsNoArgsTestHelper(true, STATE_ON, INVALID_ARG)
end

function TestPpfInCombatDisabled:testSlashCommandsInvalidArg()
    SlashCommandsNoArgsTestHelper(true, STATE_OFF, INVALID_ARG)
end

function TestPpfInCombatRaidStyle:testSlashCommandsInvalidArg()
    SlashCommandsNoArgsTestHelper(true, STATE_ON, INVALID_ARG)
end

function TestPpfInCombatRaidStyleDisabled:testSlashCommandsInvalidArg()
    SlashCommandsNoArgsTestHelper(true, STATE_OFF, INVALID_ARG)
end
-- ~testSlashCommandsInvalidArg

-- testSlashCommandsNoOp
-- Verify that slash commands to switch to the current state will result in a noOp.
local function GetLoadedString(isEnabled)
    if isEnabled then
        return PPF_L.LOADED(PPF_COMMAND)
    else
        return PPF_L.DISABLED(PPF_COMMAND, STATE_ON)
    end
end

local function SlashCommandsNoOpTestHelper(inCombat, state)
    BroadcastEvent(EVENT_LOADED)

    SlashCmdList[PPF_COMMAND_LINE_NAME](state)

    local messages = DEFAULT_CHAT_FRAME.messages
    
    if not inCombat then
        local expectedMessage = GetLoadedString(state == STATE_ON)
        local expectedCount = 1

        luaUnit.assertEquals(messages[#messages], expectedMessage)
        luaUnit.assertEquals(#messages, expectedCount)
    else
        local expectedCount = 0

        luaUnit.assertEquals(#messages, expectedCount)
    end

    luaUnit.assertEquals(PPF_IsEnabled, ENUM_STATES[state])
end

function TestPpf:testSlashCommandsNoOpEnabled()
    SlashCommandsNoOpTestHelper(false, STATE_ON)
end

function TestPpfRaidStyle:testSlashCommandsNoOpEnabled()
    SlashCommandsNoOpTestHelper(false, STATE_ON)
end

function TestPpfInCombat:testSlashCommandsNoOpEnabled()
    SlashCommandsNoOpTestHelper(true, STATE_ON)
end

function TestPpfInCombatRaidStyle:testSlashCommandsNoOpEnabled()
    SlashCommandsNoOpTestHelper(true, STATE_ON)
end
--
--
function TestPpfDisabled:testSlashCommandsNoOpDisabled()
    SlashCommandsNoOpTestHelper(false, STATE_OFF)
end

function TestPpfRaidStyleDisabled:testSlashCommandsNoOpDisabled()
    SlashCommandsNoOpTestHelper(false, STATE_OFF)
end

function TestPpfInCombatDisabled:testSlashCommandsNoOpDisabled()
    SlashCommandsNoOpTestHelper(true, STATE_OFF)
end

function TestPpfInCombatRaidStyleDisabled:testSlashCommandsNoOpDisabled()
    SlashCommandsNoOpTestHelper(true, STATE_OFF)
end
-- ~testSlashCommandsNoOp

-- testSlashCommandsToggle
-- Verify that slash commands properly toggles state in & out of combat.
-- The show party pets console variable and the PPF_isEnabled saved variable should be set.
local function FinishCombat()
    BroadcastEvent(EVENT_REGEN)

    luaUnit.assertEquals(registeredEvents[EVENT_REGEN], nil)
    luaUnit.assertTrue(unregisteredEvents[EVENT_REGEN])
end

local function SlashCommandsToggleTestSetup(inCombat, state, nextState)
    BroadcastEvent(EVENT_LOADED)

    luaUnit.assertEquals(PPF_IsEnabled, ENUM_STATES[state])

    -- Finish loading for these cases
    if inCombat then
        FinishCombat()
    end

    SlashCmdList[PPF_COMMAND_LINE_NAME](nextState)
end

local function SlashCommandsToggleTestHelper(inCombat, state, nextState)
    SlashCommandsToggleTestSetup(inCombat, state, nextState)

    luaUnit.assertEquals(PPF_IsEnabled, ENUM_STATES[nextState])

    if inCombat then
        luaUnit.assertEquals(mockCVarShowPartyPets, ENUM_STATES[state])
        
        FinishCombat()
    end

    local expectedSetCount = 2
    if state == STATE_OFF then
        expectedSetCount = expectedSetCount - 1
    end

    luaUnit.assertEquals(showPartyPetsSetCount, expectedSetCount)

    luaUnit.assertEquals(mockCVarShowPartyPets, ENUM_STATES[nextState])
end

function TestPpf:testSlashCommandsToggleDisable()
    SlashCommandsToggleTestHelper(false, STATE_ON, STATE_OFF)
end

function TestPpfRaidStyle:testSlashCommandsToggleDisable()
    SlashCommandsToggleTestHelper(false, STATE_ON, STATE_OFF)
end

function TestPpfInCombat:testSlashCommandsToggleDisable()
    SlashCommandsToggleTestHelper(true, STATE_ON, STATE_OFF)
end

function TestPpfInCombatRaidStyle:testSlashCommandsToggleDisable()
    SlashCommandsToggleTestHelper(true, STATE_ON, STATE_OFF)
end
--
--
function TestPpfDisabled:testSlashCommandsToggleEnable()
    SlashCommandsToggleTestHelper(false, STATE_OFF, STATE_ON)
end

function TestPpfRaidStyleDisabled:testSlashCommandsToggleEnable()
    SlashCommandsToggleTestHelper(false, STATE_OFF, STATE_ON)
end

function TestPpfInCombatDisabled:testSlashCommandsToggleEnable()
    SlashCommandsToggleTestHelper(true, STATE_OFF, STATE_ON)
end

function TestPpfInCombatRaidStyleDisabled:testSlashCommandsToggleEnable()
    SlashCommandsToggleTestHelper(true, STATE_OFF, STATE_ON)
end
-- ~testSlashCommandsToggle

-- testSlashCommandsSetupDeferred
--Same test case as testSlashCommandsToggle but run by first time suites only. 
local function SlashCommandsSetupDeferredTestHelper(nextState)
    BroadcastEvent(EVENT_LOADED)

    luaUnit.assertEquals(PPF_IsEnabled, nil)

    SlashCmdList[PPF_COMMAND_LINE_NAME](nextState)

    local expectedCallCount = 0
    luaUnit.assertEquals(showPartyPetsSetCount, expectedCallCount)

    local expectedMessage = PPF_L.TXT_WONT_DEFER
    local expectedMessageCount = 1

    local messages = DEFAULT_CHAT_FRAME.messages
    luaUnit.assertEquals(#messages, expectedMessageCount)
    luaUnit.assertEquals(messages[#messages], expectedMessage)
end

function TestPpfInCombatFirstTime:testSlashCommandsSetupDeferredDisable()
    SlashCommandsSetupDeferredTestHelper(STATE_OFF)
end

function TestPpfInCombatFirstTime:testSlashCommandsSetupDeferredEnable()
    SlashCommandsSetupDeferredTestHelper(STATE_ON)
end

function TestPpfInCombatRaidStyleFirstTime:testSlashCommandsSetupDeferredDisable()
    SlashCommandsSetupDeferredTestHelper(STATE_OFF)
end

function TestPpfInCombatRaidStyleFirstTime:testSlashCommandsSetupDeferredEnable()
    SlashCommandsSetupDeferredTestHelper(STATE_ON)
end
-- ~testSlashCommandsSetupDeferred

--testSlashCommandsAlreadyDeferred
-- Verifies that the system will correctly handle receiving multiple commands.
-- If a command is issued during combat, the command will be queued and executed upon exiting combat.
-- Verifies that the originally queued command is executed properly after combat, and later
-- commands are ignored. 
local function SlashCommandsAlreadyDeferredTestHelper(state, nextState)
    BroadcastEvent(EVENT_LOADED)

    FinishCombat()

    luaUnit.assertEquals(PPF_IsEnabled, ENUM_STATES[state])

    local expectedCallCount = 1
    if state == STATE_OFF then
        expectedCallCount = expectedCallCount - 1
    end

    luaUnit.assertEquals(showPartyPetsSetCount, expectedCallCount)

    SlashCmdList[PPF_COMMAND_LINE_NAME](nextState)
    SlashCmdList[PPF_COMMAND_LINE_NAME](state)

    luaUnit.assertEquals(showPartyPetsSetCount, expectedCallCount)
    
    local messages = DEFAULT_CHAT_FRAME.messages

    local expectedMessageCount = 3
    luaUnit.assertEquals(#messages, expectedMessageCount)

    luaUnit.assertEquals(messages[#messages - 1], PPF_L.TXT_WILL_DEFER)
    luaUnit.assertEquals(messages[#messages], PPF_L.TXT_WONT_DEFER)
end

function TestPpfInCombat:testSlashCommandsAlreadyDeferredDisable()
    SlashCommandsAlreadyDeferredTestHelper(STATE_ON, STATE_OFF)
end

function TestPpfInCombatDisabled:testSlashCommandsAlreadyDeferredEnable()
    SlashCommandsAlreadyDeferredTestHelper(STATE_OFF, STATE_ON)
end

function TestPpfInCombatRaidStyle:testSlashCommandsAlreadyDeferredDisable()
    SlashCommandsAlreadyDeferredTestHelper(STATE_ON, STATE_OFF)
end

function TestPpfInCombatRaidStyleDisabled:testSlashCommandsAlreadyDeferredEnable()
    SlashCommandsAlreadyDeferredTestHelper(STATE_OFF, STATE_ON)
end
-- ~testSlashCommandsAlreadyDeferred
-- ~Slash commands

-- VariableUpdate tests
-- Finish loading and send a cvar_changed event to verify correct state transition.
-- Assert on the state variables, proper state message and the relevant frameManager function call.

-- testVariableUpdateFirstTime
local function AssertStateChange(event)
    local expectedInvocation = GetStringInvocationWithArguments(event, PPF_C.EVENT_CVAR_UPDATE)
    local expectedCallCount = 1

    local invocations = mockPetFrameManager[ATTR_INVOCATIONS]
    local lastInvocation = invocations[#invocations]
    
    luaUnit.assertEquals(#invocations, expectedCallCount)
    luaUnit.assertEquals(lastInvocation, expectedInvocation)
end

local function SendPetCVarUpdateEvent(state)
    BroadcastEvent(PPF_C.EVENT_CVAR_UPDATE, PPF_C.EVENT_SHOW_PARTY_PETS, ENUM_STATES[state])
end

local function VariableUpdateTestHelper(inCombat, event, isDisabled, commandNextState)
    BroadcastEvent(EVENT_LOADED)

    if inCombat then
        FinishCombat()
        mockInCombat = false
    end

    if commandNextState then
        SlashCmdList[PPF_COMMAND_LINE_NAME](commandNextState)
    end

    SendPetCVarUpdateEvent(STATE_ON)

    local messages = DEFAULT_CHAT_FRAME.messages
    local lastMessage = messages[#messages]

    local expectedMessageCount = 2
    luaUnit.assertEquals(#messages, expectedMessageCount)
    luaUnit.assertEquals(lastMessage, PPF_L.ENABLED(PPF_COMMAND, STATE_OFF))

    local expectedSetCvarCount = 1
    if isDisabled then
        expectedSetCvarCount = expectedSetCvarCount - 1
    end
    if commandNextState then
        expectedSetCvarCount = expectedSetCvarCount + 1
    end

    luaUnit.assertEquals(showPartyPetsSetCount, expectedSetCvarCount)

    AssertStateChange(event)

    luaUnit.assertEquals(ogUpdatePetCallCounter, 0)
end

--
function TestPpfFirstTime:testVariableUpdateFirstTime()
    VariableUpdateTestHelper(false, ATTR_HIDE_ALL)
end

function TestPpfFirstTime:testVariableUpdateFirstTimeInGroup()
    mockInGroup = true

    VariableUpdateTestHelper(false, ATTR_PARTY_CHANGED)
end

function TestPpfFirstTime:testVariableUpdateFirstTimeInRaid()
    mockInRaid = true
    
    VariableUpdateTestHelper(false, ATTR_PARTY_CHANGED)
end

--
function TestPpfRaidStyleFirstTime:testVariableUpdateFirstTime()
    VariableUpdateTestHelper(false, ATTR_HIDE_ALL)
end

function TestPpfRaidStyleFirstTime:testVariableUpdateFirstTimeInGroup()
    mockInGroup = true

    VariableUpdateTestHelper(false, ATTR_HIDE_ALL)
end

function TestPpfRaidStyleFirstTime:testVariableUpdateFirstTimeInRaid()
    mockInRaid = true

    VariableUpdateTestHelper(false, ATTR_HIDE_ALL)
end

--
function TestPpfInCombatFirstTime:testVariableUpdateFirstTime()
    VariableUpdateTestHelper(true, ATTR_HIDE_ALL)
end

function TestPpfInCombatFirstTime:testVariableUpdateFirstTimeInGroup()
    mockInGroup = true

    VariableUpdateTestHelper(true, ATTR_PARTY_CHANGED)
end

function TestPpfInCombatFirstTime:testVariableUpdateFirstTimeInRaid()
    mockInRaid = true

    VariableUpdateTestHelper(true, ATTR_PARTY_CHANGED)
end

--
function TestPpfInCombatRaidStyleFirstTime:testVariableUpdateFirstTime()
    VariableUpdateTestHelper(true, ATTR_HIDE_ALL)
end

function TestPpfInCombatRaidStyleFirstTime:testVariableUpdateFirstTimeInGroup()
    mockInGroup = true

    VariableUpdateTestHelper(true, ATTR_HIDE_ALL)
end

function TestPpfInCombatRaidStyleFirstTime:testVariableUpdateFirstTimeInRaid()
    mockInRaid = true

    VariableUpdateTestHelper(true, ATTR_HIDE_ALL)
end
-- ~testVariableUpdateFirstTime

-- UpdateVariableFinishedLoading
function TestPpf:testVariableUpdateFinishedLoading()
	VariableUpdateTestHelper(false, ATTR_HIDE_ALL)
end

function TestPpf:testVariableUpdateFinishedLoadingInGroup()
	mockInGroup = true

    VariableUpdateTestHelper(false, ATTR_PARTY_CHANGED)
end

function TestPpf:testVariableUpdateFinishedLoadingInRaid()
    mockInRaid = true

    VariableUpdateTestHelper(false, ATTR_PARTY_CHANGED)
end

--
function TestPpfRaidStyle:testVariableUpdateFinishedLoading()
	VariableUpdateTestHelper(false, ATTR_HIDE_ALL)
end

function TestPpfRaidStyle:testVariableUpdateFinishedLoadingInGroup()
	mockInGroup = true

    VariableUpdateTestHelper(false, ATTR_HIDE_ALL)
end

function TestPpfRaidStyle:testVariableUpdateFinishedLoadingInRaid()
	mockInRaid = true

    VariableUpdateTestHelper(false, ATTR_HIDE_ALL)
end

--
function TestPpfDisabled:testVariableUpdateFinishedLoading()
	VariableUpdateTestHelper(false, ATTR_HIDE_ALL, true)
end

function TestPpfDisabled:testVariableUpdateFinishedLoadingInGroup()
	mockInGroup = true

    VariableUpdateTestHelper(false, ATTR_HIDE_ALL, true)
end

function TestPpfDisabled:testVariableUpdateFinishedLoadingInRaid()
	mockInRaid = true

    VariableUpdateTestHelper(false, ATTR_HIDE_ALL, true)
end

--
function TestPpfRaidStyleDisabled:testVariableUpdateFinishedLoading()
	VariableUpdateTestHelper(false, ATTR_HIDE_ALL, true)
end

function TestPpfRaidStyleDisabled:testVariableUpdateFinishedLoadingInGroup()
	mockInGroup = true

    VariableUpdateTestHelper(false, ATTR_HIDE_ALL, true)
end

function TestPpfRaidStyleDisabled:testVariableUpdateFinishedLoadingInRaid()
	mockInRaid = true

    VariableUpdateTestHelper(false, ATTR_HIDE_ALL, true)
end

--
function TestPpfInCombat:testVariableUpdateFinishedLoading()
	VariableUpdateTestHelper(true, ATTR_HIDE_ALL)
end

function TestPpfInCombat:testVariableUpdateFinishedLoadingInGroup()
	mockInGroup = true

    VariableUpdateTestHelper(true, ATTR_PARTY_CHANGED)
end

function TestPpfInCombat:testVariableUpdateFinishedLoadingInRaid()
	mockInRaid = true

    VariableUpdateTestHelper(true, ATTR_PARTY_CHANGED)
end

--
function TestPpfInCombatDisabled:testVariableUpdateFinishedLoading()
	VariableUpdateTestHelper(true, ATTR_HIDE_ALL, true)
end

function TestPpfInCombatDisabled:testVariableUpdateFinishedLoadingInGroup()
	mockInGroup = true

    VariableUpdateTestHelper(true, ATTR_HIDE_ALL, true)
end

function TestPpfInCombatDisabled:testVariableUpdateFinishedLoadingInRaid()
	mockInRaid = true

    VariableUpdateTestHelper(true, ATTR_HIDE_ALL, true)
end

--
function TestPpfInCombatRaidStyle:testVariableUpdateFinishedLoading()
	VariableUpdateTestHelper(true, ATTR_HIDE_ALL)
end

function TestPpfInCombatRaidStyle:testVariableUpdateFinishedLoadingInGroup()
	mockInGroup = true

    VariableUpdateTestHelper(true, ATTR_HIDE_ALL)
end

function TestPpfInCombatRaidStyle:testVariableUpdateFinishedLoadingInRaid()
	mockInRaid = true

    VariableUpdateTestHelper(true, ATTR_HIDE_ALL)
end

--
function TestPpfInCombatRaidStyleDisabled:testVariableUpdateFinishedLoading()
	VariableUpdateTestHelper(true, ATTR_HIDE_ALL, true)
end

function TestPpfInCombatRaidStyleDisabled:testVariableUpdateFinishedLoadingInGroup()
	mockInGroup = true

    VariableUpdateTestHelper(true, ATTR_HIDE_ALL, true)
end

function TestPpfInCombatRaidStyleDisabled:testVariableUpdateFinishedLoadingInRaid()
	mockInRaid = true

    VariableUpdateTestHelper(true, ATTR_HIDE_ALL, true)
end
-- ~UpdateVariableFinishedLoading

-- UpdateVariableVisibilityChangeRequested
-- Same test case as above but the change is initiated through a slash command
function TestPpf:testVariableUpdateVisibilityChangeRequestedDisable()
    VariableUpdateTestHelper(false, ATTR_HIDE_ALL, false, STATE_OFF)
end

function TestPpf:testVariableUpdateVisibilityChangeRequestedInGroupDisable()
    mockInGroup = true

    VariableUpdateTestHelper(false, ATTR_HIDE_ALL, false, STATE_OFF)
end

function TestPpf:testVariableUpdateVisibilityChangeRequestedInRaidDisable()
    mockInRaid = true

    VariableUpdateTestHelper(false, ATTR_HIDE_ALL, false, STATE_OFF)
end

--
function TestPpfRaidStyle:testVariableUpdateVisibilityChangeRequestedDisable()
    VariableUpdateTestHelper(false, ATTR_HIDE_ALL, false, STATE_OFF)
end

function TestPpfRaidStyle:testVariableUpdateVisibilityChangeRequestedInGroupDisable()
    mockInGroup = true

    VariableUpdateTestHelper(false, ATTR_HIDE_ALL, false, STATE_OFF)
end

function TestPpfRaidStyle:testVariableUpdateVisibilityChangeRequestedInRaidDisable()
    mockInRaid = true

    VariableUpdateTestHelper(false, ATTR_HIDE_ALL, false, STATE_OFF)
end

--
function TestPpfDisabled:testVariableUpdateVisibilityChangeRequestedEnable()
    VariableUpdateTestHelper(false, ATTR_HIDE_ALL, true, STATE_ON)
end

function TestPpfDisabled:testVariableUpdateVisibilityChangeRequestedInGroupEnable()
    mockInGroup = true

    VariableUpdateTestHelper(false, ATTR_PARTY_CHANGED, true, STATE_ON)
end

function TestPpfDisabled:testVariableUpdateVisibilityChangeRequestedInRaidEnable()
    mockInRaid = true

    VariableUpdateTestHelper(false, ATTR_PARTY_CHANGED, true, STATE_ON)
end

--
function TestPpfRaidStyleDisabled:testVariableUpdateVisibilityChangeRequestedEnable()
    VariableUpdateTestHelper(false, ATTR_HIDE_ALL, true, STATE_ON)
end

function TestPpfRaidStyleDisabled:testVariableUpdateVisibilityChangeRequestedInGroupEnable()
    mockInGroup = true

    VariableUpdateTestHelper(false, ATTR_HIDE_ALL, true, STATE_ON)
end

function TestPpfRaidStyleDisabled:testVariableUpdateVisibilityChangeRequestedInRaidEnable()
    mockInRaid = true

    VariableUpdateTestHelper(false, ATTR_HIDE_ALL, true, STATE_ON)
end

--
function TestPpfInCombat:testVariableUpdateVisibilityChangeRequestedDisable()
    VariableUpdateTestHelper(true, ATTR_HIDE_ALL, false, STATE_OFF)
end

function TestPpfInCombat:testVariableUpdateVisibilityChangeRequestedInGroupDisable()
    mockInGroup = true

    VariableUpdateTestHelper(true, ATTR_HIDE_ALL, false, STATE_OFF)
end

function TestPpfInCombat:testVariableUpdateVisibilityChangeRequestedInRaidDisable()
    mockInRaid = true

    VariableUpdateTestHelper(true, ATTR_HIDE_ALL, false, STATE_OFF)
end

--
function TestPpfInCombatDisabled:testVariableUpdateVisibilityChangeRequestedEnable()
    VariableUpdateTestHelper(true, ATTR_HIDE_ALL, true, STATE_ON)
end

function TestPpfInCombatDisabled:testVariableUpdateVisibilityChangeRequestedInGroupEnable()
    mockInGroup = true

    VariableUpdateTestHelper(true, ATTR_PARTY_CHANGED, true, STATE_ON)
end

function TestPpfInCombatDisabled:testVariableUpdateVisibilityChangeRequestedInRaidEnable()
    mockInRaid = true

    VariableUpdateTestHelper(true, ATTR_PARTY_CHANGED, true, STATE_ON)
end

--
function TestPpfInCombatRaidStyle:testVariableUpdateVisibilityChangeRequestedDisable()
    VariableUpdateTestHelper(true, ATTR_HIDE_ALL, false, STATE_OFF)
end

function TestPpfInCombatRaidStyle:testVariableUpdateVisibilityChangeRequestedInGroupDisable()
    mockInGroup = true

    VariableUpdateTestHelper(true, ATTR_HIDE_ALL, false, STATE_OFF)
end

function TestPpfInCombatRaidStyle:testVariableUpdateVisibilityChangeRequestedInRaidDisable()
    mockInRaid = true

    VariableUpdateTestHelper(true, ATTR_HIDE_ALL, false, STATE_OFF)
end

--
function TestPpfInCombatRaidStyleDisabled:testVariableUpdateVisibilityChangeRequestedEnable()
    VariableUpdateTestHelper(true, ATTR_HIDE_ALL, true, STATE_ON)
end

function TestPpfInCombatRaidStyleDisabled:testVariableUpdateVisibilityChangeRequestedInGroupEnable()
    mockInGroup = true

    VariableUpdateTestHelper(true, ATTR_HIDE_ALL, true, STATE_ON)
end

function TestPpfInCombatRaidStyleDisabled:testVariableUpdateVisibilityChangeRequestedInRaidEnable()
    mockInRaid = true

    VariableUpdateTestHelper(true, ATTR_HIDE_ALL, true, STATE_ON)
end
-- ~UpdateVariableVisibilityChangeRequested

-- ~VariableUpdate tests

-- PartyEvent tests
-- Verifies that once the loading is done, party events will be listened to and handled correctly.
-- If the addon is finished loading, enabled, while the compact party frames (raid style) are disabled,
-- we will propagate all party events to the frame manager. Otherwise no event should be routed.

-- testPartyEventsPropagation
local function PartyEventsPropagationTestHelper(inCombat, shouldRoute)
    BroadcastEvent(EVENT_LOADED)

    if inCombat then
        FinishCombat()
    end

    local partyEventCount = 0
    for key, event in pairs(PPF_C.EVENTS_PARTY) do
        BroadcastEvent(event)
        partyEventCount = partyEventCount + 1
    end

    local expectedEventCount = 0
    if shouldRoute then
        expectedEventCount = partyEventCount
    end
    
    local invocations = mockPetFrameManager[ATTR_INVOCATIONS]
    luaUnit.assertEquals(#invocations, expectedEventCount)

    luaUnit.assertEquals(ogUpdatePetCallCounter, 0)
end

function TestPpf:testPartyEventsRouted()
    PartyEventsPropagationTestHelper(false, true)
end

function TestPpf:testPartyEventsRoutedInGroup()
    mockInGroup = true

    PartyEventsPropagationTestHelper(false, true)
end

function TestPpf:testPartyEventsRoutedInRaid()
    mockInRaid = true

    PartyEventsPropagationTestHelper(false, true)
end

--
function TestPpfRaidStyle:testPartyEventsRouted()
    PartyEventsPropagationTestHelper(false, false)
end

function TestPpfRaidStyle:testPartyEventsRoutedInGroup()
    mockInGroup = true

    PartyEventsPropagationTestHelper(false, false)
end

function TestPpfRaidStyle:testPartyEventsRoutedInRaid()
    mockInRaid = true

    PartyEventsPropagationTestHelper(false, false)
end

--
function TestPpfDisabled:testPartyEventsRouted()
    PartyEventsPropagationTestHelper(false, false)
end

function TestPpfDisabled:testPartyEventsRoutedInGroup()
    mockInGroup = true

    PartyEventsPropagationTestHelper(false, false)
end

function TestPpfDisabled:testPartyEventsRoutedInRaid()
    mockInRaid = true

    PartyEventsPropagationTestHelper(false, false)
end

--
function TestPpfRaidStyleDisabled:testPartyEventsRouted()
    PartyEventsPropagationTestHelper(false, false)
end

function TestPpfRaidStyleDisabled:testPartyEventsRoutedInGroup()
    mockInGroup = true

    PartyEventsPropagationTestHelper(false, false)
end

function TestPpfRaidStyleDisabled:testPartyEventsRoutedInRaid()
    mockInRaid = true

    PartyEventsPropagationTestHelper(false, false)
end

--
function TestPpfInCombat:testPartyEventsRouted()
    PartyEventsPropagationTestHelper(true, true)
end

function TestPpfInCombat:testPartyEventsRoutedInGroup()
    mockInGroup = true

    PartyEventsPropagationTestHelper(true, true)
end

function TestPpfInCombat:testPartyEventsRoutedInRaid()
    mockInRaid = true

    PartyEventsPropagationTestHelper(true, true)
end

--
function TestPpfInCombatDisabled:testPartyEventsRouted()
    PartyEventsPropagationTestHelper(true, false)
end

function TestPpfInCombatDisabled:testPartyEventsRoutedInGroup()
    mockInGroup = true

    PartyEventsPropagationTestHelper(true, false)
end

function TestPpfInCombatDisabled:testPartyEventsRoutedInRaid()
    mockInRaid = true

    PartyEventsPropagationTestHelper(true, false)
end

--
function TestPpfInCombatRaidStyle:testPartyEventsRouted()
    PartyEventsPropagationTestHelper(true, false)
end

function TestPpfInCombatRaidStyle:testPartyEventsRoutedInGroup()
    mockInGroup = true

    PartyEventsPropagationTestHelper(true, false)
end

function TestPpfInCombatRaidStyle:testPartyEventsRoutedInRaid()
    mockInRaid = true

    PartyEventsPropagationTestHelper(true, false)
end

--
function TestPpfInCombatRaidStyleDisabled:testPartyEventsRouted()
    PartyEventsPropagationTestHelper(true, false)
end

function TestPpfInCombatRaidStyleDisabled:testPartyEventsRoutedInGroup()
    mockInGroup = true

    PartyEventsPropagationTestHelper(true, false)
end

function TestPpfInCombatRaidStyleDisabled:testPartyEventsRoutedInRaid()
    mockInRaid = true

    PartyEventsPropagationTestHelper(true, false)
end
-- ~testPartyEventsPropagation
-- ~PartyEvent tests

-- testUpdatePetPostHook
-- We post hook into this This Blizzard function to improve it's positioning shortcomings. Assert that our
-- post hook works as expected.
local function UpdatePetPostHookTestHelper()
    BroadcastEvent(EVENT_LOADED)

    if inCombat then
        FinishCombat()
    end

    local expectedCallCount = 1
    luaUnit.assertEquals(ogUpdatePetCallCounter, expectedCallCount - 1)

    PartyMemberFrame_UpdatePet()

    luaUnit.assertEquals(ogUpdatePetCallCounter, expectedCallCount)

    local invocations = mockPetFrameManager[ATTR_INVOCATIONS]
    luaUnit.assertEquals(#invocations, expectedCallCount)
end

function TestPpf:UpdatePetPostHookTestHelper()
    UpdatePetPostHookTestHelper()
end

function TestPpf:UpdatePetPostHookTestHelperInGroup()
    mockInGroup = true

    UpdatePetPostHookTestHelper()
end

function TestPpf:UpdatePetPostHookTestHelperInRaid()
    mockInRaid = true

    UpdatePetPostHookTestHelper()
end

--
function TestPpfRaidStyle:UpdatePetPostHookTestHelper()
    UpdatePetPostHookTestHelper()
end

function TestPpfRaidStyle:UpdatePetPostHookTestHelperInGroup()
    mockInGroup = true

    UpdatePetPostHookTestHelper()
end

function TestPpfRaidStyle:UpdatePetPostHookTestHelperInRaid()
    mockInRaid = true

    UpdatePetPostHookTestHelper()
end

--
function TestPpfDisabled:UpdatePetPostHookTestHelper()
    UpdatePetPostHookTestHelper()
end

function TestPpfDisabled:UpdatePetPostHookTestHelperInGroup()
    mockInGroup = true

    UpdatePetPostHookTestHelper()
end

function TestPpfDisabled:UpdatePetPostHookTestHelperInRaid()
    mockInRaid = true

    UpdatePetPostHookTestHelper()
end

--
function TestPpfRaidStyleDisabled:UpdatePetPostHookTestHelper()
    UpdatePetPostHookTestHelper()
end

function TestPpfRaidStyleDisabled:UpdatePetPostHookTestHelperInGroup()
    mockInGroup = true

    UpdatePetPostHookTestHelper()
end

function TestPpfRaidStyleDisabled:UpdatePetPostHookTestHelperInRaid()
    mockInRaid = true

    UpdatePetPostHookTestHelper()
end

--
function TestPpfInCombat:UpdatePetPostHookTestHelper()
    UpdatePetPostHookTestHelper()
end

function TestPpfInCombat:UpdatePetPostHookTestHelperInGroup()
    mockInGroup = true

    UpdatePetPostHookTestHelper()
end

function TestPpfInCombat:UpdatePetPostHookTestHelperInRaid()
    mockInRaid = true

    UpdatePetPostHookTestHelper()
end

--
function TestPpfInCombatDisabled:UpdatePetPostHookTestHelper()
    UpdatePetPostHookTestHelper()
end

function TestPpfInCombatDisabled:UpdatePetPostHookTestHelperInGroup()
    mockInGroup = true

    UpdatePetPostHookTestHelper()
end

function TestPpfInCombatDisabled:UpdatePetPostHookTestHelperInRaid()
    mockInRaid = true

    UpdatePetPostHookTestHelper()
end

--
function TestPpfInCombatRaidStyle:UpdatePetPostHookTestHelper()
    UpdatePetPostHookTestHelper()
end

function TestPpfInCombatRaidStyle:UpdatePetPostHookTestHelperInGroup()
    mockInGroup = true

    UpdatePetPostHookTestHelper()
end

function TestPpfInCombatRaidStyle:UpdatePetPostHookTestHelperInRaid()
    mockInRaid = true

    UpdatePetPostHookTestHelper()
end

--
function TestPpfInCombatRaidStyleDisabled:UpdatePetPostHookTestHelper()
    UpdatePetPostHookTestHelper()
end

function TestPpfInCombatRaidStyleDisabled:UpdatePetPostHookTestHelperInGroup()
    mockInGroup = true

    UpdatePetPostHookTestHelper()
end

function TestPpfInCombatRaidStyleDisabled:UpdatePetPostHookTestHelperInRaid()
    mockInRaid = true

    UpdatePetPostHookTestHelper()
end
-- ~testUpdatePetPostHook

os.exit(luaUnit.LuaUnit.run())
