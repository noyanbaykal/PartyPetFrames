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

PPF_L = {}

-- Commandline responses
PPF_L.COMMANDS = function(command1, enable, disable)
	return string.format('To show party pet frames: %s %s. To hide party pet frames: %s %s.', command1, enable, command1, disable)
end
PPF_L.LOADED = function(command1)
  return string.format('|cFF41a31aPartyPetFrames|r loaded. %s for commands.', command1)
end
PPF_L.ENABLED = function(command1, disable)
  return string.format('|cFF41a31aPartyPetFrames|r is enabled. To disable: %s %s.', command1, disable)
end
PPF_L.DISABLED = function(command1, enable)
  return string.format('|cFF41a31aPartyPetFrames|r is disabled. To enable: %s %s', command1, enable)
end

PPF_L.TXT_NOT_CLASSIC = 'PartyPetFrames supports classic only!'
PPF_L.TXT_USING_RAID_STYLE = [[Raid style party frames are being used. PartyPetFrames addon is
 biding it's time.]]
PPF_L.TXT_WONT_DEFER = 'A command is queued already, unable to accept new commands.'
PPF_L.TXT_WILL_DEFER = [[Unable to change console variable while in combat. Will defer until out of
 combat!]]
-- ~Commandline responses

return PPF_L
