// TFRP Build 2 Include File
// My first time making an include file

// Required for stocks
	

/**
 * Called when an item is spawned
 * @param client		Client index
 * @param item 			Item name
 * @param entindex		Entity index
 **/
forward void TFRP_OnItemSpawn(int client, char[] item, int entIndex);

/**
 * Called when an item is bought
 * @param client		Client index
 * @param item			Item name
 * @param price			Item price
 **/
forward void TFRP_OnItemBought(int client, char[] item, int price);

/**
 * Called when a player changes their job
 * @param client		Client index
 * @param oldJob		Previous job name
 * @param newJob		New job name
 **/
forward void TFRP_OnJobChanged(int client, char[] oldJob, char[] newJob);

/**
 * Called when an item is used from a player's inventory
 * @param client		Client index
 * @param item			Item name
 **/
forward void TFRP_OnItemUse(int client, char[] item);

/**
 * Called when a player buys a door 
 * @param client		Client index
 * @param door			Door index
 **/
forward void TFRP_OnDoorBought(int client, int door);

/**
 * Called when a player sells a door (or when they leave)
 * @param client		Client index
 * @param door			Door index
 **/
forward void TFRP_OnDoorSold(int client, int door);

/**
 * Get job of client index
 * @param client		Client index
 * @return 				Job index of client
 * @error 				Invalid index (Player isn't connected)
 **/
native TFRP_GetJobIndex(int client);

/**
 *  Adds item(s) to player's inventory
 *	@param client		Client index
 *	@param item			Item name
 *  @param amount		Item amount
 *  @error				Invalid item or invalid client index
 **/
native TFRP_GiveItem(int client, char[] item, int amount);

/**
 *	Removes item(s) from player's inventory
 *	@param client		Client index
 *	@param item			Item name
 *  @param amount		Item amount
 *  @error				Invalid item or invalid client index
 **/
native TFRP_RemoveItem(int client, char[] item, int amount);

/**
 * Returns the amount of money the client has
 * @param client		Client index
 * @return				Client's money
 *
 **/
native TFRP_GetCash(int client);

/**
 *	Returns true if client is a Government Offical
 *	@param client		Client index
 *	@return				IsGov
 **/
native TFRP_IsGov(int client);

/**
 *	Returns entity's owner client index (0 if no owner, or belongs to world)
 *	@param index		Entity index
 *	@return				Client index
 **/
native TFRP_GetEntOwner(int entity);

/**
 * Returns what the entity is from the store (Ex: Sandvich Table)
 * @param index			Entity index
 **/
//native TFRP_GetEntItem(int entity);
 
/**
 * Get job's name from index
 * @param client		Job index
 * @return 				Job name of index
 * @error 				Invalid index (No corresponding job)
 **/
stock TFRP_GetJobFromIndex(int jobIndex)
{
	char JobName[32];
	
	new Handle:DB4 = CreateKeyValues("Jobs");
	FileToKeyValues(DB4, "addons/sourcemod/configs/tfrp/cfg/tfrp_jobs.txt");

	KvGotoFirstSubKey(DB4,false);

	int getJobIndex = 0;

	do{
		
		getJobIndex++;
		
		if( getJobIndex == jobIndex)
		{
			KvGetSectionName(DB4, JobName, sizeof(JobName));
		}
    } while (KvGotoNextKey(DB4,false));

	CloseHandle(DB4);
	
	return JobName;
}

/**
 *	This is just so you don't have to write {green}[TFRP]{default} in every TFRP msg
 *	Same params as CPrintToChat
 **/
stock TFRP_PrintToChat(int client, const char[] text, any:...)
{
	if(client <= 0 || client > MaxClients) {
		ThrowError("Invalid client index %i", client);
	}
	if(!IsClientInGame(client)) {
		ThrowError("Client %i is not in game", client);
	}
	SetGlobalTransTarget(client);
	
	char buffer[256];
	char buffer2[256];
	
	Format(buffer, sizeof(buffer), "\x01%s", text);
	VFormat(buffer2, sizeof(buffer2), buffer, 3);

	CPrintToChat(client, "{green}[TFRP]{default} %s", buffer2);
}

/**
 *	This is just so you don't have to write {green}[TFRP]{default} in every TFRP msg
 *	Same params as CPrintToChat
 **/
stock TFRP_PrintToChatAll(const char[] text, any:...)
{
	char buffer[256];
	char buffer2[256];
	
	Format(buffer, sizeof(buffer), "\x01%s", text);
	VFormat(buffer2, sizeof(buffer2), buffer, 3);

	CPrintToChatAll("{green}[TFRP]{default} %s", buffer2);
}