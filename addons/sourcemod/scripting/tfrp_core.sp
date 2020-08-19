#define PLUGIN_NAME 		"TF2 Roleplay Mod"
#define PLUGIN_AUTHOR 		"Thod (SQL,Inv,Shop,Wearables,Targeting by The Illusion Squid)"
#define PLUGIN_DESCRIPTION 	"Roleplay mod for TF2"
#define PLUGIN_VERSION 		"1.4.0"
#define PLUGIN_URL 			"https://github.com/Th0d/tfrp"

#include <sourcemod>
#include <tf2attributes>
#include <tf2items>
#include <tf2>
#include <tfrp>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <morecolors>
#include <tf2items_giveweapon>

#pragma semicolon 1
#pragma newdecls             required


// Define
#define AUSTRALIUM_DRILL_MINED_AUSTRALIUM	"weapons/sentry_upgrading_steam4.wav"

#define DOOR_LOCK_SOUND						"doors/default_locked.wav"
#define DOOR_UNLOCK_SOUND					"doors/latchunlocked1.wav"

#define BONK_CANNER_GOT_BONK_SOUND			"buttons/button4.wav"
#define TFRP_ERROR_SOUND			"buttons/button10.wav"
#define BONK_CANNER_CANNED_BONK_SOUND		"physics/metal/metal_barrel_impact_soft3.wav"

#define PRINTER_AMBIENT_SOUND				"ambient/levels/labs/equipment_printer_loop1.wav"
#define PRINTER_PRINTED_SOUND				"mvm/mvm_money_pickup.wav"

#define MEDKIT_SOUND						"items/smallmedkit1.wav"

#define OFFSET_HEIGHT          -2.0								

#define MASK_PROP_SPAWN		(CONTENTS_SOLID|CONTENTS_WINDOW|CONTENTS_GRATE)
#define MAX_SPAWN_DISTANCE		256

#define MAX_QUERY_SIZE	2048 //Yup needed this magic number -Squid
#define DB_PRIO DBPrio_Normal

enum
{
	AnnounceJobSwitch,
	Prefix,
	Debug,
	SQLDebug,
	StartCash,
	StartJob,
	SalTime,
	JailTime,
	LotTime,
	WarrantTime,
	SandvichMakeTime,
	AustraliumDrillTime,
	AustraliumCleanTime,
	AustraliumFuelPerSecond,
	FuelPerCan,
	BankRobTime,
	CopsToRob,
	PrintTimeT1,
	PrintTimeT2,
	PrintTimeT3,
	PrintT1Money,
	PrintT2Money,
	PrintT3Money,
	LockpickingTime,
	TimeBetweenLot,
	MaxLot,
	MaxDoors,
	MaxDroppedItems,
	HitPrice,
	ShopReturn,
	BonkBrewTime,
	BonkCanTime,
	RobberyInBetweenTime,
	WarrantReward,
	SQLUpdateInterval,
	Version
} //When adding new cvars, please put them above Version. Thanks - The Illusion Squid

ConVar cvarTFRP[Version + 1];

///////////
//  SQL  //
///////////
char sUserInfoTable[32]; //Stores info
char sUserInvTable[32]; //Stores items

//Initial
char sQuery_CreateTable_UserInfo[] = "CREATE TABLE IF NOT EXISTS %s (`auth` VARCHAR(32) NOT NULL, `name` TEXT NOT NULL, `cash` INT(16) NOT NULL, `join_date` BIGINT(11) NOT NULL, `playtime` BIGINT(11) NOT NULL, `last_update` BIGINT(11) NOT NULL, PRIMARY KEY (`auth`));";
char sQuery_CreateTable_UserInventory[] = "CREATE TABLE IF NOT EXISTS %s (`auth` VARCHAR(32) NOT NULL, `item_id` VARCHAR(32) NULL DEFAULT NULL, `item_count` INT(11) NOT NULL DEFAULT 0, UNIQUE KEY `item_id` (`auth`, `item_id`));";
// Get info
char sQuery_GetUserinfo[] = "SELECT * FROM %s WHERE auth = '%s';";
// char sQuery_GetUserCash[] = "SELECT cash FROM %s WHERE auth = '%s';";
// char sQuery_GetUserItem[] = "SELECT item_count FROM %s WHERE auth = '%s' AND item_id = '%s';";
char sQuery_GetUserItems[] = "SELECT item_id, item_count FROM %s WHERE auth = '%s';";
//Update info
char sQuery_UpdateUserCash[] = "UPDATE %s SET `cash` = %d, `last_update` = %d WHERE auth = '%s';";
char sQuery_UpdateUserInfoFull[] = "UPDATE %s SET `name` = '%s', `cash` = %d, `playtime` = %d, `last_update` = %d WHERE auth = '%s';";
// char sQuery_UpdateUserItem[] = "UPDATE %s SET `item_count` = item_count + %d WHERE auth = '%s' AND item_id = '%s';";
char sQuery_SetUserItem[] = "INSERT INTO %s (auth, item_id, item_count) VALUES ('%s', '%s', %d) ON DUPLICATE KEY UPDATE `item_count` = %d;";
// char sQuery_InsertUserItem[] = "INSERT INTO  %s (auth, item_id, item_count) VALUES ('%s', '%s', %d);";
//Register
char sQuery_RegisterNewUserInfo[] = "INSERT INTO %s (auth, name, cash, join_date, playtime, last_update) VALUES ('%s', '%s', %d, %d, %i, %d);";

Handle g_hSQL;

/////////////
//  Cache  //
/////////////

enum struct UserData
{
	int iCash;			//Players cash
	int iPlayTime;		//TOTAL playtime on the plugin
	int iJoinTime;		//Timestamp of join event
	int iLogTime;		//Timestamp of last playtime update
	char sJob[255];		//Job name
	int iJobSalary;		//Jobs salary
	bool bGov;			//If the player has a goverment job
	bool bArrested;		//If the player is arrested
	bool bLockpicking;	//If the player is lockpicking a door
	bool bInLot;		//If the player is in the lottery
	bool bOwnDoors;		//If the player can own doors
	bool bHasWarrent;	//If the player has a warrent
	bool isRobbingBank; //If the player is robbing a bank
	bool firstSpawn; 	//If this is the first time a player spawns
}

UserData UD[MAXPLAYERS + 1]; 
//Much cleaner way of storing user data then all separate variables -Squid

Handle hItemArray[MAXPLAYERS + 1]; //Contains the inv of a client

// TFRP Hooks
GlobalForward g_tfrp_forwards[128];

// File Strings
static char ShopPath[PLATFORM_MAX_PATH];
static char ConfPath[PLATFORM_MAX_PATH];
static char JobPath[PLATFORM_MAX_PATH];
static char DoorsPath[PLATFORM_MAX_PATH];
static char BankVaultPath[PLATFORM_MAX_PATH];
static char NPCPath[PLATFORM_MAX_PATH];
static char NPCTypePath[PLATFORM_MAX_PATH];
static char CategoryPath[PLATFORM_MAX_PATH];
static char JailPath[PLATFORM_MAX_PATH];
static char RadioPath[PLATFORM_MAX_PATH];

// Config variables

int bankWorth = 0; // 0 is default
int bankIndex = 0; // 0 is default
int bankRobHudTime = 300; // 300 is default
bool isBeingRobbed = false; // false is default
bool RobbingEnabled = true; // true is default

int LotAmt = 0; // 0 is default
int lotteryStarter = 0; // 0 is default
bool isLottery = false; // false is default
bool lotAvaliable = true; // true is default

// RP Globals

static DroppedItems[MAXPLAYERS + 1] = {0,...};
static char DroppedItemNames[2048][255];
static char JailCells[10][255]; // Max 10 jail cells
static Doors[2048] = {0,...};
static DoorOwners[2048][5];
static lockedDoor[2048] = {false,...};
static float JailTimes[MAXPLAYERS + 1] = {0.0,...};
static isLockpicking[2048] = {0,...};
static DoorOwnedAmt[MAXPLAYERS + 1] = {0,...};
static EntOwners[2048] = {0,...};
static char EntItems[2048][255];

// Sandvich
static STableIngredients[2048][4];

// Australium
static AusFuels[2048] = {0,...};
static AusMined[2048] = {0,...};
	
static AusDirty[2048] = {0,...};
static AusClean[2048] = {0,...};
	
static AusPacks[2048] = {0,...};

// NPCs
static char NPCIds[7][255];
static NPCEnts[7] = {0,...};
static NPCEntsBox[7] = {0,...};

// Printers
static PrinterMoney[2048] = {0,...};
static isPrinter[2048] = {false,...};
static PrinterTier[2048] = {0,...};

// Hitman
static Hits[MAXPLAYERS + 1] = {0,...};

// Laws
static char Laws[10][255];

// Bonk
enum struct BonkMixerD
{
	int BonkWater;
	int BonkCaesium;
	int BonkSugar;
}
BonkMixerD BonkMixers[2048];

enum struct BonkCannerD
{
	int BonkInCanner;
	int BonkCans;
}
BonkCannerD BonkCanners[2048];

// Radio
int Radios[2048][2];

// Handles
Handle hHud1, hHud2, hHud3, hHud4, hHud5, hHud6, hHud7, hHud9, hHud10, hHud11, hHud12, hHud13, hHud14, hHud15, hHud16, hHud17;

Handle g_FfEnabled = INVALID_HANDLE;
Handle autoBalance = INVALID_HANDLE;
ConVar hEngineConVar;

//////////////
// Natives //
/////////////

public int Native_GetJobIndex(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	Handle DB4 = CreateKeyValues("Jobs");
	FileToKeyValues(DB4, "addons/sourcemod/configs/tfrp/tfrp_jobs.txt");

	KvGotoFirstSubKey(DB4,false);

	int getJobIndex = 0;

	do{
		
		getJobIndex++;
		
		char JobName[32];
		KvGetSectionName(DB4, JobName, sizeof(JobName));
		
		if(StrEqual(JobName, UD[client].sJob)) break;
		
		
    } while (KvGotoNextKey(DB4,false));

	CloseHandle(DB4);
	
	return getJobIndex;
}

public int Native_GiveItem(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char item[32];
	GetNativeString(2, item, sizeof(item));
	int amount = GetNativeCell(3);
	GiveItem(client, item, amount);
	return 0;
}

public int Native_RemoveItem(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char item[32];
	GetNativeString(2, item, sizeof(item));
	int amount = GetNativeCell(3);
	GiveItem(client, item, -amount); //Maybe remove this function entirely? -Squid
	return 0;
}

public int Native_GetCash(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client > 0 && IsClientInGame(client))
	{
		return UD[client].iCash;
	}else{
		return 0;
	}
}

public int Native_IsGov(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client > 0 && IsClientInGame(client))
	{
		if(UD[client].bGov)
		{
			return 1;
		}else{
			return 0;
		}
	}else{
		return 0;
	}
}

public int Native_GetEntOwner(Handle plugin, int numParams)
{
	int ent = GetNativeCell(1);
	if(ent >= 2048) return 0; // Entities cant have id over 2048 (table is maxed at 2047)
	int owner = EntOwners[ent];
	return owner;
}

public int Native_DeleteEnt(Handle plugin, int numParams)
{
	int ent = GetNativeCell(1);
	if(ent >= 2048 || ent <= -1 || EntOwners[ent] == 0) return 0;
	if(StrEqual(EntItems[ent], "Radio")) StopRadio(Radios[ent][0], Radios[ent][1], ent);
	EntOwners[ent] = 0;
	EntItems[ent] = "__no__item__";
	AcceptEntityInput(ent, "kill");
	RemoveEdict(ent);
	return 0;
}


public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};
 
public void OnPluginStart()
{
	//Load translation files
	LoadTranslations("common.phrases");
	
	/////////////////
	// Build Path //
	////////////////

	// Build path for shop
	CreateDirectory("addons/sourcemod/configs/tfrp/cfg", 3);
	BuildPath(Path_SM, ShopPath, sizeof(ShopPath), "configs/tfrp/cfg/tfrp_shop.txt");

	// Build path for config
	CreateDirectory("addons/sourcemod/configs/tfrp/cfg", 3);
	BuildPath(Path_SM, ConfPath, sizeof(ConfPath), "configs/tfrp/cfg/tfrp_config.txt");
	
	// Build path for jobs config
	CreateDirectory("addons/sourcemod/configs/tfrp/cfg", 3);
	BuildPath(Path_SM, JobPath, sizeof(JobPath), "configs/tfrp/cfg/tfrp_jobs.txt");
	
	// Build path for doors
	CreateDirectory("addons/sourcemod/configs/tfrp/info", 3);
	BuildPath(Path_SM, DoorsPath, sizeof(DoorsPath), "configs/tfrp/info/tfrp_doors.txt");

	// Build path for bank vault's position
	CreateDirectory("addons/sourcemod/configs/tfrp/info", 3);
	BuildPath(Path_SM, BankVaultPath, sizeof(BankVaultPath), "configs/tfrp/info/tfrp_bankvault.txt");
	
	// Build path for NPC positions
	CreateDirectory("addons/sourcemod/configs/tfrp/info", 3);
	BuildPath(Path_SM, NPCPath, sizeof(NPCPath), "configs/tfrp/info/tfrp_npcs.txt");
	
	// Build path for NPC types info
	CreateDirectory("addons/sourcemod/configs/tfrp/cfg", 3);
	BuildPath(Path_SM, NPCTypePath, sizeof(NPCTypePath), "configs/tfrp/cfg/tfrp_npctypes.txt");
	
	
	// Build path for categorized shop
	CreateDirectory("addons/sourcemod/configs/tfrp/cfg", 3);
	BuildPath(Path_SM, CategoryPath, sizeof(CategoryPath), "configs/tfrp/cfg/tfrp_categories.txt");
	
	// Build path for jail cells
	CreateDirectory("addons/sourcemod/configs/tfrp/info", 3);
	BuildPath(Path_SM, JailPath, sizeof(JailPath), "configs/tfrp/info/tfrp_jails.txt");
	
	// Build path for radio channels
	CreateDirectory("addons/sourcemod/configs/tfrp/cfg", 3);
	BuildPath(Path_SM, RadioPath, sizeof(RadioPath), "configs/tfrp/cfg/tfrp_radio.txt");

	
	// Hud
	hHud1 = CreateHudSynchronizer();
	hHud2 = CreateHudSynchronizer();
	hHud3 = CreateHudSynchronizer();
	hHud4 = CreateHudSynchronizer();
	hHud5 = CreateHudSynchronizer();
	hHud6 = CreateHudSynchronizer();
	hHud7 = CreateHudSynchronizer();
	//hHud8 = CreateHudSynchronizer();
	hHud9 = CreateHudSynchronizer();
	hHud10 = CreateHudSynchronizer();
	hHud11 = CreateHudSynchronizer();
	hHud12 = CreateHudSynchronizer();
	hHud13 = CreateHudSynchronizer();
	hHud14 = CreateHudSynchronizer();
	hHud15 = CreateHudSynchronizer();
	hHud16 = CreateHudSynchronizer();
	hHud17 = CreateHudSynchronizer();
	
	/////////////
	// Config //
	////////////
	
	// Load Config
	LoadConfig(false);

	// Event to remove control points
	HookEventEx("teamplay_round_start", Event_Roundstart);

	// Event for start weapons
	HookEvent("player_spawn", PlayerSpawn);
	
	// Event for player death
	HookEvent("player_death", OnPlayerDeath);
	
	// Prevent team switches and such
	AddCommandListener(onSwitchTeam, "jointeam");
	autoBalance = FindConVar("mp_autoteambalance");
	SetConVarFloat(autoBalance, 0.0);

	/////////////
	// Sounds //
	////////////

	PrecacheSound(AUSTRALIUM_DRILL_MINED_AUSTRALIUM, true);
	PrecacheSound(PRINTER_AMBIENT_SOUND, true);
	PrecacheSound(DOOR_LOCK_SOUND, true);
	PrecacheSound(DOOR_UNLOCK_SOUND, true);
	PrecacheSound(PRINTER_PRINTED_SOUND, true);
	PrecacheSound(MEDKIT_SOUND, true);
	PrecacheSound(BONK_CANNER_CANNED_BONK_SOUND, true);
	PrecacheSound(BONK_CANNER_GOT_BONK_SOUND, true);
	PrecacheSound(TFRP_ERROR_SOUND, true);
	
	// Precache radio music
	Handle RM = CreateKeyValues("Radio");
	FileToKeyValues(RM, RadioPath);
	
	KvGotoFirstSubKey(RM,false);
	do{
		if(KvGotoFirstSubKey(RM,false))
		{
			PrintToServer("bruh");
			do{
				char SoundFileName[64];
				KvGetSectionName(RM, SoundFileName, sizeof(SoundFileName));
				PrecacheSound(SoundFileName, true);
			} while (KvGotoNextKey(RM,false));
			KvGoBack(RM);
		}
	} while (KvGotoNextKey(RM,false));
	
	KvRewind(RM);
	CloseHandle(RM);
	
	//////////////////////
	// Create Forwards //
	/////////////////////

	g_tfrp_forwards[0] = new GlobalForward("TFRP_OnItemSpawn", ET_Event, Param_Cell, Param_String, Param_Cell);
	g_tfrp_forwards[1] = new GlobalForward("TFRP_OnItemBought", ET_Event, Param_Cell, Param_String, Param_Cell);
	g_tfrp_forwards[2] = new GlobalForward("TFRP_OnItemUse", ET_Event, Param_Cell, Param_String);
	g_tfrp_forwards[3] = new GlobalForward("TFRP_OnDoorBought", ET_Event, Param_Cell, Param_Cell);
	g_tfrp_forwards[4] = new GlobalForward("TFRP_OnDoorSold", ET_Event, Param_Cell, Param_Cell);
	
	//////////////
	// Convars //
	/////////////
	
	cvarTFRP[Version] = CreateConVar("sm_tfrp_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	cvarTFRP[AnnounceJobSwitch] = CreateConVar("tfrp_announce_job_switch", "1", "Enables/Disables announcing to all players when a player switches their job. (0 = disable)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarTFRP[Prefix] = CreateConVar("sm_tfrp_tableprefix", "tfrp", "Prefix for database tables. (Can be blank, however it is not recommended)", FCVAR_NOTIFY);
	//You're welcome to those who only have one SQL database -The Illusion Squid
	cvarTFRP[SQLDebug] = CreateConVar("sm_tfrp_sqldebug", "0", "Enables console debugging for TFRP SQL.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarTFRP[Debug] = CreateConVar("sm_tfrp_debug", "0", "Enables console debugging for TFRP General stuff.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	//////////////////////
	// Game Config CVAR //
	//////////////////////
	cvarTFRP[StartCash] = CreateConVar("sm_tfrp_startingcash", "5000", "Ammount of money new players start with.", FCVAR_NOTIFY);
	cvarTFRP[StartJob] = CreateConVar("sm_tfrp_startingjob", "Citizen", "The job players start as after connecting.", FCVAR_NOTIFY);
	cvarTFRP[SalTime] = CreateConVar("sm_tfrp_saltime", "120.0", "Time in seconds for players to recieve their paycheck. (RN needs a restart to apply changes)", FCVAR_NOTIFY);
	cvarTFRP[JailTime] = CreateConVar("sm_tfrp_jailtime", "120.0", "Jail time in seconds.", FCVAR_NOTIFY);
	cvarTFRP[LotTime] = CreateConVar("sm_tfrp_lotterytime", "300.0", "Time lottery is on in seconds.", FCVAR_NOTIFY);
	cvarTFRP[WarrantTime] = CreateConVar("sm_tfrp_warranttime", "300.0", "Time a warrant lasts in seconds.", FCVAR_NOTIFY);
	cvarTFRP[SandvichMakeTime] = CreateConVar("sm_tfrp_sandvichmaketime", "60.0", "Time it takes to make a sandvich in seconds.", FCVAR_NOTIFY);
	cvarTFRP[AustraliumDrillTime] = CreateConVar("sm_tfrp_austr_drilltime", "10.0", "Time between dirty australium being drilled.", FCVAR_NOTIFY);
	cvarTFRP[AustraliumCleanTime] = CreateConVar("sm_tfrp_austr_cleantime", "10.0", "Time between dirty australium being cleaned.", FCVAR_NOTIFY);
	cvarTFRP[AustraliumFuelPerSecond] = CreateConVar("sm_tfrp_fuelpersec", "1", "Fuel used by the australium drill per second.", FCVAR_NOTIFY);
	cvarTFRP[FuelPerCan] = CreateConVar("sm_tfrp_fuelpercan", "100", "Fuel per fuelcan.", FCVAR_NOTIFY);
	cvarTFRP[BankRobTime] = CreateConVar("sm_tfrp_bankrobtime", "300.0", "Time it takes to rob the bank in seconds.", FCVAR_NOTIFY);
	cvarTFRP[CopsToRob] = CreateConVar("sm_tfrp_cops_to_rob", "2", "Ammount of cops required to rob the bank.", FCVAR_NOTIFY);
	cvarTFRP[PrintTimeT1] = CreateConVar("sm_tfrp_printtime_t1", "60.0", "Time for bronze printers to print money.", FCVAR_NOTIFY);
	cvarTFRP[PrintTimeT2] = CreateConVar("sm_tfrp_printtime_t2", "60.0", "Time for silver printers to print money.", FCVAR_NOTIFY);
	cvarTFRP[PrintTimeT3] = CreateConVar("sm_tfrp_printtime_t3", "60.0", "Time for gold printers to print money.", FCVAR_NOTIFY);
	cvarTFRP[PrintT1Money] = CreateConVar("sm_tfrp_printmoney_t1", "250", "Ammount of money printed by bronze printers.", FCVAR_NOTIFY);
	cvarTFRP[PrintT2Money] = CreateConVar("sm_tfrp_printmoney_t2", "500", "Ammount of money printed by silver printers.", FCVAR_NOTIFY);
	cvarTFRP[PrintT3Money] = CreateConVar("sm_tfrp_printmoney_t3", "1000", "Ammount of money printed by gold printers.", FCVAR_NOTIFY);
	cvarTFRP[LockpickingTime] = CreateConVar("sm_tfrp_lockpickingtime", "20.0", "Time to lockpick a door in seconds.", FCVAR_NOTIFY);
	cvarTFRP[TimeBetweenLot] = CreateConVar("sm_tfrp_timebetweenlottery", "600.0", "Time between lotteries in seconds.", FCVAR_NOTIFY);
	cvarTFRP[MaxLot] = CreateConVar("sm_tfrp_maxlottery", "7500", "Maximum ammount a lottery can be worth. Change this as the money circulating the server increases.", FCVAR_NOTIFY);
	cvarTFRP[MaxDoors] = CreateConVar("sm_tfrp_maxdoors", "8", "Maximum ammount of doors a player can own.", FCVAR_NOTIFY);
	cvarTFRP[HitPrice] = CreateConVar("sm_tfrp_hitprice", "500", "Price to place a hit & ammount of money funded to hitman.", FCVAR_NOTIFY);
	cvarTFRP[MaxDroppedItems] = CreateConVar("sm_tfrp_maxdroppeditems", "10", "Maximum ammount of items dropped by a player. (NOTE: you don't want to set this too high, would risk lagging down the server.)", FCVAR_NOTIFY);
	cvarTFRP[ShopReturn] = CreateConVar("sm_tfrp_shopreturn", "2", "The ratio of refund. (Calculation: OriginalPrize / ShopReturn)", FCVAR_NOTIFY);
	cvarTFRP[BonkBrewTime] = CreateConVar("sm_tfrp_bonkbrewtime", "30.0", "Time for Bonk to be mixed in seconds.", FCVAR_NOTIFY);
	cvarTFRP[BonkCanTime] = CreateConVar("sm_tfrp_bonkcantime", "15.0", "Time for Bonk to be canned in seconds.", FCVAR_NOTIFY);
	cvarTFRP[RobberyInBetweenTime] = CreateConVar("sm_tfrp_robberyinbetweentime", "600.0", "Time for robbing the bank to be enabled again in seconds.", FCVAR_NOTIFY);
	cvarTFRP[WarrantReward] = CreateConVar("sm_tfrp_warrant_reward", "500", "Cash given to cop who arrests a player with a warrant.", FCVAR_NOTIFY);
	cvarTFRP[SQLUpdateInterval] = CreateConVar("sm_tfrp_sql_interval", "600.0", "Interval in between updating the SQL database. (Default = 10 min.)", FCVAR_NOTIFY);
	
	//Execute the config file in /cfg/sourcemod/ or create one if it doesn't exist
	AutoExecConfig(true, "tfrp"); 
	
	//////////////////
	// 	Downloads  //
	/////////////////
	
	if(FileExists("models/tfrp/bonkcanner.dx80.vtx")) AddFileToDownloadsTable("models/tfrp/bonkcanner.dx80.vtx");
	if(FileExists("models/tfrp/bonkcanner.dx90.vtx")) AddFileToDownloadsTable("models/tfrp/bonkcanner.dx90.vtx");
	if(FileExists("models/tfrp/bonkcanner.mdl")) AddFileToDownloadsTable("models/tfrp/bonkcanner.mdl");
	if(FileExists("models/tfrp/bonkcanner.phy")) AddFileToDownloadsTable("models/tfrp/bonkcanner.phy");
	if(FileExists("models/tfrp/bonkcanner.sw.vtx")) AddFileToDownloadsTable("models/tfrp/bonkcanner.sw.vtx");
	if(FileExists("models/tfrp/bonkcanner.vvd")) AddFileToDownloadsTable("models/tfrp/bonkcanner.vvd");
	if(FileExists("models/tfrp/bonkmixer.dx80.vtx")) AddFileToDownloadsTable("models/tfrp/bonkmixer.dx80.vtx");
	if(FileExists("models/tfrp/bonkmixer.dx90.vtx")) AddFileToDownloadsTable("models/tfrp/bonkmixer.dx90.vtx");
	if(FileExists("models/tfrp/bonkmixer.mdl")) AddFileToDownloadsTable("models/tfrp/bonkmixer.mdl");
	if(FileExists("models/tfrp/bonkmixer.phy")) AddFileToDownloadsTable("models/tfrp/bonkmixer.phy");
	if(FileExists("models/tfrp/bonkmixer.sw.vtx")) AddFileToDownloadsTable("models/tfrp/bonkmixer.sw.vtx");
	if(FileExists("models/tfrp/bonkmixer.vvd")) AddFileToDownloadsTable("models/tfrp/bonkmixer.vvd");
	if(FileExists("models/tfrp/saxton_hale.dx80.vtx")) AddFileToDownloadsTable("models/tfrp/saxton_hale.dx80.vtx");
	if(FileExists("models/tfrp/saxton_hale.dx90.vtx")) AddFileToDownloadsTable("models/tfrp/saxton_hale.dx90.vtx");
	if(FileExists("models/tfrp/saxton_hale.mdl")) AddFileToDownloadsTable("models/tfrp/saxton_hale.mdl");
	if(FileExists("models/tfrp/saxton_hale.phy")) AddFileToDownloadsTable("models/tfrp/saxton_hale.phy");
	if(FileExists("models/tfrp/saxton_hale.sw.vtx")) AddFileToDownloadsTable("models/tfrp/saxton_hale.sw.vtx");
	if(FileExists("models/tfrp/saxton_hale.vvd")) AddFileToDownloadsTable("models/tfrp/saxton_hale.vvd");
	
	// Materials (map materials come packed with the bsp)
	if(FileExists("materials/tfrp/bonkmixer/bottom.vtf")) AddFileToDownloadsTable("materials/tfrp/bonkmixer/bottom.vtf");
	if(FileExists("materials/tfrp/bonkmixer/bottom.vmt")) AddFileToDownloadsTable("materials/tfrp/bonkmixer/bottom.vmt");
	if(FileExists("materials/tfrp/bonkmixer/no_material.vtf")) AddFileToDownloadsTable("materials/tfrp/bonkmixer/no_material.vtf");
	if(FileExists("materials/tfrp/bonkmixer/no_material.vmt")) AddFileToDownloadsTable("materials/tfrp/bonkmixer/no_material.vmt");
	if(FileExists("materials/tfrp/bonkmixer/top.vtf")) AddFileToDownloadsTable("materials/tfrp/bonkmixer/top.vtf");
	if(FileExists("materials/tfrp/bonkmixer/top.vmt")) AddFileToDownloadsTable("materials/tfrp/bonkmixer/top.vmt");
	
	if(FileExists("materials/tfrp/bonkcanner/bonk_can.vtf")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/bonk_can.vtf");
	if(FileExists("materials/tfrp/bonkcanner/bonk_can.vmt")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/bonk_can.vmt");
	if(FileExists("materials/tfrp/bonkcanner/bonk_can_tips.vtf")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/bonk_can_tips.vtf");
	if(FileExists("materials/tfrp/bonkcanner/bonk_can_tips.vmt")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/bonk_can_tips.vmt");
	if(FileExists("materials/tfrp/bonkcanner/pipe.vtf")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/pipe.vtf");
	if(FileExists("materials/tfrp/bonkcanner/pipe.vmt")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/pipe.vmt");
	if(FileExists("materials/tfrp/bonkcanner/steel.vtf")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/steel.vtf");
	if(FileExists("materials/tfrp/bonkcanner/steel.vmt")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/steel.vmt");
	
	if(FileExists("materials/tfrp/bonkcanner/hale_body.vtf")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/hale_body.vtf");
	if(FileExists("materials/tfrp/bonkcanner/hale_body.vmt")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/hale_body.vmt");
	if(FileExists("materials/tfrp/bonkcanner/hale_body_normal.vtf")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/hale_body_normal.vtf");
	if(FileExists("materials/tfrp/bonkcanner/hale_egg.vtf")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/hale_egg.vtf");
	if(FileExists("materials/tfrp/bonkcanner/hale_egg.vmt")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/hale_egg.vmt");
	if(FileExists("materials/tfrp/bonkcanner/hale_head.vtf")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/hale_head.vtf");
	if(FileExists("materials/tfrp/bonkcanner/hale_head.vmt")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/hale_head.vmt");
	if(FileExists("materials/tfrp/bonkcanner/hale_misc.vtf")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/hale_misc.vtf");
	if(FileExists("materials/tfrp/bonkcanner/hale_misc.vmt")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/hale_misc.vmt");
	if(FileExists("materials/tfrp/bonkcanner/hale_misc_normal.vtf")) AddFileToDownloadsTable("materials/tfrp/bonkcanner/hale_misc_normal.vtf");
	

	////////////////////////
	// Register Commands //
	///////////////////////

	RegConsoleCmd("sm_job", Command_JOB);
	RegConsoleCmd("sm_jobs", Command_JOB);

	RegConsoleCmd("sm_shop", Command_BUYMENU);
	
	RegConsoleCmd("sm_rotate", Command_Rotate);
	
	RegConsoleCmd("sm_rphelp", Command_RPHelp);

	// Doors
	
	RegConsoleCmd("sm_buydoor", Command_BuyDoor);
	RegConsoleCmd("sm_lock", Command_LockDoor);
	RegConsoleCmd("sm_selldoor", Command_SellDoor);
	RegConsoleCmd("sm_givekeys", Command_GiveKeys);
	RegConsoleCmd("sm_revokekeys", Command_RevokeKeys);

	RegConsoleCmd("sm_givemoney", Command_GiveMoneyPtoP);
	
	RegConsoleCmd("sm_pickup", Command_Pickup);

	// Inv cmds
	RegConsoleCmd("sm_items", Command_INVENTORY);
	RegConsoleCmd("sm_inventory", Command_INVENTORY);
	RegConsoleCmd("sm_inv", Command_INVENTORY);

	// Bal cmds
	RegConsoleCmd("sm_cash", Command_BAL);
	RegConsoleCmd("sm_money", Command_BAL);
	RegConsoleCmd("sm_bal", Command_BAL);
	RegConsoleCmd("sm_balance", Command_BAL);
	
	// Police cmds
	RegConsoleCmd("sm_pradio", Command_PoliceRadio);
	RegConsoleCmd("sm_pr", Command_PoliceRadio);
	RegConsoleCmd("sm_arrest", Command_Arrest);
	
	// Bank robbing cmds
	RegConsoleCmd("sm_robbank", Command_RobBank);

	// Hitman
	RegConsoleCmd("sm_placehit", Command_PlaceHit);

	// Lottery
	RegConsoleCmd("sm_setlottery", Command_SetLottery);
	RegConsoleCmd("sm_joinlottery", Command_JoinLottery);
	
	// Laws
	RegConsoleCmd("sm_addlaw", Command_AddLaw);
	RegConsoleCmd("sm_deletelaw", Command_DeleteLaw);
	RegConsoleCmd("sm_laws", Command_Laws);
	
	// Warrant
	RegConsoleCmd("sm_setwarrant", Command_SetWarrant);
	RegConsoleCmd("sm_ram", Command_Ram);

	// Radio
	RegConsoleCmd("sm_radiochannel", Command_RadioChannel);
	
	/////////////////////
	// Admin Commands //
	////////////////////

	RegAdminCmd("sm_setcash", Command_SetCash, ADMFLAG_BAN);
	RegAdminCmd("sm_makenpc", Command_MakeNPC, ADMFLAG_BAN);
	RegAdminCmd("sm_deletenpc", Command_DeleteNPC, ADMFLAG_BAN);
	RegAdminCmd("sm_reloadconfig", Command_ReloadConf, ADMFLAG_BAN);
	RegAdminCmd("sm_setjob", Command_Setjob, ADMFLAG_BAN);
	
	// Teleport
	RegAdminCmd("sm_bring", Command_Bring, ADMFLAG_BAN);
	RegAdminCmd("sm_goto", Command_Goto, ADMFLAG_BAN);
	RegAdminCmd("sm_tp", Command_Teleport, ADMFLAG_BAN);
	
	// Doors
	RegAdminCmd("sm_deletebuyabledoor", Command_RemoveBuyableDoor, ADMFLAG_BAN);
	RegAdminCmd("sm_addbuyabledoor", Command_MakeBuyableDoor, ADMFLAG_BAN);
	
	// Police
	RegAdminCmd("sm_setjail", Command_SetJailCell, ADMFLAG_BAN);
	RegAdminCmd("sm_createbankvault", Command_CreateBankVault, ADMFLAG_BAN);
	RegAdminCmd("sm_addgovdoor", Command_AddGovDoor, ADMFLAG_BAN);
	RegAdminCmd("sm_deletegovdoor", Command_RemGovDoor, ADMFLAG_BAN);

	ConnectSQL();
}

public void OnPluginEnd()
{
	PrintToServer("[TFRP] PLUGIN IS ENDED!!!!!!!!!!!!!!");
	for (int i = 1; i < MaxClients + 1; i++)
	{
		if (IsClientConnected(i) && IsClientAuthorized(i) && IsClientInGame(i))
		{
			if (!IsFakeClient(i))
			{
				UpdateUserInfoFull(i);

				if (cvarTFRP[SQLDebug].BoolValue)
					PrintToServer("[TFRP] Update query activated for client: %d", i);
			}
		}
	}
	
	if(cvarTFRP[SQLDebug].BoolValue)
		PrintToServer("[TFRP] Updated the Database!");
}

public void ConnectSQL()
{
	SQL_TConnect(SQLCall_ConnectToDatabase, "tfrp"); //Get's sql credentials from database.cfg. Pretty standard
}

stock void RemoveWearableWeapons(int iClient) //By The Illusion Squid
{
	int iEnt = MaxClients + 1; 
	while ((iEnt = FindEntityByClassname(iEnt, "tf_wearable_demoshield")) != -1)
	{
		if (GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity") == iClient && !GetEntProp(iEnt, Prop_Send, "m_bDisguiseWearable"))
		{
			TF2_RemoveWearable(iClient, iEnt);
		}
	}

	iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, "tf_wearable")) != -1)
	{
		if(GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity") == iClient)
		{
			int i = GetEntProp(iEnt, Prop_Send, "m_iItemDefinitionIndex");
			switch(i)
			{ //Add Item Index here if I missed any wearable weapons.
				case 57, 231, 642, 226, 129, 133, 354, 444, 1101, 1001, 405, 608: {TF2_RemoveWearable(iClient, iEnt);}
				default: {}
			}
		}
	}
}

public void StripToMelee(int client) //Thanks to JB Redux (Scag, Drixvel and Nergal/Assyrian)
	{
	char sClassName[64];
	int wep = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
	if (wep > MaxClients && IsValidEdict(wep) && GetEdictClassname(wep, sClassName, sizeof(sClassName)))
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", wep);
	// TF2_SwitchToSlot(client, TFWeaponSlot_Melee);
	TF2_RemoveWeaponSlot(client, 0);
	TF2_RemoveWeaponSlot(client, 1);
	TF2_RemoveWeaponSlot(client, 3);
	TF2_RemoveWeaponSlot(client, 4);
	TF2_RemoveWeaponSlot(client, 5);
	RemoveWearableWeapons(client); //By The Illusion Squid
}

void SQLCall_ConnectToDatabase(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("Connection to the server failed with error %s.", error);
		PrintToServer("[TFRP] Connection to SQL database has failed! Error: %s", error);
		SetFailState("[TFRP] Connection to the database failed. Check log for more information. %s", PLUGIN_VERSION);
		return;
	}

	g_hSQL = hndl;

	if (g_hSQL == null) //This should be unreachable tho
	{
		LogError("Connection to the server failed with error %s.", error);
		PrintToServer("[TFRP] Connection to SQL database has failed! Error: %s", error);
		SetFailState("[TFRP] Connection to the database failed. Check log for more information. %s", PLUGIN_VERSION);
		return;
	}

	char prefix[16];
	cvarTFRP[Prefix].GetString(prefix, sizeof(prefix));
	if (prefix[0] != '\0')
		StrCat(prefix, 16, "_");
	//To keep the table names nice and clean. Default cvar will result in tfrp_user_info and tfrp_user_inventory
	Format(sUserInfoTable, sizeof(sUserInfoTable), "%suser_info", prefix);
	Format(sUserInvTable, sizeof(sUserInvTable), "%suser_inventory", prefix);

	Transaction trans = SQL_CreateTransaction();

	char sQuery[MAX_QUERY_SIZE];

	Format(sQuery, sizeof(sQuery), sQuery_CreateTable_UserInfo, sUserInfoTable);
	SQL_AddQuery(trans, sQuery);

	Format(sQuery, sizeof(sQuery), sQuery_CreateTable_UserInventory, sUserInvTable);
	SQL_AddQuery(trans, sQuery);

	SQL_ExecuteTransaction(g_hSQL, trans, SQL_Intial_Transaction_Success, SQL_Transaction_Failure, _, DB_PRIO);

	PrintToServer("[TFRP] Successfully connected to database!");
}

void SQL_Intial_Transaction_Success(Handle db, DataPack data, int numQueries, Handle[] results, any[] queryData)
{
	if (cvarTFRP[SQLDebug].BoolValue)
		LogMessage("[TFRP] Successfully created and executed Database Transaction with %d queries.", numQueries);
	
	for(int i = 1; i < MaxClients + 1; i++)
	{
		if (IsClientConnected(i) && IsClientAuthorized(i) && IsClientInGame(i))
		{
			if (!IsFakeClient(i))
			{
				GetUserInfo(i);
			}
		}
	}

	CreateTimer(cvarTFRP[SQLUpdateInterval].FloatValue, Timer_SQLUpdate, 0, TIMER_REPEAT);
}

void SQL_Transaction_Success(Handle db, DataPack data, int numQueries, Handle[] results, any[] queryData)
{
	if (cvarTFRP[SQLDebug].BoolValue)
		LogMessage("[TFRP] Successfully created and executed transaction with %d queries.", numQueries);
}

void SQL_Transaction_Failure(Handle db, DataPack data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("[TFRP] Could not complete transaction. Index %d: %s", failIndex, error);
	SetFailState("[TFRP] Failed transaction Initialization. Exiting...");
}

void RegisterNewUser(int iClient, int iPlayTime = 0)
{
	char sQuery[MAX_QUERY_SIZE],
		sAuth[32],
		sName[2 * MAX_NAME_LENGTH + 1],
		safeName[2 * MAX_NAME_LENGTH + 1];
	int iTS = GetTime();
	GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth));
	GetClientName(iClient, sName, sizeof(sName));
	SQL_EscapeString(g_hSQL, sName, safeName, sizeof(safeName)); //For heavens sake don't forget this

	//Let's also cache the new user
	UD[iClient].iCash = cvarTFRP[StartCash].IntValue;
	UD[iClient].iPlayTime = iPlayTime;
	UD[iClient].iJoinTime = iTS;
	UD[iClient].iLogTime = iTS;

	Transaction trans = SQL_CreateTransaction(); 
	//Made this a txn for updatable reasons.

	Format(sQuery, sizeof(sQuery), 
		sQuery_RegisterNewUserInfo, 
		sUserInfoTable, 
		sAuth,
		safeName,
		cvarTFRP[StartCash].IntValue,
		iTS,
		iPlayTime,
		iTS
	);

	if (hItemArray[iClient] == INVALID_HANDLE)
			hItemArray[iClient] = CreateArray();
		
	ClearArray2(hItemArray[iClient]);

	if (cvarTFRP[SQLDebug].BoolValue)
		PrintToServer("[TFRP] RegisterNewUserInfo query: %s", sQuery);
	
	SQL_AddQuery(trans, sQuery);

	SQL_ExecuteTransaction(g_hSQL, trans, SQL_Transaction_Success, SQL_Transaction_Failure, _, DB_PRIO);
}

void GetUserInfo(int iClient) //Stores user info inside cache and registers new users
{
	char sQuery[MAX_QUERY_SIZE],
		sAuth[32];
	GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth));

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, iClient);

	Transaction trans = SQL_CreateTransaction();

	Format(sQuery, sizeof(sQuery), 
		sQuery_GetUserinfo, 
		sUserInfoTable, 
		sAuth
	);
	SQL_AddQuery(trans, sQuery);

	Format(sQuery, sizeof(sQuery), sQuery_GetUserItems, sUserInvTable, sAuth);
	SQL_AddQuery(trans, sQuery);

	SQL_ExecuteTransaction(g_hSQL, trans, SQL_Join_Transaction_Success, SQL_Join_Transaction_Failure, hPack, DB_PRIO);
}

void SQL_Join_Transaction_Success(Handle db, DataPack data, int numQueries, Handle[] results, any[] queryData)
{
	if (cvarTFRP[SQLDebug].BoolValue)
		LogMessage("[TFRP] Successfully created and executed Join transaction with %d queries.", numQueries);

	ResetPack(data);
	int iClient = ReadPackCell(data);
	CloseHandle(data);

	if(results[0] != INVALID_HANDLE)
	{ //UserInfo
		if(SQL_GetRowCount(results[0]) <= 0)
		{
			RegisterNewUser(iClient);
			return;
		}

		while (SQL_FetchRow(results[0]))
		{
			UD[iClient].iCash = SQL_FetchInt(results[0], 2);
			UD[iClient].iPlayTime = SQL_FetchInt(results[0], 4);
		}
		UD[iClient].iJoinTime = GetTime();
		UD[iClient].iLogTime = GetTime();
	}
	if(results[1] != INVALID_HANDLE)
	{//UserInv
		if (hItemArray[iClient] == INVALID_HANDLE)
			hItemArray[iClient] = CreateArray();
		
		ClearArray2(hItemArray[iClient]);

		if (SQL_GetRowCount(results[1]) <= 0)
		{
			return; //Player has nothing in their inventory.
		}

		while (SQL_FetchRow(results[1]))
		{
			if (SQL_FetchInt(results[1], 1) > 0)
			{//Ignore Empty
				Handle hArray = CreateArray(ByteCountToCells(1024));
				char sItemName[32];

				SQL_FetchString(results[1], 0, sItemName, sizeof(sItemName));
				PushArrayString(hArray, sItemName);
				PushArrayCell(hArray, SQL_FetchInt(results[1], 1));

				PushArrayCell(hItemArray[iClient], hArray);
			}
		}
	}
}

void SQL_Join_Transaction_Failure(Handle db, DataPack data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("[TFRP] Could not complete Join transaction. Index %d: %s", failIndex, error);
	SetFailState("[TFRP] Failed Join transaction. Exiting...");
}

void UpdateUserInfoFull(int iClient)
{
	if(IsFakeClient(iClient)) //Don't need to save bots
		return;

	char sQuery[MAX_QUERY_SIZE],
		sAuth[32],
		sName[2 * MAX_NAME_LENGTH + 1],
		safeName[2 * MAX_NAME_LENGTH + 1];
	int iTS = GetTime();
	GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth));
	GetClientName(iClient, sName, sizeof(sName));
	SQL_EscapeString(g_hSQL, sName, safeName, sizeof(safeName));

	Transaction trans = SQL_CreateTransaction();
	//tnx for if I ever need to also finalize the inventory. -Squid
	//NOTE: And I was right wasn't I? -Squid
	
	Format(sQuery, sizeof(sQuery), 
		sQuery_UpdateUserInfoFull, 
		sUserInfoTable, 
		safeName,
		UD[iClient].iCash, 
		GetPlayTime(iClient),
		iTS, 
		sAuth
	);

	if (cvarTFRP[SQLDebug].BoolValue)
		PrintToServer("[TFRP] UpdateUserInfoFull query: %s", sQuery);

	SQL_AddQuery(trans, sQuery);

	//Now we're loping thru the inventory adding every item as a query.
	for (int i = 0; i < GetArraySize(hItemArray[iClient]); i++)
	{
		Handle hArray = GetArrayCell(hItemArray[iClient], i);
		char sItem[32];
		GetArrayString(hArray, 0, sItem, sizeof(sItem));
		Format(sQuery, sizeof(sQuery), sQuery_SetUserItem, sUserInvTable, sAuth, sItem, GetArrayCell(hArray, 1), GetArrayCell(hArray, 1));
		PrintToServer("[TFRP] %s", sQuery);
		SQL_AddQuery(trans, sQuery);
	}

	SQL_ExecuteTransaction(g_hSQL, trans, SQL_UU_Transaction_Success, SQL_Transaction_Failure, _, DB_PRIO);
}

void SQL_UU_Transaction_Success(Handle db, DataPack data, int numQueries, Handle[] results, any[] queryData)
{
	if (cvarTFRP[SQLDebug].BoolValue)
		LogMessage("[TFRP] Successfully created and execute UpdateFULL transaction with %d queries.", numQueries);

}

public Action Timer_SQLUpdate(Handle timer)
{
	for (int i = 1; i < MaxClients + 1; i++)
	{
		if (IsClientConnected(i) && IsClientAuthorized(i) && IsClientInGame(i))
		{
			if (!IsFakeClient(i))
			{
				UpdateUserInfoFull(i);

				if (cvarTFRP[SQLDebug].BoolValue)
					PrintToServer("[TFRP] Update query activated for client: %d", i);
			}
		}
	}
	
	if(cvarTFRP[SQLDebug].BoolValue)
		PrintToServer("[TFRP] Updated the Database!");

	return Plugin_Continue;
}

public int GetInvItemCount(int iClient, char[] sItem)
{
	for (int i = 0; i < GetArraySize(hItemArray[iClient]); i++)
	{
		Handle hArray = GetArrayCell(hItemArray[iClient], i);
		char buffer[32];
		GetArrayString(hArray, 0, buffer, sizeof(buffer));
		if (StrEqual(sItem, buffer))
		{
			return GetArrayCell(hArray, 1);
		}
	}
	return 0;
}

// Add/Remove items to people's inventories
public int GiveItem(int iClient, char[] GiveItemStr, int amt) //Can also give negative (so no RemItem any more)
{
	bool bItemFound = false;
	for (int i = 0; i < GetArraySize(hItemArray[iClient]); i++)
	{
		Handle hArray = GetArrayCell(hItemArray[iClient], i);
		char buffer[32];
		GetArrayString(hArray, 0, buffer, sizeof(buffer));
		if (StrEqual(GiveItemStr, buffer))
		{
			int ic = GetArrayCell(hArray, 1) + amt;
			if (ic < 0) ic = 0;
			SetArrayCell(hArray, 1, ic);
			
			bItemFound = true;
		}
	}

	if (!bItemFound && amt > 0)
	{
		Handle hArray = CreateArray(1024);
		PushArrayString(hArray, GiveItemStr);
		PushArrayCell(hArray, amt);
		PushArrayCell(hItemArray[iClient], hArray);
	}
	return 0;
}

void UpdateCash(int iClient)
{
	// UpdateCash should be called everytime the plugin changes a client's cash.
	// This helps prevent players from losing money if the server crashes.

	char sQuery[MAX_QUERY_SIZE],
		sAuth[32];
	int iTS = GetTime();
	GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth));
	
	Format(sQuery, sizeof(sQuery), 
		sQuery_UpdateUserCash, 
		sUserInfoTable, 
		UD[iClient].iCash, 
		iTS, 
		sAuth
	);
	
	if (cvarTFRP[SQLDebug].BoolValue)
		PrintToServer("[TFRP] UpdateCash query: %s", sQuery);

	SQL_TQuery(g_hSQL, SQLCall_UpdateUserCash, sQuery);
}

void SQLCall_UpdateUserCash(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
    {
		LogError("[TFRP] Failed to run UpdateUserCash query: %s", error);
		PrintToServer("[TFRP] Failed to run UpdateUserCash query: %s", error);
		return;
    }
}

int GetPlayTime(int iClient)
{
	int iTotalPlayTime = ((GetTime()-UD[iClient].iLogTime) + UD[iClient].iPlayTime);
	return iTotalPlayTime;
}

void UpdatePlayTime(int iClient)
{
	UD[iClient].iPlayTime = GetPlayTime(iClient);
	//I know this is a one line function. But I might add a query here later on.
	//This was the easiest option. -Squid
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("TFRP_GetJobIndex", Native_GetJobIndex);
	CreateNative("TFRP_GiveItem", Native_GiveItem);
	CreateNative("TFRP_RemoveItem", Native_RemoveItem);
	CreateNative("TFRP_GetCash", Native_GetCash);
	CreateNative("TFRP_IsGov", Native_IsGov);
	CreateNative("TFRP_GetEntOwner", Native_GetEntOwner);
	CreateNative("TFRP_DeleteEnt", Native_DeleteEnt); 
	
	RegPluginLibrary("tfrp");
	return APLRes_Success;
}

public void OnClientAuthorized(int iClient, const char[] sAuth)
{
	if(IsFakeClient(iClient))
		return;

	GetUserInfo(iClient); //Cashes some stuff
	
}

public void OnClientPutInServer(int client)
{
	// Load player's info when they connect and set their job to default.
	char StartingJob[32];
	cvarTFRP[StartJob].GetString(StartingJob, sizeof(StartingJob));
	UD[client].sJob = StartingJob;
	UD[client].iJobSalary = 50;
	UD[client].bGov = false;
	UD[client].bArrested = false;
	UD[client].bLockpicking = false;
	UD[client].bInLot = false;
	UD[client].bOwnDoors = false;
	UD[client].bHasWarrent = false;
	UD[client].isRobbingBank = false;
	UD[client].firstSpawn = true;

	// Team collision
	SetEntProp(client, Prop_Data, "m_CollisionGroup", 0); 
	
	// Force start team
	TF2_ChangeClientTeam(client, TFTeam_Red);
	int randomClassStart = GetRandomInt(1, 9);
	switch(randomClassStart)
	{
		case 1: {
			TF2_SetPlayerClass(client, TFClass_Scout);
		}
		case 2: {
			TF2_SetPlayerClass(client, TFClass_Sniper);
		}
		case 3: {
			TF2_SetPlayerClass(client, TFClass_Soldier);
		}
		case 4: {
			TF2_SetPlayerClass(client, TFClass_DemoMan);
		}
		case 5: {
			TF2_SetPlayerClass(client, TFClass_Medic);
		}
		case 6: {
			TF2_SetPlayerClass(client, TFClass_Heavy);
		}
		case 7: {
			TF2_SetPlayerClass(client, TFClass_Pyro);
		}
		case 8: {
			TF2_SetPlayerClass(client, TFClass_Spy);
		}
		case 9: {
			TF2_SetPlayerClass(client, TFClass_Engineer);
		}
	}

	
	// Area Voice Chat
	CreateTimer(0.1, Timer_GetChatClients, client, TIMER_REPEAT);

	// Main hud
	CreateTimer(0.1, HUD, client, TIMER_REPEAT);

	// Salary
	CreateTimer(cvarTFRP[SalTime].FloatValue, Timer_Cash, client, TIMER_REPEAT);

	// Aus Drill Hud
	CreateTimer(0.1, Timer_AusHUD, client, TIMER_REPEAT);
	
	// Bank Hud
	CreateTimer(0.1, Timer_BankHUD, client, TIMER_REPEAT);
	CreateTimer(1.0, BankHudRobbing, client, TIMER_REPEAT);
	
	// Door Hud
	CreateTimer(0.1, Timer_DoorHUD, client, TIMER_REPEAT);
	
	// Delete non-job related ents and doors
	CreateTimer(0.1, Timer_NoExploit, client, TIMER_REPEAT);
	
	// Printer Hud
	CreateTimer(0.1, Timer_PrinterHud, client, TIMER_REPEAT);
	
	// Lottery Hud
	CreateTimer(0.1, Timer_LotteryHud, client, TIMER_REPEAT);
	
	CreateTimer(1.0, Welcome, client);
	
}

public void OnClientDisconnect(int client)
{
	// Save player's info when they disconnect
	SavePlayerInfo(client);
	UpdateUserInfoFull(client);
	
}

public void LoadConfig(bool confreload)
{
	// Enable friendlyfire
	g_FfEnabled = FindConVar("mp_friendlyfire");
	SetConVarBool(g_FfEnabled, true);

	hEngineConVar = FindConVar("tf_avoidteammates_pushaway");
	SetConVarBool(hEngineConVar, true);
	
	if(!confreload)
	{
		// Just some extra startup things
		for(int i = 0; i <= 2047; i++)
		{
			DroppedItemNames[i] = "__no__item__";
			EntItems[i] = "__no__item__";
			if(i < 10) JailCells[i] = "none";
			
			DoorOwners[i][0] = 0;
			DoorOwners[i][1] = 0;
			DoorOwners[i][2] = 0;
			DoorOwners[i][3] = 0;
			DoorOwners[i][4] = 0;
			STableIngredients[i][0] = 0;
			STableIngredients[i][1] = 0;
			STableIngredients[i][2] = 0;
			STableIngredients[i][3] = 0;

			if(i <= MAXPLAYERS)
			{
				PrinterMoney[i] = 0;
			}
			
			if(i <= 6)
			{
				NPCIds[i] = "none";
			}
			if(i <= 9)
			{
				Laws[i] = "NO_LAW";
			}
		}
	}

}

public Action OnPlayerDeath(Handle event, char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(Hits[attacker] == victim)
	{
		char GetKilledPlayerName[MAX_NAME_LENGTH];
		GetClientName(victim, GetKilledPlayerName, sizeof(GetKilledPlayerName));
		
		UD[attacker].iCash += cvarTFRP[HitPrice].IntValue;
		// UpdateCash(attacker);
		
		CPrintToChatAll("{yellow}[TFRP ADVERT]{default} The hit on %s has been completed", GetKilledPlayerName);

		Hits[attacker] = 0;
	}
	
	if(UD[attacker].isRobbingBank)
	{
		UD[attacker].isRobbingBank = false;
		PrintCenterTextAll("Robbery failed");
		isBeingRobbed = false;
		RobbingEnabled = false;
		CreateTimer(cvarTFRP[RobberyInBetweenTime].FloatValue, ResetBank);
	}
	
	return Plugin_Continue;
}

// Prevent non cops from going blu and cops from going red (and everyone from going spec)

public Action onSwitchTeam(int client, char[] command, int argc)
{
	if(UD[client].bGov)
	{
		TF2_ChangeClientTeam( client, TFTeam_Blue );
		CPrintToChat(client, "{green}[TFRP]{default} Government officals must be {blue}BLU!");
	}else{
		TF2_ChangeClientTeam( client, TFTeam_Red );
		CPrintToChat(client, "{green}[TFRP]{default} Non-government must be {red}RED!");
	}
	return Plugin_Handled;
}

// Disabling control points as this is an rp mod
// Also disables the timer for infinite round time
// I guess this isn't needed anymore, but I'll keep it for now just in case
// I used to use cp_junction as a test map and that's why I implemented this
 
public Action Event_Roundstart(Handle event, const char[] name, bool dontBroadcast)
{

	CPrintToChatAll("{green}[TFRP]{default} Game starting, deleting control points...");

	int entity = -1;

	while ((entity = FindEntityByClassname(entity, "team_round_timer")) != -1)
	{
		AcceptEntityInput(entity, "kill");
		RemoveEdict(entity);
	}
	while ((entity = FindEntityByClassname(entity, "trigger_capture_area")) != -1)
	{
   		AcceptEntityInput(entity, "kill");
		RemoveEdict(entity);
	}
	while ((entity = FindEntityByClassname(entity, "team_control_point")) != -1)
	{
   		AcceptEntityInput(entity, "kill");
		RemoveEdict(entity);
	}

	CPrintToChatAll("{green}[TFRP]{default} Done!");
	
	CPrintToChatAll("{green}[TFRP]{default} Finding doors...");
	SetDoors();
	SetBank();
	SetNPCs();
	SetJails();
}

////////////////////
// Money related //
///////////////////

public void SavePlayerInfo(int client) //Maybe rename this function? -Squid
{
	// Reset arrays
	
	DoorOwnedAmt[client] = 0;
	DroppedItems[client] = 0;
	DeleteJobEnts(client);
	DeleteHit(client);
	
	for(int i = 0; i <= 2047; i++)
	{
		
		if(Doors[i] == client)
		{
			Doors[i] = -1;
			lockedDoor[i] = false;
			for(int d = 0; d <= 4; i++)
			{
				DoorOwners[i][d] = 0;
			}
			Action result;
			Call_StartForward(g_tfrp_forwards[4]);
			Call_PushCell(client);
			Call_PushCell(i);
			Call_Finish(result);
			
		}
		if(isLockpicking[i] == client)
		{
			isLockpicking[0] = 0;
		}
	}
	
	if(StrEqual(UD[client].sJob, "Mayor") && isLottery == true)
	{
		CPrintToChatAll("{yellow}[TFRP ADVERT]{default} Mayor left, canceling lottery and refunding participants");
		CancelLottery();
	}
	
}

public Action Command_SetCash(int client, int args)
{
	if(args!=2){
		CReplyToCommand(client, "{green}[TFRP]{default} Usage: sm_setcash <name> <amt>");
		return Plugin_Handled;
	}

	char sTarget[32], sName[32];
	int iTargetList[MAXPLAYERS];
	bool tn_is_ml;
	GetCmdArg(1, sTarget, sizeof(sTarget));
	int iTargetCount = ProcessTargetString(sTarget, client, iTargetList, MAXPLAYERS, 0, sName, sizeof(sName), tn_is_ml);

	if (iTargetCount != 1)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	char Arg2[32];
	GetCmdArg(2, Arg2, sizeof(Arg2));

	if(client == iTargetList[0])
	{
		if(StrEqual(Arg2, "default"))
		{
		UD[client].iCash = cvarTFRP[StartCash].IntValue;
		UpdateCash(client);
		CPrintToChat(client, "{green}[TFRP]{default} Set your balance to {mediumseagreen}%d", cvarTFRP[StartCash].IntValue);
		return Plugin_Handled;
		}else{
			UD[client].iCash = StringToInt(Arg2);
			UpdateCash(client);
			CPrintToChat(client, "{green}[TFRP]{default} Set your balance to {mediumseagreen}%d", StringToInt(Arg2));
			return Plugin_Handled;
		}
	}

	if (!IsFakeClient(iTargetList[0]) && IsClientInGame(iTargetList[0]))
	{
		if(StrEqual(Arg2, "default")){
			UD[iTargetList[0]].iCash = cvarTFRP[StartCash].IntValue;
		}
		else
		{
			UD[iTargetList[0]].iCash = StringToInt(Arg2);
		}
		char sTargetName[32];
		GetClientName(iTargetList[0], sTargetName, sizeof(sTargetName));
		UpdateCash(iTargetList[0]);
		CPrintToChat(iTargetList[0], "{green}[TFRP]{default} Your balance was set to {mediumseagreen}%d{default} by an administrator.", UD[iTargetList[0]].iCash);
		ReplyToCommand(client, "[TFRP] Set %s\'s balance to %d!", sTargetName, UD[iTargetList[0]].iCash);
		return Plugin_Handled;
	}
	
	ReplyToCommand(client, "[SM] Target is no longer in-game or is a Fake Client!");
	return Plugin_Handled;
}

// Salary Timer
public Action Timer_Cash(Handle timer, int client)
{
    // See if the player is in game and if they're a bot
	if(!IsClientInGame(client)) return Plugin_Continue;
	if(IsFakeClient(client)) return Plugin_Continue;
       	
	if(UD[client].bArrested)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You didn't get paid since you're arrested");
		return Plugin_Continue;
	}
	UD[client].iCash += UD[client].iJobSalary;
	// UpdateCash(client);
	CPrintToChat(client, "{green}[TFRP]{default} You recieved{mediumseagreen} %d{default} from your paycheck", UD[client].iJobSalary);

	return Plugin_Continue;

} 

// Reset timer
public Action Timer_NoExploit(Handle timer, int client)
{
	if(!IsClientInGame(client)) return Plugin_Continue;
	for(int i = 0; i <= 2047; i++)
	{
		if(Doors[i] == client && UD[client].bGov)
		{
			Doors[i] = -1;
			DoorOwnedAmt[client] = DoorOwnedAmt[client] - 1;
		}
		if(EntOwners[i] == client && isPrinter[i] && UD[client].bGov && !StrEqual(UD[client].sJob, "Mayor"))
		{
			PrinterMoney[i] = 0;
			AcceptEntityInput(i, "kill");
			RemoveEdict(i);
			isPrinter[i] = false;
			PrinterTier[i] = 0;
		}
	}
	return Plugin_Continue;
}


////////////////////
//// Menu Shit ////
///////////////////

public int MenuCallBackJob(Handle menuhandle, MenuAction action, int Client, int Position)
{
	if(action == MenuAction_Select)
	{
		char Item[20];
		char name[48];
		GetClientName(Client, name, sizeof(name));
		
		GetMenuItem(menuhandle, Position, Item, sizeof(Item));
		// See if there is already a mayor if they're switching to that job
		bool isMayor = false;
		
		if(StrEqual(Item, "Mayor"))
		{
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i))
				{
					if(StrEqual(UD[i].sJob, "Mayor"))
					{
						TFRP_PrintToChat(Client, "There is already a {mediumseagreen}Mayor!");
						isMayor = true;
					}
				}
			}
		}
		// See if their already that job.
		if(StrEqual(UD[Client].sJob, Item)){
			CPrintToChat(Client, "{green}[TFRP]{default} Your job is already {mediumseagreen}%s", Item);
		}else{
			if(!isMayor)
			{
				// Cancel lottery if they had one running
				if(StrEqual(UD[Client].sJob, "Mayor") && isLottery == true)
				{
					CPrintToChatAll("{yellow}[TFRP ADVERT]{default} Mayor switched jobs, canceling lottery and refunding participants");
					CancelLottery();
				}
		
		
				// Find job in file and give client the rules of that job
				Handle DB4 = CreateKeyValues("Jobs");
				FileToKeyValues(DB4, JobPath);

				if(KvJumpToKey(DB4, Item, false)){
					// Will detect if admin later
					UD[Client].sJob = Item;
					UD[Client].iJobSalary = KvGetNum(DB4, "Salary", 50); // If there isn't a salary it'll just be set to 50
					char IsPoliceStr[8];
					KvGetString(DB4, "IsGov", IsPoliceStr, sizeof(IsPoliceStr), "false");
					if(StrEqual(IsPoliceStr, "true"))
					{
						UD[Client].bGov = true;
						TF2_ChangeClientTeam(Client, TFTeam_Blue);
					}else{
						UD[Client].bGov = false;
						TF2_ChangeClientTeam(Client, TFTeam_Red);
					}
					
					ForcePlayerSuicide(Client);
			
					char CanOwnDoorsStr[8];
					KvGetString(DB4, "CanOwnDoors", CanOwnDoorsStr, sizeof(CanOwnDoorsStr), "true");
					if(StrEqual(CanOwnDoorsStr, "false"))
					{
						UD[Client].bOwnDoors = false;
					} else {
						UD[Client].bOwnDoors = true;
					}
					KvRewind(DB4);
					if(cvarTFRP[AnnounceJobSwitch].BoolValue){
						CPrintToChatAll("{green}[TFRP]{goldenrod} %s{default} set their job to {mediumseagreen}%s", name, Item);
					}else{
						CPrintToChat(Client, "{green}[TFRP]{default} Set your job to {mediumseagreen}%s", Item);
					}
			
					// Delete entities when people change jobs
					DeleteJobEnts(Client);
				
				}else{
					CPrintToChat(Client, "{green}[TFRP]{red} ERROR: {default}Could not find job in database");
				}

				CloseHandle(DB4);
			}
	    }
	}else if(action == MenuAction_End)
	{
		CloseHandle(menuhandle);
	}
	return 0;
}

public int MenuCallBackNPC(Handle menuhandlenpc, MenuAction action, int Client, int Position)
{
	if(action == MenuAction_Select)
	{
		char ItemNameNPC[32];
		GetMenuItem(menuhandlenpc, Position, ItemNameNPC, sizeof(ItemNameNPC));
		
		char ItemNamePriceNPC[32][32];
		ExplodeString(ItemNameNPC, ":", ItemNamePriceNPC, 2, sizeof(ItemNamePriceNPC));
		SellItem(Client, ItemNamePriceNPC[0], StringToInt(ItemNamePriceNPC[1]), 1);	

	} else if(action == MenuAction_End)
	{
		CloseHandle(menuhandlenpc);
	}
	return 0;
}


public int MenuCallBackHitman(Handle menuhandle, MenuAction action, int Client, int Position)
{
	if(action == MenuAction_Select)
	{
		char HitPlaceName[MAX_NAME_LENGTH];
		GetMenuItem(menuhandle, Position, HitPlaceName, sizeof(HitPlaceName));
			
		char SplitHitmanIdHit[MAX_NAME_LENGTH][MAX_NAME_LENGTH];
		ExplodeString(HitPlaceName, ":", SplitHitmanIdHit, 2, sizeof(SplitHitmanIdHit));
			
		HitmanNextMenu(Client, SplitHitmanIdHit[0], StringToInt(SplitHitmanIdHit[1]));
			
	} else if(action == MenuAction_End)
	{
		CloseHandle(menuhandle);
	}
	return 0;
}

public int HitmanNextMenu(int client, char NextHitPlaceName[MAX_NAME_LENGTH], int Hitman)
{
	Handle menuhandle = CreateMenu(MenuCallBackNextHitman);
	SetMenuTitle(menuhandle, "[TFRP] Place hit on %s for %d?", NextHitPlaceName, cvarTFRP[HitPrice].IntValue);

	int HitVictimId = 0;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			char GetHitVictimId[MAX_NAME_LENGTH];
			GetClientName(i, GetHitVictimId, sizeof(GetHitVictimId));
			
			if(StrEqual(GetHitVictimId, NextHitPlaceName)) HitVictimId = i;
		}
	}

	char FormatHitManNextHit[48];
	FormatEx(FormatHitManNextHit, sizeof(FormatHitManNextHit), "%d:%d-%d", HitVictimId, Hitman, client);
	AddMenuItem(menuhandle, FormatHitManNextHit, "Place Hit");

	SetMenuPagination(menuhandle, 2);
	SetMenuExitButton(menuhandle, true);
	DisplayMenu(menuhandle, client, 250);
	
	return 0;
}

public int MenuCallBackNextHitman(Handle menuhandle, MenuAction action, int Client, int Position)
{
	if(action == MenuAction_Select)
	{
		if(UD[Client].iCash  < cvarTFRP[HitPrice].IntValue)
		{
			CPrintToChat(Client, "{green}[TFRP]{default} Insufficent funds");
		}else{
			
			char HitPlaceName[48];
			GetMenuItem(menuhandle, Position, HitPlaceName, sizeof(HitPlaceName));
			
			char SplitHitmanIdHit[MAX_NAME_LENGTH][8];
			ExplodeString(HitPlaceName, ":", SplitHitmanIdHit, 2, sizeof(SplitHitmanIdHit));
			
			char SplitHitmanHitPlacer[8][8];
			ExplodeString(SplitHitmanIdHit[1], "-", SplitHitmanHitPlacer, 2, sizeof(SplitHitmanHitPlacer));
			
			int curHitman = StringToInt(SplitHitmanHitPlacer[0]);
			int curPlacerHit = StringToInt(SplitHitmanHitPlacer[1]);
			int curHitVictim = StringToInt(SplitHitmanIdHit[0]);

			char GetHitmanAndHitName[MAX_NAME_LENGTH*2];
			FormatEx(GetHitmanAndHitName, sizeof(GetHitmanAndHitName), "%s:%s", curPlacerHit, curHitman);

			Hits[StringToInt(SplitHitmanHitPlacer[0])] = curHitVictim;
			UD[curPlacerHit].iCash -= cvarTFRP[HitPrice].IntValue;
			
			char GetHitPlacerName[MAX_NAME_LENGTH];
			GetClientName(curPlacerHit, GetHitPlacerName, sizeof(GetHitPlacerName));
			
			char GetHitVictimName[MAX_NAME_LENGTH];
			GetClientName(curHitVictim, GetHitVictimName, sizeof(GetHitVictimName));
			
			CPrintToChat(curPlacerHit, "{green}[TFRP]{default} You set a hit on {mediumseagreen}%s{default} for{mediumseagreen} %d", GetHitVictimName, cvarTFRP[HitPrice].IntValue);
			CPrintToChat(curHitman, "{green}[TFRP]{default} {mediumseagreen}%s set a hit on {mediumseagreen}%s for {mediumseagreen}%d", GetHitPlacerName, GetHitVictimName, cvarTFRP[HitPrice].IntValue);
			
		}
			
	} else if(action == MenuAction_End)
	{
		CloseHandle(menuhandle);
	}
	return 0;
}

public int MenuCallBackGiveKeys(Handle menuhandle, MenuAction action, int client, int pos)
{
	if(action == MenuAction_Select)
	{
		char GiveKeysIndexName[256];
		GetMenuItem(menuhandle, pos, GiveKeysIndexName, sizeof(GiveKeysIndexName));
		
		char GiveKeysIndexAndName[256][256];
		ExplodeString(GiveKeysIndexName, ":", GiveKeysIndexAndName, 2, sizeof(GiveKeysIndexAndName));
		
		char GiveKeysNameAndDoor[256][256];
		ExplodeString(GiveKeysIndexAndName[1], "-", GiveKeysNameAndDoor, 2, sizeof(GiveKeysNameAndDoor));
		
		// Habit Im trying to get into is splitting them up into seperate vars
		int GiveKeysIndex = StringToInt(GiveKeysIndexAndName[0]);
		int GiveKeysDoor = StringToInt(GiveKeysNameAndDoor[1]);
		bool alreadyKeys = false;

		for(int i = 0; i <= 4; i++)
		{
			// Sees if this person already has keys
			if(DoorOwners[GiveKeysDoor][i] == GiveKeysIndex)
			{
				TFRP_PrintToChat(client, "Player already has keys to this door!");
				alreadyKeys = true;
			}
		}

		if(!alreadyKeys)
		{
			for(int i = 0; i <= 4; i++)
			{
				if(i != 0 && DoorOwners[GiveKeysDoor][i] == 0)
				{
					DoorOwners[GiveKeysDoor][i] = GiveKeysIndex;
					TFRP_PrintToChat(client, "Gave keys to {goldenrod}%s{default}. You can reverse this with sm_revokekeys", GiveKeysNameAndDoor[0]);
					break;
				}
			}
		}
	} else if(action == MenuAction_End)
	{
		CloseHandle(menuhandle);
	}
	return 0;
}

public int MenuCallBackRemKeys(Handle menuhandle, MenuAction action, int client, int pos)
{
	if(action == MenuAction_Select)
	{
		char RemKeysIndexName[256];
		GetMenuItem(menuhandle, pos, RemKeysIndexName, sizeof(RemKeysIndexName));
		
		char RemkeysIndexAndName[256][256];
		ExplodeString(RemKeysIndexName, ":", RemkeysIndexAndName, 2, sizeof(RemkeysIndexAndName));
		
		char RemKeysNameAndDoor[256][256];
		ExplodeString(RemkeysIndexAndName[1], "-", RemKeysNameAndDoor, 2, sizeof(RemKeysNameAndDoor));
		
		int RemKeysIndex = StringToInt(RemkeysIndexAndName[0]);
		int RemKeysDoor = StringToInt(RemKeysNameAndDoor[1]);
		bool alreadyKeys = false;

		for(int i = 1; i <= 4; i++)
		{
			if(DoorOwners[RemKeysDoor][i] == RemKeysIndex)
			{
				DoorOwners[RemKeysDoor][i] = 0;
				TFRP_PrintToChat(client, "Revoked keys from {goldenrod}%s", RemKeysNameAndDoor[0]);
				alreadyKeys = true;
				break;
			}
		}
		
		if(!alreadyKeys)
		{
			TFRP_PrintToChat(client, "Player doesn't have keys to this door!");
		}
	
	} else if(action == MenuAction_End)
	{
		CloseHandle(menuhandle);
	}
	return 0;
}

public int MenuCallBackWarrant(Handle menuhandle, MenuAction action, int client, int position)
{
	if(action == MenuAction_Select)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				if(UD[i].bArrested)
				{
					TFRP_PrintToChat(client, "Player is arrested");
					break;
				}
				char GetSetWarrantName[MAX_NAME_LENGTH];
				GetClientName(i, GetSetWarrantName, sizeof(GetSetWarrantName));
			
				char WarrantSetName[MAX_NAME_LENGTH];
				GetMenuItem(menuhandle, position, WarrantSetName, sizeof(WarrantSetName));
				
				if(StrEqual(GetSetWarrantName, WarrantSetName))
				{
					if(UD[i].bHasWarrent)
					{
						CPrintToChat(client, "{green}[TFRP]{default} This player already has a warrant!");
						break;
					}
					UD[i].bHasWarrent = true;
					SetWarrantHud(i);
					CreateTimer(cvarTFRP[WarrantTime].FloatValue, Timer_Warrant, i);
					
				}
			
			}
		}
		
	} else if(action == MenuAction_End)
	{
		CloseHandle(menuhandle);
	}
	return 0;
}

public Action PlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	
	int client = GetClientOfUserId(event.GetInt("userid"));

	StripToMelee(client); //Thanks again JB Redux
	
	Handle DB = CreateKeyValues("Jobs");
	FileToKeyValues(DB, JobPath);

	if(!UD[client].bArrested)
	{
		if(KvJumpToKey(DB, UD[client].sJob, false))
		{
			if(KvJumpToKey(DB, "StartWeapons", false))
			{	
				if(KvGotoFirstSubKey(DB,false))
				{
	
					do{
						// I had a minor mental breakdown here and spent an hour trying to figure out
						// why the weaponid kept on being 0, it was because I didn't use NULL_STRING
						int StartWeaponID = KvGetNum(DB, NULL_STRING, 0);
						TF2Items_GiveWeapon(client, StartWeaponID);

					} while (KvGotoNextKey(DB,false));
				}
			
			}
		
		}
	}
	
	KvRewind(DB);
	KeyValuesToFile(DB, JobPath);
	CloseHandle(DB);
	
	// Spawn protection
    
	if(!UD[client].bArrested)
	{
		TF2_AddCondition(client, TFCond_Ubercharged, 5.0);
		TF2_AddCondition(client, TFCond_MegaHeal, 5.0);
	}
	
	if(UD[client].bArrested)
	{
		Arrest(-90, client);
	}

	return Plugin_Continue;
} 

/*
public Action SetMaxHealth(int client, int &maxhealth)
{
	Handle DB = CreateKeyValues("Jobs");
	FileToKeyValues(DB, JobPath);
	if(KvJumpToKey(DB, UD[client].sJob, false))
	{
		maxhealth = KvGetNum(DB, "MaxHealth", 150);
		KvRewind(DB);
	}
	
	KvRewind(DB);
	CloseHandle(DB);
	return Plugin_Changed;
} 
*/

////////////////////
////// Items //////
///////////////////

public Action Timer_NoSpawnInPlayer(Handle timer, int index)
{
	AcceptEntityInput(index, "EnableCollision");
	return Plugin_Changed;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
    return entity > MaxClients || !entity;
}

public bool TraceRayProp(int entityhit, int mask)
{
	if (entityhit == 0)
	{
		return true;
	}
	return false;
}

public int SpawnInv(int client, char[] ent)
{
	// See if player is alive
	if(!IsPlayerAlive(client))
	{
		CPrintToChat(client, "{green}[TFRP]{default} You cannot spawn items while dead!");
		return 0;
	}
	
	// First off, we need to see if the item is spawnable, this is located in the shop file under "type"
	Handle DB2 = CreateKeyValues("Shop");

	char curEnt[32];
	FormatEx(curEnt, sizeof(curEnt), "%s", ent);

	FileToKeyValues(DB2, ShopPath);
	if(KvJumpToKey(DB2, curEnt, false))
	{
		char spawning_item[48];
		KvGetString(DB2, "type", spawning_item, sizeof(spawning_item), "item");
		if(StrEqual(spawning_item, "ent")){
			char IsPrinterSpawn[32];
			KvGetString(DB2, "IsPrinter", IsPrinterSpawn, sizeof(IsPrinterSpawn), "false");
			
			if(StrEqual(IsPrinterSpawn, "true") && UD[client].bGov && !StrEqual(UD[client].sJob, "Mayor"))
			{
				CPrintToChat(client, "{green}[TFRP]{default} Government Officals cannot spawn {mediumseagreen}printers! {default}(Except the Mayor)");
				return 0;
			}
			
			bool FoundJobSpawn = false;
			
			char curModel[96];
			KvGetString(DB2, "Model", curModel, sizeof(curModel), "error");
			char spawnPhysics[8];
			KvGetString(DB2, "Physics", spawnPhysics, sizeof(spawnPhysics), "false");

			char entClass[32];
			if(StrEqual(spawnPhysics, "true") || StrEqual(spawnPhysics, "True"))
			{
				FormatEx(entClass, sizeof(entClass), "prop_physics_override");
			}else{
				FormatEx(entClass, sizeof(entClass), "prop_dynamic_override");
			}
			
			if(StrEqual(IsPrinterSpawn, "true")) FoundJobSpawn = true; // Doesn't have to worry about job requirements since it's a printer
			
			if(!StrEqual(IsPrinterSpawn, "true"))
			{
				if(KvJumpToKey(DB2, "Job_Reqs", true))
				{
					if(KvGotoFirstSubKey(DB2,false))
					{
				
						do{
		
							char GetJobRequireBuy[32];
							KvGetString(DB2, NULL_STRING, GetJobRequireBuy, sizeof(GetJobRequireBuy));
							
							if(StrEqual(GetJobRequireBuy, "any") || StrEqual(GetJobRequireBuy, UD[client].sJob))
							{
								FoundJobSpawn = true;
							}

						} while (KvGotoNextKey(DB2,false));

					}
				}
			}

			
			if(!FoundJobSpawn)
			{
				CPrintToChat(client, "{green}[TFRP]{default} Incorrect job");
				return 0;
			}
			
			// See if they reached the max
			int getMax = KvGetNum(DB2, "Max", 2);
			int curAmt = 0;
			for(int i = 0; i <= 2047; i++)
			{
				if(EntOwners[i] == client)
				{
					if(StrEqual(EntItems[i], curEnt))
					{
						curAmt++;
					}
					
				}
			}
			if(curAmt >= getMax)
			{
				TFRP_PrintToChat(client, "You've already reached the max {mediumseagreen}%d %s", getMax, curEnt);
				return 0;
			}

			// Spawning the item
			int EntIndex = CreateEntityByName(entClass);
			bool canSpawn = true;
		
			if(EntIndex != -1 && IsValidEntity(EntIndex) && canSpawn == true)
			{
				Handle TraceRay;
				float StartOrigin[3];
				float Angles[3] = {90.0, 0.0, 0.0};								// down

				GetClientAbsOrigin(client, StartOrigin);
				TraceRay = TR_TraceRayFilterEx(StartOrigin, Angles, MASK_PROP_SPAWN, RayType_Infinite, TraceRayProp);
				if (TR_DidHit(TraceRay))
				{
					float EndOrigin[3];
					TR_GetEndPosition(EndOrigin, TraceRay);

					float normal[3];
					float normalAng[3];				// offset the prop from the ground plane
					TR_GetPlaneNormal(TraceRay, normal);
					EndOrigin[0] += normal[0]*(OFFSET_HEIGHT);
					EndOrigin[1] += normal[1]*(OFFSET_HEIGHT);
					EndOrigin[2] += normal[2]*(OFFSET_HEIGHT);
		
					GetClientEyeAngles(client, Angles);
					GetVectorAngles(normal, normalAng);

					Angles[0]  = normalAng[0] -270;						// horizontal is boring

					if (normalAng[0] != 270)
					{
						Angles[1]  = normalAng[1];						// override the horizontal plane
					}
		
					float origin[3];
					float angles[3];
					float vBuffer[3];
					float vStart[3];
					float Distance;
						
					float g_pos[3];
			
					GetClientEyePosition(client,origin);
					GetClientEyeAngles(client, angles);
    
	
					//get endpoint for teleport
					Handle trace = TR_TraceRayFilterEx(origin, angles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
			
					if(TR_DidHit(trace))
					{       
						TR_GetEndPosition(vStart, trace);
						GetVectorDistance(origin, vStart, false);
						Distance = -35.0;
						GetAngleVectors(angles, vBuffer, NULL_VECTOR, NULL_VECTOR);
						g_pos[0] = vStart[0] + (vBuffer[0]*Distance);
						g_pos[1] = vStart[1] + (vBuffer[1]*Distance);
						EndOrigin[0] = g_pos[0];
						EndOrigin[1] = g_pos[1];
					}
							
					Distance = (GetVectorDistance(StartOrigin, EndOrigin));
							
					if (Distance <= MAX_SPAWN_DISTANCE)
					{
							
						DispatchKeyValue(EntIndex, "model", curModel);
							
						SetEntProp(EntIndex, Prop_Data, "m_CollisionGroup", 5);
						SetEntProp(EntIndex, Prop_Data, "m_usSolidFlags", 16);
						SetEntProp(EntIndex, Prop_Data, "m_nSolidType", 6);
						AcceptEntityInput(EntIndex, "DisableCollision");
						DispatchSpawn(EntIndex);
						TeleportEntity(EntIndex, EndOrigin, NULL_VECTOR, NULL_VECTOR);
						CPrintToChat(client, "{green}[TFRP]{default} Successfully spawned item!");
						GiveItem(client, curEnt, -1); //Yes negative == remove
						EntOwners[EntIndex] = client;
						char GetItemNameEnt[32];
						FormatEx(GetItemNameEnt, sizeof(GetItemNameEnt), "%s", ent);
						EntItems[EntIndex] = GetItemNameEnt;
						CreateTimer(3.0, Timer_NoSpawnInPlayer, EntIndex);
					
					}else{
						CPrintToChat(client, "{green}[TFRP]{default} You must spawn the entity closer!");
						RemoveEdict(EntIndex);
						return 0;
					}
						
				}else{
					CPrintToChat(client, "{green}[TFRP]{red} ERROR: {default} Trace ray didn't hit! If the problem persists, contact a server admin");
					RemoveEdict(EntIndex);
					return 0;
				}
					
					
				char GetSpawnEntColors[48];
				KvGetString(DB2, "Color", GetSpawnEntColors, sizeof(GetSpawnEntColors));
						
				if(KvJumpToKey(DB2, "Color", false))
				{
						
					char EntColorsArr1[8][8];
					ExplodeString(GetSpawnEntColors, ",", EntColorsArr1, 2, sizeof(EntColorsArr1));
						
					int EntColorR = StringToInt(EntColorsArr1[0]);
						
					char EntColorsArr2[8][8];
					ExplodeString(EntColorsArr1[1], ":", EntColorsArr2, 2, sizeof(EntColorsArr2));
						
					int EntColorG = StringToInt(EntColorsArr2[0]);
					int EntColorB = StringToInt(EntColorsArr2[1]);
						
					int EntColorA = 255;
						
					SetEntityRenderColor(EntIndex, EntColorR, EntColorG, EntColorB, EntColorA);
						
				}
					
				// Spawn functions for specific items
				
				if(StrEqual(curEnt,"Australium Drill"))
				{
					AddAusDrill(EntIndex, client);
				}else if(StrEqual(curEnt, "Australium Cleaner"))
				{
					AddAusCleaner(EntIndex, client);
				}else if(StrEqual(curEnt, "Empty Package"))
				{
					AddAusPackage(EntIndex, client);
				}else if(StrEqual(curEnt, "Bronze Money Printer"))
				{
					AddPrinter(client, EntIndex, "Bronze");
				}else if(StrEqual(curEnt, "Silver Money Printer"))
				{
					AddPrinter(client, EntIndex, "Silver");
				}else if(StrEqual(curEnt, "Gold Money Printer"))
				{
					AddPrinter(client, EntIndex, "Gold");
				} else if(StrEqual(curEnt, "Bonk Mixer"))
				{
					BonkMixers[EntIndex].BonkWater = 0;
					BonkMixers[EntIndex].BonkCaesium = 0;
					BonkMixers[EntIndex].BonkSugar = 0;
				} else if(StrEqual(curEnt, "Bonk Canner"))
				{
					BonkCanners[EntIndex].BonkInCanner = 0;
					BonkCanners[EntIndex].BonkCans = 0;
					SDKHookEx(EntIndex, SDKHook_OnTakeDamage, BonkCannerHit);
				} else if(StrEqual(curEnt, "Radio"))
				{
					PlayChannel(1, 1, EntIndex);
				}
				
		
				// Run Module Ent Input
				Action result;
				Call_StartForward(g_tfrp_forwards[0]);
				Call_PushCell(client);
				Call_PushString(curEnt);
				Call_PushCell(EntIndex);
				Call_Finish(result);
 
			} else {
				CPrintToChat(client, "{green}[TFRP]{red} ERROR: {default}Couldn't create entity! Maybe the server has to update Sourcemod?");
			}


			KvRewind(DB2);
			CloseHandle(DB2);
			
		} else{
				CPrintToChat(client, "{green}[TFRP]{default} You cannot spawn this item!");
		}
	}else{
		CPrintToChat(client, "{green}[TFRP]{red} ERROR: {default}For some reason, the item couldn't be found in the database. Maybe the item was deleted from the server?");
	}

	return 0;
}

// Removes item in return for cash
public int SellItem(int iClient, char[] sItem, int sellPrice, int amt)
{
	char sAuth[32];
	GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth));

	if (GetInvItemCount(iClient, sItem) - amt >= 0)
	{
		GiveItem(iClient, sItem, -amt);
		UD[iClient].iCash += sellPrice * amt;
		CPrintToChat(iClient, "{green}[TFRP]{default} You sold {crimson}%d {mediumseagreen}%s{default} for {mediumseagreen}%d{default} a piece. Your balance is now {mediumseagreen}%d", amt, sItem, sellPrice, UD[iClient].iCash);
	}
	else
	{
		CPrintToChat(iClient, "{green}[TFRP]{default} Your inventory does not contain {crimson}%d {mediumseagreen}%s.", amt, sItem);
	}

	return 0;
}

// Using items
public int UseItem(int client, char[] ItemUse)
{
	
	if(!IsPlayerAlive(client))
	{
		CPrintToChat(client, "{green}[TFRP]{default} You cannot use items while dead!");
		return 0;
	}
	

	Handle DB2 = CreateKeyValues("Shop");
	FileToKeyValues(DB2, ShopPath);

	if(KvJumpToKey(DB2, ItemUse, true))
	{
		char ItemTypeUse[16];
		KvGetString(DB2, "type", ItemTypeUse, sizeof(ItemTypeUse), "error");
		char IsMedkit[16];
		KvGetString(DB2, "Medkit", IsMedkit, sizeof(IsMedkit));
		char IsAmmopack[16];
		KvGetString(DB2, "Ammopack", IsAmmopack, sizeof(IsAmmopack));
		
		int weaponid = KvGetNum(DB2, "id");
		
		bool FoundJobUse = false;
		
		if(KvJumpToKey(DB2, "Job_Reqs", true))
		{
			if(KvGotoFirstSubKey(DB2,false))
			{
				
				do{
		
					char GetJobRequireBuy[32];
					KvGetString(DB2, NULL_STRING, GetJobRequireBuy, sizeof(GetJobRequireBuy));
							
					if(StrEqual(GetJobRequireBuy, "any") || StrEqual(GetJobRequireBuy, UD[client].sJob))
					{
						FoundJobUse = true;
					}

				} while (KvGotoNextKey(DB2,false));

			}
			KvRewind(DB2);
		}
		
		if(!FoundJobUse)
		{
			CPrintToChat(client, "{green}[TFRP]{default} Incorrect job");
			return 0;
		}
		
		if(StrEqual(ItemTypeUse, "weapon")){

			TF2Items_GiveWeapon(client, weaponid);
			GiveItem(client, ItemUse, -1);
			CPrintToChat(client, "{green}[TFRP]{default} Giving you {mediumseagreen}%s.", ItemUse);
		}else if(StrEqual(ItemTypeUse, "error")){
			CPrintToChat(client, "{green}[TFRP]{red} ERROR: {default}Could not find item type. The item has not been removed from your inventory.");
		}
		

		if(StrEqual(IsMedkit, "true"))
		{
			int HealthKitSizeUse = KvGetNum(DB2, "HKSize", 1);
			UseMedkit(client, HealthKitSizeUse);
			GiveItem(client, ItemUse, -1); //Don't know why you removed these in 1.1 -Squid
			KvRewind(DB2);
		}
		if(StrEqual(IsAmmopack, "true"))
		{
			int AmmopackSizeUse = KvGetNum(DB2, "APSize", 1);
			UseAmmopack(client, AmmopackSizeUse);
			GiveItem(client, ItemUse, -1);
			KvRewind(DB2);
		}

		KvRewind(DB2);
		CloseHandle(DB2);
		} else {
			CPrintToChat(client, "{green}[TFRP]{red} ERROR: {default}For some reason, the item couldn't be found in the database. Maybe the item was deleted from the server?");
		}



// Sandvich Stuff
	if(StrEqual(ItemUse, "Bread")){
		AddIngredientSandvich(client, "Bread");
	} else if(StrEqual(ItemUse, "Lettuce")){
		AddIngredientSandvich(client, "Lettuce");
	} else if(StrEqual(ItemUse, "Meat")){
		AddIngredientSandvich(client, "Meat");
	} else if(StrEqual(ItemUse, "Cheese")){
		AddIngredientSandvich(client, "Cheese"); 
	} else if(StrEqual(ItemUse, "Fuel")){
	// Australium
		AddFuelAustraliumDrill(client);
	} else if(StrEqual(ItemUse, "Dirty Australium")){
		AddAustraliumToCleaner(client);
	} else if(StrEqual(ItemUse, "Australium")){
		AddCleanAusToPackage(client);
	// Thief
	} else if(StrEqual(ItemUse, "Lockpick")){
		Lockpick(client);
	} else if(StrEqual(ItemUse, "Carbonated Water")){
		AddWaterBonk(client);
	} else if (StrEqual(ItemUse, "Sugar")){
		AddSugarBonk(client);
	} else if (StrEqual(ItemUse, "Caesium")){
		AddCaesiumBonk(client);
	}

	// Module item input
	Action result;
	Call_StartForward(g_tfrp_forwards[2]);
	Call_PushCell(client);
	Call_PushString(ItemUse);
	Call_Finish(result);

	return 0;
}

// Drop items

public int DropItem(int client, char[] ItemDrop)
{
	if(!IsPlayerAlive(client))
	{
		CPrintToChat(client, "{green}[TFRP]{default} You cannot drop items while dead!");
		return 0;
	}


	if(DroppedItems[client] >= cvarTFRP[MaxDroppedItems].IntValue)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You can only have %d dropped items.", cvarTFRP[MaxDroppedItems].IntValue);
		return 0;
	}
	
	int EntIndex = CreateEntityByName("prop_dynamic_override");
	
	if(EntIndex != -1 && IsValidEntity(EntIndex))
	{
		Handle TraceRay;
		float StartOrigin[3];

		float Angles[3] = {90.0, 0.0, 0.0};								// down

		GetClientAbsOrigin(client, StartOrigin);
		TraceRay = TR_TraceRayFilterEx(StartOrigin, Angles, MASK_PROP_SPAWN, RayType_Infinite, TraceRayProp);
		if (TR_DidHit(TraceRay))
		{
			float EndOrigin[3];
			TR_GetEndPosition(EndOrigin, TraceRay);

			float normal[3];
			float normalAng[3];				// offset the prop from the ground plane
			TR_GetPlaneNormal(TraceRay, normal);
			EndOrigin[0] += normal[0]*(OFFSET_HEIGHT);
			EndOrigin[1] += normal[1]*(OFFSET_HEIGHT);
			EndOrigin[2] += normal[2]*(OFFSET_HEIGHT);
		
			GetClientEyeAngles(client, Angles);
			GetVectorAngles(normal, normalAng);

			Angles[0]  = normalAng[0] -270;						// horizontal is boring

			if (normalAng[0] != 270)
			{
				Angles[1]  = normalAng[1];						// override the horizontal plane
			}
							
			float origin[3];
			float angles[3];
			float vBuffer[3];
			float vStart[3];
			float Distance;
						
			float g_pos[3];
			
			GetClientEyePosition(client,origin);
			GetClientEyeAngles(client, angles);
    
	
			//get endpoint for teleport
			Handle trace = TR_TraceRayFilterEx(origin, angles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
			
			if(TR_DidHit(trace))
			{       
				TR_GetEndPosition(vStart, trace);
				GetVectorDistance(origin, vStart, false);
				Distance = -35.0;
				GetAngleVectors(angles, vBuffer, NULL_VECTOR, NULL_VECTOR);
				g_pos[0] = vStart[0] + (vBuffer[0]*Distance);
				g_pos[1] = vStart[1] + (vBuffer[2]*Distance);
				EndOrigin[0] = g_pos[0];
				EndOrigin[1] = g_pos[1];
			}

			Distance = (GetVectorDistance(StartOrigin, EndOrigin));

			EndOrigin[2] += 10.0;
							
			if (Distance <= MAX_SPAWN_DISTANCE)
			{
				DispatchKeyValue(EntIndex, "model", "models/props_junk/cardboard_box001a.mdl");
		
				DispatchKeyValueFloat(EntIndex, "solid", 2.0); 
			
				DispatchSpawn(EntIndex);

				TeleportEntity(EntIndex, EndOrigin, NULL_VECTOR, NULL_VECTOR);
				GiveItem(client, ItemDrop, -1);
				CPrintToChat(client, "{green}[TFRP]{default} You dropped {mediumseagreen}%s", ItemDrop);
				DroppedItems[client]++;
				EntOwners[EntIndex] = client;
				EntItems[EntIndex] = "__Dropped__Item__";
				char FormatItemDrop[32];
				FormatEx(FormatItemDrop, sizeof(FormatItemDrop),"%s", ItemDrop);
				DroppedItemNames[EntIndex] = FormatItemDrop;
				
			}else{
				CPrintToChat(client, "{green}[TFRP]{default} You must drop this item closer!");
			}
	
		}
	}
	return 0;
}


// Pickup dropped items
public Action Command_Pickup(int client, int args)
{
	int PickupClientAim = GetClientAimTarget(client, false);
	
	if(PickupClientAim == -1)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a dropped item!");
		return Plugin_Handled;
	}	
	
	if(!IsPlayerAlive(client))
	{
		TFRP_PrintToChat(client, "You can't pickup items while dead!");
		return Plugin_Handled;
	}
	
	int PickupItemOwner = EntOwners[PickupClientAim];
	
	float ClientPosPickup[3];
	GetClientAbsOrigin(client, ClientPosPickup);
	
	float PickupPos[3];
	GetEntPropVector(PickupClientAim, Prop_Send, "m_vecOrigin", PickupPos);

	if(GetVectorDistance(ClientPosPickup, PickupPos) <= 150){
		
		if(StrEqual(EntItems[PickupClientAim], "__Dropped__Item__"))
		{
			GiveItem(client, DroppedItemNames[PickupClientAim], 1);
			CPrintToChat(client, "{green}[TFRP]{default} You picked up {mediumseagreen}%s", DroppedItemNames[PickupClientAim]);
		
			TFRP_DeleteEnt(PickupClientAim);
			DroppedItemNames[PickupClientAim] = "__no__item__";
			DroppedItems[PickupItemOwner] = DroppedItems[PickupItemOwner] - 1;
		}else{
			if(EntOwners[PickupClientAim] == client)
			{
				GiveItem(client, EntItems[PickupClientAim], 1);
				TFRP_PrintToChat(client, "You picked up {mediumseagreen}%s", EntItems[PickupClientAim]);
				TFRP_DeleteEnt(PickupClientAim);
			}else{
				TFRP_PrintToChat(client, "You don't own this entity!");
			}
		}
	}else{
		CPrintToChat(client, "{green}[TFRP]{default} You have to be closer to item to pick it up!");
	}
	
	
	return Plugin_Handled;
}

// Health function
public int UseMedkit(int client, int size)
{
	int giveHPAmt = 0;
	
	if(size == 1) giveHPAmt = 65;
	if(size == 2) giveHPAmt = 125;
	if(size == 3) giveHPAmt = 300;
	
	int curMKHp = GetEntProp(client, Prop_Data, "m_iHealth");
	int curMKMax = GetEntProp(client, Prop_Data, "m_iMaxHealth");
	if(curMKHp + giveHPAmt <= curMKMax)
	{
		SetEntProp(client, Prop_Data, "m_iHealth", curMKHp+giveHPAmt);	
	}else{
		SetEntProp(client, Prop_Data, "m_iHealth", curMKMax);	
	}
	
	float GetMedkitSoundVec[3];
	GetClientAbsOrigin(client, GetMedkitSoundVec);
	
	EmitAmbientSound(MEDKIT_SOUND, GetMedkitSoundVec, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
	
	return 0;
}

// Ammo function
public int UseAmmopack(int client, int size)
{
	int AmmoUseAmt = 0;
	bool foundWeaponAmmoUse = true;
	
	if(size == 1) AmmoUseAmt = 12;
	if(size == 2) AmmoUseAmt = 24;
	if(size == 3) AmmoUseAmt = 36;
	
	for(int i = 0; i <= 5; i++)
	{
		int GetWeapon = GetPlayerWeaponSlot(client, i);
		if(GetWeapon != -1)
		{
			int iAmmoType = GetEntProp(GetWeapon, Prop_Send, "m_iPrimaryAmmoType");
			if(iAmmoType != -1) 
			{
				GivePlayerAmmo(client, AmmoUseAmt, iAmmoType, false);
				foundWeaponAmmoUse = true;
			}
		}
	}
	if(foundWeaponAmmoUse)
	{
		CPrintToChat(client, "{green}[TFRP]{default} Gave you {mediumseagreen}%d ammo", AmmoUseAmt);
	}else
	{
		CPrintToChat(client, "{green}[TFRP]{default} You don't have a weapon!");
	}
	return 0;
}

///////////////////////////
//// General Commands ////
//////////////////////////

public Action Command_JOB(int client, int args)
{

	if(client==0){
		PrintToServer("[TFRP] Command can't be ran from console.");
		return Plugin_Handled;
	}
	
	if(UD[client].bArrested)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You cannot do sm_job while arrested.");
		return Plugin_Handled;
	}

	UpdatePlayTime(client); //My idea was to restrict certain jobs to have at least X playtime. -Squid

	// Get jobs from file

	Handle hJobList = CreateArray(32);
	Handle DB4 = CreateKeyValues("Jobs");
	FileToKeyValues(DB4, JobPath);

	KvGotoFirstSubKey(DB4,false);

	do{
		
		char JobName[32];
		KvGetSectionName(DB4, JobName, sizeof(JobName));
		PushArrayString(hJobList, JobName);

    } while (KvGotoNextKey(DB4,false));

	CloseHandle(DB4);

	Handle menuhandle = CreateMenu(MenuCallBackJob);
	SetMenuTitle(menuhandle, "TFRP - Jobs");

	for(int i = 0 ; i < GetArraySize(hJobList) ; i++) 
	{
		char jobBuffer[32];
		GetArrayString(hJobList, i, jobBuffer, sizeof(jobBuffer));
		AddMenuItem(menuhandle, jobBuffer, jobBuffer);
	}

	SetMenuPagination(menuhandle, 7);
	SetMenuExitButton(menuhandle, true);
	DisplayMenu(menuhandle, client, 250);


	return Plugin_Handled;


}

public Action Command_BAL(int client, int args)
{
	if(client==0){
		PrintToServer("[TFRP] Command can't be ran from console.");
		return Plugin_Handled;
	}

	CPrintToChat(client, "{green}[TFRP]{default} Your balance is{mediumseagreen} %d", UD[client].iCash);

	return Plugin_Handled;
}

public Action Command_GiveMoneyPtoP(int client, int args)
{
	if(args != 1)
	{
		CPrintToChat(client, "{green}[TFRP]{default} Usage: sm_givemoney <amount>");
		return Plugin_Handled;
	}
	
	int curPlayerGiveMoney = GetClientAimTarget(client, false);

	if(!IsClientInGame(curPlayerGiveMoney) || curPlayerGiveMoney > MaxClients+1 || curPlayerGiveMoney == -1){
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a player!");
		return Plugin_Handled;
	}

	char MoneyPtoP[32];
	GetCmdArg(1, MoneyPtoP, sizeof(MoneyPtoP));
	
	if(UD[client].iCash  >= StringToInt(MoneyPtoP))
	{
		UD[client].iCash -= StringToInt(MoneyPtoP);
		// UpdateCash(client);
		UD[curPlayerGiveMoney].iCash += StringToInt(MoneyPtoP);
		// UpdateCash(curPlayerGiveMoney);
		
		char curPlayerGiveMoneyName[MAX_NAME_LENGTH];
		GetClientName(curPlayerGiveMoney, curPlayerGiveMoneyName, sizeof(curPlayerGiveMoneyName));
		
		CPrintToChat(client, "{green}[TFRP]{default} You gave {mediumseagreen}%d{default} to {goldenrod}%s", StringToInt(MoneyPtoP), curPlayerGiveMoneyName);
	
		char curPlayerGiveMoneyCLName[MAX_NAME_LENGTH];
		GetClientName(client, curPlayerGiveMoneyCLName, sizeof(curPlayerGiveMoneyCLName));
		
		CPrintToChat(curPlayerGiveMoney, "{green}[TFRP]{goldenrod} %s {default}gave you {mediumseagreen}%d", curPlayerGiveMoneyCLName, StringToInt(MoneyPtoP));
	
	}else{
		CPrintToChat(client, "{green}[TFRP]{default} Insufficent funds");
	}

	return Plugin_Handled;
}

///////////////////////////////////////////
// Shop Revamped (By The Illusion Squid) //
///////////////////////////////////////////
public Action Command_BUYMENU(int client, int args)
{
	
	if(UD[client].bArrested)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You cannot do /shop while arrested.");
		return Plugin_Handled;
	}

	OpenBuyMenu(client);

	return Plugin_Handled;	
}

public void OpenBuyMenu(int iClient)
{
	Handle hMenu = CreateMenu(MenuCallBackShop);
	SetMenuTitle(hMenu, "[TFRP] Item Shop. Balance: %d", UD[iClient].iCash);

	
	// Get All Items to insert to menu
	Handle hItemListShop = CreateArray(32);
	Handle DB3 = CreateKeyValues("Categories");
	FileToKeyValues(DB3, CategoryPath);

	KvGotoFirstSubKey(DB3,false);
	
	do{
		
		char itemCatShop[32];
		KvGetSectionName(DB3, itemCatShop, sizeof(itemCatShop));

		PushArrayString(hItemListShop, itemCatShop);

    } while (KvGotoNextKey(DB3,false));

	CloseHandle(DB3);

	for(int i = 0 ; i < GetArraySize(hItemListShop) ; i++) 
	{	
		char itemShopBuffer[32];
		GetArrayString(hItemListShop, i, itemShopBuffer, sizeof(itemShopBuffer));
		AddMenuItem(hMenu, itemShopBuffer, itemShopBuffer);
	}

	SetMenuPagination(hMenu, 7);
	SetMenuExitButton(hMenu, true);
	DisplayMenu(hMenu, iClient, 250);
}

public int MenuCallBackShop(Handle menuhandleshop, MenuAction action, int iClient, int Position)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char ItemNameShop[32];

			GetMenuItem(menuhandleshop, Position, ItemNameShop, sizeof(ItemNameShop));
				
			NextCatShopMenu(iClient, ItemNameShop);
		}
		case MenuAction_Cancel:
		{
			switch(Position)
			{
				case MenuCancel_ExitBack:
				{
					OpenBuyMenu(iClient);
				}
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menuhandleshop);
		}
	}
	return 0;
}

public int NextCatShopMenu(int client, char[] sItem)
{
	Handle hItemListShop = CreateArray(32);
	Handle DB2 = CreateKeyValues("Shop");
	FileToKeyValues(DB2, ShopPath);

	KvGotoFirstSubKey(DB2,false);
	
	do{
			char GetItem[32];
			KvGetSectionName(DB2, GetItem, sizeof(GetItem));
			
			char GetCategoryShop[32];
			KvGetString(DB2, "Category", GetCategoryShop, sizeof(GetCategoryShop), "NONE");
			if(StrEqual(sItem, GetCategoryShop) && !StrEqual(GetCategoryShop, "NONE"))
			{
				PushArrayString(hItemListShop, GetItem);
			}

    } while (KvGotoNextKey(DB2,false));

	CloseHandle(DB2);

	Handle hMenu = CreateMenu(MenuCallBackShopItems);
	SetMenuTitle(hMenu, "[TFRP] %s Items. Balance: %d", sItem, UD[client].iCash);


	for(int i = 0 ; i < GetArraySize(hItemListShop) ; i++) 
	{
		char itemBuffer[32];
		GetArrayString(hItemListShop, i, itemBuffer, sizeof(itemBuffer));	
		AddMenuItem(hMenu, itemBuffer, itemBuffer);
	}

	SetMenuPagination(hMenu, 7);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, 250);

	return 0;
}

public int MenuCallBackShopItems(Handle menuhandle, MenuAction action, int iClient, int Position)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char ItemNameShopItem[32];

			GetMenuItem(menuhandle, Position, ItemNameShopItem, sizeof(ItemNameShopItem));
			BuyShopMenu(iClient, ItemNameShopItem);
		}
		case MenuAction_Cancel:
		{
			switch(Position)
			{
				case MenuCancel_ExitBack:
				{
					OpenBuyMenu(iClient);
				}
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menuhandle);
		}
	}

	return 0;
}

public void BuyShopMenu(int client, char[] iteminfoshop)
{
	int price;

	Handle DB2 = CreateKeyValues("Shop");

	FileToKeyValues(DB2, ShopPath);
	if(!KvJumpToKey(DB2, iteminfoshop, false))
	{
		CPrintToChat(client, "{green}[TFRP]{red} ERROR:{default} Could not find item in database. This means that the item was deleted while you had the menu open. How unlucky");
		KvRewind(DB2);
		CloseHandle(DB2);
	}else{
		
		price = KvGetNum(DB2, "Price", 0);
		
		KvRewind(DB2);
		CloseHandle(DB2);
	
		Handle menuhandleNShop = CreateMenu(MenuCallBackNextShop);
		SetMenuTitle(menuhandleNShop, "[TFRP] %s | Price: %d", iteminfoshop, price);

	
		char BuyItemInfoShop[32];
		FormatEx(BuyItemInfoShop, sizeof(BuyItemInfoShop), "buy_%s-=%d", iteminfoshop, price);
		char SellItemInfoShop[32];
		FormatEx(SellItemInfoShop, sizeof(SellItemInfoShop), "sell_%s-=%d", iteminfoshop, price);

		AddMenuItem(menuhandleNShop, BuyItemInfoShop, "Buy");
		AddMenuItem(menuhandleNShop, SellItemInfoShop, "Sell");
		SetMenuPagination(menuhandleNShop, 7);
		SetMenuExitButton(menuhandleNShop, true);
		SetMenuExitBackButton(menuhandleNShop, true);
		DisplayMenu(menuhandleNShop, client, 250);
	}
}

public int MenuCallBackNextShop(Handle menuhandle, MenuAction action, int Client, int Position)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char CmdItemNameShop[32];
			char IsPrinterBuy[32];
			char ItemInfoNextShop[32][32];
			GetMenuItem(menuhandle, Position, CmdItemNameShop, sizeof(CmdItemNameShop));
			ExplodeString(CmdItemNameShop, "_", ItemInfoNextShop, 2, sizeof(ItemInfoNextShop), false);

			// Format information into 3 different strings - command(buy/sell), name, and price

			char CmdShop[4]; // Bandaid fix, but for some reason after exploding the string, 
			// it will copy the underscore plus 3 letters of the item's name. I figured "why waste
			// an hour looking for a fix if I can just set the size of the string to 4" 
			// it works but Im not sure if this'll cause problems down the line. This is also why the "sell" command is "sel"

			char ItemInfoNamePrice[32][32]; 

			FormatEx(CmdShop, sizeof(CmdShop), "%s", CmdItemNameShop[0]);
			// Seperate name from price
			ExplodeString(ItemInfoNextShop[1], "-=", ItemInfoNamePrice, 2, sizeof(ItemInfoNamePrice));

			if(StrEqual(CmdShop, "buy")){
				if(UD[Client].iCash>=StringToInt(ItemInfoNamePrice[1])){
					// Get Job Requirement
							
					Handle DB2 = CreateKeyValues("Shop");

					FileToKeyValues(DB2, ShopPath);
					if(KvJumpToKey(DB2, ItemInfoNamePrice[0], false))
					{
						KvGetString(DB2, "IsPrinter", IsPrinterBuy, sizeof(IsPrinterBuy));
						bool FoundJobBuy = false;
						if(KvJumpToKey(DB2, "Job_Reqs", true))
						{
							if(KvGotoFirstSubKey(DB2,false))
							{
					
								do{
			
									char GetJobRequireBuy[32];
									KvGetString(DB2, NULL_STRING, GetJobRequireBuy, sizeof(GetJobRequireBuy));
								
									if(StrEqual(GetJobRequireBuy, "any") || StrEqual(GetJobRequireBuy, UD[Client].sJob))
									{
										GiveItem(Client, ItemInfoNamePrice[0], 1);
					
										UD[Client].iCash = UD[Client].iCash - StringToInt(ItemInfoNamePrice[1]);
										// UpdateCash(Client);
					
										CPrintToChat(Client, "{green}[TFRP]{default} You bought {mediumseagreen}%s{default} for {mediumseagreen}%d.{default} Your balance is now {mediumseagreen}%d", ItemInfoNamePrice[0], StringToInt(ItemInfoNamePrice[1]), UD[Client].iCash);
										FoundJobBuy = true;
										
										Action result;
										Call_StartForward(g_tfrp_forwards[1]);
										Call_PushCell(Client);
										Call_PushString(ItemInfoNamePrice[0]);
										Call_PushCell(StringToInt(ItemInfoNamePrice[1]));
										Call_Finish(result);
										
										break;
									}
					
			
								} while (KvGotoNextKey(DB2,false));
						
								if(!FoundJobBuy)
								{
									CPrintToChat(Client, "{green}[TFRP]{default} Incorrect job");
								}
							
							}
						}
					}else{
						CPrintToChat(Client,"{green}[TFRP]{red} ERROR:{default} Could not find item in database");
					}
					KvRewind(DB2);
					CloseHandle(DB2);
					
					if(StrEqual(IsPrinterBuy, "true"))
					{
						if((UD[Client].bGov && StrEqual(UD[Client].sJob, "Mayor")) || !UD[Client].bGov)
						{
							GiveItem(Client, ItemInfoNamePrice[0], 1);
					
							UD[Client].iCash = UD[Client].iCash - StringToInt(ItemInfoNamePrice[1]);
							// UpdateCash(Client);
					
							CPrintToChat(Client, "{green}[TFRP]{default} You bought {mediumseagreen}%s{default} for {mediumseagreen}%d.{default} Your balance is now {mediumseagreen}%d", ItemInfoNamePrice[0], StringToInt(ItemInfoNamePrice[1]), UD[Client].iCash);
						}
					}
					
				} else {
					CPrintToChat(Client, "{green}[TFRP]{default} Insufficent funds");
				}
		
			} else if(StrEqual(CmdShop, "sel")){
				SellItem(Client, ItemInfoNamePrice[0], StringToInt(ItemInfoNamePrice[1])/cvarTFRP[ShopReturn].IntValue, 1);
			}
			BuyShopMenu(Client, ItemInfoNamePrice[0]);
		}
		case MenuAction_Cancel:
		{
			switch(Position)
			{
				case MenuCancel_ExitBack:
				{
					OpenBuyMenu(Client); //Quick fix but rather put back to catagory
				}
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menuhandle);
		}
	}
	
	return 0;

}

public Action Command_Setjob(int client, int args)
{
	if(args!=2){
		CReplyToCommand(client, "{green}[TFRP]{default} Usage: sm_setjob <name> <job>");
		return Plugin_Handled;
	}

	char sTarget[32], sName[32];
	int iTargetList[MAXPLAYERS];
	bool tn_is_ml;
	GetCmdArg(1, sTarget, sizeof(sTarget));
	int iTargetCount = ProcessTargetString(sTarget, client, iTargetList, MAXPLAYERS, 0, sName, sizeof(sName), tn_is_ml);

	if (iTargetCount != 1)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	char sNameSetJob[48];
	GetCmdArg(2, sNameSetJob, sizeof(sNameSetJob));
		
	if(StrEqual(sNameSetJob, "Mayor"))
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				if(StrEqual(UD[i].sJob, "Mayor"))
				{
					CReplyToCommand(client, "{green}[TFRP]{red} There already is a {mediumseagreen}Mayor!");
					return Plugin_Handled;
				}
			}
		}
	}

	char sTargetName[32];
	GetClientName(iTargetList[0], sTargetName, sizeof(sTargetName));
	// See if their already that job.
	if(StrEqual(UD[iTargetList[0]].sJob, sNameSetJob))
	{
		CReplyToCommand(client, "{green}[TFRP]{default} %s\'s job is already {mediumseagreen}%s", sTargetName, sNameSetJob);
		return Plugin_Handled;
	}
	else
	{
		// Cancel lottery if they had one running
		if(StrEqual(UD[iTargetList[0]].sJob, "Mayor") && isLottery == true)
		{
			CPrintToChatAll("{yellow}[TFRP ADVERT]{default} Mayor switched jobs, canceling lottery and refunding participants");
			CancelLottery();
		}

		// Find job in file and give client the rules of that job
		Handle DB4 = CreateKeyValues("Jobs");
		FileToKeyValues(DB4, JobPath);

		if(KvJumpToKey(DB4, sNameSetJob, false)){
			// Will detect if admin later
			UD[iTargetList[0]].sJob = sNameSetJob;
			UD[iTargetList[0]].iJobSalary = KvGetNum(DB4, "Salary", 50); // If there isn't a salary it'll just be set to 50
			char IsPoliceStr[8];
			KvGetString(DB4, "IsGov", IsPoliceStr, sizeof(IsPoliceStr), "false");
			if(StrEqual(IsPoliceStr, "true"))
			{
				UD[iTargetList[0]].bGov = true;
				TF2_ChangeClientTeam(iTargetList[0], TFTeam_Blue);
			}else{
				UD[iTargetList[0]].bGov = false;
				TF2_ChangeClientTeam(iTargetList[0], TFTeam_Red);
			}
				
			ForcePlayerSuicide(iTargetList[0]);
		
			char CanOwnDoorsStr[8];
			KvGetString(DB4, "CanOwnDoors", CanOwnDoorsStr, sizeof(CanOwnDoorsStr), "true");
			if(StrEqual(CanOwnDoorsStr, "false"))
			{
				UD[iTargetList[0]].bOwnDoors = false;
			} else {
				UD[iTargetList[0]].bOwnDoors = true;
			}
			KvRewind(DB4);
			if(cvarTFRP[AnnounceJobSwitch].BoolValue){
				CPrintToChatAll("{green}[TFRP]{goldenrod} %s{default} set their job to {mediumseagreen}%s", sTargetName, sNameSetJob);
			}else{
				CPrintToChat(iTargetList[0], "{green}[TFRP]{default} Set your job to {mediumseagreen}%s", sNameSetJob);
			}
			CPrintToChat(iTargetList[0], "{green}[TFRP]{default} Your job was set by an administrator.");
			CReplyToCommand(client, "{green}[TFRP]{default} %s\'s job is succesfully set to %s.", sTargetName, sNameSetJob);

				// Delete entities when people change jobs
			DeleteJobEnts(iTargetList[0]);
				
		}else{
			CReplyToCommand(client, "{green}[TFRP]{red} ERROR: {default}Could not find job in database");
		}

		CloseHandle(DB4);
		return Plugin_Handled;
    }
}

public Action Command_SetJailCell(int client, int args)
{
	if(args != 1)
	{
		CPrintToChat(client, "{green}[TFRP]{default} Usage: sm_setjail <number> <x> <y> <z>");
		return Plugin_Handled;
	}
	
	char sJailId[32];
	GetCmdArg(1, sJailId, sizeof(sJailId));
	int nJailId = StringToInt(sJailId);
	
	if(nJailId < 1 || nJailId > 9)
	{
		CPrintToChat(client, "{green}[TFRP]{default} Number must be greater than 0 and less than 9!");
		return Plugin_Handled;
	}

	float setJailPos[3];

	GetClientAbsOrigin(client, setJailPos);

	char nFullPos[255];
	FormatEx(nFullPos, sizeof(nFullPos), "%f,%f:%f", setJailPos[0], setJailPos[1], setJailPos[2]);

	JailCells[nJailId] = nFullPos;
	
	
	Handle DB = CreateKeyValues("Jails");
	FileToKeyValues(DB, JailPath);
	
	if(KvJumpToKey(DB, sJailId, true))
	{
		KvSetNum(DB, "id", nJailId);
		KvSetFloat(DB, "x", setJailPos[0]);
		KvSetFloat(DB, "y", setJailPos[1]);
		KvSetFloat(DB, "z", setJailPos[2]);
	}
	
	KvRewind(DB);
	KeyValuesToFile(DB, JailPath);
	CloseHandle(DB);
	
	
	CPrintToChat(client, "{green}[TFRP]{default} Set jail cell {mediumseagreen}#%d{default} at your position.", nJailId);
	
	return Plugin_Handled;
}

public Action Command_ReloadConf(int client, int args)
{
	LoadConfig(true);
	CPrintToChat(client, "{green}[TFRP]{default} Reloaded config");
	return Plugin_Handled;
}

////////////
/// HUD ///
///////////

public Action HUD(Handle timer, int client)
{
	if(!IsClientInGame(client)) return Plugin_Continue;
	if(IsFakeClient(client)) return Plugin_Continue;

	char HudJob[32];
	FormatEx(HudJob, sizeof(HudJob), "Job: %s", UD[client].sJob);
	char HudCash[32];
	FormatEx(HudCash, sizeof(HudCash), "Cash: %d", UD[client].iCash);
	char HudSalary[32];
	FormatEx(HudSalary, sizeof(HudSalary), "Salary: %d", UD[client].iJobSalary);
	SetHudTextParams(0.010, 0.010, 1.0, 120, 56, 21, 200, 0, 6.0, 0.0, 0.0);
	ShowSyncHudText(client, hHud1, "%s", HudJob);
	SetHudTextParams(0.010, 0.050, 1.0, 120, 56, 21, 200, 0, 6.0, 0.0, 0.0);
	ShowSyncHudText(client, hHud2, "%s", HudCash);
	SetHudTextParams(0.010, 0.090, 1.0, 120, 56, 21, 200, 0, 6.0, 0.0, 0.0);
	ShowSyncHudText(client, hHud3, "%s", HudSalary);
	
	// I will be moving every hud to here for more optimization, but since Im adding Bonk I'll be doing that now
	int GetHudLook = GetClientAimTarget(client, false);
	if(GetHudLook == -1) return Plugin_Continue;
	if(StrEqual(EntItems[GetHudLook], "Bonk Mixer"))
	{
		char GetBonkWater[32];
		FormatEx(GetBonkWater, sizeof(GetBonkWater), "Water: %dml", BonkMixers[GetHudLook].BonkWater*100);
		SetHudTextParams(0.85, 0.50, 1.0, 100, 255, 100, 225, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, hHud12, "%s", GetBonkWater);
		
		char GetBonkCaesium[32];
		FormatEx(GetBonkCaesium, sizeof(GetBonkCaesium), "Caesium: %d", BonkMixers[GetHudLook].BonkCaesium);
		SetHudTextParams(0.85, 0.55, 1.0, 100, 255, 100, 225, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, hHud13, "%s", GetBonkCaesium);
		
		char GetBonkSugar[32];
		FormatEx(GetBonkSugar, sizeof(GetBonkSugar), "Sugar: %dkg", BonkMixers[GetHudLook].BonkSugar*9);
		SetHudTextParams(0.85, 0.60, 1.0, 100, 255, 100, 225, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, hHud14, "%s", GetBonkSugar);
		
	} else if (StrEqual(EntItems[GetHudLook], "Bonk Canner"))
	{
		char GetBonkCanned[32];
		FormatEx(GetBonkCanned, sizeof(GetBonkCanned), "Bonk: %d", BonkCanners[GetHudLook].BonkCans);
		SetHudTextParams(0.85, 0.60, 1.0, 100, 255, 100, 225, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, hHud15, "%s", GetBonkCanned);
	}
	if(GetHudLook <= MaxClients && IsClientInGame(GetHudLook))
	{
		float GetHudLookPos[3];
		GetClientAbsOrigin(GetHudLook, GetHudLookPos);
	
		float GetHudClientPos[3];
		GetClientAbsOrigin(client, GetHudClientPos);
	
		if(GetVectorDistance(GetHudLookPos, GetHudClientPos) <= 500)
		{
			
			char GetJobLook[32];
			FormatEx(GetJobLook, sizeof(GetJobLook), "Job: %s", UD[GetHudLook].sJob);
			SetHudTextParams(-1.0, 0.75, 1.0, 255, 165, 56, 225, 0, 0.0, 0.0, 0.0);
			ShowSyncHudText(client, hHud5, "%s", GetJobLook);
		
			// Enemy health
			if( TF2_GetClientTeam(client) != TF2_GetClientTeam(GetHudLook) )
			{
				char GetNameLook[32];
				GetClientName(GetHudLook, GetNameLook, sizeof(GetNameLook));
				SetHudTextParams(-1.0, 0.65, 1.0, 255, 165, 56, 225, 0, 0.0, 0.0, 0.0);
				ShowSyncHudText(client, hHud17, "%s", GetNameLook);
				char GetEnemyHealth[32];
				FormatEx(GetEnemyHealth, sizeof(GetEnemyHealth), "HP: %d", GetClientHealth(GetHudLook));
				SetHudTextParams(-1.0, 0.80, 1.0, 255, 0, 0, 225, 0, 0.0, 0.0, 0.0);
				ShowSyncHudText(client, hHud16, "%s", GetEnemyHealth);
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Welcome(Handle timer, int client)
{
	TFRP_PrintToChat(client, "Welcome to {green}TFRP!{default} Do /rphelp for more information");
	return Plugin_Continue;
}


////////////////////////////////////////////////
// Inventory Revamped (By The Illusion Squid) //
////////////////////////////////////////////////
public Action Command_INVENTORY(int client, int args)
{
	if(UD[client].bArrested)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You cannot access your invenotry while arrested.");
		return Plugin_Handled;
	}

	if(client==0){
		PrintToServer("[TFRP] Command can't be ran from console.");
		return Plugin_Handled;
	}

	OpenInv(client);

	return Plugin_Handled;
}

void OpenInv(int iClient)
{
	Handle hInvMenu = CreateMenu(MenuCallBackItems);
	SetMenuTitle(hInvMenu, "[TFRP] %d Items. Balance : %d", GetArraySize(hItemArray[iClient]), UD[iClient].iCash);
	for (int i=0; i < GetArraySize(hItemArray[iClient]); i++)
	{
		char ItemName[32],
			buffer[32];
		Handle hArray = GetArrayCell(hItemArray[iClient], i);
		GetArrayString(hArray, 0, ItemName, sizeof(ItemName));
		if(GetArrayCell(hArray, 1) > 0) //Lets not draw items we dont have
		{
			Format(buffer, sizeof(buffer), "%s (%d)", ItemName, GetArrayCell(hArray, 1));
			Format(ItemName, sizeof(ItemName), "%s_%d", ItemName, GetArrayCell(hArray, 1));
			AddMenuItem(hInvMenu, ItemName, buffer);
		}
	}

	if (GetMenuItemCount(hInvMenu) < 1)
	{
		AddMenuItem(hInvMenu, "", "[Inventory Empty]", ITEMDRAW_DISABLED); //So it doesn't seem like the plugin gave up
	}

	SetMenuPagination(hInvMenu, 7);
	SetMenuExitButton(hInvMenu, true);
	DisplayMenu(hInvMenu, iClient, 250);
}

public int MenuCallBackItems(Handle menuhandleitems, MenuAction action, int iClient, int Position)
{
	if(action == MenuAction_Select)
	{
		char CmdItemName[32];

		GetMenuItem(menuhandleitems, Position, CmdItemName, sizeof(CmdItemName));

		char ItemInfoNextInv[32][32];
		ExplodeString(CmdItemName, "_", ItemInfoNextInv, 2, sizeof(ItemInfoNextInv));

		if (cvarTFRP[Debug].BoolValue)
		{
			PrintToServer("[TFRP] Item selected: %s", ItemInfoNextInv[0]);
			PrintToServer("[TFRP] Item count: %d", ItemInfoNextInv[1]);
		}

		NextInvMenu(iClient, ItemInfoNextInv[0], StringToInt(ItemInfoNextInv[1]));

	} else if(action == MenuAction_End)
	{
		CloseHandle(menuhandleitems);
	}
	return 0;
}

public void NextInvMenu(int client, char[] iteminfo, int itemcount)
{
	Handle hMenu = CreateMenu(MenuCallBackNextInv);
	SetMenuTitle(hMenu, "[TFRP] You have %d %s", itemcount, iteminfo);

	char SpawnItemInfo[32],
		UseItemInfo[32],
		DropItemInfo[32];
	FormatEx(SpawnItemInfo, sizeof(SpawnItemInfo), "spawn_%s_%d", iteminfo, itemcount);
	FormatEx(UseItemInfo, sizeof(UseItemInfo), "use_%s_%d", iteminfo, itemcount);
	FormatEx(DropItemInfo, sizeof(DropItemInfo), "drop_%s_%d", iteminfo, itemcount);
	
	// First off, we need to see if the item is spawnable, this is located in the shop file under "type"
	Handle DB2 = CreateKeyValues("Shop");

	FileToKeyValues(DB2, ShopPath);
	if(KvJumpToKey(DB2, iteminfo, false))
	{
		char spawning_item[48];
		KvGetString(DB2, "type", spawning_item, sizeof(spawning_item), "item");
		if(StrEqual(spawning_item, "ent"))
		{
			AddMenuItem(hMenu, SpawnItemInfo, "Spawn Item");
		}
		if (StrEqual(spawning_item, "item", false) || StrEqual(spawning_item, "weapon"))
		{
			AddMenuItem(hMenu, UseItemInfo, "Use Item");
		}
	}
	else
	{
		CPrintToChat(client, "{green}[TFRP]{red} ERROR: {default}For some reason, the item couldn't be found in the database. Maybe the item was deleted from the server?");
	}
	//Supprised this worked out so well -Squid
	
	AddMenuItem(hMenu, DropItemInfo, "Drop Item");
	SetMenuPagination(hMenu, 7);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, 250);
}

public int MenuCallBackNextInv(Handle menuhandle, MenuAction action, int iClient, int Position)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char CmdItemName[32];

			GetMenuItem(menuhandle, Position, CmdItemName, sizeof(CmdItemName));

			char ItemInfoNextInv[32][32];
			ExplodeString(CmdItemName, "_", ItemInfoNextInv, 3, sizeof(ItemInfoNextInv));

			if(StrEqual(ItemInfoNextInv[0], "spawn")){
				SpawnInv(iClient, ItemInfoNextInv[1]);
			}else if(StrEqual(ItemInfoNextInv[0], "use")){
				UseItem(iClient, ItemInfoNextInv[1]);
			} else if(StrEqual(ItemInfoNextInv[0], "drop")){
				DropItem(iClient, ItemInfoNextInv[1]);
			}
			InvBack(iClient, ItemInfoNextInv[1], ItemInfoNextInv[2]);
		}
		case MenuAction_Cancel:
		{
			switch(Position)
			{
				case MenuCancel_ExitBack:
				{
					OpenInv(iClient);
				}
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menuhandle);
		}
	}		
	return 0;
}

public void InvBack(int iClient, char[] ItemID, const char[] itemcount)
{
	int ic = StringToInt(itemcount) - 1;
	if (ic > 0) //More of these items? Keep open the items tab
	{
		for (int i=0; i < GetArraySize(hItemArray[iClient]); i++) //This schould update the inv array so that if they go back and then again to the same item it has a correct Itemcount.
		{
			char ItemName[32];
			Handle hArray = GetArrayCell(hItemArray[iClient], i);
			GetArrayString(hArray, 0, ItemName, sizeof(ItemName));
			if(StrEqual(ItemID, ItemName, false))
			{
				SetArrayCell(hArray, 1, ic);
			}
		}
		NextInvMenu(iClient, ItemID, ic);
	}
	else //No more of these items? Send them back to the updated inventory
	{
		OpenInv(iClient);
	}
}

//////////////////////
// Sandvich Making //
/////////////////////

public int AddIngredientSandvich(int client, char[] ingredientSandvich)
{
	// Remade the remade sandvich making
	int curSandvichTable = GetClientAimTarget(client, false);
	if(curSandvichTable == -1)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a {mediumseagreen}Sandvich Table!");
		return 0;
	}
	if(StrEqual(EntItems[curSandvichTable], "Sandvich Table"))
	{
		if(StrEqual(ingredientSandvich, "Bread")) STableIngredients[curSandvichTable][0]++;
		if(StrEqual(ingredientSandvich, "Cheese")) STableIngredients[curSandvichTable][1]++;
		if(StrEqual(ingredientSandvich, "Meat")) STableIngredients[curSandvichTable][2]++;
		if(StrEqual(ingredientSandvich, "Lettuce")) STableIngredients[curSandvichTable][3]++;
		TFRP_PrintToChat(client, "Added {mediumseagreen}1 %s{default} to the {mediumseagreen}Sandvich Table",ingredientSandvich);
		if(STableIngredients[curSandvichTable][0] >= 1 && STableIngredients[curSandvichTable][1] >= 1 >= STableIngredients[curSandvichTable][2] >= 1 && STableIngredients[curSandvichTable][3] >= 1)
		{
			TFRP_PrintToChat(client, "All ingredients have been added to the table, making {mediumseagreen}Sandvich{default} in {mediumseagreen}%.0f{default} seconds", cvarTFRP[SandvichMakeTime].FloatValue);
			CreateTimer(cvarTFRP[SandvichMakeTime].FloatValue, Timer_Sandvich, client);
			STableIngredients[curSandvichTable][0] = STableIngredients[curSandvichTable][0] - 1;
			STableIngredients[curSandvichTable][1] = STableIngredients[curSandvichTable][1] - 1; 
			STableIngredients[curSandvichTable][2] = STableIngredients[curSandvichTable][2] - 1; 
			STableIngredients[curSandvichTable][3] = STableIngredients[curSandvichTable][3] - 1; 
		}
		GiveItem(client, ingredientSandvich, -1);
	}else{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a {mediumseagreen}Sandvich Table!");
	}
	return 0;
}

// Sandvich Timer
public Action Timer_Sandvich(Handle timer, int client)
{
	if(!IsClientInGame(client)) return Plugin_Continue;
	GiveItem(client, "Sandvich", 1);
	CPrintToChat(client, "{green}[TFRP]{default} You made a {mediumseagreen}Sandvich!");
	return Plugin_Continue;
}

public int DeleteJobEnts(int client)
{
	for(int i = 0; i <= 2047; i++)
	{
		if(EntOwners[i] == client)
		{
			// This finds the item type and sees if the player's new job can own them, if not it deletes them
			Handle DB = CreateKeyValues("Shop");
			FileToKeyValues(DB, ShopPath);
			
			bool FoundJobDel = false;
		
			if(KvJumpToKey(DB, EntItems[i], false))
			{
				if(KvJumpToKey(DB, "Job_Reqs", true))
				{
					if(KvGotoFirstSubKey(DB,false))
					{
				
						do{
		
							char GetJobReqDel[32];
							KvGetString(DB, NULL_STRING, GetJobReqDel, sizeof(GetJobReqDel));
							
							if(StrEqual(GetJobReqDel, "any") || StrEqual(GetJobReqDel, UD[client].sJob))
							{
								FoundJobDel = true;
							}

						} while (KvGotoNextKey(DB,false));

					}
				}
			}else{
				PrintToServer("[TFRP] ERROR: Tried to delete entity with no item type!");
			}
			
			if(!FoundJobDel)
			{
				// New job can't own this item, delete it
				TFRP_DeleteEnt(i);
			}
			
			KvRewind(DB);
			CloseHandle(DB);
		}
	}
	return 0;
}

/////////////////
// Australium // 
////////////////

// Drill, Fuel for drill, cleaner, packing boxes
// Adding fuel to drill

public int AddFuelAustraliumDrill(int client)
{
	int curAusDrill = GetClientAimTarget(client, false);
	if(curAusDrill == -1 || !StrEqual(EntItems[curAusDrill], "Australium Drill"))
	{
		TFRP_PrintToChat(client, "You must be looking at an {mediumseagreen}Australium Drill!");
	}else{
		AusFuels[curAusDrill] = AusFuels[curAusDrill] + cvarTFRP[FuelPerCan].IntValue;
		CPrintToChat(client, "{green}[TFRP]{default} Added {mediumseagreen}%d{default} fuel to the {mediumseagreen}Australium Drill", cvarTFRP[FuelPerCan].IntValue);
		GiveItem(client, "Fuel", -1);
	}

	return 0;
}

// Use fuel
public Action Timer_AusDrillFuelTimer(Handle timer, int curAusDrillFuelTimer)
{
	if(curAusDrillFuelTimer == -1 || !IsValidEntity(curAusDrillFuelTimer) || !StrEqual(EntItems[curAusDrillFuelTimer], "Australium Drill")) return Plugin_Continue;
	{
		if(AusFuels[curAusDrillFuelTimer] > 0) AusFuels[curAusDrillFuelTimer] = AusFuels[curAusDrillFuelTimer] - cvarTFRP[AustraliumFuelPerSecond].IntValue;	
	}
	return Plugin_Continue;
}
// Australium Drill
public Action Timer_AusDrill(Handle timer, int curAusDrillTimer)
{

	if(curAusDrillTimer == -1 || !IsValidEntity(curAusDrillTimer) || !StrEqual(EntItems[curAusDrillTimer], "Australium Drill") || AusFuels[curAusDrillTimer] <= 0) return Plugin_Continue;

	AusMined[curAusDrillTimer] = AusMined[curAusDrillTimer] + 1;
	// Create sound for when the drill mined australium
	float curAusDrillLoc[3];
	GetEntPropVector(curAusDrillTimer, Prop_Send, "m_vecOrigin", curAusDrillLoc);
	EmitAmbientSound(AUSTRALIUM_DRILL_MINED_AUSTRALIUM, curAusDrillLoc, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
	
	return Plugin_Continue;
}

// Getting australium from drill to cleaner
public Action OnTakeDamageAusDrill(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	// This probably isn't needed, but im too paranoid to care rn
	if(!StrEqual(EntItems[victim], "Australium Drill")) return Plugin_Continue;
	
	// Only Australium Miners can use drills
	if(StrEqual(UD[attacker].sJob, "Australium Miner"))
	{
		if(AusMined[victim] > 0)
		{
			// To make things a bit less repetitive, if the drill has atleast 5 Australium it'll take 5 at a time
			if(AusMined[victim] >= 5)
			{
				AusMined[victim] = AusMined[victim] - 5;
				GiveItem(attacker, "Dirty Australium", 5);
				TFRP_PrintToChat(attacker, "You took {mediumseagreen}5 Dirty Australium{default}");
			}else{
				AusMined[victim] = AusMined[victim] - 1;
				GiveItem(attacker, "Dirty Australium", 1);
				TFRP_PrintToChat(attacker, "You took {mediumseagreen}1 Dirty Australium{default}");
			}
		}else{
			TFRP_PrintToChat(attacker, "No {mediumseagreen}Australium{default} has been mined yet!");
		}
		

	}else{
		CPrintToChat(attacker, "{green}[TFRP]{default} Only {goldenrod}Australium Miners{default} can use {mediumseagreen}Australium Drills!");
	}
	return Plugin_Continue;
}

// Australium cleaner
public Action Timer_AusCleaner(Handle timer, int curAusCleanerTimer)
{
	if(curAusCleanerTimer == -1 || !IsValidEntity(curAusCleanerTimer) || !StrEqual(EntItems[curAusCleanerTimer], "Australium Cleaner")) return Plugin_Continue;
	// Needs to be australium in the cleaner for it to clean the australium idk
	if(AusDirty[curAusCleanerTimer] >= 1)
	{
		// There is australium in the cleaner, ready to clean		
		AusClean[curAusCleanerTimer]++;
		AusDirty[curAusCleanerTimer] = AusDirty[curAusCleanerTimer] - 1;
	}
	
	return Plugin_Continue;
}

// Getting clean australium ready to package
public Action OnTakeDamageAusCleaner(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(!StrEqual(EntItems[victim], "Australium Cleaner")) return Plugin_Continue;
	
	// Only Australium Miners can use cleaners
	if(StrEqual(UD[attacker].sJob, "Australium Miner"))
	{	
		if(AusClean[victim] <= 0)
		{
			TFRP_PrintToChat(attacker, "No {mediumseagreen}Australium{default} has been cleaned yet");
			return Plugin_Continue;
		}
		if(AusClean[victim] >= 5)
		{
			GiveItem(attacker, "Australium", 5);
			AusClean[victim] = AusClean[victim] - 5;
			TFRP_PrintToChat(attacker, "You took {mediumseagreen}5 Australium{default} from the {mediumseagreen}Australium Cleaner");
			return Plugin_Continue;
	   	}
		if(AusClean[victim] >= 1)
		{
			GiveItem(attacker, "Australium", 1);
			AusClean[victim] = AusClean[victim] - 1;
			TFRP_PrintToChat(attacker, "You took {mediumseagreen}1 Australium{default} from the {mediumseagreen}Australium Cleaner");
			return Plugin_Continue;
		}
		

	}else{
		CPrintToChat(attacker, "{green}[TFRP]{default} Only {goldenrod}Australium Miners{default} can use {mediumseagreen}Australium Cleaners!");
	}
	return Plugin_Continue;
}


// Timer that constantly checks if the player is looking at an australium drill
// If the player is near the drill and looking at it, it'll add the drill's fuel to the center of the screen
public Action Timer_AusHUD(Handle timer, int client)
{
	if(!IsClientInGame(client)) return Plugin_Continue;
	if(IsFakeClient(client)) return Plugin_Continue;
	int curLookingAtAus = GetClientAimTarget(client, false);
	if(curLookingAtAus == -1) return Plugin_Continue;
	
	float clientPosAusHUD[3];
	GetClientAbsOrigin(client, clientPosAusHUD);
	
	float drillPosAusHUD[3];
	GetEntPropVector(curLookingAtAus, Prop_Send, "m_vecOrigin", drillPosAusHUD);

	if(GetVectorDistance(clientPosAusHUD, drillPosAusHUD) > 200) return Plugin_Continue;
	
	if(StrEqual(EntItems[curLookingAtAus], "Australium Drill") && AusFuels[curLookingAtAus] >= 0)
	{
		char HudAusFuel[32];
		FormatEx(HudAusFuel, sizeof(HudAusFuel), "Fuel: %d", AusFuels[curLookingAtAus]);
		SetHudTextParams(-1.0, -1.0, 1.0, 255, 0, 0, 200, 0, 6.0, 0.0, 0.0);
		ShowSyncHudText(client, hHud10, HudAusFuel);
	}
	return Plugin_Continue;
}

public int AddAustraliumToCleaner(int client)
{
	int curAusCleaner = GetClientAimTarget(client, false);
	
	if(curAusCleaner == -1 || !StrEqual(EntItems[curAusCleaner], "Australium Cleaner"))
	{
		TFRP_PrintToChat(client, "You must be looking at an {mediumseagreen}Australium Cleaner");
		return 0;
	}
	
	AusDirty[curAusCleaner]++;
	CreateTimer(cvarTFRP[AustraliumCleanTime].FloatValue, Timer_AusCleaner, curAusCleaner);
	TFRP_PrintToChat(client, "Added {mediumseagreen}Dirty Australium{default} to the {mediumseagreen}Australium Drill");
	GiveItem(client, "Dirty Australium", -1);
	return 0;
}

// Australium packaging

public int AddCleanAusToPackage(int client)
{
	int curAusPackage = GetClientAimTarget(client, false);

	if(curAusPackage == -1 || !StrEqual(EntItems[curAusPackage], "Empty Package"))
	{
		TFRP_PrintToChat(client, "You must be looking at an {mediumseagreen}Australium Package");
		return 0;
	}
	if(AusPacks[curAusPackage] < 5)
	{
		AusPacks[curAusPackage]++;
		TFRP_PrintToChat(client, "Added {mediumseagreen}Australium{default} to {mediumseagreen}Package");
		GiveItem(client, "Australium", -1);
	}else{
		TFRP_PrintToChat(client, "There is already {mediumseagreen}5 Australium{default} in the {mediumseagreen}Package");
	}
	return 0;
}

public Action OnTakeDamageAusPackage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(!StrEqual(EntItems[victim], "Empty Package")) return Plugin_Continue;
	// Only Australium Miners can use packages
	if(StrEqual(UD[attacker].sJob, "Australium Miner"))
	{
		if(AusPacks[victim] == 5)
		{
			GiveItem(attacker, "Full Australium Package", 1);
			TFRP_PrintToChat(attacker, "You picked up {mediumseagreen}Full Australium Package");
			AusPacks[victim] = 0;
			TFRP_DeleteEnt(victim);
		}else{
			TFRP_PrintToChat(attacker, "There must be {mediumseagreen}5 Australium{default} in the {mediumseagreen}package{default} to pick it up");
		}
	}else{
		CPrintToChat(attacker, "{green}[TFRP]{default} Only {goldenrod}Australium Miners{default} can use {mediumseagreen}Australium Packages!");
	}
	return Plugin_Continue;
}

// Spawning Australium related entities

public int AddAusDrill(int index, int client)
{
	AusMined[index] = 0;
	AusFuels[index] = 0;

	CreateTimer(cvarTFRP[AustraliumDrillTime].FloatValue, Timer_AusDrill, index, TIMER_REPEAT);
	CreateTimer(1.0, Timer_AusDrillFuelTimer, index, TIMER_REPEAT);

	SDKHookEx(index, SDKHook_OnTakeDamage, OnTakeDamageAusDrill);
	return 0;
}

public int AddAusCleaner(int index, int client)
{
	SDKHookEx(index, SDKHook_OnTakeDamage, OnTakeDamageAusCleaner);
	return 0;
}

public int AddAusPackage(int index, int client)
{
	AusPacks[index] = 0;
	SDKHookEx(index, SDKHook_OnTakeDamage, OnTakeDamageAusPackage);
	return 0;
}

/////////////
// Police //
////////////

public void SetJails()
{
	
	bool FoundJailLoad = false;
	
	Handle DB = CreateKeyValues("Jails");
	FileToKeyValues(DB, JailPath);
		
	KvGotoFirstSubKey(DB);
		
	do{
		
		int GetJailCellId = KvGetNum(DB, "id", 0);
		float GetJailCellPos[3];
		GetJailCellPos[0] = KvGetFloat(DB, "x", 0.0);
		GetJailCellPos[1] = KvGetFloat(DB, "y", 0.0);
		GetJailCellPos[2] = KvGetFloat(DB, "z", 0.0);
			
		char FormatPosJailCell[32];
		FormatEx(FormatPosJailCell, sizeof(FormatPosJailCell), "%f,%f:%f", GetJailCellPos[0], GetJailCellPos[1], GetJailCellPos[2]);
		JailCells[GetJailCellId] = FormatPosJailCell;
			
		FoundJailLoad = true;
			
	} while (KvGotoNextKey(DB,false));
		
	KvRewind(DB);
	CloseHandle(DB);
	
	
	if(FoundJailLoad) CPrintToChatAll("{green}[TFRP]{default} Set jails.");
	
}

public int Arrest(int client, int arrestTarget)
{
	if(!UD[arrestTarget].bGov){

		if(UD[arrestTarget].bArrested && client != -90)
		{
			CPrintToChat(client, "{green}[TFRP]{default} Player is already arrested!");
			return 0;
		}
		
		int GetRandom = 0;
		bool FoundCell = false;
		bool AreCells = false;
	
		for(int i = 0; i < 10; i++)
		{
			if(!StrEqual(JailCells[i], "none"))
			{
				AreCells = true;
				break;
			}
		}
		
		if(!AreCells)
		{
			if(client == -90)
			{
				CPrintToChat(arrestTarget, "{green}[TFRP]{default} Could not teleport you because no jail cells have been set!");
			}else{
				CPrintToChat(client, "{green}[TFRP]{default} No cells have been set!");
			}
			return 0;
		}
		
		while(!FoundCell)
		{
			GetRandom = GetRandomInt(0, 9);
			if(GetRandom >= 0 && !StrEqual(JailCells[GetRandom], "none")) FoundCell = true;
		}
		
		char curJailCoords[32][32];
		ExplodeString(JailCells[GetRandom], ",", curJailCoords, 2, sizeof(curJailCoords));
		char curJailCoordsCol[32][32];
		ExplodeString(curJailCoords[1], ":", curJailCoordsCol, 2, sizeof(curJailCoordsCol));
		
		float ArrestPos[3];
		ArrestPos[0] = StringToFloat(curJailCoords[0]);
		ArrestPos[1] = StringToFloat(curJailCoordsCol[0]);
		ArrestPos[2] = StringToFloat(curJailCoordsCol[1]);
		
		TeleportEntity(arrestTarget, ArrestPos, NULL_VECTOR, NULL_VECTOR);
			
		if(client != -90)
		{
			char targetName[MAX_NAME_LENGTH];
			GetClientName(arrestTarget, targetName, sizeof(targetName));
			
			char copName[MAX_NAME_LENGTH];
			GetClientName(client, copName, sizeof(copName));
		
		
			CPrintToChat(client, "{green}[TFRP]{goldenrod} %s{default} was sent to jail cell {mediumseagreen}%d", targetName, GetRandom);
		
			CPrintToChat(arrestTarget, "{green}[TFRP]{default} You were arrested by {goldenrod}%s", copName);
			UD[arrestTarget].bArrested = true;
			if(UD[arrestTarget].bHasWarrent)
			{
				UD[arrestTarget].bHasWarrent = false;
				TFRP_PrintToChat(client, "You were given {mediumseagreen}%d{default} for arresting a player with a warrant", cvarTFRP[WarrantReward].IntValue);
				UD[client].iCash += cvarTFRP[WarrantReward].IntValue;
			}
			
			
			JailTimes[arrestTarget] = cvarTFRP[JailTime].FloatValue;
			
			CreateTimer(1.0, Timer_JailTime, arrestTarget, TIMER_REPEAT);
			CreateTimer(0.1, Timer_JailHud, arrestTarget, TIMER_REPEAT);
			CreateTimer(cvarTFRP[JailTime].FloatValue, Timer_Jail, arrestTarget);
			
		}
		return 0;
	}else{
		CPrintToChat(client, "{green}[TFRP]{default} You cannot arrest other police officers.");
		return 0;
	}
}

public Action Command_Arrest(int client, int args)
{
	if(!UD[client].bGov)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be a {mediumseagreen}Government Offical{default} to arrest people!");
		return Plugin_Handled;
	}
	
	if(StrEqual(UD[client].sJob,"Mayor"))
	{
		CPrintToChat(client, "{green}[TFRP]{default} Mayor cannot arrest people!");
		return Plugin_Handled;
	}
	
	if(!IsPlayerAlive(client))
	{
		CPrintToChat(client, "{green}[TFRP]{default} You cannot arrest people while dead!");
		return Plugin_Handled;
	}
	
	int curArrestPlayer = GetClientAimTarget(client, false);
	
	if(curArrestPlayer <= -1 || curArrestPlayer > MaxClients)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a player!");
		return Plugin_Handled;	
	}

	
	if(curArrestPlayer > MaxClients+1){
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a player!");
		return Plugin_Handled;
	}
	
	float ClientOriginArrest[3];
	GetClientAbsOrigin(client, ClientOriginArrest);
	float ArrestTargetVec[3];
	GetEntPropVector(curArrestPlayer, Prop_Send, "m_vecOrigin", ArrestTargetVec);

	if(GetVectorDistance(ClientOriginArrest, ArrestTargetVec) <= 125){
		Arrest(client, curArrestPlayer);
	}else{
		CPrintToChat(client, "{green}[TFRP]{default} You have to be closer to the player to arrest them!");
	}
	return Plugin_Handled;
}

// Police chat

public Action Command_PoliceRadio(int client, int args)
{
	if(!UD[client].bGov)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be a {mediumseagreen}Government Offical{default} to use {mediumseagreen}Police Radio.");
	}

	if (args < 1)
		return Plugin_Handled;
	
	for(int i = 0; i <= MaxClients + 1; i++)
	{
		if(UD[i].bGov)
		{
			char FullPoliceMessage[128];
			GetCmdArgString(FullPoliceMessage, sizeof(FullPoliceMessage));
			
			char PoliceName[MAX_NAME_LENGTH];
			GetClientName(i, PoliceName, sizeof(PoliceName));
			
			CPrintToChat(i, "{mediumseagreen}[POLICE RADIO] {deepskyblue}[%s]: {dodgerblue} %s", PoliceName, FullPoliceMessage);
		}
	}

	return Plugin_Handled;
	
}

// Arrest timer
public Action Timer_Jail(Handle timer, int client)
{
	UD[client].bArrested = false;
	JailTimes[client] = 0.0;
	ForcePlayerSuicide(client);
	CPrintToChat(client, "{green}[TFRP]{default} You've served your sentance");
}	

// Arrested Hud

public Action Timer_JailHud(Handle timer, int client)
{
	if(!IsClientInGame(client)) return Plugin_Continue;
	if(IsFakeClient(client)) return Plugin_Continue;
	if(!UD[client].bArrested) return Plugin_Continue;
	
	char ArrestHudTime[32];
	FormatEx(ArrestHudTime, sizeof(ArrestHudTime), "Jail Time: %.0f", JailTimes[client]);
	SetHudTextParams(-1.0, 0.30, 1.0, 0, 255, 0, 200, 0, 6.0, 0.0, 0.0);
	ShowSyncHudText(client, hHud11, ArrestHudTime);

	return Plugin_Continue;
}

public Action Timer_JailTime(Handle timer, int client)
{
	if(!UD[client].bArrested) return Plugin_Continue;
	JailTimes[client] -= 1.0;
	return Plugin_Continue;
}

///////////
// NPCs //
//////////

// Create saved NPCs
public void SetNPCs()
{
	CPrintToChatAll("{green}[TFRP]{default} Creating NPCs...");
	
	Handle DB = CreateKeyValues("NPCs");
	FileToKeyValues(DB, NPCPath);
	
	
	if(KvGotoFirstSubKey(DB,false))
	{
		do{
			
			float originnpc[3];
			float npcAngles[3];
		
			char GetNPCTypeSec[32];
			KvGetSectionName(DB, GetNPCTypeSec, sizeof(GetNPCTypeSec));
		
			char GetNPCType[32][32];
			ExplodeString(GetNPCTypeSec, ":", GetNPCType, 2, sizeof(GetNPCType));
		
			// Model is set from npc type
		
			char SetNPCModel[64];
		
			Handle DB2 = CreateKeyValues("NPCTypes");
			FileToKeyValues(DB2, NPCTypePath);
		
			// Also checks if the NPC type still exists
		
			if(KvJumpToKey(DB2, GetNPCType[0], true))
			{
				KvGetString(DB2, "Model", SetNPCModel, sizeof(SetNPCModel), "SETAMODELPLEASEORITLLBEANERROR");
			}
		
			KvRewind(DB2);
			CloseHandle(DB2);
		
			originnpc[0] = KvGetFloat(DB, "x", 0.0);
			originnpc[1] = KvGetFloat(DB, "y", 0.0);
			originnpc[2] = KvGetFloat(DB, "z", 0.0);
			npcAngles[0] = KvGetFloat(DB, "Pitch", 0.0);
			npcAngles[1] = KvGetFloat(DB, "Yaw", 0.0);
			npcAngles[2] = KvGetFloat(DB, "Roll", 0.0);
		
			// Spawning the NPC
			int EntIndex = CreateEntityByName("prop_dynamic_override");
			if(EntIndex != -1 && IsValidEntity(EntIndex))
			{	
				DispatchKeyValue(EntIndex, "model", SetNPCModel);
				DispatchSpawn(EntIndex);

				// Create the collision box for the npc as playermodels don't have them
				// The hydro water barrel seems to be an alright model to use as collisions
				int EntIndexBox = CreateEntityByName("prop_dynamic_override");
				if(EntIndexBox != -1 && IsValidEntity(EntIndexBox)){
					DispatchKeyValue(EntIndexBox, "model", "models/props_hydro/water_barrel.mdl");
					DispatchKeyValueFloat(EntIndexBox, "solid", 2.0);
					SetEntProp(EntIndexBox, Prop_Send, "m_nRenderFX", RENDERFX_NONE);
					SetEntProp(EntIndexBox, Prop_Send, "m_nRenderMode", RENDER_NONE);
					DispatchSpawn(EntIndexBox);
					// SetEntPropFloat(EntIndexBox, Prop_Send, "m_flShadowCastDistance", 0.0);
					TeleportEntity(EntIndexBox, originnpc, npcAngles, NULL_VECTOR);
					AcceptEntityInput(EntIndexBox, "SetParent", EntIndex);
					SDKHookEx(EntIndexBox, SDKHook_OnTakeDamage, OpenNPCMenu);
				}

				TeleportEntity(EntIndex, originnpc, npcAngles, NULL_VECTOR);
			
				NPCIds[StringToInt(GetNPCType[1])] = GetNPCType[0];
				NPCEnts[StringToInt(GetNPCType[1])] = EntIndex;
				NPCEntsBox[StringToInt(GetNPCType[1])] = EntIndexBox;
				
			

			} else {
				CPrintToChatAll("{green}[TFRP]{red} ERROR: {default}Couldn't create npc! Maybe the server has to update Sourcemod?");
			}
			
		
		} while (KvGotoNextKey(DB,false));
	}
	
	KvRewind(DB);
	CloseHandle(DB);
}

public Action Command_MakeNPC(int client, int args)
{
	if(args != 1){
		CPrintToChat(client, "{green}[TFRP]{default} Usage: sm_makenpc <type>");
		return Plugin_Handled;
	}
	
	char CurArgNpc[32];
	GetCmdArg(1, CurArgNpc, sizeof(CurArgNpc));

	char npcModel[64];

	Handle DB = CreateKeyValues("NPCTypes");
	FileToKeyValues(DB, NPCTypePath);
		
	if(KvJumpToKey(DB, CurArgNpc, false))
	{
		
		KvGetString(DB, "Model", npcModel, sizeof(npcModel), "SETAMODELPLEASEORITLLBEANERROR");
			
	}else{
		TFRP_PrintToChat(client, "Invalid NPC Type!");
	}

	KvRewind(DB);
	CloseHandle(DB);

	int EntIndex = CreateEntityByName("prop_dynamic_override");
	if(EntIndex != -1 && IsValidEntity(EntIndex))
	{

		float originnpc[3];
		GetClientAbsOrigin(client, originnpc);
		DispatchKeyValue(EntIndex, "model", npcModel);
		DispatchSpawn(EntIndex);
		
		// Get client's angles to use as npc's
		float npcAngles[3];
		GetClientAbsAngles(client, npcAngles);


		// Create the collision box for the npc as playermodels don't have them
		// The hydro water barrel seems to be an alright model to use as collisions
		int EntIndexBox = CreateEntityByName("prop_dynamic_override");
		if(EntIndexBox != -1 && IsValidEntity(EntIndexBox)){
			DispatchKeyValue(EntIndexBox, "model", "models/props_hydro/water_barrel.mdl");
			DispatchKeyValueFloat(EntIndexBox, "solid", 2.0);
			SetEntityRenderMode(EntIndexBox, RENDER_NONE); 
			SetEntityRenderColor(EntIndexBox, 0, 0, 0, 0); 
			DispatchSpawn(EntIndexBox);
            // SetEntPropFloat(EntIndexBox, Prop_Send, "m_flShadowCastDistance", 0.0);
			TeleportEntity(EntIndexBox, originnpc, npcAngles, NULL_VECTOR);
			AcceptEntityInput(EntIndexBox, "SetParent", EntIndex);
			SDKHookEx(EntIndexBox, SDKHook_OnTakeDamage, OpenNPCMenu);
		}

		TeleportEntity(EntIndex, originnpc, npcAngles, NULL_VECTOR);


		CPrintToChat(client, "{green}[TFRP]{default} Created {mediumseagreen}%s", CurArgNpc);
			
			
		// Save NPC and add to array
		Handle DB2 = CreateKeyValues("NPCs");
		FileToKeyValues(DB2, NPCPath);
			
		for(int i = 0; i <= 6; i++)
		{
			if(StrEqual(NPCIds[i], "none"))
			{
				NPCIds[i] = CurArgNpc;
				NPCEnts[i] = EntIndex;
				NPCEntsBox[i] = EntIndexBox;
				
				char FormatIDNPCType[48];
				FormatEx(FormatIDNPCType, sizeof(FormatIDNPCType), "%s:%d", CurArgNpc, i);
					
				if(KvJumpToKey(DB2, FormatIDNPCType, true))
				{
					KvSetFloat(DB2, "x", originnpc[0]);
					KvSetFloat(DB2, "y", originnpc[1]);
					KvSetFloat(DB2, "z", originnpc[2]);
					KvSetFloat(DB2, "Pitch", npcAngles[0]);
					KvSetFloat(DB2, "Yaw", npcAngles[1]);
					KvSetFloat(DB2, "Roll", npcAngles[2]);
				}
			
				break;
			}
		}
			
			
		KvRewind(DB2);
		KeyValuesToFile(DB2, NPCPath);
		CloseHandle(DB2);

	}
	return Plugin_Handled;
}

// Deleting npcs
public Action Command_DeleteNPC(int client, int args)
{
	int GetDelNPC = GetClientAimTarget(client, false);
	if(GetDelNPC == -1)
	{
		CPrintToChat(client, "{green}[TFRP]{default} Must be looking at an NPC!");
		return Plugin_Handled;
	}
	
	bool foundNPCDel = false;
	
	for(int i = 0; i <= 6; i++)
	{
		if(NPCEntsBox[i] == GetDelNPC)
		{ 
			char GetNPCDelStr[32];
			FormatEx(GetNPCDelStr, sizeof(GetNPCDelStr), "%s:%d", NPCIds[i],i);	
			
			RemoveEdict(NPCEnts[i]);
			RemoveEdict(GetDelNPC);
			NPCIds[i] = "none";
			NPCEnts[i] = 0;
			NPCEntsBox[i] = 0;
			
		
			Handle DB = CreateKeyValues("NPCs");
			FileToKeyValues(DB, NPCPath);
			
			if(KvJumpToKey(DB, GetNPCDelStr, false))
			{
				KvGotoFirstSubKey(DB);
				do{
					KvDeleteThis(DB);
			
				} while (KvGotoNextKey(DB,false));
				
				KvDeleteKey(DB, GetNPCDelStr);
			}else{
				TFRP_PrintToChat(client, "{red}ERROR:{default} Couldn't find NPC in file! The server developer must manually remove it from the file.");
			}
		
			
			KvRewind(DB);
			KeyValuesToFile(DB, NPCPath);
			CloseHandle(DB);
			
		

			foundNPCDel = true;
			TFRP_PrintToChat(client, "Deleted NPC.");
			break;
		}
	}
	
	if(!foundNPCDel)
	{
		CPrintToChat(client, "{green}[TFRP]{default} Must be looking at an NPC!");
	}
	
	return Plugin_Handled;
}


// Players need to hit the npc to activate the menu
public Action OpenNPCMenu(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(!IsClientInGame(attacker)) return Plugin_Continue;
	if(IsFakeClient(attacker)) return Plugin_Handled;

	// Players have to be close to the npc to use it
	float sTableClientOriginAttack[3];
	GetClientAbsOrigin(attacker, sTableClientOriginAttack);
	float sTableVecNpc[3];
	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", sTableVecNpc);
	if(GetVectorDistance(sTableClientOriginAttack, sTableVecNpc) <= 125)
	{
    	// NPC's menu
		char NPCTypeMenu[32];

		for(int i = 0; i <=6; i++)
		{
			if(NPCEntsBox[i] == victim)
			{
				FormatEx(NPCTypeMenu, sizeof(NPCTypeMenu), "%s", NPCIds[i]);
			}
		}
		
		Handle menuhandle = CreateMenu(MenuCallBackNPC);
		SetMenuTitle(menuhandle, "[TFRP] %s", NPCTypeMenu);
		
		Handle NPCMenuDB = CreateKeyValues("NPCTypes");
		FileToKeyValues(NPCMenuDB, NPCTypePath);
		
		if(KvJumpToKey(NPCMenuDB, NPCTypeMenu, false))
		{
			if(KvJumpToKey(NPCMenuDB, "Buys_Items", false))
			{
				if(KvGotoFirstSubKey(NPCMenuDB, false))
				{
					do{
						
						char CurBuyItemNPC[32];
						KvGetSectionName(NPCMenuDB, CurBuyItemNPC, sizeof(CurBuyItemNPC));
				
						int CurBuyItemPriceNPC = KvGetNum(NPCMenuDB, NULL_STRING, 0);
				
						char FormatSellItemNPC[48];
						FormatEx(FormatSellItemNPC, sizeof(FormatSellItemNPC), "Sell %s", CurBuyItemNPC);
					
						char FormatNamePriceNPC[64];
						FormatEx(FormatNamePriceNPC, sizeof(FormatNamePriceNPC), "%s:%d",CurBuyItemNPC,CurBuyItemPriceNPC);  
				
						AddMenuItem(menuhandle, FormatNamePriceNPC, FormatSellItemNPC);
					
			
					} while (KvGotoNextKey(NPCMenuDB,false));
				}
			}
		
		}else{
			TFRP_PrintToChat(attacker, "{red}ERROR:{default} Couldn't find NPC type! Contact the server developer.");
			return Plugin_Handled;
		}
		
		
		KvRewind(NPCMenuDB);
		CloseHandle(NPCMenuDB);
		SetMenuPagination(menuhandle, 7);
		SetMenuExitButton(menuhandle, true);
		DisplayMenu(menuhandle, attacker, 250);
	}
	return Plugin_Handled;
}

// Bank Robbing

public Action Command_CreateBankVault(int client, int args)
{
	if(args != 1)
	{
		CPrintToChat(client, "{green}[TFRP]{default} Usage: sm_createbankvault <worth>");
		return Plugin_Handled;
	}
	if(bankIndex != 0)
	{
		CPrintToChat(client, "{green}[TFRP]{default} A bank vault has already been set!");
		return Plugin_Handled;
	}

	char GetBankWorth[32];
	GetCmdArg(1, GetBankWorth, sizeof(GetBankWorth));
	
	bankWorth = StringToInt(GetBankWorth);
	
	int EntIndex = CreateEntityByName("prop_dynamic_override");

	if(EntIndex != -1 && IsValidEntity(EntIndex))
	{
		float origin[3];
		GetClientAbsOrigin(client, origin);
		DispatchKeyValue(EntIndex, "model", "models/props_lakeside/wood_crate_01.mdl");
		DispatchKeyValueFloat(EntIndex, "solid", 2.0);
		DispatchSpawn(EntIndex);
		origin[1] += 10;
		TeleportEntity(EntIndex, origin, NULL_VECTOR, NULL_VECTOR);
		
		Handle DB = CreateKeyValues("BankVaultPos");
		FileToKeyValues(DB, BankVaultPath);
		
		if(KvJumpToKey(DB, "x", true))
		{
			KvSetFloat(DB, "x", origin[0]);
			KvRewind(DB);
		}
		if(KvJumpToKey(DB, "y", true))
		{
			KvSetFloat(DB, "y", origin[1]);
			KvRewind(DB);
		}
		if(KvJumpToKey(DB, "z", true))
		{
			KvSetFloat(DB, "z", origin[2]);
			KvRewind(DB);
		}
		if(KvJumpToKey(DB, "bankWorth", true))
		{
			KvSetNum(DB, "bankWorth", StringToInt(GetBankWorth));
			KvRewind(DB);
		}
		
		KvRewind(DB);
		KeyValuesToFile(DB, BankVaultPath);
		CloseHandle(DB);
		
		bankIndex = EntIndex;
	}
	
	return Plugin_Handled;
}

public Action Command_RobBank(int client, int args)
{
	if(!StrEqual(UD[client].sJob, "Bank Robber"))
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be a {mediumseagreen}Bank Robber{default} to rob banks!");
		return Plugin_Handled;
	}
	
	int curCopsRob = 0;
	for(int i = 0; i <= MaxClients; i++)
	{
		if(UD[i].bGov) curCopsRob++;
	}
	if(curCopsRob != cvarTFRP[CopsToRob].IntValue)
	{
		CPrintToChat(client, "{green}[TFRP]{default} There has to be atleast %d cops on to start a robbery.", cvarTFRP[CopsToRob].IntValue);
		return Plugin_Handled;
	}
	
	if(!RobbingEnabled)
	{
		TFRP_PrintToChat(client, "You must wait to do the next robbery");
		return Plugin_Handled;
	}
	
	int GetBankRob = GetClientAimTarget(client, false);
	if(GetBankRob == bankIndex)
	{
		float ClientOriginRob[3];
		GetClientAbsOrigin(client, ClientOriginRob);
		float originRobBankVault[3];
		GetEntPropVector(bankIndex, Prop_Send, "m_vecOrigin", originRobBankVault);
		if(GetVectorDistance(ClientOriginRob, originRobBankVault) <= 125){
			char RobberName[MAX_NAME_LENGTH];
			GetClientName(client, RobberName, sizeof(RobberName));
			PrintCenterTextAll("%s is robbing a bank!", RobberName); 
			UD[client].isRobbingBank = true;
			CreateTimer(cvarTFRP[BankRobTime].FloatValue, Timer_RobBank, client);
			isBeingRobbed = true;
		}else{
			CPrintToChat(client, "{green}[TFRP]{default} You must be closer to the {mediumseagreen}bank vault {default}to rob it");
		}
	}else{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a {mediumseagreen}bank vault {default}to rob a bank.");
		return Plugin_Handled;
	}
	return Plugin_Handled;
}


public Action Timer_RobBank(Handle timer, int client)
{
	if(!IsClientInGame(client)) return Plugin_Continue;
	if(!isBeingRobbed)
	{
		return Plugin_Continue;
	}
	CPrintToChat(client, "{green}[TFRP]{default} You robbed the bank and recieved {mediumseagreen}%d!", bankWorth);
	UD[client].iCash += bankWorth;
	UD[client].isRobbingBank = false;
	// UpdateCash(client);
	isBeingRobbed = false;
	RobbingEnabled = false;
	CreateTimer(cvarTFRP[RobberyInBetweenTime].FloatValue, ResetBank);
	return Plugin_Continue;
}

public Action ResetBank(Handle timer)
{
	RobbingEnabled = true;
}

// Bank HUD
public Action Timer_BankHUD(Handle timer, int client)
{
	if(!IsClientInGame(client)) return Plugin_Continue;
	if(IsFakeClient(client)) return Plugin_Continue;
	int curLookingAtBank = GetClientAimTarget(client, false);

	// First it has to be a drill

	if(curLookingAtBank == bankIndex)
	{
		float BankVec[3];
    
		GetEntPropVector(curLookingAtBank, Prop_Send, "m_vecOrigin", BankVec);
    
		float ClientBankVec[3];

		GetClientAbsOrigin(client, ClientBankVec);
	
		if(GetVectorDistance(ClientBankVec, BankVec) <= 500)
		{
			char BankHudWorth[32];
			FormatEx(BankHudWorth, sizeof(BankHudWorth), "Money: %d", bankWorth);
			
			SetHudTextParams(-1.0, 0.30, 1.0, 0, 255, 0, 200, 0, 6.0, 0.0, 0.0);
			ShowSyncHudText(client, hHud6, BankHudWorth);
		}
	}
	return Plugin_Continue;
}

public Action BankHudRobbing(Handle timer, int client)
{
	if(!IsClientInGame(client) || !UD[client].isRobbingBank) return Plugin_Continue;

	bankRobHudTime += -1;
	char GetBankRobTime[32];
	FormatEx(GetBankRobTime, sizeof(GetBankRobTime), "Rob Time: %d", bankRobHudTime);
	SetHudTextParams(-1.0, 0.040, 1.0, 100, 255, 100, 225, 0, 0.0, 0.0, 0.0);
	ShowSyncHudText(client, hHud7, "%s", GetBankRobTime);
	
	return Plugin_Continue;
}


// Load bank's position
public void SetBank()
{
	int canCreateBVault = 0;
	
	Handle DB6 = CreateKeyValues("BankVaultPos");
	FileToKeyValues(DB6, BankVaultPath);

	float BankPos[3];

	if(KvJumpToKey(DB6, "x", false))
	{
		BankPos[0] = KvGetFloat(DB6, "x", 0.0);
		KvRewind(DB6);
		canCreateBVault++;
	}
	if(KvJumpToKey(DB6, "y", false))
	{
		BankPos[1] = KvGetFloat(DB6, "y", 0.0);
		KvRewind(DB6);
		canCreateBVault++;
	}
	if(KvJumpToKey(DB6, "z", false))
	{
		BankPos[2] = KvGetFloat(DB6, "z", 0.0);
		KvRewind(DB6);
		canCreateBVault++;
	}
	if(KvJumpToKey(DB6, "bankWorth", true))
	{
		bankWorth = KvGetNum(DB6, "bankWorth", 10000);
		KvRewind(DB6);
		canCreateBVault++;
	}
	
	KvRewind(DB6);
	KeyValuesToFile(DB6, BankVaultPath);
	CloseHandle(DB6);
	
	if(canCreateBVault == 4)
	{
	
		int EntIndex = CreateEntityByName("prop_dynamic_override");

		if(EntIndex != -1 && IsValidEntity(EntIndex))
		{
			DispatchKeyValue(EntIndex, "model", "models/props_lakeside/wood_crate_01.mdl");
			DispatchKeyValueFloat(EntIndex, "solid", 2.0);
			DispatchSpawn(EntIndex);
			TeleportEntity(EntIndex, BankPos, NULL_VECTOR, NULL_VECTOR);
			bankIndex = EntIndex;
			CPrintToChatAll("{green}[TFRP]{default} Created bank.");
		}
	}
	
}

///////////////////
// Doors System //
//////////////////

public void SetDoors()
{
	int findDoorEntity = -1;

	while ((findDoorEntity = FindEntityByClassname(findDoorEntity, "func_door_rotating")) != -1)
	{
		Doors[findDoorEntity] = -1;
		Handle DB6 = CreateKeyValues("Doors");
		FileToKeyValues(DB6, DoorsPath);

		char formFindDoorEntity[8];
		FormatEx(formFindDoorEntity, sizeof(formFindDoorEntity), "%d", findDoorEntity);
		if(KvJumpToKey(DB6, formFindDoorEntity, true))
		{
			int setDoorPriceDef = KvGetNum(DB6, "Price", 250);
			KvSetNum(DB6, "Price", setDoorPriceDef);
			char isGovDoor[8];
			KvGetString(DB6, "GovDoor", isGovDoor, sizeof(isGovDoor), "false");
			if(StrEqual(isGovDoor, "true"))
			{
				Doors[findDoorEntity] = 420;
				AcceptEntityInput(findDoorEntity, "Lock");
			}
			
			KvRewind(DB6);
		}
		KvRewind(DB6);
		KeyValuesToFile(DB6, DoorsPath);
		CloseHandle(DB6);
	}
	
	CPrintToChatAll("{green}[TFRP]{default} Done!");
}

public Action Command_BuyDoor(int client, int args)
{
	
	if(DoorOwnedAmt[client] >= cvarTFRP[MaxDoors].IntValue)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You have reached the max {mediumseagreen}%d{default} doors.", cvarTFRP[MaxDoors].IntValue);
		return Plugin_Handled;
	}
	
	if(!UD[client].bOwnDoors)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You cannot own doors as a {mediumseagreen}%s", UD[client].sJob);
		return Plugin_Handled;
	}
	
	// Get door
	int curLookingDoor = GetClientAimTarget(client, false);
	
	if(curLookingDoor == -1)
	{
		TFRP_PrintToChat(client, "You must be looking at a door!");
		return Plugin_Handled;
	}

	// Get owner of door

	if(Doors[curLookingDoor] == -1)
	{
		// No owner
		int DoorPrice = 250;
		
		Handle DB = CreateKeyValues("Doors");
		FileToKeyValues(DB, DoorsPath);
		
		char GetBuyDoorPrice[8];
		FormatEx(GetBuyDoorPrice, sizeof(GetBuyDoorPrice), "%d", curLookingDoor);
		if(KvJumpToKey(DB, GetBuyDoorPrice, true))
		{
			char GetBuyableDoor[8];
			KvGetString(DB, "Buyable", GetBuyableDoor, sizeof(GetBuyableDoor));
			
			if(StrEqual(GetBuyableDoor,"false"))
			{
				CPrintToChat(client, "{green}[TFRP]{default} You cannot buy this door!");
				KvRewind(DB);
				KvRewind(DB);
				CloseHandle(DB);
				return Plugin_Handled;
			}
			
			DoorPrice = KvGetNum(DB, "Price", 250);
			KvRewind(DB);
		}
		
		KvRewind(DB);
		CloseHandle(DB);
		
		
		if(UD[client].iCash  >= DoorPrice)
		{
			UD[client].iCash -= DoorPrice;
			// UpdateCash(client);
			// The Doors table will always hold the original owner
			Doors[curLookingDoor] = client;
			CPrintToChat(client, "{green}[TFRP]{default} You bought a door for {mediumseagreen}%d", DoorPrice);
			DoorOwnedAmt[client] = DoorOwnedAmt[client] + 1;
			DoorOwners[curLookingDoor][0] = client;
			Action result;
			Call_StartForward(g_tfrp_forwards[3]);
			Call_PushCell(client);
			Call_PushCell(curLookingDoor);
			Call_Finish(result);
		}else{
			CPrintToChat(client, "{green}[TFRP]{default} You need %d to buy this door!", DoorPrice);
		}
	}else if(Doors[curLookingDoor] > 0){
		CPrintToChat(client, "{green}[TFRP]{default} Someone already owns this door!");
	}else{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a door!");
	}
	
	return Plugin_Handled;
}

public Action Command_SellDoor(int client, int args)
{
	int curLookingDoorSell = GetClientAimTarget(client, false);
	
	if(curLookingDoorSell == -1)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a door!");
		return Plugin_Handled;
	}
	
	if(Doors[curLookingDoorSell] == client)
	{
		// Owns the door
		int DoorPrice = 250;
		
		Handle DB = CreateKeyValues("Doors");
		FileToKeyValues(DB, DoorsPath);
		
		char GetSellDoorPrice[8];
		FormatEx(GetSellDoorPrice, sizeof(GetSellDoorPrice), "%d", curLookingDoorSell);
		if(KvJumpToKey(DB, GetSellDoorPrice, true))
		{
			DoorPrice = KvGetNum(DB, "Price", 250);
			KvRewind(DB);
		}
		
		KvRewind(DB);
		CloseHandle(DB);
		
		UD[client].iCash += DoorPrice/2;
		// UpdateCash(client);
		Doors[curLookingDoorSell] = -1;
		DoorOwnedAmt[client] = DoorOwnedAmt[client] - 1;
		for(int i = 0; i <= 4; i++)
		{
			DoorOwners[curLookingDoorSell][i] = 0;
		}
		CPrintToChat(client, "{green}[TFRP]{default} Sold the door for {mediumseagreen}%d", DoorPrice/2);
		Action result;
		Call_StartForward(g_tfrp_forwards[4]);
		Call_PushCell(client);
		Call_PushCell(curLookingDoorSell);
		Call_Finish(result);

	} else if(UD[client].bGov && Doors[curLookingDoorSell] == 420)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You cannot sell government doors!");
	} else if(Doors[curLookingDoorSell] > 0 && Doors[curLookingDoorSell] != client || Doors[curLookingDoorSell] <= -1){
		CPrintToChat(client, "{green}[TFRP]{default} You don't own this door!");
	} else if(Doors[curLookingDoorSell] == 0){
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a door!");
	}
	
	return Plugin_Handled;
	
}

public Action Command_LockDoor(int client, int args)
{
	
	if(!IsPlayerAlive(client))
	{
		CPrintToChat(client, "{green}[TFRP]{default} You cannot lock doors while dead!");
		return Plugin_Handled;
	}

	int curLookingDoorLock = GetClientAimTarget(client, false);

	if(curLookingDoorLock == -1)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a door!");
		return Plugin_Handled;
	}
	
	bool foundOwnerDoor = false;
	
	if(Doors[curLookingDoorLock] == client)
	{
		foundOwnerDoor = true;
	}else{
		for(int i = 0; i <= 4; i++)
		{
			if(DoorOwners[curLookingDoorLock][i] == client)
			{
				foundOwnerDoor = true;
				break;
			}
		}
	}

	if(foundOwnerDoor || Doors[curLookingDoorLock] == 420 && UD[client].bGov)
	{
		// Owns the door
		if(!lockedDoor[curLookingDoorLock])
		{
			AcceptEntityInput(curLookingDoorLock, "Lock");
			lockedDoor[curLookingDoorLock] = true;
			CPrintToChat(client, "{green}[TFRP]{default} Door locked");
			float curDoorLockSound[3];
			GetEntPropVector(curLookingDoorLock, Prop_Send, "m_vecOrigin", curDoorLockSound);
			EmitAmbientSound(DOOR_LOCK_SOUND, curDoorLockSound, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
		}else{
			AcceptEntityInput(curLookingDoorLock, "Unlock");
			lockedDoor[curLookingDoorLock] = false;
			CPrintToChat(client, "{green}[TFRP]{default} Door unlocked");
			float curDoorUnLockSound[3];
			GetEntPropVector(curLookingDoorLock, Prop_Send, "m_vecOrigin", curDoorUnLockSound);
			EmitAmbientSound(DOOR_UNLOCK_SOUND, curDoorUnLockSound, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
		}
	}else if(Doors[curLookingDoorLock] != client && Doors[curLookingDoorLock] > 0 || Doors[curLookingDoorLock] == -1 || Doors[curLookingDoorLock] == 420){
		CPrintToChat(client, "{green}[TFRP]{default} You don't own this door!");
	}else{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a door!");
	}
	return Plugin_Handled;
}

public Action Timer_DoorHUD(Handle timer, int client)
{
	if(!IsClientInGame(client)) return Plugin_Continue;
	if(IsFakeClient(client)) return Plugin_Continue;
	int curLookingAtDoor = GetClientAimTarget(client, false);
	
	if(curLookingAtDoor == -1)
	{
		return Plugin_Continue;
	}

	float DoorVec[3];
    
	GetEntPropVector(curLookingAtDoor, Prop_Send, "m_vecOrigin", DoorVec);
    
	float ClientDoorVec[3];

	GetClientAbsOrigin(client, ClientDoorVec);
	
	if(GetVectorDistance(ClientDoorVec, DoorVec) <= 225)
	{
		if(Doors[curLookingAtDoor] == -1)
		{
			SetHudTextParams(-1.0, 0.30, 1.0, 255, 255, 255, 200, 0, 6.0, 0.0, 0.0);
			ShowHudText(client, 2, "No Owner");
		}else if(Doors[curLookingAtDoor] > 0 && Doors[curLookingAtDoor] < 420){
			char DoorOwnerHudName[MAX_NAME_LENGTH];
			GetClientName(Doors[curLookingAtDoor], DoorOwnerHudName, sizeof(DoorOwnerHudName));
			
			char DoorOwnerHud[32];
			FormatEx(DoorOwnerHud, sizeof(DoorOwnerHud), "%s's Door", DoorOwnerHudName);
			SetHudTextParams(-1.0, 0.30, 1.0, 255, 255, 255, 200, 0, 6.0, 0.0, 0.0);
			ShowHudText(client, 3, DoorOwnerHud);
		}else if(Doors[curLookingAtDoor] == 420){
			// Government door
			SetHudTextParams(-1.0, 0.30, 1.0, 255, 255, 255, 200, 0, 6.0, 0.0, 0.0);
			ShowHudText(client, 3, "Government Officals");
		}
		
	}
	
	return Plugin_Continue;
}

public Action Command_AddGovDoor(int client, int args)
{
	int curLookingGovDoor = GetClientAimTarget(client, false);
	if(Doors[curLookingGovDoor] >= -2 && Doors[curLookingGovDoor] != 420)
	{
		Doors[curLookingGovDoor] = 420;
		// Save the door in file
		Handle DB = CreateKeyValues("Doors");
		FileToKeyValues(DB, DoorsPath);

		char FormatGovDoorKV[8];
		FormatEx(FormatGovDoorKV, sizeof(FormatGovDoorKV), "%d", curLookingGovDoor);
		if(KvJumpToKey(DB, FormatGovDoorKV, true))
		{
			KvSetString(DB, "GovDoor", "true");
			KvRewind(DB);
		}
	
		KvRewind(DB);
		KeyValuesToFile(DB, DoorsPath);
		CloseHandle(DB);

		TFRP_PrintToChat(client, "Added government door");
	}else if(Doors[curLookingGovDoor] == 420)
	{
		CPrintToChat(client, "{green}[TFRP]{default} This door is already government only!");
	} else {
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a door!");
	}
	return Plugin_Handled;
}

public Action Command_RemGovDoor(int client, int args)
{
	int curLookingRemGovDoor = GetClientAimTarget(client, false);
	if(Doors[curLookingRemGovDoor] == 420)
	{
		// Is government door
		Handle DB = CreateKeyValues("Doors");
		FileToKeyValues(DB, DoorsPath);

		char FormatRemGovDoorKV[8];
		FormatEx(FormatRemGovDoorKV, sizeof(FormatRemGovDoorKV), "%d", curLookingRemGovDoor);
		
		if(KvJumpToKey(DB, FormatRemGovDoorKV, true))
		{
			KvSetString(DB, "GovDoor", "false");
			KvRewind(DB);
		}
		
		KeyValuesToFile(DB, DoorsPath);
		CloseHandle(DB);
		Doors[curLookingRemGovDoor] = -1;

		
	}else{
		CPrintToChat(client, "{green}[TFRP]{default} Must be looking at a government door!");
	}
}

public Action Command_GiveKeys(int client, int args)
{
	int GetGiveKeyDoor = GetClientAimTarget(client, false);
	if(GetGiveKeyDoor == -1 || Doors[GetGiveKeyDoor] == 0)
	{
		TFRP_PrintToChat(client, "Must be looking at a {mediumseagreen}door!");
		return Plugin_Handled;
	}
	
	if(Doors[GetGiveKeyDoor] != client)
	{
		TFRP_PrintToChat(client, "You must be the original owner of this door!");
		return Plugin_Handled;
	}

	Handle menuhandle = CreateMenu(MenuCallBackGiveKeys);
	SetMenuTitle(menuhandle, "[TFRP] Give Keys");
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && i != client)
		{
			char GetGiveKeysMenuName[MAX_NAME_LENGTH];
			GetClientName(i, GetGiveKeysMenuName, sizeof(GetGiveKeysMenuName));
			
			char FormatGiveKeysNameIndex[256];
			FormatEx(FormatGiveKeysNameIndex, sizeof(FormatGiveKeysNameIndex), "%d:%s-%d", i, GetGiveKeysMenuName, GetGiveKeyDoor); 
			AddMenuItem(menuhandle, FormatGiveKeysNameIndex, GetGiveKeysMenuName);
		}
	}
		
	SetMenuPagination(menuhandle, 7);
	SetMenuExitButton(menuhandle, true);
	DisplayMenu(menuhandle, client, 250);
	
	return Plugin_Continue;
}

public Action Command_RevokeKeys(int client, int args)
{
	int RemGiveKeyDoor = GetClientAimTarget(client, false);
	if(RemGiveKeyDoor == -1 || Doors[RemGiveKeyDoor] == 0)
	{
		TFRP_PrintToChat(client, "Must be looking at a {mediumseagreen}door!");
		return Plugin_Handled;
	}
	
	if(Doors[RemGiveKeyDoor] != client)
	{
		TFRP_PrintToChat(client, "You must be the original owner of this door!");
		return Plugin_Handled;
	}
	
	Handle menuhandle = CreateMenu(MenuCallBackRemKeys);
	SetMenuTitle(menuhandle, "[TFRP] Revoke Keys");
	for(int i = 0; i <= 4; i++)
	{
		if(i != 0 && DoorOwners[RemGiveKeyDoor][i] > 0)
		{
			if(IsClientInGame(DoorOwners[RemGiveKeyDoor][i]))
			{
				char GetMenuNameRemKeys[MAX_NAME_LENGTH];
				GetClientName(DoorOwners[RemGiveKeyDoor][i], GetMenuNameRemKeys,sizeof(GetMenuNameRemKeys));
				
				char FormatRemKeysIndexName[256];
				FormatEx(FormatRemKeysIndexName, sizeof(FormatRemKeysIndexName), "%d:%s-%d", DoorOwners[RemGiveKeyDoor][i], GetMenuNameRemKeys, RemGiveKeyDoor); 
				AddMenuItem(menuhandle, FormatRemKeysIndexName, GetMenuNameRemKeys);

			}
		}
	}
		
	SetMenuPagination(menuhandle, 7);
	SetMenuExitButton(menuhandle, true);
	DisplayMenu(menuhandle, client, 250);
	
	return Plugin_Continue;
}

public Action LockpickTimer(Handle timer, int curDoorLockpick)
{	
	int lockpicker = isLockpicking[curDoorLockpick];
	if(!UD[lockpicker].bLockpicking) return Plugin_Continue;
	AcceptEntityInput(curDoorLockpick, "Unlock");
	lockedDoor[curDoorLockpick] = false;
	CPrintToChat(lockpicker, "{green}[TFRP]{default} Lockpicking done");
	isLockpicking[curDoorLockpick] = 0;
	Doors[curDoorLockpick] = 0;
	return Plugin_Continue;
}

public Action LockpickMove(Handle timer, int curDoorLockpickMove)
{
	
	int lockpickerMove = isLockpicking[curDoorLockpickMove];
	if(!UD[lockpickerMove].bLockpicking) return Plugin_Continue;
	
	float GetLockpickerVecMove[3];
	GetClientAbsOrigin(lockpickerMove, GetLockpickerVecMove);
	
	float GetLockpickerVecDoor[3];
	GetEntPropVector(curDoorLockpickMove, Prop_Send, "m_vecOrigin", GetLockpickerVecDoor);
	
	if(GetVectorDistance(GetLockpickerVecMove, GetLockpickerVecDoor) > 275)
	{
		isLockpicking[curDoorLockpickMove] = 0;
		UD[lockpickerMove].bLockpicking = false;
		CPrintToChat(lockpickerMove, "{green}[TFRP]{default} Canceled lockpicking because you moved away from the door! Returned lockpick");
		GiveItem(lockpickerMove, "Lockpick", 1);
	}
	return Plugin_Continue; 
}


public int Lockpick(int client)
{
	int curLookingLockpickDoor = GetClientAimTarget(client, false);

	if(isLockpicking[curLookingLockpickDoor] > 0)
	{
		CPrintToChat(client, "{green}[TFRP]{default} This door is already being lockpicked!");
		return 0;
	}

	if(Doors[curLookingLockpickDoor] == 0)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a door!");
		return 0;
	}

	if(Doors[curLookingLockpickDoor] == -1)
	{
		CPrintToChat(client, "{green}[TFRP]{default} Nobody owns this door!");
		return 0;
	}
	if(Doors[curLookingLockpickDoor] > 0)
	{
		CPrintToChat(client, "{green}[TFRP]{default} Lockpicking...");
		isLockpicking[curLookingLockpickDoor] = client;
		UD[client].bLockpicking = true;
		GiveItem(client, "Lockpick", -1);
		CreateTimer(cvarTFRP[LockpickingTime].FloatValue, LockpickTimer, curLookingLockpickDoor);
		CreateTimer(0.1, LockpickMove, curLookingLockpickDoor, TIMER_REPEAT);
		return 0;	
	}
	
	return 0;
}

public Action Command_RemoveBuyableDoor(int client, int args)
{
	if(!IsClientInGame(client) || client <= 0) return Plugin_Handled;
	
	int GetDoorRemBuy = GetClientAimTarget(client, false);
	
	if(GetDoorRemBuy <= -1)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a door!");
		return Plugin_Handled;
	}
	
	if(Doors[GetDoorRemBuy] == 0)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a door!");
		return Plugin_Handled;
	}
	
	
	Handle DB = CreateKeyValues("DoorsPath");
	FileToKeyValues(DB, DoorsPath);
	
	char GetDoorRemBuyString[8];
	FormatEx(GetDoorRemBuyString, sizeof(GetDoorRemBuyString), "%d", GetDoorRemBuy);
	if(KvJumpToKey(DB, GetDoorRemBuyString, false))
	{
		Doors[GetDoorRemBuy] = -2;
		KvSetString(DB, "Buyable", "false");
		AcceptEntityInput(GetDoorRemBuy, "Unlock");
		CPrintToChat(client, "{green}[TFRP]{default} Door is no longer buyable. You can reset this with sm_addbuyabledoor");
		KvRewind(DB);
		
	}else{
		CPrintToChat(client, "{green}[TFRP]{red} ERROR: {default}Couldn't find door in file. Try contacting a developer");
	}
	
	KvRewind(DB);
	
	KeyValuesToFile(DB, DoorsPath);
	CloseHandle(DB);
	
	return Plugin_Handled;
}

public Action Command_MakeBuyableDoor(int client, int args)
{
	if(!IsClientInGame(client) || client <= 0) return Plugin_Handled;
	
	int GetDoorAddBuy = GetClientAimTarget(client, false);
	
	if(GetDoorAddBuy == -1 || Doors[GetDoorAddBuy] == 0)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a door!");
		return Plugin_Handled;
	}
	
	Doors[GetDoorAddBuy] = -1;
	
	Handle DB = CreateKeyValues("DoorsPath");
	FileToKeyValues(DB, DoorsPath);
	
	char GetDoorRemBuyString[8];
	FormatEx(GetDoorRemBuyString, sizeof(GetDoorRemBuyString), "%d", GetDoorAddBuy);
	if(KvJumpToKey(DB, GetDoorRemBuyString, false))
	{
		KvSetString(DB, "Buyable", "true");
		CPrintToChat(client, "{green}[TFRP]{default} Door is buyable now");
		KvRewind(DB);
		
	}else{
		CPrintToChat(client, "{green}[TFRP]{red} ERROR: {default}Couldn't find door in file. Try contacting a developer");
	}
	
	KvRewind(DB);
	
	KeyValuesToFile(DB, DoorsPath);
	CloseHandle(DB);
	
	return Plugin_Continue;
}

///////////////
// Printers //
//////////////
public int AddPrinter(int client, int printerIndex, char[] Tier)
{
	
	if(StrEqual(Tier, "Bronze"))
	{
		SDKHookEx(printerIndex, SDKHook_OnTakeDamage, OnTakeDamagePrinter);
		PrinterMoney[printerIndex] = 0;
		PrinterTier[printerIndex] = 1;
		CreateTimer(cvarTFRP[PrintTimeT1].FloatValue, Timer_PrinterTier1, printerIndex, TIMER_REPEAT);
		isPrinter[printerIndex] = true; 
		return 0;
		
	}else if(StrEqual(Tier, "Silver"))
	{
		SDKHookEx(printerIndex, SDKHook_OnTakeDamage, OnTakeDamagePrinter);
		PrinterMoney[printerIndex] = 0;
		PrinterTier[printerIndex] = 2;
		CreateTimer(cvarTFRP[PrintTimeT2].FloatValue, Timer_PrinterTier2, printerIndex, TIMER_REPEAT);
		isPrinter[printerIndex] = true; 
		return 0;
	}else if(StrEqual(Tier, "Gold"))
	{
		SDKHookEx(printerIndex, SDKHook_OnTakeDamage, OnTakeDamagePrinter);
		PrinterMoney[printerIndex] = 0;
		PrinterTier[printerIndex] = 3;
		CreateTimer(cvarTFRP[PrintTimeT3].FloatValue, Timer_PrinterTier3, printerIndex, TIMER_REPEAT);
		isPrinter[printerIndex] = true; 	
		return 0;

	}
	return 0;
}


public Action OnTakeDamagePrinter(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(attacker > MaxClients) return Plugin_Continue;
	
	if(damagetype & DMG_BLAST){
		DestroyPrinter(victim);
		return Plugin_Continue;
	}
	float OnTakeDmgPrinterVic[3];
	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", OnTakeDmgPrinterVic);
	
	float OnTakeDmgTier1Att[3];
	GetClientAbsOrigin(attacker, OnTakeDmgTier1Att);
	
	if(GetVectorDistance(OnTakeDmgTier1Att, OnTakeDmgPrinterVic) >200) return Plugin_Continue;
	
	if(PrinterMoney[victim] > 0)
	{
		UD[attacker].iCash += PrinterMoney[victim];
		// UpdateCash(attacker);
		CPrintToChat(attacker, "{green}[TFRP]{default} You collected {mediumseagreen}%d {default} from the {mediumseagreen}printer", PrinterMoney[victim]);
		PrinterMoney[victim] = 0;
	}else{
		CPrintToChat(attacker, "{green}[TFRP]{default} No money has been printed yet!");
	}
	return Plugin_Continue;
}

// Bronze (tier 1) printer

public Action Timer_PrinterTier1(Handle timer, int printerIndex)
{
	if(EntOwners[printerIndex] == 0) return Plugin_Continue;
	PrinterMoney[printerIndex] = PrinterMoney[printerIndex] + cvarTFRP[PrintT1Money].IntValue;
	float printerPosTimer1[3];
	GetEntPropVector(printerIndex, Prop_Send, "m_vecOrigin", printerPosTimer1);
	EmitAmbientSound(PRINTER_PRINTED_SOUND, printerPosTimer1, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
	return Plugin_Continue;
}

public Action Timer_PrinterTier2(Handle timer, int printerIndex)
{
	if(EntOwners[printerIndex] == 0) return Plugin_Continue;
	
	PrinterMoney[printerIndex] = PrinterMoney[printerIndex] + cvarTFRP[PrintT2Money].IntValue;
	float printerPosTimer1[3];
	GetEntPropVector(printerIndex, Prop_Send, "m_vecOrigin", printerPosTimer1);
	EmitAmbientSound(PRINTER_PRINTED_SOUND, printerPosTimer1, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
	return Plugin_Continue;
}

// Gold (Tier 3) printer
public Action Timer_PrinterTier3(Handle timer, int printerIndex)
{
	if(EntOwners[printerIndex] == 0) return Plugin_Continue;
	PrinterMoney[printerIndex] = PrinterMoney[printerIndex] + cvarTFRP[PrintT3Money].IntValue;
	float printerPosTimer1[3];
	GetEntPropVector(printerIndex, Prop_Send, "m_vecOrigin", printerPosTimer1);
	EmitAmbientSound(PRINTER_PRINTED_SOUND, printerPosTimer1, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
	return Plugin_Continue;
}


public Action Timer_PrinterHud(Handle timer, int client)
{
	if(!IsClientInGame(client)) return Plugin_Continue;
	int GetPrinterLook = GetClientAimTarget(client, false);
	
	if(GetPrinterLook == -1) return Plugin_Continue;
	
	float GetPrinterLookPos[3];
	GetEntPropVector(GetPrinterLook, Prop_Send, "m_vecOrigin", GetPrinterLookPos);
	
	float GetPrinterLookClientPos[3];
	GetClientAbsOrigin(client, GetPrinterLookClientPos);
	
	if(GetVectorDistance(GetPrinterLookClientPos, GetPrinterLookPos) >200) return Plugin_Continue;
	
	if(EntOwners[GetPrinterLook] > 0 && isPrinter[GetPrinterLook])
	{
		char PrinterMoneyHud[32];
		FormatEx(PrinterMoneyHud, sizeof(PrinterMoneyHud), "Money: %d", PrinterMoney[GetPrinterLook]);
		if(PrinterTier[GetPrinterLook]==1)
		{
			SetHudTextParams(-1.0, 0.30, 1.0, 224, 155, 22, 200, 0, 6.0, 0.0, 0.0);
		}else if(PrinterTier[GetPrinterLook]==2)
		{
			SetHudTextParams(-1.0, 0.30, 1.0, 193, 192, 191, 200, 0, 6.0, 0.0, 0.0);
		}else{
			SetHudTextParams(-1.0, 0.30, 1.0, 255, 242, 71, 200, 0, 6.0, 0.0, 0.0);
		}
		ShowHudText(client, 3, PrinterMoneyHud);
	}

	return Plugin_Continue;
}

public int DestroyPrinter(int printerIndex)
{
	PrinterMoney[printerIndex] = 0;
	CPrintToChat(EntOwners[printerIndex], "{green}[TFRP]{default} Your printer was destroyed!");
	EntOwners[printerIndex] = 0;
	AcceptEntityInput(printerIndex, "kill");
	RemoveEdict(printerIndex);
	isPrinter[printerIndex] = false; 
	PrinterTier[printerIndex] = 0;
	return 0;
}

// Hitman

public Action Command_PlaceHit(int client, int args)
{
	int GetHitmanLook = GetClientAimTarget(client, true);
	
	if(GetHitmanLook == -1)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a {mediumseagreen}Hitman!");
		return Plugin_Handled;
	}
	
	if(StrEqual(UD[GetHitmanLook].sJob, "Hitman"))
	{
		
		if(Hits[GetHitmanLook] > 0)
		{
			CPrintToChat(client, "{green}[TFRP]{default} This Hitman already has an active hit!");
			return Plugin_Handled;
		}
		
		Handle menuhandle = CreateMenu(MenuCallBackHitman);
		SetMenuTitle(menuhandle, "[TFRP] Hitman Menu");
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && i != GetHitmanLook && i != client)
			{
				char GetPlayerHitmanMenu[MAX_NAME_LENGTH];
				GetClientName(i, GetPlayerHitmanMenu, sizeof(GetPlayerHitmanMenu));
				
				char GetPlayerHitmanMenuFormat[48];
				FormatEx(GetPlayerHitmanMenuFormat, sizeof(GetPlayerHitmanMenuFormat), "%s:%d", GetPlayerHitmanMenu, GetHitmanLook);
				AddMenuItem(menuhandle, GetPlayerHitmanMenuFormat, GetPlayerHitmanMenu);
			}
		}
		
		SetMenuPagination(menuhandle, 7);
		SetMenuExitButton(menuhandle, true);
		DisplayMenu(menuhandle, client, 250);
		
	}else{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a {mediumseagreen}Hitman!");
	}
	return Plugin_Handled;
}


public int DeleteHit(int client)
{
	char getClientHitDel[MAX_NAME_LENGTH];
	GetClientName(client, getClientHitDel, sizeof(getClientHitDel));
	
	char getHitmanNameDel[MAX_NAME_LENGTH];
	GetClientName(client, getHitmanNameDel, sizeof(getHitmanNameDel));
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(Hits[client] > 0)
		{
			
			char GetHitDelVictim[MAX_NAME_LENGTH];
			GetClientName(Hits[client], GetHitDelVictim, sizeof(GetHitDelVictim));
			
			CPrintToChatAll("{yellow}[TFRP ADVERT]{default} The hit on {mediumseagreen}%s{default} was canceled because the hitman left!", GetHitDelVictim);

			Hits[client] = 0;
			
		}
		if(Hits[i] == client)
		{
			char GetHitVictimNameDel[MAX_NAME_LENGTH];
			GetClientName(client, GetHitVictimNameDel, sizeof(GetHitVictimNameDel));
			CPrintToChatAll("{yellow}[TFRP ADVERT]{default} The hit on {mediumseagreen}%s{default} was canceled because they left!", GetHitVictimNameDel);
			Hits[i] = 0;
			
		}
	}
	return 0;
}

// Lottery
public Action Command_SetLottery(int client, int args)
{
	
	if(!StrEqual(UD[client].sJob, "Mayor"))
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be {mediumseagreen}Mayor{default} to start the lottery!");
		return Plugin_Handled;
	}
	
	if(!lotAvaliable)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must wait before starting another lottery!");
		return Plugin_Handled;
	}
	
	if(args != 1)
	{
		CPrintToChat(client, "{green}[TFRP]{default} Usage: sm_setlottery <amount>");
		return Plugin_Handled;
	}
	
	
	char GetLotArg1[32];
	GetCmdArg(1, GetLotArg1, sizeof(GetLotArg1));
	LotAmt = StringToInt(GetLotArg1);
	
	if(LotAmt > cvarTFRP[MaxLot].IntValue)
	{
		CPrintToChat(client, "{green}[TFRP]{default} The max a lottery can be worth is {mediumseagreen}%d!", cvarTFRP[MaxLot].IntValue);
		return Plugin_Handled;
	}
	
	if(LotAmt < 2)
	{
		CPrintToChat(client, "{green}[TFRP]{default} Lottery has to be over {mediumseagreen}1!");
		return Plugin_Handled;
	}
	
	if(UD[client].iCash < LotAmt)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You do not have {mediumseagreen}%d!", LotAmt);
		return Plugin_Handled;
	}
	
	lotteryStarter = client;
	isLottery = true;
	lotAvaliable = false;
	CPrintToChatAll("{yellow}[TFRP ADVERT]{default} A lottery has started for {mediumseagreen}%d!", LotAmt);
	CreateTimer(cvarTFRP[LotTime].FloatValue, Timer_Lottery, client);
	return Plugin_Handled;
}

public Action Timer_LotteryHud(Handle timer, int client)
{
	if(!IsClientInGame(client)) return Plugin_Continue;
	if(IsFakeClient(client)) return Plugin_Continue;
	if(!isLottery) return Plugin_Continue;
	
	char LotteryHud[32];
	FormatEx(LotteryHud, sizeof(LotteryHud), "Lottery: %d", LotAmt);
	SetHudTextParams(1.0, 0.010, 1.0, 120, 20, 21, 200, 0, 6.0, 0.0, 0.0);
	ShowSyncHudText(client, hHud4, "%s", LotteryHud);
	return Plugin_Continue;
}

public Action Timer_Lottery(Handle timer, int client)
{
	if(!isLottery) return Plugin_Continue;
	
	bool foundLotWinner = false;
	
	int GetRandomLot = 0;
	
	while(!foundLotWinner)
	{
		GetRandomLot = GetRandomInt(0, MaxClients);
		if(UD[GetRandomLot].bInLot) foundLotWinner = true;
	}

	UD[GetRandomLot].iCash += LotAmt;
	// UpdateCash(GetRandomLot);
	
	char LotWinnerName[MAX_NAME_LENGTH];
	GetClientName(GetRandomLot, LotWinnerName, sizeof(LotWinnerName));
	
	CPrintToChatAll("{green}[TFRP]{goldenrod}%s{default} won the lottery and won {mediumseagreen}%d!", LotWinnerName, LotAmt);

	for(int i = 0; i <= MaxClients; i++)
	{
		UD[i].bInLot = false;
	}
	
	LotAmt = 0;
	lotteryStarter = 0;
	isLottery = false;
	CreateTimer(cvarTFRP[TimeBetweenLot].FloatValue, Timer_LotteryReset);
	
	return Plugin_Continue;
}

public Action Timer_LotteryReset(Handle timer)
{
	lotAvaliable = true;
}

public Action Command_JoinLottery(int client, int args)
{
	if(!isLottery)
	{
		CPrintToChat(client, "{green}[TFRP]{default} There is no lottery running right now");
		return Plugin_Handled;
	}
	
	if(client == lotteryStarter)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You cannot join a lottery you started!");
		return Plugin_Handled;
	}
	
	UD[client].iCash -= LotAmt/2;
	UD[lotteryStarter].iCash += LotAmt/2;
	UD[client].bInLot = true;

	// UpdateCash(client);
	// UpdateCash(lotteryStarter);
	
	return Plugin_Handled;
}

public int CancelLottery()
{
	for(int i = 0; i <= MAXPLAYERS; i++)
	{
		if(UD[i].bInLot)
		{
			UD[i].iCash += LotAmt;
			// UpdateCash(i);
			CPrintToChat(i, "{green}[TFRP]{default} You were refunded{mediumseagreen} %d{default} because the lottery was canceled");
		}
		
		UD[i].bInLot = false;
	}

	isLottery = false;
	LotAmt = 0;
	lotteryStarter = 0;
	
	return 0;
}

// Laws
public Action Command_Laws(int client, int args)
{
	CPrintToChat(client, "{green}[TFRP]{default} Laws: ");
	
	bool foundLaws = false;
	
	for(int i = 0; i <= 9; i++)
	{
		if(!StrEqual(Laws[i], "NO_LAW")) 
		{
			PrintToChat(client, "%d. %s", i + 1, Laws[i]);
			foundLaws = true;
		}
	}
	if(!foundLaws)
	{
		CPrintToChat(client, "{green}[TFRP]{default} No laws have been set!");
	}
	return Plugin_Handled;
}

public Action Command_AddLaw(int client, int args)
{
	if(!StrEqual(UD[client].sJob, "Mayor"))
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be {mediumseagreen}Mayor{default} to add laws!");
		return Plugin_Handled;
	}
	
	bool foundEmptyLaw = false;
	char AddLawStr[48];
	GetCmdArgString(AddLawStr, sizeof(AddLawStr));
	
	for(int i = 0; i <= 9; i++)
	{
		if(StrEqual(Laws[i], "NO_LAW"))
		{
			Laws[i] = AddLawStr;
			CPrintToChat(client, "{green}[TFRP]{default} Added law!");
			foundEmptyLaw = true;
			break;
		}
	}

	if(!foundEmptyLaw)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You reached the max amount of laws!");
		return Plugin_Handled;
	}
	
	return Plugin_Handled;
	
}

public Action Command_DeleteLaw(int client, int args)
{
	if(!StrEqual(UD[client].sJob, "Mayor"))
	{
		CPrintToChat(client, "{green}[TFRP]{default} Your job must be {mediumseagreen}Mayor{default} to delete laws!");
		return Plugin_Handled;
	}
	
	if(args != 1)
	{
		CPrintToChat(client, "{green}[TFRP]{default} Usage: sm_deletelaw <law #>");
		return Plugin_Handled;
	}
	
	char GetDelLawStr[32];
	GetCmdArg(1, GetDelLawStr, sizeof(GetDelLawStr));
	int curLawDel = StringToInt(GetDelLawStr) - 1;

	if(!StrEqual(Laws[curLawDel], "NO_LAW"))
	{
		Laws[curLawDel] = "NO_LAW";
		CPrintToChat(client, "{green}[TFRP]{default} Removed law");
	}else{
		CPrintToChat(client, "{green}[TFRP]{default} Law doesn't exist!");
	}
	
	int curLawNum = -1;
	for(int i = 0; i <= 9; i++)
	{
		if(!StrEqual(Laws[i], "NO_LAW"))
		{
			curLawNum++;
			Laws[curLawNum] = Laws[i];
			if(curLawNum != i) Laws[i] = "NO_LAW";
		}
	}
	
	return Plugin_Handled;
}

// Battering ram
public Action Command_Ram(int client, int args)
{
	if(!UD[client].bGov)
	{
		CPrintToChat(client, "{green}[TFRP]{default} Only police can use the battering ram!");
		return Plugin_Handled;
	}
	
	int GetDoorRam = GetClientAimTarget(client, false);
	if(GetDoorRam == -1)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a door!");
		return Plugin_Handled;
	}
	
	if(Doors[GetDoorRam] == -1)
	{
		CPrintToChat(client, "{green}[TFRP]{default} Nobody owns this door!");
		return Plugin_Handled;
	}
	
	if(UD[Doors[GetDoorRam]].bHasWarrent)
	{
		AcceptEntityInput(GetDoorRam, "Unlock");
	}else{
		CPrintToChat(client, "{green}[TFRP]{default} Owner of door doesn't have a warrant!");
	}
	
	return Plugin_Handled;
}

// Warrants

public Action Command_SetWarrant(int client, int args)
{
	if(!StrEqual(UD[client].sJob, "Mayor") && !StrEqual(UD[client].sJob, "Police Chief"))
	{
		CPrintToChat(client, "{green}[TFRP]{default} Only the Police Chief and Mayor can set warrants!");
		return Plugin_Handled;
	}
	
	Handle menuhandle = CreateMenu(MenuCallBackWarrant);
	SetMenuTitle(menuhandle, "[TFRP] Warrant Menu");
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !UD[i].bGov)
		{
			char GetPlayerSetwarrant[MAX_NAME_LENGTH];
			GetClientName(i, GetPlayerSetwarrant, sizeof(GetPlayerSetwarrant));
			
			AddMenuItem(menuhandle, GetPlayerSetwarrant, GetPlayerSetwarrant);
		}
	}
	SetMenuPagination(menuhandle, 7);
	SetMenuExitButton(menuhandle, true);
	DisplayMenu(menuhandle, client, 250);
	
	return Plugin_Handled;
}

public int SetWarrantHud(int client)
{
	char GetWarrantName[MAX_NAME_LENGTH];
	GetClientName(client, GetWarrantName, sizeof(GetWarrantName));
	CPrintToChatAll("{green}[TFRP]{default} A warrant has been set out for %s!", GetWarrantName);
	
	return 0;
}

public Action Timer_Warrant(Handle timer, int client)
{
	
	UD[client].bHasWarrent = false;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			char GetWarrantNameHudRem[MAX_NAME_LENGTH];
			GetClientName(client, GetWarrantNameHudRem, sizeof(GetWarrantNameHudRem));
			
			char WarrantHudRem[32];
			FormatEx(WarrantHudRem, sizeof(WarrantHudRem), "The warrant on %s expired", GetWarrantNameHudRem);
			SetHudTextParams(-1.0, 0.070, 8.0, 255, 79, 79, 200, 0, 6.0, 0.0, 0.0);
			ShowSyncHudText(i, hHud9, "%s", WarrantHudRem);
		}
	}
	
}

// Area Voice Chat
public Action Timer_GetChatClients(Handle timer, int client)
{
	if(!IsClientInGame(client)) return Plugin_Continue;
	
	float GetClientAngChat[3];
	GetClientAbsOrigin(client, GetClientAngChat);
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			float GetClientAngChatOther[3];
			GetClientAbsOrigin(i, GetClientAngChatOther);
		
			if(GetVectorDistance(GetClientAngChat, GetClientAngChatOther) <= 1000)
			{
				// Unmute them if they're not in range
				SetListenOverride(client, i, Listen_Yes);
			}else{
				// Mute them if they're out of range
				SetListenOverride(client, i, Listen_No);
			}
		}
	}
	return Plugin_Continue;
}

// Admin Teleportation

public Action Command_Bring(int client, int args)
{
	if(client == 0)
	{
		PrintToServer("[TFRP] Cannot run command from console!");
		return Plugin_Handled;
	}

	if (!args)
	{
		ReplyToCommand(client, "[SM] Usage: sm_bring <user>");
		return Plugin_Handled;
	}

	char sTarget[32], sName[32];
	int iTargetList[MAXPLAYERS];
	bool tn_is_ml;
	GetCmdArg(1, sTarget, sizeof(sTarget));
	int iTargetCount = ProcessTargetString(sTarget, client, iTargetList, MAXPLAYERS, 0, sName, sizeof(sName), tn_is_ml);

	if (iTargetCount != 1)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	if (client == iTargetList[0])
	{
		ReplyToCommand(client, "[SM] You cannot target yourself!");
		return Plugin_Handled;
	}

	if (!IsFakeClient(iTargetList[0]) && IsClientInGame(iTargetList[0]))
	{
		char sTargetName[32];
		GetClientName(iTargetList[0], sTargetName, sizeof(sTargetName));
		if (!IsPlayerAlive(iTargetList[0]))
		{
			ReplyToCommand(client, "[SM] Target must be alive to be brought!");
			return Plugin_Handled;
		}
		else
		{
			float BringClientOrigin[3];
			GetClientAbsOrigin(client, BringClientOrigin);
			TeleportEntity(iTargetList[0], BringClientOrigin, NULL_VECTOR, NULL_VECTOR);
			char GetBringerName[MAX_NAME_LENGTH];
			GetClientName(client, GetBringerName, sizeof(GetBringerName));
			TFRP_PrintToChat(iTargetList[0], "{goldenrod}%s {default}brought you to them", GetBringerName);
			TFRP_PrintToChat(client, "You brought {goldenrod}%s", sTargetName);
			return Plugin_Handled;
		}
	}
	
	ReplyToCommand(client, "[SM] Target is no longer in-game or is a Fake Client!");
	return Plugin_Handled;	
}

public Action Command_Goto(int client, int args)
{
	if(client == 0)
	{
		PrintToServer("[TFRP] Cannot run command from console!");
		return Plugin_Handled;
	}

	if (!args)
	{
		ReplyToCommand(client, "[SM] Usage: sm_goto <user>");
		return Plugin_Handled;
	}

	char sTarget[32], sName[32];
	int iTargetList[MAXPLAYERS];
	bool tn_is_ml;
	GetCmdArg(1, sTarget, sizeof(sTarget));
	int iTargetCount = ProcessTargetString(sTarget, client, iTargetList, MAXPLAYERS, 0, sName, sizeof(sName), tn_is_ml);

	if (iTargetCount != 1)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	if (client == iTargetList[0])
	{
		ReplyToCommand(client, "[SM] You cannot target yourself!");
		return Plugin_Handled;
	}

	if (!IsFakeClient(iTargetList[0]) && IsClientInGame(iTargetList[0]))
	{
		char sTargetName[32];
		GetClientName(iTargetList[0], sTargetName, sizeof(sTargetName));
		if (!IsPlayerAlive(iTargetList[0]))
		{
			ReplyToCommand(client, "[SM] Target must be alive to be brought!");
			return Plugin_Handled;
		}
		else
		{
			float BringClientOrigin[3];
			GetClientAbsOrigin(iTargetList[0], BringClientOrigin);
			TeleportEntity(client, BringClientOrigin, NULL_VECTOR, NULL_VECTOR);
			char GetBringerName[MAX_NAME_LENGTH];
			GetClientName(client, GetBringerName, sizeof(GetBringerName));
			TFRP_PrintToChat(client, "You went to {goldenrod}%s", sTargetName);
			return Plugin_Handled;
		}
	}
	
	ReplyToCommand(client, "[SM] Target is no longer in-game or is a Fake Client!");
	return Plugin_Handled;
}

public Action Command_Teleport(int client, int args)
{
}

//Full credits to Drixevel (SourceMod shop plugin) (Designed for handles)
stock bool ClearArray2(Handle hGlobalArray)
{
	if (hGlobalArray != null)
	{
		for (int i = 0; i < GetArraySize(hGlobalArray); i++)
		{
			Handle hArray = GetArrayCell(hGlobalArray, i);
			
			if (hArray != null)
			{
				CloseHandle(hArray);
				hArray = null;
			}
		}
		
		ClearArray(hGlobalArray);
		
		return true;
	}
	
	return false;
}

// Rotating Ents //
public Action Command_Rotate(int client, int args)
{
	int getRotateEnt = GetClientAimTarget(client, false);
	if(getRotateEnt == -1)
	{
		TFRP_PrintToChat(client, "You must be looking at a spawned entity!");
		return Plugin_Handled;
	}
	if(EntOwners[getRotateEnt] == client)
	{
		char newYaw[32];
		GetCmdArg(1, newYaw, sizeof(newYaw));
	
		float newAngles[3];
		GetEntPropVector(getRotateEnt, Prop_Data, "m_angRotation", newAngles);
		newAngles[1] = StringToFloat(newYaw);

		TeleportEntity(getRotateEnt, NULL_VECTOR, newAngles, NULL_VECTOR); 
		
		return Plugin_Handled;
	}else{
		TFRP_PrintToChat(client, "You don't own this entity!");
		return Plugin_Handled;
	}
}

// Bonk!
// After reading up the TF2 wiki and inspecting the model, these are the ingredients that I know of
// Ingredients: 9kg of Sugar, Radiation (Caesium), water

public int AddWaterBonk(int client)
{
	int getBonkMixer = GetClientAimTarget(client, false);
	if(!StrEqual(EntItems[getBonkMixer], "Bonk Mixer"))
	{
		TFRP_PrintToChat(client, "You must be looking at a {mediumseagreen}Bonk Mixer");
		return 0;
	}
	
	BonkMixers[getBonkMixer].BonkWater += 2;
	TFRP_PrintToChat(client, "Added {mediumseagreen}200ml of Carbonated Water{default} to the {mediumseagreen}Bonk Mixer");
	GiveItem(client, "Carbonated Water", -1);
	
	CheckStartBonk(getBonkMixer);
	
	return 0;
}

public int AddCaesiumBonk(int client)
{
	int getBonkMixer = GetClientAimTarget(client, false);
	if(!StrEqual(EntItems[getBonkMixer], "Bonk Mixer"))
	{
		TFRP_PrintToChat(client, "You must be looking at a {mediumseagreen}Bonk Mixer");
		return 0;
	}
	
	BonkMixers[getBonkMixer].BonkCaesium++;
	TFRP_PrintToChat(client, "Added {mediumseagreen}Caesium{default} to the {mediumseagreen}Bonk Mixer");
	GiveItem(client, "Caesium", -1);
	
	CheckStartBonk(getBonkMixer);
	
	return 0;
}

public int AddSugarBonk(int client)
{
	int getBonkMixer = GetClientAimTarget(client, false);
	if(!StrEqual(EntItems[getBonkMixer], "Bonk Mixer"))
	{
		TFRP_PrintToChat(client, "You must be looking at a {mediumseagreen}Bonk Mixer");
		return 0;
	}
	
	BonkMixers[getBonkMixer].BonkSugar++;
	TFRP_PrintToChat(client, "Added {mediumseagreen}9kg of Sugar{default} to the {mediumseagreen}Bonk Mixer");
	GiveItem(client, "Sugar", -1);
	
	CheckStartBonk(getBonkMixer);
	
	return 0;
}

public int CheckStartBonk(int BonkMixer)
{
	if(BonkMixers[BonkMixer].BonkWater < 1 || BonkMixers[BonkMixer].BonkCaesium < 1 || BonkMixers[BonkMixer].BonkSugar < 1) return 0;
	
	BonkMixers[BonkMixer].BonkWater += -1;
	BonkMixers[BonkMixer].BonkCaesium += -1;
	BonkMixers[BonkMixer].BonkSugar += -1;
	
	CreateTimer(cvarTFRP[BonkBrewTime].FloatValue, Timer_BonkBrew, BonkMixer);
	return 0;
}

public Action Timer_BonkBrew(Handle timer, int BonkMixer)
{
	if(!StrEqual(EntItems[BonkMixer], "Bonk Mixer")) return Plugin_Continue;
	
	// Canner must be next to mixer
	float BonkMixerPos[3];
	GetEntPropVector(BonkMixer, Prop_Data, "m_vecOrigin", BonkMixerPos);
	
	bool foundMixer = false;
	
	for(int i = 0; i <= 2047; i++)
	{
		if(StrEqual(EntItems[i], "Bonk Canner"))
		{
			float GetCannerPos[3];
			GetEntPropVector(i, Prop_Data, "m_vecOrigin", GetCannerPos);
			if(GetVectorDistance(BonkMixerPos, GetCannerPos) <= 200)
			{
				EmitAmbientSound(BONK_CANNER_GOT_BONK_SOUND, GetCannerPos, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
				BonkCanners[i].BonkInCanner++;
				
				CreateTimer(cvarTFRP[BonkCanTime].FloatValue, Timer_BonkCanTime, i);
				
				foundMixer = true;
				break;
			}
		}
	}
	
	if(!foundMixer)
	{
		EmitAmbientSound(TFRP_ERROR_SOUND, BonkMixerPos, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
		TFRP_PrintToChat(EntOwners[BonkMixer], "Your {mediumseagreen}Bonk Mixer{default} made Bonk, but no {mediumseagreen}Bonk Canner{default} was found!");
	}
	
	return Plugin_Continue;
}

public Action Timer_BonkCanTime(Handle timer, int BonkCanner)
{
	if(!StrEqual(EntItems[BonkCanner], "Bonk Canner")) return Plugin_Continue;
	
	float BonkCannerPos[3];
	GetEntPropVector(BonkCanner, Prop_Data, "m_vecOrigin", BonkCannerPos);
	
	BonkCanners[BonkCanner].BonkCans++;
	EmitAmbientSound(BONK_CANNER_CANNED_BONK_SOUND, BonkCannerPos, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
	
	return Plugin_Continue;
}


public Action BonkCannerHit(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(attacker > MaxClients || !IsClientInGame(attacker)) return Plugin_Continue;
	
	if(!StrEqual(UD[attacker].sJob, "Bonk Mixer"))
	{
		TFRP_PrintToChat(attacker, "Only {goldenrod}Bonk Mixers{default} can use this!");
		return Plugin_Continue;
	}
	
	if(BonkCanners[victim].BonkCans > 0)
	{	
		TFRP_PrintToChat(attacker, "Took {mediumseagreen}1 Bonk! Atomic Punch{default} from the {mediumseagreen}Bonk Canner");
		GiveItem(attacker, "Bonk! Atomic Punch", 1);
		BonkCanners[victim].BonkCans += -1;
	}else{
		TFRP_PrintToChat(attacker, "No {mediumseagreen}Bonk! Atomic Punch{default} has been canned yet!");
	}
	
	return Plugin_Continue;
}

// Radio

public Action Command_RadioChannel(int client, any args)
{
	if(client == 0)
	{
		PrintToServer("[TFRP] Command can only be ran in-game");
		return Plugin_Handled;
	}
	
	int curRadio = GetClientAimTarget(client, false);
	if(curRadio == -1 || !StrEqual(EntItems[curRadio], "Radio"))
	{
		TFRP_PrintToChat(client, "Must be looking at a {mediumseagreen}Radio");
		return Plugin_Handled;
	}
	
	if(args != 1)
	{
		TFRP_PrintToChat(client, "Usage: sm_radiochannel <channel>");
		return Plugin_Handled;
	}
	
	char switchChannel[8];
	GetCmdArg(1, switchChannel, sizeof(switchChannel));
	StopRadio(Radios[curRadio][0], Radios[curRadio][1], curRadio);
	PlayChannel(StringToInt(switchChannel), 1, curRadio);
	
	return Plugin_Handled;
}

public int PlayChannel(int channel, int soundid, int RadioEnt)
{
	Handle RM = CreateKeyValues("Radio");
	FileToKeyValues(RM, RadioPath);
	char SoundFileName[64];
	float SoundDur = 0.0;
	bool foundId = false;
	
	char getKey[32];
	FormatEx(getKey, sizeof(getKey), "%d", channel);
	
	if(KvJumpToKey(RM, getKey, false))
	{
		int m = 0;
		if(KvGotoFirstSubKey(RM, false))
		{
			do{	
				m++;
				if(m==soundid)
				{
					KvGetSectionName(RM, SoundFileName, sizeof(SoundFileName));
					SoundDur = KvGetFloat(RM, NULL_STRING, 0.0);
					foundId = true;
					break;
				}
			} while (KvGotoNextKey(RM,false));
		}
	}
	KvRewind(RM);
	CloseHandle(RM);
	if(foundId)
	{
		Radios[RadioEnt][0] = channel;
		Radios[RadioEnt][1] = soundid;
		float RadioPos[3];
		GetEntPropVector(RadioEnt, Prop_Data, "m_vecOrigin", RadioPos);
		EmitSoundToAll(SoundFileName, RadioEnt, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.000000, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.000000);
		CreateTimer(SoundDur, ScrollChannel, RadioEnt);
	}else{
		float RadioPos[3];
		GetEntPropVector(RadioEnt, Prop_Data, "m_vecOrigin", RadioPos);
		EmitSoundToAll(TFRP_ERROR_SOUND, RadioEnt, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.000000, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.000000);
		
	}
}

public Action ScrollChannel(Handle timer, int RadioEnt)
{
	Radios[RadioEnt][1]++;
	PlayChannel(Radios[RadioEnt][0], Radios[RadioEnt][1], RadioEnt);
}

public int StopRadio(int channel, int soundid, int RadioEnt)
{
	float RadioPos[3];
	GetEntPropVector(RadioEnt, Prop_Data, "m_vecOrigin", RadioPos);
	
	Handle RM = CreateKeyValues("Radio");
	FileToKeyValues(RM, RadioPath);
	char SoundFileName[64];
	bool foundId = false;
	
	char getKey[32];
	FormatEx(getKey, sizeof(getKey), "%d", channel);
	
	if(KvJumpToKey(RM, getKey, false))
	{
		int m = 0;
		if(KvGotoFirstSubKey(RM, false))
		{
			do{	
				m++;
				if(m==soundid)
				{
					KvGetSectionName(RM, SoundFileName, sizeof(SoundFileName));
					foundId = true;
					break;
				}
			} while (KvGotoNextKey(RM,false));
		}
	}
	KvRewind(RM);
	CloseHandle(RM);
	if(foundId)
	{
		StopSound(RadioEnt, SNDCHAN_AUTO, SoundFileName);
		PrintToServer("attempted to stop sound %s", SoundFileName);
	}
}

// Help menu


public int HelpMenuCB(Handle menuhandle, MenuAction action, int client, int pos)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(pos)
			{
				case 0:
				{
					OpenRPHelpCmd(client);
				}
				case 1:
				{
					OpenRPHelpInv(client);
				}
				case 2:
				{
					OpenRPHelpMM(client);
				}
				case 3:
				{
					OpenRPHelpGov(client);
				}
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menuhandle);
		}
	}
	return 0;
}


public Action Command_RPHelp(int client, any args)
{
	if(!IsClientInGame(client)) return Plugin_Handled;
	OpenHelpMenu(client);
	return Plugin_Handled;
}

public void OpenHelpMenu(int client)
{
	Handle menuhandle = CreateMenu(HelpMenuCB);
	SetMenuTitle(menuhandle, "[TFRP] Help Menu");

	AddMenuItem(menuhandle, "Commands", "Commands");
	AddMenuItem(menuhandle, "Inventory", "Inventory");
	AddMenuItem(menuhandle, "Making Money", "Making Money");
	AddMenuItem(menuhandle, "Government", "Government");
	
	SetMenuPagination(menuhandle, 7);
	SetMenuExitButton(menuhandle, true);
	DisplayMenu(menuhandle, client, 250);
}

public void OpenRPHelpCmd(int client)
{
	Handle menuhandle = CreateMenu(HelpMenuCmdCB);
	SetMenuTitle(menuhandle, "[TFRP] Help Menu");

	AddMenuItem(menuhandle, "sm_jobs", "sm_jobs");
	AddMenuItem(menuhandle, "sm_shop", "sm_shop");
	AddMenuItem(menuhandle, "sm_items", "sm_items");
	AddMenuItem(menuhandle, "sm_rotate", "sm_rotate");
	AddMenuItem(menuhandle, "sm_rphelp", "sm_rphelp");
	AddMenuItem(menuhandle, "sm_buydoor", "sm_buydoor");
	AddMenuItem(menuhandle, "sm_lock", "sm_lock");
	AddMenuItem(menuhandle, "sm_selldoor", "sm_selldoor");
	AddMenuItem(menuhandle, "sm_givekeys", "sm_givekeys");
	AddMenuItem(menuhandle, "sm_revokekeys", "sm_revokekeys");
	AddMenuItem(menuhandle, "sm_givemoney", "sm_givemoney");
	AddMenuItem(menuhandle, "sm_pickup", "sm_pickup");
	AddMenuItem(menuhandle, "sm_placehit", "sm_placehit");
	
	SetMenuPagination(menuhandle, 7);
	SetMenuExitButton(menuhandle, true);
	DisplayMenu(menuhandle, client, 250);
}

public int HelpMenuCmdCB(Handle menuhandle, MenuAction action, int client, int pos)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char GetHelpCmd[32];
			GetMenuItem(menuhandle, pos, GetHelpCmd, sizeof(GetHelpCmd));
			
			ClientCommand(client, GetHelpCmd);
			
		}
		case MenuAction_End:
		{
			CloseHandle(menuhandle);
		}
	}
	return 0;
}

public void OpenRPHelpInv(int client)
{
	Handle menuhandle = CreateMenu(HelpMenuInvCB);
	SetMenuTitle(menuhandle, "[TFRP] Help Menu");

	AddMenuItem(menuhandle, "","The inventory contains all your items. It can be accessed using /items",  ITEMDRAW_DISABLED);	
	AddMenuItem(menuhandle, "","Items have 3 types: Ent, Item, and Weapon.", ITEMDRAW_DISABLED);
	AddMenuItem(menuhandle, "","Entities are items that can be spawned as props", ITEMDRAW_DISABLED);
	AddMenuItem(menuhandle, "","Items (type) are items that can be used", ITEMDRAW_DISABLED);
	AddMenuItem(menuhandle, "","Weapons are items that can give you a weapon",ITEMDRAW_DISABLED);
	
	SetMenuPagination(menuhandle, 7);
	SetMenuExitButton(menuhandle, true);
	DisplayMenu(menuhandle, client, 250);
}

public int HelpMenuInvCB(Handle menuhandle, MenuAction action, int client, int pos)
{
	switch(action)
	{
		case MenuAction_End:
		{
			CloseHandle(menuhandle);
		}
	}
	return 0;
}


public void OpenRPHelpMM(int client)
{
	Handle menuhandle = CreateMenu(HelpMenuMMCB);
	SetMenuTitle(menuhandle, "[TFRP] Help Menu");
	
	AddMenuItem(menuhandle, "", "Each job has it's own salary", ITEMDRAW_DISABLED );
	AddMenuItem(menuhandle, "Sandvich Making", "Sandvich Making");	
	AddMenuItem(menuhandle, "Australium Mining", "Australium Mining");
	AddMenuItem(menuhandle, "Bonk! Mixing", "Bonk! Mixing");
	AddMenuItem(menuhandle, "Bank Robbing", "Bank Robbing");
	AddMenuItem(menuhandle, "Hitman", "Hitman");

	SetMenuPagination(menuhandle, 7);
	SetMenuExitButton(menuhandle, true);
	DisplayMenu(menuhandle, client, 250);
}

public int HelpMenuMMCB(Handle menuhandle, MenuAction action, int client, int pos)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(pos)
			{
				case 1:
				{
					OpenSandvichMakingHelp(client);
				}
				case 2:
				{
					OpenAustraliumMiningHelp(client);
				}
				case 3:
				{
					OpenBonkMixingHelp(client);
				}
				case 4:
				{
					OpenBankRobbingHelp(client);
				}
				case 5:
				{
					OpenHitmanHelp(client);
				}
			}
			
		}
		case MenuAction_End:
		{
			CloseHandle(menuhandle);
		}
	}
	return 0;
}

public void OpenSandvichMakingHelp(int client)
{
	// These are instructions to follow, so I figured it'd be easier to read if it was in chat
	TFRP_PrintToChat(client, "How to make {mediumseagreen}Sandviches:");
	TFRP_PrintToChat(client, "1. Open the {mediumseagreen}jobs{default} menu and select {goldenrod}Sandvich Maker");
	TFRP_PrintToChat(client, "2. Open the {mediumseagreen}shop{default} and buy one of everything from the {mediumseagreen}Sandvich Making{default} category");
	TFRP_PrintToChat(client, "3. Open your {mediumseagreen}inventory{default} and select the {mediumseagreen}Sandvich Table,{default} spawn it");
	TFRP_PrintToChat(client, "4. Open your {mediumseagreen}inventory{default} and select each ingredient and use it while looking at the {mediumseagreen}Sandvich Table");
	TFRP_PrintToChat(client, "5. When the {mediumseagreen}Sandvich{default} is done, find a {mediumseagreen}Sandvich Buyer{default} NPC, hit it, and select {mediumseagreen}Sell Sandvich");
	TFRP_PrintToChat(client, "6. {goldenrod}Profit");
	TFRP_PrintToChat(client, "NOTE: You can make an infinite number of sandviches at a time");
}

public void OpenAustraliumMiningHelp(int client)
{
	TFRP_PrintToChat(client, "How to mine {mediumseagreen}Australium:");
	TFRP_PrintToChat(client, "1. Open the {mediumseagreen}jobs{default} menu and select {goldenrod}Australium Miner");
	TFRP_PrintToChat(client, "2. Open the {mediumseagreen}shop{default} and buy one of everything from the {mediumseagreen}Australium Mining{default} category");
	TFRP_PrintToChat(client, "3. Open your {mediumseagreen}inventory{default} and select the {mediumseagreen}Australium Drill,{default} spawn it");
	TFRP_PrintToChat(client, "4. Do the same with the {mediumseagreen}Australium Cleaner");
	TFRP_PrintToChat(client, "5. Open your {mediumseagreen}inventory{default} and select {mediumseagreen}Fuel{default} and use it while looking at the {mediumseagreen}Australium Drill");
	TFRP_PrintToChat(client, "6. The {mediumseagreen}Australium Drill{default} will emit a noise when it has mined {mediumseagreen}Australium");
	TFRP_PrintToChat(client, "7. When it does, hit it and you will be given {mediumseagreen}Dirty Australium");
	TFRP_PrintToChat(client, "8. Open your {mediumseagreen}inventory{default} and use the {mediumseagreen}Dirty Australium{default} on the {mediumseagreen}Australium Cleaner");
	TFRP_PrintToChat(client, "9. The {mediumseagreen}Australium Cleaner{default} will also emit a sound when it is done cleaning");
	TFRP_PrintToChat(client, "10. When it does, hit it and you will be given {mediumseagreen}Australium");
	TFRP_PrintToChat(client, "11. Open your {mediumseagreen}inventory{default} and spawn your {mediumseagreen}Empty Package");
	TFRP_PrintToChat(client, "12. Open your {mediumseagreen}inventory{default} and use your {mediumseagreen}Australium{default} on the {mediumseagreen}Empty Package");
	TFRP_PrintToChat(client, "13. When the package has {mediumseagreen}5 Australium{default} in it, you can pick it up by hitting it, and you will be given a {mediumseagreen}Full Australium Package");
	TFRP_PrintToChat(client, "14. Find an {mediumseagreen}Australium Buyer{default} NPC, hit it, and select {mediumseagreen}Sell Full Australium Package");
	TFRP_PrintToChat(client, "15. {goldenrod}Profit");
}	

public void OpenBonkMixingHelp(int client)
{
	TFRP_PrintToChat(client, "How to mix {mediumseagreen}Bonk! Atomic Punch");
	TFRP_PrintToChat(client, "1. Open the {mediumseagreen}jobs{default} menu and select {goldenrod}Bonk Mixer");
	TFRP_PrintToChat(client, "2. Open the {mediumseagreen}shop{default} and buy one of everything from the {mediumseagreen}Bonk{default} category");
	TFRP_PrintToChat(client, "3. Open your {mediumseagreen}inventory{default} and select the {mediumseagreen}Bonk Mixer{default}, spawn it");
	TFRP_PrintToChat(client, "4. Do the same with the {mediumseagreen}Bonk Canner,{default} make sure it is near the {mediumseagreen}Bonk Mixer");
	TFRP_PrintToChat(client, "5. Open your {mediumseagreen}inventory{default} and use all of the ingredients on the {mediumseagreen}Bonk Mixer");
	TFRP_PrintToChat(client, "6. When it is done mixing, it will emit a sound indicating that it has been transfered to the {mediumseagreen}Bonk Canner");
	TFRP_PrintToChat(client, "7. When the {mediumseagreen}Bonk Canner{default} is done, it will emit a sound");
	TFRP_PrintToChat(client, "8. When it does, hit it and you will be given {mediumseagreen}Bonk! Atomic Punch");
	TFRP_PrintToChat(client, "9. Find a {mediumseagreen}Bonk Buyer{default} NPC, hit it, and select {mediumseagreen}Sell Bonk! Atomic Punch");
	TFRP_PrintToChat(client, "10. {goldenrod}Profit");
}

public void OpenBankRobbingHelp(int client)
{
	TFRP_PrintToChat(client, "How to rob a {mediumseagreen}bank");
	TFRP_PrintToChat(client, "1. Make sure there are atleast %d cops on (Cops are Blu)", cvarTFRP[CopsToRob].IntValue);
	TFRP_PrintToChat(client, "2. Be prepared to defend the {mediumseagreen}vault");
	TFRP_PrintToChat(client, "3. While looking at the {mediumseagreen}vault,{default} do /robbank");
	TFRP_PrintToChat(client, "4. Defend the {mediumseagreen}vault until the time runs out, dying stops the robbery");
	TFRP_PrintToChat(client, "5. {goldenrod}Mega Profit");
}

public void OpenHitmanHelp(int client)
{
	TFRP_PrintToChat(client, "How to {mediumseagreen}Execute Hits");
	TFRP_PrintToChat(client, "1. Have a player do {mediumseagreen}/placehit{default} while looking at you");
	TFRP_PrintToChat(client, "2. Kill the player that the hit is on");
	TFRP_PrintToChat(client, "3. {goldenrod}Profit");
}

public void OpenRPHelpGov(int client)
{
	Handle menuhandle = CreateMenu(HelpMenuGovCB);
	SetMenuTitle(menuhandle, "[TFRP] Help Menu");
	
	AddMenuItem(menuhandle, "Police", "Police");
	AddMenuItem(menuhandle, "Police", "Mayor");
	
	SetMenuPagination(menuhandle, 3);
	SetMenuExitButton(menuhandle, true);
	DisplayMenu(menuhandle, client, 250);
}

public int HelpMenuGovCB(Handle menuhandle, MenuAction action, int client, int pos)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(pos)
			{
				case 0:
				{
					OpenPoliceHelpMenu(client);
				}
				case 1:
				{
					OpenMayorHelpMenu(client);
				}
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menuhandle);
		}
	}
	return 0;
}

public void OpenPoliceHelpMenu(int client)
{
	Handle menuhandle = CreateMenu(HelpMenuPoliceCB);
	SetMenuTitle(menuhandle, "[TFRP] Help Menu");
	
	AddMenuItem(menuhandle, "", "Police spawn with a Big Kill and Bat", ITEMDRAW_DISABLED);
	AddMenuItem(menuhandle, "", "All Government jobs can lock/unlock Government Offical doors", ITEMDRAW_DISABLED);
	AddMenuItem(menuhandle, "", "To arrest players, do /arrest (It's recommended to have a bind for it)", ITEMDRAW_DISABLED);
	AddMenuItem(menuhandle, "", "The Police Chief and Mayor have the ability to issue warrants", ITEMDRAW_DISABLED);
	AddMenuItem(menuhandle, "", "Any officer can do /ram on a door owned by someone who has a warrant to force it open", ITEMDRAW_DISABLED);
	
	SetMenuPagination(menuhandle, 7);
	SetMenuExitButton(menuhandle, true);
	DisplayMenu(menuhandle, client, 250);
}

public int HelpMenuPoliceCB(Handle menuhandle, MenuAction action, int client, int pos)
{
	switch(action)
	{
		case MenuAction_End:
		{
			CloseHandle(menuhandle);
		}
	}
	return 0;
}

public void OpenMayorHelpMenu(int client)
{
	Handle menuhandle = CreateMenu(HelpMenuMayorCB);
	SetMenuTitle(menuhandle, "[TFRP] Help Menu");
	
	AddMenuItem(menuhandle, "", "The Mayor can set laws with /addlaw", ITEMDRAW_DISABLED);
	AddMenuItem(menuhandle, "", "Laws can be removed with /deletelaw", ITEMDRAW_DISABLED);
	AddMenuItem(menuhandle, "", "The Mayor and Police Chief can also set warrants on other players with /setwarrant", ITEMDRAW_DISABLED);
	AddMenuItem(menuhandle, "", "If a player has a warrant, their doors can be forced open by officers using /ram", ITEMDRAW_DISABLED);
	

	SetMenuPagination(menuhandle, 7);
	SetMenuExitButton(menuhandle, true);
	DisplayMenu(menuhandle, client, 250);
}

public int HelpMenuMayorCB(Handle menuhandle, MenuAction action, int client, int pos)
{
	switch(action)
	{
		case MenuAction_End:
		{
			CloseHandle(menuhandle);
		}
	}
	return 0;
}
