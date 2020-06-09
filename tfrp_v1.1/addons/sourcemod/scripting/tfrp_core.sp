#define PLUGIN_NAME 		"TF2 Roleplay Mod"
#define PLUGIN_AUTHOR 		"Thod (SQL by The Illusion Squid)"
#define PLUGIN_DESCRIPTION 	"Roleplay mod for TF2"
#define PLUGIN_VERSION 		"1.1-sql"
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
#define AUSTRALIUM_MAX_DRILLS				3
#define AUSTRALIUM_MAX_CLEANERS				3
#define AUSTRALIUM_MAX_PACKAGES				3

#define SANDVICH_MAX_TABLES					2

#define DOOR_LOCK_SOUND						"doors/default_locked.wav"
#define DOOR_UNLOCK_SOUND					"doors/latchunlocked1.wav"

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
	Version
}

ConVar cvarTFRP[Version + 1];

///////////
//  SQL  //
///////////
char sUserInfoTable[32]; //Stores info
char sUserInvTable[32]; //Stores items

//Initial
char sQuery_CreateTable_UserInfo[] = "CREATE TABLE IF NOT EXISTS %s (`auth` VARCHAR(32) NOT NULL, `name` TEXT NOT NULL, `cash` INT(16) NOT NULL, `join_date` BIGINT(11) NOT NULL, `playtime` BIGINT(11) NOT NULL, `last_update` BIGINT(11) NOT NULL, PRIMARY KEY (`auth`));";
char sQuery_CreateTable_UserInventory[] = "CREATE TABLE IF NOT EXISTS %s (`auth` VARCHAR(32) NOT NULL, `item_id` VARCHAR(32) NULL DEFAULT NULL, `item_count` INT(11) NOT NULL DEFAULT 0);";
// Get info
char sQuery_GetUserinfo[] = "SELECT * FROM %s WHERE auth = '%s';";
// char sQuery_GetUserCash[] = "SELECT cash FROM %s WHERE auth = '%s';";
char sQuery_GetUserItem[] = "SELECT item_count FROM %s WHERE auth = '%s' AND item_id = '%s';";
char sQuery_GetUserItems[] = "SELECT item_id, item_count FROM %s WHERE auth = '%s';";
//Update info
char sQuery_UpdateUserCash[] = "UPDATE %s SET `cash` = %d, `last_update` = %d WHERE auth = '%s';";
char sQuery_UpdateUserInfoFull[] = "UPDATE %s SET `name` = '%s', `cash` = %d, `playtime` = %d, `last_update` = %d WHERE auth = '%s';";
char sQuery_UpdateUserItem[] = "UPDATE %s SET `item_count` = item_count + %d WHERE auth = '%s' AND item_id = '%s';";
char sQuery_InsertUserItem[] = "INSERT INTO  %s (auth, item_id, item_count) VALUES ('%s', '%s', %d);";
//Register
char sQuery_RegisterNewUserInfo[] = "INSERT INTO %s (auth, name, cash, join_date, playtime, last_update) VALUES ('%s', '%s', %d, %d, %i, %d);";

Handle g_hSQL;

/////////////
//  Cache  //
/////////////

enum struct UserData
{
	int iCash;
	int iPlayTime;
	int iJoinTime; 	//Timestamp of join event
	int iLogTime; 	//Timestamp of last playtime update
	char sJob[32]; 	//Job name
	int iJobSalary;
	bool bIsGov;
	bool bArrested;
	bool bBuyDoors;
	bool bHasWarrent;
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

// Config variables
int StartCash = 5000; // 5000 is default
char StartJob[32] = "Citizen"; // Citizen is default
float SalTime = 120.0; // 120.0 is default
int ShopReturn = 2; // 2 is default
float SandvichMakeTime = 60.0; // 60 is default

// int maxnpcs = 10;

int FuelPerCan = 100;
float AustraliumDrillTime = 10.0; // 5.0 is default
int FuelConsumptionPerSecond = 1; // 1 is default
float AustraliumCleanTime = 10.0; // 5.0 is default

int bankWorth = 0; // 0 is default
int bankIndex = 0; // 0 is default
float bankRobTime = 300.0; // 300.0 is default
int bankRobHudTime = 300; // 300 is default
bool isBeingRobbed = false; // false is default
int CopsToRob = 2; // 2 is default

float lockpickTime = 20.0; // 20.0 is default
int maxDoors = 8; // 8 is default

int maxDroppedItems = 10; // 10 is default

float moneyPrintTimeTier1 = 60.0; // 60.0 is default
float moneyPrintTimeTier2 = 60.0; // 60.0 is default
float moneyPrintTimeTier3 = 60.0; // 60.0 is default

int printerTier1MoneyPerPrint = 50; // 50 is default
int printerTier2MoneyPerPrint = 135; // 135 is default
int printerTier3MoneyPerPrint = 250; // 250 is default

int maxPrintersTier1 = 3; // 3 default < v v
int maxPrintersTier2 = 3;
int maxPrintersTier3 = 3;

int HitPrice = 500; // 500 is default

float JailTime = 120.0; // 120.0 is default

int LotAmt = 0; // 0 is default
int lotteryStarter = 0; // 0 is default
bool isLottery = false; // false is default
bool lotAvaliable = true; // true is default

float timeBetweenLot = 600.0; // 600.0 is default
float lotTime = 300.0; // 300.0 is default
int maxLottery = 7500; // 7500 is default

float WarrantTime = 300.0;

// RP Globals

static char Job[MAXPLAYERS + 1][255];
static char CanOwnDoors[MAXPLAYERS + 1][255];
static DroppedItems[MAXPLAYERS + 1] = {0,...};
// static Crime[MAXPLAYERS + 1] = {0,...};
static IsGov[MAXPLAYERS + 1] = {false,...};
static char droppedItemsString[2048][255];
static char JailCells[10][255]; // Max 10 jail cells
static Doors[2048] = {0,...};
static DoorOwners[2048][5];
static lockedDoor[2048] = {false,...};
static isArrested[MAXPLAYERS + 1] = {false,...};
static float JailTimes[MAXPLAYERS + 1] = {0.0,...};
static isLockpicking[2048] = {0,...};
static isLockpickingPlayers[MAXPLAYERS + 1] = {false,...};
static DoorOwnedAmt[MAXPLAYERS + 1] = {0,...};
static WelcomeHuds[MAXPLAYERS + 1] = {false,...};
static HasWarrant[MAXPLAYERS + 1] = {false,...};
static EntOwners[2048] = {0,...};
static char EntItems[2048][255];
// static Bank[MAXPLAYERS + 1] = {0,...};
	
	// Sandvich
		static STableIngredients[2048][4];
	// Australium
		static AusFuels[2048] = {0,...};
		static AusMined[2048] = {0,...};
		static AusDrillsOwned[MAXPLAYERS + 1] = {0,...};
	
		static AusDirty[2048] = {0,...};
		static AusClean[2048] = {0,...};
		static AusCleanersOwned[MAXPLAYERS + 1] = {0,...};
	
		static AusPacks[2048] = {0,...};
		static AusPacksOwned[MAXPLAYERS + 1] = {0,...};
	// NPCs
		static char NPCIds[7][255];
		static NPCEnts[7] = {0,...};
		static NPCEntsBox[7] = {0,...};
	// Printers
		static PrinterMoney[2048] = {0,...};
		static PrintersOwned[MAXPLAYERS + 1][3];
		static isPrinter[2048] = {false,...};
		static PrinterTier[2048] = {0,...};
	// Casino
		//static BlackjackGames[2048] = {0,...};
		static PlayingBlackjack[MAXPLAYERS + 1] = {0,...};
		static char BlackjackCards[MAXPLAYERS + 1][255];
		//static BlackjackWagers[MAXPLAYERS + 1] = {0,...};
		// static BlackjackPos[MAXPLAYERS + 1] = {0,...};
	// Hitman
		static Hits[MAXPLAYERS + 1] = {0,...};
	// Lottery
		static playingLot[MAXPLAYERS + 1] = {false,...};
	// Laws
		static char Laws[10][255];

// Handles
Handle hHud1, hHud2, hHud3, hHud4, hHud5, hHud6, hHud7, hHud8, hHud9, hHud10, hHud11;

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
		
		if(StrEqual(JobName, Job[client])) break;
		
		
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
		if(IsGov[client])
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
	
	// Hud
	hHud1 = CreateHudSynchronizer();
	hHud2 = CreateHudSynchronizer();
	hHud3 = CreateHudSynchronizer();
	hHud4 = CreateHudSynchronizer();
	hHud5 = CreateHudSynchronizer();
	hHud6 = CreateHudSynchronizer();
	hHud7 = CreateHudSynchronizer();
	hHud8 = CreateHudSynchronizer();
	hHud9 = CreateHudSynchronizer();
	hHud10 = CreateHudSynchronizer();
	hHud11 = CreateHudSynchronizer();

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
	cvarTFRP[AnnounceJobSwitch] = CreateConVar("tfrp_announce_job_switch", "1", "Enables/Disables announcing to all players when a player switches their job. (0 = disable)", FCVAR_NOTIFY);
	cvarTFRP[Prefix] = CreateConVar("sm_tfrp_tableprefix", "tfrp", "Prefix for database tables. (Can be blank, however it is not recommended)", FCVAR_NOTIFY);
	//You're welcome to those who only have one SQL database -The Illusion Squid
	cvarTFRP[SQLDebug] = CreateConVar("sm_tfrp_sqldebug", "0", "Enables console debugging for TFRP SQL.", FCVAR_NOTIFY);
	cvarTFRP[Debug] = CreateConVar("sm_tfrp_debug", "0", "Enables console debugging for TFRP General stuff.", FCVAR_NOTIFY);

	////////////////////////
	// Register Commands //
	///////////////////////

	RegConsoleCmd("sm_job", Command_JOB);
	RegConsoleCmd("sm_jobs", Command_JOB);

	RegConsoleCmd("sm_shop", Command_BUYMENU);

	// Doors
	
	RegConsoleCmd("sm_buydoor", Command_BuyDoor);
	RegConsoleCmd("sm_lock", Command_LockDoor);
	RegConsoleCmd("sm_selldoor", Command_SellDoor);
	RegConsoleCmd("sm_givekeys", Command_GiveKeys);

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
	
	// Blackjack  
	// RegConsoleCmd("sm_wager", Command_PlaceWager);

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

public void ConnectSQL()
{
	SQL_TConnect(SQLCall_ConnectToDatabase, "tfrp"); //Get's sql credentials from database.cfg. Pretty standard
}

public void StripToMelee(int client) //Thanks to JB Redux
	{
	TF2_RemoveWeaponSlot(client, 0);
	TF2_RemoveWeaponSlot(client, 1);
	TF2_RemoveWeaponSlot(client, 3);
	TF2_RemoveWeaponSlot(client, 4);
	TF2_RemoveWeaponSlot(client, 5);
	//TF2_SwitchToSlot(client, TFWeaponSlot_Melee);

	char sClassName[64];
	int wep = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
	if (wep > MaxClients && IsValidEdict(wep) && GetEdictClassname(wep, sClassName, sizeof(sClassName)))
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", wep);
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
	//To keep the table names nice and clean. Default cvar will result in tfrp_user_info
	Format(sUserInfoTable, sizeof(sUserInfoTable), "%suser_info", prefix);
	Format(sUserInvTable, sizeof(sUserInvTable), "%suser_inventory", prefix);

	Transaction trans = SQL_CreateTransaction();

	char sQuery[MAX_QUERY_SIZE];

	Format(sQuery, sizeof(sQuery), sQuery_CreateTable_UserInfo, sUserInfoTable);
	SQL_AddQuery(trans, sQuery);

	Format(sQuery, sizeof(sQuery), sQuery_CreateTable_UserInventory, sUserInvTable);
	SQL_AddQuery(trans, sQuery);

	SQL_ExecuteTransaction(g_hSQL, trans, SQL_Transaction_Success, SQL_Transaction_Failure, _, DB_PRIO);

	PrintToServer("[TFRP] Successfully connected to database!");
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

void RegisterNewUser(int iClient, int iCash = 0, int iPlayTime = 0)
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
	UD[iClient].iCash = iCash;
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
		iCash,
		iTS,
		iPlayTime,
		iTS
	);

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

	Format(sQuery, sizeof(sQuery), 
		sQuery_GetUserinfo, 
		sUserInfoTable, 
		sAuth
	);

	if (cvarTFRP[SQLDebug].BoolValue)
		PrintToServer("GetUserInfo query: %s", sQuery);

	SQL_TQuery(g_hSQL, SQLCall_GetUserInfo, sQuery, hPack);
}

void SQLCall_GetUserInfo(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
    {
		CloseHandle(data);
		LogError("[TFRP] Failed to run GetUserInfo query: %s", error);
		PrintToServer("[TFRP] Failed to run GetUserInfo query: %s", error);
		return;
    }
	//Get client index
	ResetPack(data);
	int iClient = ReadPackCell(data);
	CloseHandle(data);
	
	if (SQL_GetRowCount(hndl) <= 0)
	{
		RegisterNewUser(iClient);
		return;
	}
	
	while (SQL_FetchRow(hndl)) //Should loop once. But if for some reason there is a dublicate (imposible) it will overwrite anyways.
	{
		UD[iClient].iCash = SQL_FetchInt(hndl, 2);
		UD[iClient].iPlayTime = SQL_FetchInt(hndl, 4);
	}
	UD[iClient].iJoinTime = GetTime();
	UD[iClient].iLogTime = GetTime();
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
	//tnx for if I ever need to also finalize the inventory.
	
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

	SQL_ExecuteTransaction(g_hSQL, trans, SQL_Transaction_Success, SQL_Transaction_Failure, _, DB_PRIO);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("TFRP_GetJobIndex", Native_GetJobIndex);
	CreateNative("TFRP_GiveItem", Native_GiveItem);
	CreateNative("TFRP_RemoveItem", Native_RemoveItem);
	CreateNative("TFRP_GetCash", Native_GetCash);
	CreateNative("TFRP_IsGov", Native_IsGov);
	CreateNative("TFRP_GetEntOwner", Native_GetEntOwner);
	
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
	UD[client].sJob = StartJob; //This was not yet converting fully. -Squid
	UD[client].iJobSalary = 50;
	UD[client].bIsGov = false;
	
	Job[client] = StartJob;
	// Will make a config file for jobs that includes salaries
	IsGov[client] = false;

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
	
	// Start Hud
	WelcomeHuds[client] = true;
	CreateTimer(0.1, WelcomeHUD, client, TIMER_REPEAT);
	CreateTimer(10.0, WelcomeHUDStop, client);

	// Main hud
	CreateTimer(0.1, HUD, client, TIMER_REPEAT);

	// Salary
	CreateTimer(SalTime, Timer_Cash, client, TIMER_REPEAT);

	// Aus Drill Hud
	CreateTimer(0.1, Timer_AusHUD, client, TIMER_REPEAT);
	
	// Bank Hud
	CreateTimer(1.0, Timer_BankHUD, client, TIMER_REPEAT);
	
	// Door Hud
	CreateTimer(0.1, Timer_DoorHUD, client, TIMER_REPEAT);
	
	// Delete non-job related ents and doors
	CreateTimer(0.1, Timer_NoExploit, client, TIMER_REPEAT);
	
	// Printer Hud
	CreateTimer(0.1, Timer_PrinterHud, client, TIMER_REPEAT);
	
	// Lottery Hud
	CreateTimer(0.1, Timer_LotteryHud, client, TIMER_REPEAT);
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
	
	Handle DB3 = CreateKeyValues("Config");
	FileToKeyValues(DB3, ConfPath);

	// Start cash
	StartCash = KvGetNum(DB3, "Start Cash", 5000);

	// Start job
	KvGetString(DB3, "Start Job", StartJob, sizeof(StartJob), "Citizen");

	// Paycheck time
	SalTime = KvGetFloat(DB3, "Pay Time", 120.0);

	// Shop return
	ShopReturn = KvGetNum(DB3, "Shop Return", 2);

	//// Sandvich //////

	// Sandvich Make Time
	SandvichMakeTime = KvGetFloat(DB3, "Sandvich Make Time", 60.0);

	///// Bank /////
	
	// Bank Rob Time
	bankRobTime = KvGetFloat(DB3, "Bank Rob Time", 300.0);

	// Cops to rob
	CopsToRob = KvGetNum(DB3, "Cops To Rob", 2);

	//// Doors /////
	
	// Max Doors
	maxDoors = KvGetNum(DB3, "MaxDoors", 8);
	
	// Lockpick time
	lockpickTime = KvGetFloat(DB3, "Lockpick Time", 20.0);
	
	//// Printers //////
	
	// Bronze
	printerTier1MoneyPerPrint = KvGetNum(DB3, "MoneyTier1Yield", 50);
	moneyPrintTimeTier1 = KvGetFloat(DB3, "PrintTimeTier1", 60.0);
	maxPrintersTier1 = KvGetNum(DB3, "MaxTier1Printers", 3);
	// Silver
	printerTier2MoneyPerPrint = KvGetNum(DB3, "MoneyTier2Yield", 50);
	moneyPrintTimeTier2 = KvGetFloat(DB3, "PrintTimeTier2", 60.0);
	maxPrintersTier2 = KvGetNum(DB3, "MaxTier2Printers", 3);
	// Gold
	printerTier3MoneyPerPrint = KvGetNum(DB3, "MoneyTier3Yield", 50);
	moneyPrintTimeTier3 = KvGetFloat(DB3, "PrintTimeTier3", 60.0);
	maxPrintersTier3 = KvGetNum(DB3, "MaxTier3Printers", 3);

	// Australium //
	AustraliumDrillTime = KvGetFloat(DB3, "Aus Drill Time", 10.0);
	AustraliumCleanTime = KvGetFloat(DB3, "Aus Clean Time", 10.0);
	FuelConsumptionPerSecond = KvGetNum(DB3, "Aus Fuel Consumption", 1);
	
	// Jail //
	JailTime = KvGetFloat(DB3, "Jail Time", 120.0);

	// Lottery
	timeBetweenLot = KvGetFloat(DB3, "Time Between Lotteries", 600.0);
	lotTime = KvGetFloat(DB3, "Lottery Time", 300.0);
	maxLottery = KvGetNum(DB3, "Max Lottery", 7500);
	
	// Warrant
	WarrantTime = KvGetFloat(DB3, "Warrant Time", 300.0);

	CloseHandle(DB3);
	
	
	
	if(!confreload)
	{
		// Just some extra startup things
		for(int i = 0; i <= 2047; i++)
		{
			droppedItemsString[i] = "__no__item__";
			EntItems[i] = "__no__item__";
			if(i < 10) JailCells[i] = "none";
		
			// if(i <= MaxClients) BlackjackCards[i] = "none,none|none,none";
			
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
				PrintersOwned[i][0] = 0;
				PrintersOwned[i][1] = 0;
				PrintersOwned[i][2] = 0;
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
		
		UD[attacker].iCash += HitPrice;
		UpdateCash(attacker);
		
		CPrintToChatAll("{yellow}[TFRP ADVERT]{default} The hit on %s has been completed", GetKilledPlayerName);

		Hits[attacker] = 0;
	}
	return Plugin_Continue;
}

// Prevent non cops from going blu and cops from going red (and everyone from going spec)

public Action onSwitchTeam(int client, char[] command, int argc)
{
	if(IsGov[client])
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
	
	AusDrillsOwned[client] = 0;
	AusCleanersOwned[client] = 0;
	AusPacksOwned[client] = 0;
	
	IsGov[client] = false;
	isArrested[client] = false;
	DoorOwnedAmt[client] = 0;
	DroppedItems[client] = 0;
	WelcomeHuds[client] = false;
	PlayingBlackjack[client] = 0;
	BlackjackCards[client] = "none,none|none,none";
	DeleteJobEnts(client);
	DeleteHit(client);
	HasWarrant[client] = false;
	PrintersOwned[client][0] = 0;
	PrintersOwned[client][1] = 0;
	PrintersOwned[client][2] = 0;
	
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
	
	if(StrEqual(Job[client], "Mayor") && isLottery == true)
	{
		CPrintToChatAll("{yellow}[TFRP ADVERT]{default} Mayor left, canceling lottery and refunding participants");
		CancelLottery();
	}
	
}

public Action Command_SetCash(int client, int args)
{
	if(args!=2){
		CPrintToChat(client, "{green}[TFRP]{default} Usage: sm_setcash <name> <amt>");
		return Plugin_Handled;
	}

	char Arg1[48];
	GetCmdArg(1, Arg1, sizeof(Arg1));

	char Arg2[32];
	GetCmdArg(2, Arg2, sizeof(Arg2));

	if(StrEqual(Arg1, "@me"))
	{
		if(StrEqual(Arg2, "default"))
		{
		UD[client].iCash = StartCash;
		UpdateCash(client);
		CPrintToChat(client, "{green}[TFRP]{default} Set your balance to {mediumseagreen}%d", StartCash);
		return Plugin_Handled;
		}else{
			UD[client].iCash = StringToInt(Arg2);
			UpdateCash(client);
			CPrintToChat(client, "{green}[TFRP]{default} Set your balance to {mediumseagreen}%d", StringToInt(Arg2));
			return Plugin_Handled;
		}
	}

	for(int i = 1; i < MaxClients+1; i++)
	{

		if(IsClientInGame(i)){

			char curNameSetCash[48];
			GetClientName(i, curNameSetCash, sizeof(curNameSetCash));

			if(StrEqual(curNameSetCash, Arg1)){
				if(StrEqual(Arg2, "default")){
					UD[client].iCash = StartCash;
					UpdateCash(i);
					if(client>0){
						CPrintToChat(client, "{green}[TFRP]{default} Set {goldenrod}%s\'s {default}balance to {mediumseagreen}%d", curNameSetCash, StartCash);
					}else{
						PrintToServer("[TFRP] Set %s\'s balance to %d", curNameSetCash, StartCash);
					}
				}else{
					UD[client].iCash = StringToInt(Arg2);
					UpdateCash(i);
					if(client>0)
					{
						CPrintToChat(client, "{green}[TFRP]{default} Set {goldenrod}%s\'s {default}balance to {mediumseagreen}%d", curNameSetCash, StringToInt(Arg2));
					}else{
						PrintToServer("[TFRP] Set %s\'s balance to %d", curNameSetCash, StartCash);
					}
				}
			
				return Plugin_Handled;
			
			}
	    }
	}
	CPrintToChat(client, "{green}[TFRP]{default} Could not find player!");
	return Plugin_Handled;

}

// Salary Timer
public Action Timer_Cash(Handle timer, int client)
{
    // See if the player is in game and if they're a bot
	if(!IsClientInGame(client)) return Plugin_Continue;
	if(IsFakeClient(client)) return Plugin_Continue;
       	
	if(isArrested[client])
	{
		CPrintToChat(client, "{green}[TFRP]{default} You didn't get paid since you're arrested");
		return Plugin_Continue;
	}
	UD[client].iCash += UD[client].iJobSalary;
	UpdateCash(client);
	CPrintToChat(client, "{green}[TFRP]{default} You recieved{mediumseagreen} %d{default} from your paycheck", UD[client].iJobSalary);

	return Plugin_Continue;

} 

// Reset timer
public Action Timer_NoExploit(Handle timer, int client)
{
	if(!IsClientInGame(client)) return Plugin_Continue;
	for(int i = 0; i <= 2047; i++)
	{
		if(Doors[i] == client && IsGov[client])
		{
			Doors[i] = -1;
			DoorOwnedAmt[client] = DoorOwnedAmt[client] - 1;
		}
		if(EntOwners[i] == client && isPrinter[i] && IsGov[client] && !StrEqual(Job[client], "Mayor"))
		{
			PrinterMoney[i] = 0;
			PrintersOwned[client][PrinterTier[i]-1] = PrintersOwned[client][PrinterTier[i]-1] - 1;
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
		// See if their already that job.
		if(StrEqual(Job[Client], Item)){
			CPrintToChat(Client, "{green}[TFRP]{default} Your job is already {mediumseagreen}%s", Item);
		}else{

		// Cancel lottery if they had one running
		if(StrEqual(Job[Client], "Mayor") && isLottery == true)
		{
			CPrintToChatAll("{yellow}[TFRP ADVERT]{default} Mayor switched jobs, canceling lottery and refunding participants");
			CancelLottery();
		}
		
		// Find job in file and give client the rules of that job
		Handle DB4 = CreateKeyValues("Jobs");
		FileToKeyValues(DB4, JobPath);

		if(KvJumpToKey(DB4, Item, false)){
		// Will detect if admin later
			Job[Client] = Item;
			UD[Client].iJobSalary = KvGetNum(DB4, "Salary", 50); // If there isn't a salary it'll just be set to 50
			char IsPoliceStr[8];
			KvGetString(DB4, "IsGov", IsPoliceStr, sizeof(IsPoliceStr), "false");
			if(StrEqual(IsPoliceStr, "true"))
			{
				IsGov[Client] = true;
				TF2_ChangeClientTeam(Client, TFTeam_Blue);
			}else{
				IsGov[Client] = false;
				TF2_ChangeClientTeam(Client, TFTeam_Red);
			}
			
			ForcePlayerSuicide(Client);
			
			char CanOwnDoorsStr[8];
			KvGetString(DB4, "CanOwnDoors", CanOwnDoorsStr, sizeof(CanOwnDoorsStr), "true");
			CanOwnDoors[Client] = CanOwnDoorsStr;
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
	}else if(action == MenuAction_End)
	{
		CloseHandle(menuhandle);
	}
	return 0;
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
			ExplodeString(CmdItemName, "_", ItemInfoNextInv, 2, sizeof(ItemInfoNextInv));

			if(StrEqual(ItemInfoNextInv[0], "spawn")){
				SpawnInv(iClient, ItemInfoNextInv[1]);
			}else if(StrEqual(ItemInfoNextInv[0], "use")){
				UseItem(iClient, ItemInfoNextInv[1]);
			} else if(StrEqual(ItemInfoNextInv[0], "drop")){
				DropItem(iClient, ItemInfoNextInv[1]);
			}
		}
		case MenuAction_Cancel:
		{
			switch(Position)
			{
				case MenuCancel_ExitBack:
				{
					MenuInvDisplayBack(iClient);
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
								
									if(StrEqual(GetJobRequireBuy, "any") || StrEqual(GetJobRequireBuy, Job[Client]))
									{
										GiveItem(Client, ItemInfoNamePrice[0], 1);
					
										UD[Client].iCash = UD[Client].iCash - StringToInt(ItemInfoNamePrice[1]);
										UpdateCash(Client);
					
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
						if(IsGov[Client] && StrEqual(Job[Client], "Mayor") || !IsGov[Client])
						{
							GiveItem(Client, ItemInfoNamePrice[0], 1);
					
							UD[Client].iCash = UD[Client].iCash - StringToInt(ItemInfoNamePrice[1]);
							UpdateCash(Client);
					
							CPrintToChat(Client, "{green}[TFRP]{default} You bought {mediumseagreen}%s{default} for {mediumseagreen}%d.{default} Your balance is now {mediumseagreen}%d", ItemInfoNamePrice[0], StringToInt(ItemInfoNamePrice[1]), UD[Client].iCash);
						}
					}
					
				} else {
					CPrintToChat(Client, "{green}[TFRP]{default} Insufficent funds");
				}
		
			} else if(StrEqual(CmdShop, "sel")){
				SellItem(Client, ItemInfoNamePrice[0], StringToInt(ItemInfoNamePrice[1])/ShopReturn);
				
			}
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



public void NextInvMenu(int client, char[] iteminfo, int itemcount)
{
	Handle menuhandleNInv = CreateMenu(MenuCallBackNextInv);
	SetMenuTitle(menuhandleNInv, "[TFRP] You have %d %s", itemcount, iteminfo);

	char SpawnItemInfo[32],
		UseItemInfo[32],
		DropItemInfo[32];
	FormatEx(SpawnItemInfo, sizeof(SpawnItemInfo), "spawn_%s", iteminfo);
	FormatEx(UseItemInfo, sizeof(UseItemInfo), "use_%s", iteminfo);
	FormatEx(DropItemInfo, sizeof(DropItemInfo), "drop_%s", iteminfo);
	
	// First off, we need to see if the item is spawnable, this is located in the shop file under "type"
	Handle DB2 = CreateKeyValues("Shop");

	FileToKeyValues(DB2, ShopPath);
	if(KvJumpToKey(DB2, iteminfo, false))
	{
		char spawning_item[48];
		KvGetString(DB2, "type", spawning_item, sizeof(spawning_item), "item");
		if(StrEqual(spawning_item, "ent"))
		{
			AddMenuItem(menuhandleNInv, SpawnItemInfo, "Spawn Item");
		}
		if (StrEqual(spawning_item, "item", false) || StrEqual(spawning_item, "weapon"))
		{
			AddMenuItem(menuhandleNInv, UseItemInfo, "Use Item");
		}
	}
	else
	{
		CPrintToChat(client, "{green}[TFRP]{red} ERROR: {default}For some reason, the item couldn't be found in the database. Maybe the item was deleted from the server?");
	}
	//Supprised this worked out so well -Squid
	
	AddMenuItem(menuhandleNInv, DropItemInfo, "Drop Item");
	SetMenuPagination(menuhandleNInv, 7);
	SetMenuExitButton(menuhandleNInv, true);
	SetMenuExitBackButton(menuhandleNInv, true);
	DisplayMenu(menuhandleNInv, client, 250);
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


public int MenuCallBackItems(Handle menuhandleitems, MenuAction action, int iClient, int Position)
{
	if(action == MenuAction_Select)
	{
		char ItemName[32];

		Handle hArray = GetArrayCell(hItemArray[iClient], Position);

		GetArrayString(hArray, 0, ItemName, sizeof(ItemName));

		if(cvarTFRP[Debug].BoolValue)
		{
			PrintToServer("[TFRP] Item selected: %s", ItemName);
			PrintToServer("[TFRP] Item count: %d", GetArrayCell(hArray, 1));
		}

		NextInvMenu(iClient, ItemName, GetArrayCell(hArray, 1));

	} else if(action == MenuAction_End)
	{
		CloseHandle(menuhandleitems);
	}
	return 0;
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

public int NextCatShopMenu(int client, char[] iteminfocatshop)
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
			if(StrEqual(iteminfocatshop, GetCategoryShop) && !StrEqual(GetCategoryShop, "NONE"))
			{
				PushArrayString(hItemListShop, GetItem);
			}

    } while (KvGotoNextKey(DB2,false));

	CloseHandle(DB2);

	Handle menuhandle = CreateMenu(MenuCallBackShopItems);
	SetMenuTitle(menuhandle, "[TFRP] %s Items. Balance: %d", iteminfocatshop, UD[client].iCash);


	for(int i = 0 ; i < GetArraySize(hItemListShop) ; i++) 
	{
		char itemBuffer[32];
		GetArrayString(hItemListShop, i, itemBuffer, sizeof(itemBuffer));	
		AddMenuItem(menuhandle, itemBuffer, itemBuffer);
	}

	SetMenuPagination(menuhandle, 7);
	SetMenuExitButton(menuhandle, true);
	SetMenuExitBackButton(menuhandle, true);
	DisplayMenu(menuhandle, client, 250);

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
	// if(action == MenuAction_Select)
	// {
	// 	char ItemNameShopItem[32];

	// 	GetMenuItem(menuhandle, Position, ItemNameShopItem, sizeof(ItemNameShopItem));
	// 	BuyShopMenu(Client, ItemNameShopItem);
		
	// } else if(action == MenuAction_End)
	// {
	// 	CloseHandle(menuhandle);
	// }
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
		SellItem(Client, ItemNamePriceNPC[0], StringToInt(ItemNamePriceNPC[1]));	

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
	SetMenuTitle(menuhandle, "[TFRP] Place hit on %s for %d?", NextHitPlaceName, HitPrice);

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
		if(UD[Client].iCash  < HitPrice)
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
			UD[curPlacerHit].iCash -= HitPrice;
			
			char GetHitPlacerName[MAX_NAME_LENGTH];
			GetClientName(curPlacerHit, GetHitPlacerName, sizeof(GetHitPlacerName));
			
			char GetHitVictimName[MAX_NAME_LENGTH];
			GetClientName(curHitVictim, GetHitVictimName, sizeof(GetHitVictimName));
			
			CPrintToChat(curPlacerHit, "{green}[TFRP]{default} You set a hit on {mediumseagreen}%s{default} for{mediumseagreen} %d", GetHitVictimName, HitPrice);
			CPrintToChat(curHitman, "{green}[TFRP]{default} {mediumseagreen}%s set a hit on {mediumseagreen}%s for {mediumseagreen}%d", GetHitPlacerName, GetHitVictimName, HitPrice);
			
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

		for(int i = 0; i <= 4; i++)
		{
			if(i != 0 && DoorOwners[GiveKeysDoor][i] == 0)
			{
				DoorOwners[GiveKeysDoor][i] = GiveKeysIndex;
				TFRP_PrintToChat(client, "Gave keys to {goldenrod}%s{default}. You can reverse this with sm_revokekeys", GiveKeysNameAndDoor[0]);
				break;
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

		for(int i = 0; i <= 4; i++)
		{
			if(i != 0 && DoorOwners[RemKeysDoor][i] == RemKeysIndex)
			{
				DoorOwners[RemKeysDoor][i] = 0;
				TFRP_PrintToChat(client, "Revoked keys from {goldenrod}%s", RemKeysNameAndDoor[0]);
				break;
			}
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
				char GetSetWarrantName[MAX_NAME_LENGTH];
				GetClientName(i, GetSetWarrantName, sizeof(GetSetWarrantName));
			
				char WarrantSetName[MAX_NAME_LENGTH];
				GetMenuItem(menuhandle, position, WarrantSetName, sizeof(WarrantSetName));
				
				if(StrEqual(GetSetWarrantName, WarrantSetName))
				{
					if(HasWarrant[i])
					{
						CPrintToChat(client, "{green}[TFRP]{default} This player already has a warrant!");
						break;
					}
					HasWarrant[i] = true;
					SetWarrantHud(i);
					CreateTimer(WarrantTime, Timer_Warrant, i);
					
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

	if(!isArrested[client])
	{
		if(KvJumpToKey(DB, Job[client], false))
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
    
	if(!isArrested[client])
	{
		TF2_AddCondition(client, TFCond_Ubercharged, 5.0);
		TF2_AddCondition(client, TFCond_MegaHeal, 5.0);
	}
	
	if(isArrested[client])
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
	if(KvJumpToKey(DB, Job[client], false))
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
			
			if(StrEqual(IsPrinterSpawn, "true") && IsGov[client] && !StrEqual(Job[client], "Mayor"))
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
							
							if(StrEqual(GetJobRequireBuy, "any") || StrEqual(GetJobRequireBuy, Job[client]))
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
				}
				/*else if(StrEqual(curEnt, "Blackjack Table"))
				{
					SpawnBlackjackTable(client, EntIndex);
				}*/
				
		
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



// Add items to people's inventories
public int GiveItem(int iClient, char[] GiveItemStr, int amt) //Can also give negative (so no RemItem any more)
{
	char sAuth[32],
		sQuery[MAX_QUERY_SIZE];
	GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth));

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, amt);
	WritePackString(hPack, sAuth);
	WritePackString(hPack, GiveItemStr);

	Format(sQuery, sizeof(sQuery), sQuery_UpdateUserItem, sUserInvTable, amt, sAuth, GiveItemStr);
	if (cvarTFRP[SQLDebug].BoolValue)
		PrintToServer("[TFRP] GiveItem query: %s", sQuery);
	
	SQL_TQuery(g_hSQL, SQLCall_GiveItem, sQuery, hPack);
	return 0;
}

void SQLCall_GiveItem(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
    {
		CloseHandle(data);
		LogError("[TFRP] Failed to run GiveItem query: %s", error);
		PrintToServer("[TFRP] Failed to run GiveItem query: %s", error);
		return;
    }
	if (SQL_GetAffectedRows(hndl) < 1)
	{
		char sAuth[32],
			sID[32],
			sQuery[MAX_QUERY_SIZE];
		ResetPack(data);
		int amt = ReadPackCell(data);
		ReadPackString(data, sAuth, sizeof(sAuth));
		ReadPackString(data, sID, sizeof(sID));
		CloseHandle(data);

		Format(sQuery, sizeof(sQuery), sQuery_InsertUserItem, sUserInvTable, sAuth, sID, amt);
		if (cvarTFRP[SQLDebug].BoolValue)
			PrintToServer("[TFRP] GiveItem Insert query: %s", sQuery);

		SQL_TQuery(g_hSQL, SQLCall_GiveItemInsert, sQuery);
	}
	else 
	{
		CloseHandle(data);
	}
}

void SQLCall_GiveItemInsert(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
    {
		LogError("[TFRP] Failed to run GiveItem Insert query: %s", error);
		PrintToServer("[TFRP] Failed to run GiveItem Insert query: %s", error);
		return;
    }
}

// Removes item in return for cash
public int SellItem(int iClient, char[] SellItemStr, int sellPrice)
{

	char sAuth[32],
		sQuery[MAX_QUERY_SIZE];
	GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth));

	DataPack hPack = CreateDataPack();
	WritePackCell(hPack, iClient); 
	WritePackCell(hPack, sellPrice);
	WritePackString(hPack, SellItemStr);

	Format(sQuery, sizeof(sQuery), sQuery_GetUserItem, sUserInvTable, sAuth, SellItemStr);
	
	if (cvarTFRP[SQLDebug].BoolValue)
		PrintToServer("[TFRP] SellItem query: %s", sQuery);

	SQL_TQuery(g_hSQL, SQLCall_SellItem, sQuery, hPack);

	return 0;
}

void SQLCall_SellItem(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
    {
		CloseHandle(data);
		LogError("[TFRP] Failed to run SellItem Get query: %s", error);
		PrintToServer("[TFRP] Failed to run SellItem Get query: %s", error);
		return;
    }
	//Get client index
	char sItemName[32];
	ResetPack(data);
	int iClient = ReadPackCell(data);
	int sellPrice = ReadPackCell(data);
	ReadPackString(data, sItemName, sizeof(sItemName));
	CloseHandle(data);

	if (SQL_GetRowCount(hndl) <= 0)
	{
		CPrintToChat(iClient, "{green}[TFRP]{default} Your inventory does not contain {mediumseagreen}%s.", sItemName);
		return;
	}
	else
	{
		while (SQL_FetchRow(hndl))
		{
			if(SQL_FetchInt(hndl, 0) < 1)
			{
				CPrintToChat(iClient, "{green}[TFRP]{default} Your inventory does not contain {mediumseagreen}%s.", sItemName);
				return;
			} 
			else
			{
				UD[iClient].iCash += sellPrice;
				UpdateCash(iClient);
				GiveItem(iClient, sItemName, -1);
				CPrintToChat(iClient, "{green}[TFRP]{default} You sold {mediumseagreen}%s{default} for {mediumseagreen}%d.{default} Your balance is now {mediumseagreen}%d", sItemName, sellPrice, UD[iClient].iCash);
				return;
			}
		}
	}
}

// Using items
public int UseItem(int client, char[] ItemUse)
{
	
	if(!IsPlayerAlive(client))
	{
		CPrintToChat(client, "{green}[TFRP]{default} You cannot use items while dead!");
		return 0;
	}
	
	
	// Find weaponid if the item is a weapon
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
							
					if(StrEqual(GetJobRequireBuy, "any") || StrEqual(GetJobRequireBuy, Job[client]))
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


	if(DroppedItems[client] >= maxDroppedItems)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You can only have 10 dropped items.");
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
				CPrintToChat(client, "{green}[TFRP]{default} You dropped a {mediumseagreen}%s", ItemDrop);
				DroppedItems[client] = DroppedItems[client] + 1;
				
				char FormatClientDroppedItem[32];
				FormatEx(FormatClientDroppedItem, sizeof(FormatClientDroppedItem), "%d:%s", client, ItemDrop);
				droppedItemsString[EntIndex] = FormatClientDroppedItem;
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
	
	if(StrEqual(droppedItemsString[PickupClientAim], "__no__item__"))
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be looking at a dropped item!");
		return Plugin_Handled;
	}
	
	char GetClientDroppedItem[32][32];
	ExplodeString(droppedItemsString[PickupClientAim], ":", GetClientDroppedItem, 2, sizeof(GetClientDroppedItem));
	
	int PickupItemOwner = StringToInt(GetClientDroppedItem[0]);
	
	float ClientPosPickup[3];
	GetClientAbsOrigin(client, ClientPosPickup);
	
	float PickupPos[3];
	GetEntPropVector(PickupClientAim, Prop_Send, "m_vecOrigin", PickupPos);

	if(GetVectorDistance(ClientPosPickup, PickupPos) <= 150){
		
		GiveItem(client, GetClientDroppedItem[1], 1);
		CPrintToChat(client, "{green}[TFRP]{default} You picked up a {mediumseagreen}%s!", GetClientDroppedItem[1]);
		
		AcceptEntityInput(PickupClientAim, "kill");
		RemoveEdict(PickupClientAim);
		
		droppedItemsString[PickupClientAim] = "__no__item__";
		DroppedItems[PickupItemOwner] = DroppedItems[PickupItemOwner] - 1;
		
		
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
	
	if(isArrested[client])
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
		UpdateCash(client);
		UD[curPlayerGiveMoney].iCash += StringToInt(MoneyPtoP);
		UpdateCash(curPlayerGiveMoney);
		
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

public Action Command_BUYMENU(int client, int args)
{
	
	if(isArrested[client])
	{
		CPrintToChat(client, "{green}[TFRP]{default} You cannot do /shop while arrested.");
		return Plugin_Handled;
	}

	OpenBuyMenu(client);

	return Plugin_Handled;	

}

public void OpenBuyMenu(int iClient)
{
	// This is the menu version of the buy command, supports items with spaces in their names!
	Handle menuhandle = CreateMenu(MenuCallBackShop);
	SetMenuTitle(menuhandle, "[TFRP] Item Shop. Balance: %d", UD[iClient].iCash);

	
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
		AddMenuItem(menuhandle, itemShopBuffer, itemShopBuffer);
	}

	SetMenuPagination(menuhandle, 7);
	SetMenuExitButton(menuhandle, true);
	DisplayMenu(menuhandle, iClient, 250);
}

public Action Command_Setjob(int client, int args)
{

	char SetJobArg1[32];
	GetCmdArg(1, SetJobArg1, sizeof(SetJobArg1));
	
	if(StrEqual(SetJobArg1, "@me")){
	char SetJobArg2[32];
	GetCmdArg(1, SetJobArg2, sizeof(SetJobArg2));
		
	Job[client] = SetJobArg2;
	}else{
		char NameSetJob[48];
		GetCmdArgString(NameSetJob, sizeof(NameSetJob));
		if(StrContains(NameSetJob, ":", true) != -1)
		{
			char SeperateNameJob[MAX_NAME_LENGTH][32];
			ExplodeString(NameSetJob, ":", SeperateNameJob, 2, sizeof(SeperateNameJob));
			
			for(int i = 0; i <= MaxClients + 1; i++)
			{
				
				if( i > 0)
				{
					if(IsClientInGame(i))
					{
						char FindTargetSetJob[MAX_NAME_LENGTH];
						GetClientName(i, FindTargetSetJob, sizeof(FindTargetSetJob));
						if(StrEqual(FindTargetSetJob, SeperateNameJob[0]))
						{
							Job[i] = SeperateNameJob[1];
						}
					}
				}
			}
			
		}else{
			CPrintToChat(client, "{green}[TFRP]{default} Usage: sm_setjob <name> :<job>");
			return Plugin_Handled;
		}
	}
	
	
	return Plugin_Handled;
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
	FormatEx(HudJob, sizeof(HudJob), "Job: %s", Job[client]);
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
	
	return Plugin_Continue;
}

public Action WelcomeHUD(Handle timer, int client)
{
	if(!IsClientInGame(client)) return Plugin_Continue;
	if(IsFakeClient(client)) return Plugin_Continue;
	if(WelcomeHuds[client])
	{
		SetHudTextParams(-1.0, 0.090, 1.0, 184, 0, 46, 200, 0, 6.0, 0.0, 0.0);
		ShowSyncHudText(client, hHud7, "Welcome to TFRP! Do /jobs to get started!");
	}
	return Plugin_Continue;
}

public Action WelcomeHUDStop(Handle timer, int client)
{
	WelcomeHuds[client] = false;
	return Plugin_Continue;
}


////////////////
// Inventory //
///////////////


public Action Command_INVENTORY(int client, int args)
{
	if(isArrested[client])
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
	char sAuth[32],
		sQuery[MAX_QUERY_SIZE];
	GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth));

	DataPack hPack = CreateDataPack();
	WritePackCell(hPack, iClient); 

	Format(sQuery, sizeof(sQuery), sQuery_GetUserItems, sUserInvTable, sAuth);
	
	if (cvarTFRP[SQLDebug].BoolValue)
		PrintToServer("[TFRP] Inventory query: %s", sQuery);

	SQL_TQuery(g_hSQL, SQLCall_OpenInventory, sQuery, hPack);
}

void SQLCall_OpenInventory(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
    {
		CloseHandle(data);
		LogError("[TFRP] Failed to run OpenInventory query: %s", error);
		PrintToServer("[TFRP] Failed to run OpenInventory query: %s", error);
		return;
    }
	//Get client index
	ResetPack(data);
	int iClient = ReadPackCell(data);
	CloseHandle(data);

	int count = SQL_GetRowCount(hndl);

	Handle hInvMenu = CreateMenu(MenuCallBackItems);
	SetMenuTitle(hInvMenu, "[TFRP] %d Items. Balance : %d", count, UD[iClient].iCash);

	if(hItemArray[iClient] == INVALID_HANDLE)
		hItemArray[iClient] = CreateArray(); 
	//Storing in a Array in order to only run the query once took me too long -Squid
	
	ClearArray2(hItemArray[iClient]);

	while (SQL_FetchRow(hndl)) //This goes on until there are no more rows.
	{
		Handle hArray = CreateArray(ByteCountToCells(1024));
		char buffer[32],
			ItemName[32];

		SQL_FetchString(hndl, 0, ItemName, sizeof(ItemName));

		if(SQL_FetchInt(hndl, 1) > 0) //Lets not draw items we dont have
		{
			Format(buffer, sizeof(buffer), "%s (%d)", ItemName, SQL_FetchInt(hndl, 1));
			AddMenuItem(hInvMenu, ItemName, buffer);
			PushArrayString(hArray, ItemName);
			PushArrayCell(hArray, SQL_FetchInt(hndl, 1));
			
			PushArrayCell(hItemArray[iClient], hArray);
		}
	}

	if (GetMenuItemCount(hInvMenu) < 1)
	{
		AddMenuItem(hInvMenu, "", "[Inventory Empty]", ITEMDRAW_DISABLED); //So it doesn't seem like the plugin gave up
	}

	//Wow I've got the full inventory, now it's time to show the menu with it.
	SetMenuPagination(hInvMenu, 7);
	SetMenuExitButton(hInvMenu, true);
	DisplayMenu(hInvMenu, iClient, 250);
}

void MenuInvDisplayBack(int iClient) //Assuming things did not change :/
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
			AddMenuItem(hInvMenu, ItemName, buffer);
		}
	}

	SetMenuPagination(hInvMenu, 7);
	SetMenuExitButton(hInvMenu, true);
	DisplayMenu(hInvMenu, iClient, 250);
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
		TFRP_PrintToChat(client, "Added {mediumseagreen}1 %s{default} to the {mediumseagreen}Sandvicuh Table",ingredientSandvich);
		if(STableIngredients[curSandvichTable][0] >= 1 && STableIngredients[curSandvichTable][1] >= 1 >= STableIngredients[curSandvichTable][2] >= 1 && STableIngredients[curSandvichTable][3] >= 1)
		{
			TFRP_PrintToChat(client, "All ingredients have been added to the table, making {mediumseagreen}Sandvich{default} in {mediumseagreen}%f{default} seconds", SandvichMakeTime);
			CreateTimer(SandvichMakeTime, Timer_Sandvich, client);
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
							
							if(StrEqual(GetJobReqDel, "any") || StrEqual(GetJobReqDel, Job[client]))
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
				EntOwners[i] = 0;
				EntItems[i] = "_no_item_";
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
		AusFuels[curAusDrill] = AusFuels[curAusDrill] + FuelPerCan;
		CPrintToChat(client, "{green}[TFRP]{default} Added {mediumseagreen}%d{default} fuel to the {mediumseagreen}Australium Drill", FuelPerCan);
		GiveItem(client, "Fuel", -1);
	}

	return 0;
}

// Use fuel
public Action Timer_AusDrillFuelTimer(Handle timer, int curAusDrillFuelTimer)
{
	if(curAusDrillFuelTimer == -1 || !IsValidEntity(curAusDrillFuelTimer) || !StrEqual(EntItems[curAusDrillFuelTimer], "Australium Drill")) return Plugin_Continue;
	{
		if(AusFuels[curAusDrillFuelTimer] > 0) AusFuels[curAusDrillFuelTimer] = AusFuels[curAusDrillFuelTimer] - FuelConsumptionPerSecond;	
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
	if(StrEqual(Job[attacker], "Australium Miner"))
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
	if(StrEqual(Job[attacker], "Australium Miner"))
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
	CreateTimer(AustraliumCleanTime, Timer_AusCleaner, curAusCleaner);
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
	if(StrEqual(Job[attacker], "Australium Miner"))
	{
		if(AusPacks[victim] == 5)
		{
			AusPacks[victim] = 0;
			GiveItem(attacker, "Full Australium Package", 1);
			AcceptEntityInput(victim, "kill");
			RemoveEdict(victim);
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
	
	if(AusDrillsOwned[client] >= AUSTRALIUM_MAX_PACKAGES)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You already reached the max %d drills!", AUSTRALIUM_MAX_PACKAGES);
		GiveItem(client, "Australium Drill", 1);
		AcceptEntityInput(index, "kill");
		RemoveEdict(index);
		return 0;
	}
	
	AusMined[index] = 0;
	AusFuels[index] = 0;
	AusDrillsOwned[client]++;

	CreateTimer(AustraliumDrillTime, Timer_AusDrill, index, TIMER_REPEAT);
	CreateTimer(1.0, Timer_AusDrillFuelTimer, index, TIMER_REPEAT);

	SDKHookEx(index, SDKHook_OnTakeDamage, OnTakeDamageAusDrill);
	return 0;
}

public int AddAusCleaner(int index, int client)
{
	if(AusCleanersOwned[client] >= AUSTRALIUM_MAX_CLEANERS)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You already reached the max %d cleaners!", AUSTRALIUM_MAX_CLEANERS);
		GiveItem(client, "Australium Cleaner", 1);
		AcceptEntityInput(index, "kill");
		RemoveEdict(index);
		return 0;
	}
	
	SDKHookEx(index, SDKHook_OnTakeDamage, OnTakeDamageAusCleaner);
	AusCleanersOwned[client]++;
	return 0;
}

public int AddAusPackage(int index, int client)
{
	if(AusPacksOwned[client] >= AUSTRALIUM_MAX_PACKAGES)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You already reached the max %d packages!", AUSTRALIUM_MAX_PACKAGES);
		GiveItem(client, "Empty Package", 1);
		AcceptEntityInput(index, "kill");
		RemoveEdict(index);
		return 0;
	}

	AusPacks[index] = 0;
	SDKHookEx(index, SDKHook_OnTakeDamage, OnTakeDamageAusPackage);
	AusPacksOwned[client]++;
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
	if(!IsGov[arrestTarget]){

		if(isArrested[arrestTarget] && client != -90)
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
			isArrested[arrestTarget] = true;
			
			JailTimes[arrestTarget] = JailTime;
			
			CreateTimer(1.0, Timer_JailTime, arrestTarget, TIMER_REPEAT);
			CreateTimer(0.1, Timer_JailHud, arrestTarget, TIMER_REPEAT);
			CreateTimer(JailTime, Timer_Jail, arrestTarget);
			
		}
		return 0;
	}else{
		CPrintToChat(client, "{green}[TFRP]{default} You cannot arrest other police officers.");
		return 0;
	}
}

public Action Command_Arrest(int client, int args)
{
	if(!IsGov[client])
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be a {mediumseagreen}Government Offical{default} to arrest people!");
		return Plugin_Handled;
	}
	
	if(StrEqual(Job[client],"Mayor"))
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
	if(!IsGov[client])
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be a {mediumseagreen}Government Offical{default} to use {mediumseagreen}Police Radio.");
	}
	
	for(int i = 0; i <= MaxClients + 1; i++)
	{
		if(IsGov[i])
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
	isArrested[client] = false;
	JailTimes[client] = 0.0;
	ForcePlayerSuicide(client);
	CPrintToChat(client, "{green}[TFRP]{default} You've served your sentance");
}	

// Arrested Hud

public Action Timer_JailHud(Handle timer, int client)
{
	if(!IsClientInGame(client)) return Plugin_Continue;
	if(IsFakeClient(client)) return Plugin_Continue;
	if(!isArrested[client]) return Plugin_Continue;
	
	char ArrestHudTime[32];
	FormatEx(ArrestHudTime, sizeof(ArrestHudTime), "Jail Time: %f", JailTimes[client]);
	SetHudTextParams(-1.0, 0.30, 1.0, 0, 255, 0, 200, 0, 6.0, 0.0, 0.0);
	ShowSyncHudText(client, hHud11, ArrestHudTime);

	return Plugin_Continue;
}

public Action Timer_JailTime(Handle timer, int client)
{
	if(!isArrested[client]) return Plugin_Continue;
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
	if(!StrEqual(Job[client], "Bank Robber"))
	{
		CPrintToChat(client, "{green}[TFRP]{default} You must be a {mediumseagreen}Bank Robber{default} to rob banks!");
		return Plugin_Handled;
	}
	
	int curCopsRob = 0;
	for(int i = 0; i <= MaxClients; i++)
	{
		if(IsGov[i]) curCopsRob++;
	}
	if(curCopsRob != CopsToRob)
	{
		CPrintToChat(client, "{green}[TFRP]{default} There has to be atleast %d cops on to start a robbery.", CopsToRob);
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
			CreateTimer(bankRobTime, Timer_RobBank, client);
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
	UpdateCash(client);
	isBeingRobbed = false;
	return Plugin_Continue;
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
			
			if(isBeingRobbed)
			{
				bankRobHudTime = bankRobHudTime - 1;
				char BankHudTime[32];
				FormatEx(BankHudTime, sizeof(BankHudTime), "Time Left: %d", bankRobHudTime);
				SetHudTextParams(-1.0, 0.30, 1.0, 0, 255, 0, 200, 0, 6.0, 0.0, 0.0);
				ShowSyncHudText(client, hHud5, BankHudTime);
			}
			SetHudTextParams(-1.0, 0.30, 1.0, 0, 255, 0, 200, 0, 6.0, 0.0, 0.0);
			ShowSyncHudText(client, hHud6, BankHudWorth);
		}
	}
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
	
	if(DoorOwnedAmt[client] >= maxDoors)
	{
		CPrintToChat(client, "{green}[TFRP]{default} You have reached the max {mediumseagreen}%d{default} doors.", maxDoors);
		return Plugin_Handled;
	}
	
	if(StrEqual(CanOwnDoors[client], "false"))
	{
		CPrintToChat(client, "{green}[TFRP]{default} You cannot own doors as a {mediumseagreen}%s", Job[client]);
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
			UpdateCash(client);
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
		UpdateCash(client);
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

	} else if(IsGov[client] && Doors[curLookingDoorSell] == 420)
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

	if(foundOwnerDoor || Doors[curLookingDoorLock] == 420 && IsGov[client])
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
				FormatEx(FormatRemKeysIndexName, sizeof(FormatRemKeysIndexName), "%d:%s-%d", i, GetMenuNameRemKeys, RemGiveKeyDoor); 
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
	if(!isLockpickingPlayers[lockpicker]) return Plugin_Continue;
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
	if(!isLockpickingPlayers[lockpickerMove]) return Plugin_Continue;
	
	float GetLockpickerVecMove[3];
	GetClientAbsOrigin(lockpickerMove, GetLockpickerVecMove);
	
	float GetLockpickerVecDoor[3];
	GetEntPropVector(curDoorLockpickMove, Prop_Send, "m_vecOrigin", GetLockpickerVecDoor);
	
	if(GetVectorDistance(GetLockpickerVecMove, GetLockpickerVecDoor) > 275)
	{
		isLockpicking[curDoorLockpickMove] = 0;
		isLockpickingPlayers[lockpickerMove] = false;
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
		isLockpickingPlayers[client] = true;
		GiveItem(client, "Lockpick", -1);
		CreateTimer(lockpickTime, LockpickTimer, curLookingLockpickDoor);
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
		if(PrintersOwned[client][0] >= maxPrintersTier1)
		{
			CPrintToChat(client, "{green}[TFRP]{default} You have already reached the max {mediumseagreen}%d Bronze Printers!", maxPrintersTier1);
			AcceptEntityInput(printerIndex, "kill");
			RemoveEdict(printerIndex);
			GiveItem(client, "Bronze Money Printer", 1);
			return 0;
		}
	}else if(StrEqual(Tier, "Silver"))
	{
		if(PrintersOwned[client][1] >= maxPrintersTier2)
		{
			CPrintToChat(client, "{green}[TFRP]{default} You have already reached the max {mediumseagreen}%d Silver Printers!", maxPrintersTier2);
			AcceptEntityInput(printerIndex, "kill");
			RemoveEdict(printerIndex);
			GiveItem(client, "Silver Money Printer", 1);
			return 0;
		}
	}else if(StrEqual(Tier, "Gold"))
	{
		if(PrintersOwned[client][2] >= maxPrintersTier3)
		{
			CPrintToChat(client, "{green}[TFRP]{default} You have already reached the max {mediumseagreen}%d Gold Printers!", maxPrintersTier3);
			AcceptEntityInput(printerIndex, "kill");
			RemoveEdict(printerIndex);
			GiveItem(client, "Gold Money Printer", 1);
			return 0;
		}
	}
	
	if(StrEqual(Tier, "Bronze"))
	{
		SDKHookEx(printerIndex, SDKHook_OnTakeDamage, OnTakeDamagePrinter);
		PrintersOwned[client][0] = PrintersOwned[client][0] + 1;
		PrinterMoney[printerIndex] = 0;
		PrinterTier[printerIndex] = 1;
		CreateTimer(moneyPrintTimeTier1, Timer_PrinterTier1, printerIndex, TIMER_REPEAT);
		isPrinter[printerIndex] = true; 
		return 0;
		
	}else if(StrEqual(Tier, "Silver"))
	{
		SDKHookEx(printerIndex, SDKHook_OnTakeDamage, OnTakeDamagePrinter);
		PrintersOwned[client][1] = PrintersOwned[client][1] + 1;
		PrinterMoney[printerIndex] = 0;
		PrinterTier[printerIndex] = 2;
		CreateTimer(moneyPrintTimeTier2, Timer_PrinterTier2, printerIndex, TIMER_REPEAT);
		isPrinter[printerIndex] = true; 
		return 0;
	}else if(StrEqual(Tier, "Gold"))
	{
		SDKHookEx(printerIndex, SDKHook_OnTakeDamage, OnTakeDamagePrinter);
		PrintersOwned[client][2] = PrintersOwned[client][2] + 1;
		PrinterMoney[printerIndex] = 0;
		PrinterTier[printerIndex] = 3;
		CreateTimer(moneyPrintTimeTier3, Timer_PrinterTier3, printerIndex, TIMER_REPEAT);
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
		UpdateCash(attacker); //Why was this not here before?
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
	PrinterMoney[printerIndex] = PrinterMoney[printerIndex] + printerTier1MoneyPerPrint;
	float printerPosTimer1[3];
	GetEntPropVector(printerIndex, Prop_Send, "m_vecOrigin", printerPosTimer1);
	EmitAmbientSound(PRINTER_PRINTED_SOUND, printerPosTimer1, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
	return Plugin_Continue;
}

public Action Timer_PrinterTier2(Handle timer, int printerIndex)
{
	if(EntOwners[printerIndex] == 0) return Plugin_Continue;
	
	PrinterMoney[printerIndex] = PrinterMoney[printerIndex] + printerTier2MoneyPerPrint;
	float printerPosTimer1[3];
	GetEntPropVector(printerIndex, Prop_Send, "m_vecOrigin", printerPosTimer1);
	EmitAmbientSound(PRINTER_PRINTED_SOUND, printerPosTimer1, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
	return Plugin_Continue;
}

// Gold (Tier 3) printer
public Action Timer_PrinterTier3(Handle timer, int printerIndex)
{
	if(EntOwners[printerIndex] == 0) return Plugin_Continue;
	PrinterMoney[printerIndex] = PrinterMoney[printerIndex] + printerTier3MoneyPerPrint;
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
	PrintersOwned[EntOwners[printerIndex]][PrinterTier[printerIndex]-1] = PrintersOwned[EntOwners[printerIndex]][PrinterTier[printerIndex]-1] - 1;
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
	
	if(StrEqual(Job[GetHitmanLook], "Hitman"))
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
	
	if(!StrEqual(Job[client], "Mayor"))
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
	
	if(LotAmt > maxLottery)
	{
		CPrintToChat(client, "{green}[TFRP]{default} The max a lottery can be worth is {mediumseagreen}%d!", maxLottery);
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
	CreateTimer(lotTime, Timer_Lottery, client);
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
		if(playingLot[GetRandomLot]) foundLotWinner = true;
	}

	UD[GetRandomLot].iCash += LotAmt;
	UpdateCash(GetRandomLot);
	
	char LotWinnerName[MAX_NAME_LENGTH];
	GetClientName(GetRandomLot, LotWinnerName, sizeof(LotWinnerName));
	
	CPrintToChatAll("{green}[TFRP]{goldenrod}%s{default} won the lottery and won {mediumseagreen}%d!", LotWinnerName, LotAmt);

	for(int i = 0; i <= MaxClients; i++)
	{
		playingLot[i] = false;
	}
	
	LotAmt = 0;
	lotteryStarter = 0;
	isLottery = false;
	CreateTimer(timeBetweenLot, Timer_LotteryReset);
	
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
	playingLot[client] = true;
	
	return Plugin_Handled;
}

public int CancelLottery()
{
	for(int i = 0; i <= MAXPLAYERS; i++)
	{
		if(playingLot[i])
		{
			UD[i].iCash += LotAmt;
			CPrintToChat(i, "{green}[TFRP]{default} You were refunded{mediumseagreen} %d{default} because the lottery was canceled");
		}
		
		playingLot[i] = false;
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
	if(!StrEqual(Job[client], "Mayor"))
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
	if(!StrEqual(Job[client], "Mayor"))
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
	if(!IsGov[client])
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
	
	if(HasWarrant[Doors[GetDoorRam]])
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
	if(!StrEqual(Job[client], "Mayor") && !StrEqual(Job[client], "Police Chief"))
	{
		CPrintToChat(client, "{green}[TFRP]{default} Only the Police Chief and Mayor can set warrants!");
		return Plugin_Handled;
	}
	
	Handle menuhandle = CreateMenu(MenuCallBackWarrant);
	SetMenuTitle(menuhandle, "[TFRP] Warrant Menu");
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsGov[i])
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
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			char GetWarrantNameHud[MAX_NAME_LENGTH];
			GetClientName(client, GetWarrantNameHud, sizeof(GetWarrantNameHud));
			PrintToChat(i, "%s", GetWarrantNameHud);
			char WarrantHud[32];
			FormatEx(WarrantHud, sizeof(WarrantHud), "A warrant has been set on %s", GetWarrantNameHud);
			SetHudTextParams(-1.0, 0.070, 8.0, 255, 79, 79, 200, 0, 6.0, 0.0, 0.0);
			ShowSyncHudText(i, hHud8, "%s", WarrantHud);
		}
	}	
	
	return 0;
}

public Action Timer_Warrant(Handle timer, int client)
{
	
	HasWarrant[client] = false;
	
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
	if(client == 0){
		PrintToServer("[TFRP] Cannot run command from console!");
		return Plugin_Handled;
	}
	
	char GetBringName[MAX_NAME_LENGTH];
	GetCmdArgString(GetBringName, sizeof(GetBringName));
	
	bool FoundBring = false;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		
		if(IsClientInGame(i))
		{
			char VerifyBringName[MAX_NAME_LENGTH];
			GetClientName(i, VerifyBringName, sizeof(VerifyBringName));
			if(StrEqual(VerifyBringName, GetBringName))
			{
				
				if(!IsPlayerAlive(i))
				{
					TFRP_PrintToChat(client, "{goldenrod}%s{default} must be alive!", VerifyBringName);
					FoundBring = true;
					break;
				}
				float BringClientOrigin[3];
				GetClientAbsOrigin(client, BringClientOrigin);
				TeleportEntity(i, BringClientOrigin, NULL_VECTOR, NULL_VECTOR);
				char GetBringerName[MAX_NAME_LENGTH];
				GetClientName(client, GetBringerName, sizeof(GetBringerName));
				TFRP_PrintToChat(i, "{goldenrod}%s {default}brought you to them", GetBringerName);
				TFRP_PrintToChat(client, "You brought {goldenrod}%s", VerifyBringName);
				FoundBring = true;
				break;
			}
		}
	}
	
	if(!FoundBring)
	{
		TFRP_PrintToChat(client, "Couldn't find player! (NOTE: Command is case sensitive!)");
	}
	
	return Plugin_Handled;
	
}

public Action Command_Goto(int client, int args)
{
	if(client == 0){
		PrintToServer("[TFRP] Cannot run command from console!");
		return Plugin_Handled;
	}
	
	char GetGotoName[MAX_NAME_LENGTH];
	GetCmdArgString(GetGotoName, sizeof(GetGotoName));
	
	bool FoundGoto = false;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			char VerifyGotoName[MAX_NAME_LENGTH];
			GetClientName(i, VerifyGotoName, sizeof(VerifyGotoName));
			if(StrEqual(GetGotoName, VerifyGotoName))
			{
				if(!IsPlayerAlive(i))
				{
					TFRP_PrintToChat(client, "{goldenrod}%s{default} must be alive!", VerifyGotoName);
					FoundGoto = true;
					break;
				}
				float GotoClientOrigin[3];
				GetClientAbsOrigin(i, GotoClientOrigin);
				TeleportEntity(client, GotoClientOrigin, NULL_VECTOR, NULL_VECTOR);
				char GetGotoerName[MAX_NAME_LENGTH];
				GetClientName(client, GetGotoerName, sizeof(GetGotoerName));
				TFRP_PrintToChat(i, "{goldenrod}%s {default}teleported to you!", GetGotoerName);
				TFRP_PrintToChat(client, "You teleported to {goldenrod}%s", VerifyGotoName);
				FoundGoto = true;
				break;
			}
		}
	}
	
	if(!FoundGoto)
	{
		TFRP_PrintToChat(client, "Couldn't find player! (NOTE: Command is case sensitive!)");
	}
	
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
