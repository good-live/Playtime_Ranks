#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <playtime>
#include <multicolors>
#include <emitsoundany>

#pragma newdecls required

#define MAX_RANK_LENGTH 64
#define MAX_TAG_LENGTH 64
#define LEVEL_UP_SOUND "test.mp3"

public Plugin myinfo = 
{
	name = "Playtime - Ranks",
	author = "good_live",
	description = "Adds a rank system to the Playtime plugin.",
	version = "1.0.0",
	url = "painlessgaming.eu"
};

ArrayList g_aRank;
ArrayList g_aTime;
ArrayList g_aTag;

Handle g_hTimer[MAXPLAYERS + 1] = {null, ...};

int g_iRank[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
   CreateNative("PTR_GetClientTag", Native_GetClientTag);
   return APLRes_Success;
}

public void OnPluginStart()
{
	g_aRank = new ArrayList(MAX_RANK_LENGTH);
	g_aTime = new ArrayList();
	g_aTag = new ArrayList(MAX_TAG_LENGTH);
	ReadConfig();
	
	LoadTranslations("playtime_ranks.phrases");
}

public void OnMapStart()
{ 
    AddFileToDownloadsTable(LEVEL_UP_SOUND); 
    PrecacheSoundAny(LEVEL_UP_SOUND); 
} 

bool ReadConfig(){
	KeyValues kv = new KeyValues("Ranks");
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/playtime/ranks.cfg");
	
	if (!kv.GotoFirstSubKey())
	{
		return false;
	}
 
	char sRank[MAX_RANK_LENGTH];
	char sTag[MAX_TAG_LENGTH];
	int iPlaytime;
	do
	{
		kv.GetSectionName(sRank, sizeof(sRank));
		if(strlen(sRank)<= 0){
			LogError("[Playtime Ranks] Invalid Sectionname in the config. Please check your config again");
			continue;
		}
		
		iPlaytime = kv.GetNum("time", -1);
		
		if(iPlaytime == -1){
			LogError("[Playtime Ranks] Missing playtime attribute at Section: %s", sRank);
			continue;
		}
		
		kv.GetString("tag", sTag, sizeof(sTag), "");
		
		PrintToServer("[Playtime Ranks] Loaded %s with a minimunm playtime of %i and the tag: %s", sRank, iPlaytime, sTag);
		
		g_aRank.PushString(sRank);
		g_aTime.Push(iPlaytime);
		g_aTag.PushString(sTag);
		
	} while (kv.GotoNextKey());

	delete kv;
	
	SortArrays();
	return true;
}

//Sortiert die Arrays nach playtime mit einem Bubblesort (kleinstes Element auf Position 0)
void SortArrays(){
	for (int i = 0; i < g_aTime.Length; i++)
	{
	    for (int j = 0; j < g_aTime.Length - 1; j++)
	    {
	        if (g_aTime.Get(j) > g_aTime.Get(j + 1))
	        {
	        	g_aTime.SwapAt(j, j + 1);
	        	g_aRank.SwapAt(j, j + 1);
	        	g_aTag.SwapAt(j, j + 1);
	        }       
	    }    
	}
}

public void PT_OnPlaytimeLoaded(int client){
	//Load the players rank based on his Playtime
	int iPlaytime = PT_GetPlayTime(client);
	int iRank;
	for (iRank = 0; iRank < g_aTime.Length; iRank++)
	{
		if(iPlaytime < g_aTime.Get(iRank))
		{
			iRank--;
			break;
		}
	}
	
	g_iRank[client] = iRank;
}

public void PT_OnPlaytimeTracked(int client){
	SafeKill(g_hTimer[client]);
	g_hTimer[client] = null;
	
	CalculateTimer(client);
}

public void PT_OnPlaytimeTrackStop(int client){
	SafeKill(g_hTimer[client]);
	g_hTimer[client] = null;
}

void SafeKill(Handle timer) {
	if(timer != null)
		KillTimer(timer);
}

void CalculateTimer(int client) {
	//Check if their is a Rank that the client can reach
	if(g_iRank[client] == (g_aTime.Length -1))	
		return;
	
	int iPlaytime = PT_GetPlayTime(client);
	
	float fRemainingTime = g_aTime.Get(g_iRank[client] + 1) - iPlaytime;
	
	g_hTimer[client] = CreateTimer(fRemainingTime, Timer_LevelUp, GetClientUserId(client));
}

public Action Timer_LevelUp(Handle Timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(!IsClientValid(client))
		return Plugin_Stop;
		
	g_iRank[client]++;
	
	char sRank[MAX_RANK_LENGTH];
	g_aRank.GetString(g_iRank[client], sRank, sizeof(sRank));
	CPrintToChatAll("%t", "Level_Up", client, sRank);
	EmitSoundToAllAny(LEVEL_UP_SOUND);
	CalculateTimer(client);
	
	return Plugin_Stop;
}

bool IsClientValid(int client){
	return (1 <= client <= MaxClients && IsClientConnected(client));
}

//Natives
public int Native_GetClientTag(Handle plugin, int numParams){
	
	int client = GetNativeCell(1);
	
	int len;
	GetNativeStringLength(2, len);
	
	if (len <= 0)
		return false;
	
	if(g_iRank[client] < 0)
		return false;
		
	char[] str = new char[len + 1];
	g_aTag.GetString(g_iRank[client], str, len+1);
	
	SetNativeString(1, str, len+1, false);
	return true;
}

public void OnClientPutInServer(int client){
	g_iRank[client] = -1;
}

public void OnClientDisconnect(int client){
	g_iRank[client] = -1;
	SafeKill(g_hTimer[client]);
	g_hTimer[client] = null;
}
