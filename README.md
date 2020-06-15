TFRP v1.2.0 by Thod

Thank you for downloading my Team Fortress Roleplay Mod!
All required plugins are on the AlliedModders page.

___________________________________________
[ Installation ]

	1. Dump every folder from tfrp_v1.2 into your server's tf folder
	2. Restart your server if it's running
	3. Enter database's info (See [Configuring Database] in this file)
	4. Configure everything to your liking (addons/sourcemod/configs/tfrp/cfg)
	5. Done!
___________________________________________

[ Configuring Database ]
Add this to tf/addons/sourcemod/configs/database.cfg

	"tfrp"
	{
		"driver"			"default"
		"host"				""
		"database"			""
		"user"				""
		"pass"				""
	}

Enter your database information accordingly

[ Configuring ]

*All config files can be found at addons/sourcemod/configs/tfrp/cfg
*General configuration can be found in tfrp_config.txt

[Configuring Shop]

*Shop can be found in tfrp_shop.txt
*All items MUST have a valid category or else it won't show up!
*You can make categories in tfrp_categories
*The number the category has is how high it will apear in the shop
(Ex: 1 will be first in the shop)

*Shop items have 3 types: Item, Ent, and Weapon

Creating Items:
	
	"New Item" // Name of item
	{
		"Type"		"item" // Type of item
		"Price"		"100" // Price of item
		"Category" 	"General" // Category name
		"Job_Reqs" // Jobs that can buy the item
		{
			"1" "JobName" // If you want to allow everyone, simply put "1" "any" here
			"2"	"JobName" // If you have "1" "any" you can remove this line, you can also add more by just adding the first number
		}
	}

Creating Ents:

	"New Ent" // Name of item
	{
		"Type"		"ent" // Type of item
		"Model"		"models/props_spytech/work_table001.mdl" // Model path of item
		"Price"		"100" // Price of item
		"Category"	"General" // Category name
		"Job_Reqs" // Jobs that can buy the item
		{
			"1" "JobName" // If you want to allow everyone, simply put "1" "any" here
			"2" "JobName" // If you have "1" "any" you can remove this line, you can also add more by just adding the first number
		}
	}

Creating Weapons:
	
	"Shotgun" // Name of weapon (doesn't have to be actual weapon's name)
	{
		"Type"		"weapon" // Type of item
		"Price"		"100" // Price of item
		"id"		"10" // Id of weapon (see http://wiki.alliedmods.net/Team_Fortress_2_Item_Definition_Indexes)
		"Job_Reqs" // Jobs that can buy the item
		{
			"1" "JobName" // If you want to allow everyone, simply put "1" "any" here
			"2" "JobName" // If you have "1" "any" you can remove this line, you can also add more by just adding the first number
		}
		"Category"	"Weapons" // Category of item
	}

[ NPC Types ]
You can change prices of NPC's items

You probably won't need to make another NPC type unless you're making an addon
NPC Types can be found in tfrp_npctypes

	"NewNPC" // NPC Type name
	{
		"Model"	"models/player/heavy.mdl" // NPC's model
		"Buys_Items" // List of items the NPC buys
		{
			"Sandvich"	"250" // Name and price
		}
	}

___________________________________________
[ What's New? ]

v1.1.0
*Changed messages for Sandvich making
*Changed messages for Australium mining
*All ents are stored in one array for owners
*New array for ent's item type
*Fixed bug related to using items
*Shortened and improved lots of code related to money making systems

v1.2.0

___________________________________________
[  Credits  ]

Thod - Main Programmer & Mapper
(https://steamcommunity.com/profiles/76561197975749074) 

The Illusion Squid - SQL Support
(https://steamcommunity.com/profiles/76561198126704647/)

TF2Attributes by FlaminSarge
https://forums.alliedmods.net/showthread.php?t=210221

TF2Items by FlaminSarge
https://forums.alliedmods.net/showthread.php?p=1337899

MoreColors by Dr. McKay
https://forums.alliedmods.net/showthread.php?t=185016

Play Testers:
Nutleaf (https://steamcommunity.com/profiles/76561198130434226)
GAME_NADE (https://steamcommunity.com/profiles/76561198029943162)
Hanstun (https://steamcommunity.com/profiles/76561198272066461)
Mokey900 (https://steamcommunity.com/profiles/76561197976549844)

Special Thanks:

TF2Maps.net
AlliedModders <3
___________________________________________
