# PartyPetFrames
 A World of Warcraft Classic addon that manages the visibility of the party pet frames and implements party pet frame power bars.

 In vanilla WoW the default party frames also showed party members' pets. This feature seems to have disappeared somewhere around patch 7.0.3 and is missing in classic as well. Having pet frames is useful in some niche situations and seeing awesome pet names is fun. I created PartyPetFrames to restore the vanilla feeling and functionality of these frames.

 Currently the party pet frames are hidden behind a console variable (ShowPartyPets) that can only be changed by loaded addon code. Once unhidden, the party fet frames mostly work with a few shortcomings. The placement of the frames are no longer accurate, pet existence is not tracked properly and the power bars have been lost.

 PartyPetFrames manages the console variable, updates party pet frames and implements pet power bars. Party pet frames display unit portraits, names, health & power bars and debuffs. The pet frames will be shown when the pets are nearby.

 If raid style party frames (compact frames) are enabled, this addon lies dormant.

 The addon has it's own enable / disable state which can be toggled without having to reload the ui. This might be convenient for players who'd like to see party pet frames only in certain situations.
 Note that the ShowPartyPets console variable cannot be modified while in combat.

 Commands
 /ppf enable
 /ppf disable
