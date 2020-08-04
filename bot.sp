#pragma semicolon 1

#include <sourcemod>
#include <smlib/arrays>
#include <smlib/math>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>	
#include <morecolors>

/* ConVars */
Handle g_botName = null;
Handle g_percentVote = null;
Handle g_hCvarVoteTime;
Handle g_hCvarVoteTimeDelay;
Handle g_hMinReactionTime;
Handle g_hMaxReactionTime;
Handle g_hMinOrbitTime;
Handle g_hMaxOrbitTime;
Handle g_hMaxOrbitSpeed;
Handle g_hOrbitChance;
Handle g_hFlickChances;
Handle g_hCQCFlickChances;
Handle g_hBeatableBot;

Handle g_hCvarServerChatTag;
Handle g_hCvarMainChatColor;
Handle g_hCvarKeywordChatColor;
Handle g_hCvarClientChatColor;
Handle g_hCvarBeatableBotMode;
Handle g_hCvarUnbeatableBotMode;

/* Stuff */
int bot;
int iVotes;
int iOwner;
int iOldOwner;
//int iBotMode;
bool TargetOwner = false;
bool bVoted[MAXPLAYERS + 1] = false;
bool AllowedVote; // check if we can vote
bool ScaryPlayer[MAXPLAYERS + 1];
bool botActivated = false;
bool IsSetupDone = false;
bool IsBotOrbiting = false;
bool IsBotOrbitingRight = false;
bool IsBotOrbitingLeft = false;
bool HasBotFlicked = false;
bool IsBotTouched = false;
bool IsBotBeatable;
bool MapChanged; // check if the map changed
float FlickChances[7];
float CQCFlickChances[7];
float LastDeflectionTime;
float MinReactionTime;
float MaxReactionTime;
float CurrentReactionTime;
float MinOrbitTime;
float MaxOrbitTime;
float MaxOrbitSpeed;
float OrbitChance;

char g_strServerChatTag[256];
char g_strMainChatColor[256];
char g_strKeywordChatColor[256];
char g_strClientChatColor[256];
char g_strBeatableBotMode[256];
char g_strUnbeatableBotMode[256];

public Plugin myinfo =
{
	name = "Advanced bot",
	author = "soul & modifications by DeadSworn",
	description = "Advanced bot (orbit)",
	version = "v1.8.1",
	url = ""
};

public void OnPluginStart() {
	g_botName = CreateConVar("sm_botname", "Super Bot", "Set the bot's name.");
	
	g_percentVote = CreateConVar("sm_percentageVotes", "50.0", "Needed percentage to activate the superbot", _, true, 0.0, true, 100.0);
	g_hCvarVoteTimeDelay = CreateConVar("sm_bot_vote_delay", "60.0", "Time in seconds before players can initiate another PvB vote.", 0);
	g_hCvarVoteTime = CreateConVar("sm_bot_vote_time", "25.0", "Time in seconds the vote menu should last.", 0);
	
	g_hMinReactionTime = CreateConVar("sm_bot_reacttime_min", "125.0", "Fastest the bot can react to the rocket being airblasted, DEFAULT: 125 milliseconds.", FCVAR_PROTECTED, true, 0.00, true, 225.00);
	MinReactionTime = GetConVarFloat(g_hMinReactionTime);
	HookConVarChange(g_hMinReactionTime, OnConVarChange);
	
	g_hMaxReactionTime = CreateConVar("sm_bot_reacttime_max", "225.0", "Slowest the bot can react to the rocket being airblasted, DEFAULT: 225 milliseconds, which is average for humans.", FCVAR_PROTECTED, true, 125.00, false);
	MaxReactionTime = GetConVarFloat(g_hMaxReactionTime);
	HookConVarChange(g_hMaxReactionTime, OnConVarChange);
	
	g_hMinOrbitTime = CreateConVar("sm_bot_orbittime_min", "0.00", "Minimum amount of time (in seconds) the bot can orbit, DEFAULT: 0 seconds.", FCVAR_PROTECTED, true, 0.00, false);
	MinOrbitTime = GetConVarFloat(g_hMinOrbitTime);
	HookConVarChange(g_hMinOrbitTime, OnConVarChange);
	
	g_hMaxOrbitTime = CreateConVar("sm_bot_orbittime_max", "3.00", "Maximum amount of time (in seconds) the bot can orbit, DEFAULT: 3 seconds.", FCVAR_PROTECTED, true, 0.00, false);
	MaxOrbitTime = GetConVarFloat(g_hMaxOrbitTime);
	HookConVarChange(g_hMaxOrbitTime, OnConVarChange);
	
	g_hMaxOrbitSpeed = CreateConVar("sm_bot_orbitspeed", "-1.0", "Max speed bot can orbit (in MPH), DEFAULT: Infinite, or -1.0.", FCVAR_PROTECTED, true, -1.00, false);
	MaxOrbitSpeed = GetConVarFloat(g_hMaxOrbitSpeed);
	HookConVarChange(g_hMaxOrbitSpeed, OnConVarChange);
	
	g_hOrbitChance = CreateConVar("sm_bot_orbitchance", "20.0", "Percent chance that the bot will orbit before airblasting.", FCVAR_PROTECTED, true, 0.00, true, 100.0);
	OrbitChance = GetConVarFloat(g_hOrbitChance);
	HookConVarChange(g_hOrbitChance, OnConVarChange);
	
	g_hFlickChances = CreateConVar("sm_bot_flick_chances", "25.0 37.5 7.5 7.5 7.5 7.5 7.5", "Percentage chances (out of 100%) that the bot will do a <None Wave USpike DSpike LSpike RSpike BackShot> flick.", FCVAR_PROTECTED);
	GetConVarArray(g_hFlickChances, FlickChances, sizeof(FlickChances));
	HookConVarChange(g_hFlickChances, OnConVarChange);
	
	g_hCQCFlickChances = CreateConVar("sm_bot_flick_chances_cqc", "10.0 7.5 22.5 22.5 7.5 7.5 22.5", "Percentage chances (out of 100%) that the bot will do a <None Wave USpike DSpike LSpike RSpike BackShot> flick during close quarters combat.", FCVAR_PROTECTED);
	GetConVarArray(g_hCQCFlickChances, CQCFlickChances, sizeof(CQCFlickChances));
	HookConVarChange(g_hCQCFlickChances, OnConVarChange);
	
	g_hBeatableBot = CreateConVar("sm_bot_beatable", "0", "Is the bot beatable or not? If 1, the bot will airblast at the normal rate and will take damage. Otherwise, 0 for a bot that never dies.", FCVAR_PROTECTED, true, 0.0, true, 1.0);
	IsBotBeatable = GetConVarBool(g_hBeatableBot);
	HookConVarChange(g_hBeatableBot, OnConVarChange);
	
	g_hCvarServerChatTag = CreateConVar("sm_bot_servertag", "{ORANGE}[DBBOT]", "Tag that appears at the start of each chat announcement.", FCVAR_PROTECTED);
	GetConVarString(g_hCvarServerChatTag, g_strServerChatTag, sizeof(g_strServerChatTag));
	HookConVarChange(g_hCvarServerChatTag, OnConVarChange);
	g_hCvarMainChatColor = CreateConVar("sm_bot_maincolor", "{WHITE}", "Color assigned to the majority of the words in chat announcements.");
	GetConVarString(g_hCvarMainChatColor, g_strMainChatColor, sizeof(g_strMainChatColor));
	HookConVarChange(g_hCvarMainChatColor, OnConVarChange);
	g_hCvarKeywordChatColor = CreateConVar("sm_bot_keywordcolor", "{DARKOLIVEGREEN}", "Color assigned to the most important words in chat announcements.", FCVAR_PROTECTED);
	GetConVarString(g_hCvarKeywordChatColor, g_strKeywordChatColor, sizeof(g_strKeywordChatColor));
	HookConVarChange(g_hCvarKeywordChatColor, OnConVarChange);
	g_hCvarClientChatColor = CreateConVar("sm_bot_clientwordcolor", "{TURQUOISE}", "Color assigned to the client in chat announcements.", FCVAR_PROTECTED);
	GetConVarString(g_hCvarClientChatColor, g_strClientChatColor, sizeof(g_strClientChatColor));
	HookConVarChange(g_hCvarClientChatColor, OnConVarChange);
	g_hCvarBeatableBotMode = CreateConVar("sm_bot_beatablebot_mode", "Beatable", "Name assigned to the beatable bot mode.", FCVAR_PROTECTED);
	GetConVarString(g_hCvarBeatableBotMode, g_strBeatableBotMode, sizeof(g_strBeatableBotMode));
	HookConVarChange(g_hCvarBeatableBotMode, OnConVarChange);
	g_hCvarUnbeatableBotMode = CreateConVar("sm_bot_unbeatablebot_mode", "Unbeatable", "Name assigned to the unbeatable bot mode.", FCVAR_PROTECTED);
	GetConVarString(g_hCvarUnbeatableBotMode, g_strUnbeatableBotMode, sizeof(g_strUnbeatableBotMode));
	HookConVarChange(g_hCvarUnbeatableBotMode, OnConVarChange);
	
	HookEvent("object_deflected", OnDeflect, EventHookMode_Post);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("teamplay_setup_finished", OnSetupFinished, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_Post);

	RegAdminCmd("sm_pvb", Command_PVB, ADMFLAG_ROOT, "Enable PVB");
	RegAdminCmd("sm_scary", Command_ScaryPlayer, ADMFLAG_ROOT, "Make rockets scared of you!");
	RegAdminCmd("sm_botmode", Command_BotModeToggle, ADMFLAG_ROOT, "Toggle bot mode (ex: from Unbeatable -> Beatable or vice-versa)");

	RegConsoleCmd("sm_votepvb", Command_VotePVB, "Vote for the PVB");

	// create the bot config (tf/cfg/sourcemod/superbot.cfg)
	AutoExecConfig(true, "superbot");
}


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("superbot");
	return APLRes_Success;
}

public void OnConVarChange(Handle hConvar, const char[] oldValue, const char[] newValue)
{
	if(hConvar == g_hMinReactionTime)
		MinReactionTime = StringToFloat(newValue);
	if(hConvar == g_hMaxReactionTime)
		MaxReactionTime = StringToFloat(newValue);
	if(hConvar == g_hMinOrbitTime)
		MinOrbitTime = StringToFloat(newValue);
	if(hConvar == g_hMaxOrbitTime)
		MaxOrbitTime = StringToFloat(newValue);
	if(hConvar == g_hMaxOrbitSpeed)
		MaxOrbitSpeed = StringToFloat(newValue);
	if (hConvar == g_hOrbitChance)
		OrbitChance = StringToFloat(newValue);
	if (hConvar == g_hFlickChances)
		GetConVarArray(g_hFlickChances, FlickChances, sizeof(FlickChances));
	if (hConvar == g_hCQCFlickChances)
		GetConVarArray(g_hCQCFlickChances, CQCFlickChances, sizeof(CQCFlickChances));
	if (hConvar == g_hBeatableBot)
		IsBotBeatable = GetConVarBool(g_hBeatableBot);
	if (hConvar == g_hCvarServerChatTag)
		strcopy(g_strServerChatTag, sizeof(g_strServerChatTag), newValue);
	if (hConvar == g_hCvarMainChatColor)
		strcopy(g_strMainChatColor, sizeof(g_strMainChatColor), newValue);
	if (hConvar == g_hCvarKeywordChatColor)
		strcopy(g_strKeywordChatColor, sizeof(g_strKeywordChatColor), newValue);
	if (hConvar == g_hCvarClientChatColor)
		strcopy(g_strClientChatColor, sizeof(g_strClientChatColor), newValue);
	if (hConvar == g_hCvarBeatableBotMode)
		strcopy(g_strBeatableBotMode, sizeof(g_strBeatableBotMode), newValue);
	if (hConvar == g_hCvarUnbeatableBotMode)
		strcopy(g_strUnbeatableBotMode, sizeof(g_strUnbeatableBotMode), newValue);
}

float GetConVarArray(Handle convar, float[] destarr, int size)
{
	char tmp[32];
	new String:split[size][5];
	GetConVarString(convar, tmp, sizeof(tmp));
	ExplodeString(tmp, " ", split, size, 5);
	
	new Float:arr[size];
	for (int i = 0; i < size; i++)
	{
		arr[i] = StringToFloat(split[i]);
	}
	Array_Copy(arr, destarr, size);
}

/*
**▄▀ ▄▀▄ █▄░▄█ █▄░▄█ ▄▀▄ █▄░█ █▀▄ ▄▀▀
**█░ █░█ █░█░█ █░█░█ █▀█ █░▀█ █░█ ░▀▄
**░▀ ░▀░ ▀░░░▀ ▀░░░▀ ▀░▀ ▀░░▀ ▀▀░ ▀▀░
**********************************************/
public Action Command_PVB(int client, int args) {
  if (IsValidClient(client)) {
    if (!botActivated) {
      CPrintToChatAll("%s %sPlayer vs Bot is now %sactivated", g_strServerChatTag, g_strMainChatColor, g_strKeywordChatColor);
      EnableMode();
    } else {
      CPrintToChatAll("%s %sPlayer vs Bot is now %sdisabled", g_strServerChatTag, g_strMainChatColor, g_strKeywordChatColor);
      DisableMode();
    }
  }
  return Plugin_Handled;
}

public Action Command_VotePVB(int client, int args) {
	if (!AllowedVote)
	{
		char botName[255];
		GetConVarString(g_botName, botName, sizeof(botName));
		CReplyToCommand(client, "%s %s%s%s Sorry, voting for Player vs Bot is currently on%s cool-down.", g_strServerChatTag, g_strClientChatColor, botName, g_strMainChatColor, g_strKeywordChatColor);
		return Plugin_Continue;
	}
	
	int iNeededVotes = RoundToCeil((GetAllClientCount() * GetConVarFloat(g_percentVote)) / 100.0);
	if (!bVoted[client] && IsValidClient(client)) {
		iVotes++;
		if (!botActivated) {
			CPrintToChatAll("%s %s%N %swants to enable Player Vs. Bot! (%s%i %svotes), (%s%i %srequired).", g_strServerChatTag, g_strClientChatColor, client, g_strMainChatColor, g_strKeywordChatColor, iVotes, g_strMainChatColor, g_strKeywordChatColor, iNeededVotes, g_strMainChatColor);
		} else {
			CPrintToChatAll("%s %s%N %swants to change or disable Player Vs. Bot! (%s%i %svotes), (%s%i %srequired).", g_strServerChatTag, g_strClientChatColor, client, g_strMainChatColor, g_strKeywordChatColor, iVotes, g_strMainChatColor, g_strKeywordChatColor, iNeededVotes, g_strMainChatColor);
		}
		bVoted[client] = true;
	} else if (bVoted[client] && IsValidClient(client)) {
		CPrintToChat(client, "%s %s%N %syou can't vote twice!", g_strServerChatTag, g_strClientChatColor, client, g_strMainChatColor);
	}
	if (iVotes >= iNeededVotes) {
		StartPvBVotes();
		bVoted[client] = false;
		iVotes = 0;
	}
	return Plugin_Handled;
}

StartPvBVotes()
{
	PvBVoteMenu();
	
	ResetPvBVotes();
	AllowedVote = false;
	CreateTimer(GetConVarFloat(g_hCvarVoteTimeDelay), Timer_Delay, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Delay(Handle timer)
{
	AllowedVote = true;
}

PvBVoteMenu()
{
	if (IsVoteInProgress()) return;
	
	Handle vm = CreateMenu(PvBVoteMenuHandler, MenuAction:MENU_ACTIONS_ALL);
	SetVoteResultCallback(vm, Handle_VoteResults);
	
	if (!botActivated)
	{
		SetMenuTitle(vm, "Set Bot Mode:");
		AddMenuItem(vm, "beatable", g_strBeatableBotMode);
		AddMenuItem(vm, "unbeatable", g_strUnbeatableBotMode);
	}
	else
	{
		SetMenuTitle(vm, "Set Bot Mode/Disable Bot:");
		AddMenuItem(vm, "beatable", g_strBeatableBotMode);
		AddMenuItem(vm, "unbeatable", g_strUnbeatableBotMode);
		AddMenuItem(vm, "disable", "Disable");
	}
	
	SetMenuExitButton(vm, false);
	VoteMenuToAll(vm, GetConVarInt(g_hCvarVoteTime));
}

ResetPvBVotes()
{
	iVotes = 0;
	for (new i = 1; i <= MAXPLAYERS; i++) bVoted[i] = false;
}

public OnMapEnd()
{
	MapChanged = true;
}

public OnMapStart()
{
	ResetPvBVotes();
	AllowedVote = true;
	
	CreateTimer(5.0, Timer_MapStart);
}

public Action Timer_MapStart(Handle timer)
{
	MapChanged = false;
}

public PvBVoteMenuHandler(Handle menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_End) CloseHandle(menu);
}

public Handle_VoteResults(Handle menu, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
	int winner = 0;
	if (num_items > 1 && (item_info[0][VOTEINFO_ITEM_VOTES] == item_info[1][VOTEINFO_ITEM_VOTES]))
	{
		winner = GetRandomInt(0, 1);
	}
	
	char winInfo[32];
	GetMenuItem(menu, item_info[winner][VOTEINFO_ITEM_INDEX], winInfo, sizeof(winInfo));
	
	if (!botActivated)
	{
		if (StrEqual(winInfo, "beatable"))
		{
			CPrintToChatAll("%s %s %sPlayer vs Bot is now %sactivated!", g_strServerChatTag, g_strBeatableBotMode, g_strMainChatColor, g_strKeywordChatColor);
			IsBotBeatable = true;
			EnableMode();
		}
		else
		{
			CPrintToChatAll("%s %s %sPlayer vs Bot is now %sactivated!", g_strServerChatTag, g_strUnbeatableBotMode, g_strMainChatColor, g_strKeywordChatColor);
			IsBotBeatable = false;
			EnableMode();
		}
	}
	else
	{
		if (StrEqual(winInfo, "beatable"))
		{
			if (!IsBotBeatable)
			{
				CPrintToChatAll("%s %s %sPlayer vs Bot is now %sactivated!", g_strServerChatTag, g_strBeatableBotMode, g_strMainChatColor, g_strKeywordChatColor);
				IsBotBeatable = true;
			}
			else
			{
				CPrintToChatAll("%s %s %sBot Mode is %sstill activated.", g_strServerChatTag, g_strBeatableBotMode, g_strMainChatColor, g_strKeywordChatColor);
			}
		}
		else if (StrEqual(winInfo, "unbeatable"))
		{
			if (IsBotBeatable)
			{
				CPrintToChatAll("%s %s %sPlayer vs Bot is now %sactivated!", g_strServerChatTag, g_strUnbeatableBotMode, g_strMainChatColor, g_strKeywordChatColor);
				IsBotBeatable = false;
				if (IsPlayerAlive(bot))
				{
					SDKHook(bot, SDKHook_OnTakeDamage, OnTakeDamage);
				}
			}
			else
			{
				CPrintToChatAll("%s %s %sBot Mode is%s still activated.", g_strServerChatTag, g_strUnbeatableBotMode, g_strMainChatColor, g_strKeywordChatColor);
			}
		}
		else
		{
			CPrintToChatAll("%s %sPlayer vs Bot is now%s disabled!", g_strServerChatTag, g_strMainChatColor, g_strKeywordChatColor);
			DisableMode();
		}
	}
}

public Action Command_ScaryPlayer(int client, int args)
{
  if (IsValidClient(client))
  {
    if (!ScaryPlayer[client])
    {
      CPrintToChatAll("%s %sYou are now %sscary!", g_strServerChatTag, g_strMainChatColor, g_strKeywordChatColor);
      ScaryPlayer[client] = true;
    }
    else
    {
      CPrintToChatAll("%s %sYou are no longer %sscary", g_strServerChatTag, g_strMainChatColor, g_strKeywordChatColor);
      ScaryPlayer[client] = false;
    }
  }
  return Plugin_Handled;
}

public Action Command_BotModeToggle(int client, int args)
{
	if (IsValidClient(client))
	{
		if (!botActivated)
		{
			CReplyToCommand(client, "%s %sUnable to change Bot Mode because PvB is %sdisabled.", g_strServerChatTag, g_strMainChatColor, g_strKeywordChatColor);
		}
		if (!IsBotBeatable)
		{
			CPrintToChatAll("%s %sBot Mode changed to %s%s", g_strServerChatTag, g_strMainChatColor, g_strKeywordChatColor, g_strBeatableBotMode);
		}
		else if (IsBotBeatable)
		{
			CPrintToChatAll("%s %sBot Mode changed to %s%s", g_strServerChatTag, g_strMainChatColor, g_strKeywordChatColor, g_strUnbeatableBotMode);
		}
	}
}

/*
**▄▀▀ █▀▀ ▀█▀ █░█ █▀▄
**░▀▄ █▀▀ ░█░ █░█ █░█
**▀▀░ ▀▀▀ ░▀░ ░▀░ █▀░
**************************/
public void OnClientPutInServer(int client) {
	ScaryPlayer[client] = false;
	if (IsFakeClient(client) && !botActivated) {
		DisableMode();
	}
	else if (!IsFakeClient(client))
	{
		bVoted[client] = false;
	}
}

public Action OnPlayerSpawn(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	if (botActivated) {
		int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
		if (IsValidClient(iClient) && !IsFakeClient(iClient)) {
			if (GetClientTeam(iClient) == 2) {
				ChangeClientTeam(iClient, 3);
			}
		} else if (IsFakeClient(iClient)) {
			bot = iClient;
			if (!IsBotBeatable)
			{
				SDKHook(bot, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
	}
}

public Action OnSetupFinished(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	if (botActivated) {
		for(int i = 1; i <= MaxClients; i++) {
			if (IsValidClient(i)) {
				if(GetClientTeam(i) > 1) {
					SetEntityHealth(i, 175);
				}
			}
		}
		IsSetupDone = true;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!StrEqual(classname, "tf_projectile_rocket", false) || !botActivated)
		return;
	
	SDKHook(entity, SDKHook_StartTouch, OnStartTouchBot);
}

public void OnPreThinkBot(int entity)
{
	if (entity == bot && IsBotTouched)
	{
		float fEntityOrigin[3], fBotOrigin[3], fDistance[3], fFinalAngle[3];
		int iEntity = -1;
		while ((iEntity = FindEntityByClassname(iEntity, "tf_projectile_*")) != INVALID_ENT_REFERENCE) {
			int buttons = GetClientButtons(bot);
			int iCurrentWeapon = GetEntPropEnt(bot, Prop_Send,"m_hActiveWeapon");
			int iTeamRocket = GetEntProp(iEntity, Prop_Send, "m_iTeamNum");
			//Distance between the rocket and the bot eyes.
			GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
			GetClientEyePosition(bot, fBotOrigin);
			MakeVectorFromPoints(fBotOrigin, fEntityOrigin, fDistance);
			//Transform the vectors into angles
			GetVectorAngles(fDistance, fFinalAngle);
			// fix for clamping spam
			FixAngle(fFinalAngle);
			if (iTeamRocket != 2) {
				if (!IsBotBeatable || (IsBotBeatable && (LastDeflectionTime + CurrentReactionTime) <= GetEngineTime()))
				{
					TeleportEntity(bot, NULL_VECTOR, fFinalAngle, NULL_VECTOR);
				}
				if (!IsBotBeatable)
				{
					FireRate(iCurrentWeapon);
				}
				buttons |= IN_ATTACK2;
				SetEntProp(entity, Prop_Data, "m_nButtons", buttons);
				IsBotTouched = false;
			}
		}
	}
	SDKUnhook(entity, SDKHook_PreThink, OnPreThinkBot);
}

public Action OnDeflect(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	if (botActivated) {
		iOwner = GetClientOfUserId(GetEventInt(hEvent, "userid"));
		int iEntity = GetEventInt(hEvent, "object_entindex");
		if (FindEntityByClassname(iEntity, "tf_projectile_rocket") && IsValidEntity(iEntity)) {
			if (iOwner != bot && IsValidClient(iOwner) && IsPlayerAlive(iOwner)) {
				LastDeflectionTime = GetEngineTime();
				CurrentReactionTime = GetRandomFloat(MinReactionTime/1000.0, MaxReactionTime/1000.0);
				iOldOwner = iOwner;
				TargetOwner = true;
			}
		}
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
  if (botActivated && victim == bot) {
    damage = 0.0;
  }
  return Plugin_Changed;
}

public Action OnPlayerDeath(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	if (botActivated) {
		int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
		if (client == iOldOwner) {
			TargetOwner = false;
		}
	}
}

public Action OnRoundEnd(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	if (botActivated) {
		IsSetupDone = false;
		TargetOwner = false;
	}
}

/*
**█▀▄ ▄▀▄ ▀█▀     ▄▀ ▄▀▄ █▀▀▄ █▀▀
**█▀█ █░█ ░█░     █░ █░█ █▐█▀ █▀▀
**▀▀░ ░▀░ ░▀░     ░▀ ░▀░ ▀░▀▀ ▀▀▀
*************************************/
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
	if (IsSetupDone && botActivated && GetAllClientCount() > 0) {
		if (MapChanged) DisableMode();
		/*if (iBotMode == 2)*/
		int iClient = ChooseClient();
		if (IsValidClient(iClient) && IsPlayerAlive(iClient) && IsPlayerAlive(bot) && IsValidClient(bot) && IsValidClient(client)) 
		{
			if (client == iClient/* && iBotMode == 2*/) {
				// FollowClient(client, buttons);
				ManeuverBotAgainstClient(client);
			}
			else if (client == bot)
			{
				if (IsBotBeatable && (LastDeflectionTime + CurrentReactionTime) > GetEngineTime())
				{
					return Plugin_Continue;
				}
				OrbitRocket();
				AutoReflect(iClient, buttons);
				/*if (iBotMode == 2)*/ 
			}
		}
	}
	return Plugin_Continue;
}

public void ManeuverBotAgainstClient(int client) {
	// client position
	float client_position[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", client_position);
	
	// bot position
	float bot_position[3];
	GetEntPropVector(bot, Prop_Send, "m_vecOrigin", bot_position);
	
	// spawner position
	// -1 to being searching for the spawner from the first entity
	float spawner_position[3];
	int entity_id = -1;
	while((entity_id = FindEntityByClassname(entity_id, "info_target")) != -1) {
		char entity_name[50];
		GetEntPropString(entity_id, Prop_Data, "m_iName", entity_name, sizeof(entity_name));
		
		if(strcmp(entity_name, "rocket_spawn_blue", false) == 0) {
			break;
		}
	}
	GetEntPropVector(entity_id, Prop_Send, "m_vecOrigin", spawner_position);
	
	// solving midpoint equasion (Xm, Ym) = (X1 + X2) / 2, (Y1 + Y2) / 2
	// X1, Y1, = client position
	// midpoint (M) = spawner position
	// X2, Y2 = desired endpoint, coordinate opposite the spawner from the chosen client
	
	float endpoint[3]; 
	endpoint[0] = (2 * spawner_position[0]) - client_position[0];
	endpoint[1] = (2 * spawner_position[1]) - client_position[1];
	endpoint[2] = bot_position[2];
	
	// velocity, we take the difference in the X and Y axises and normalise them, then multiple the vector to 500. 
	float fVelocity[3];
	MakeVectorFromPoints(bot_position, endpoint, fVelocity);
	NormalizeVector(fVelocity, fVelocity);
	ScaleVector(fVelocity, 500.0);
	
	// no jumping!
	fVelocity[2] = 0.0;

	// if the point has been reached, roughly speaking, we'll set the velocity to 0 incrementally as we get closer
	if(GetVectorDistance(endpoint, bot_position) < 20) {
		ScaleVector(fVelocity, 0.0);
	} else if(GetVectorDistance(endpoint, bot_position) < 30) {
		ScaleVector(fVelocity, 0.2);
	} else if(GetVectorDistance(endpoint, bot_position) < 50) {
		ScaleVector(fVelocity, 0.5);
	}
	if(!IsBotOrbiting) {
		TeleportEntity(bot, NULL_VECTOR, NULL_VECTOR, fVelocity);
	}
}

/*
**█▀▀ █▄░█ █▀▄
**█▀▀ █░▀█ █░█
**▀▀▀ ▀░░▀ ▀▀░
*****************/
public void OnClientDisconnect(int client) {
	ScaryPlayer[client] = false;
	if (bVoted[client]) {
		if (iVotes > 0) {
			iVotes -= 1;
		}
		bVoted[client] = false;
	}
	if (GetAllClientCount() == 0 && botActivated) {
		DisableMode();
	}
}

/*
**█▀▀ █▄░█ ▄▀▄ █▀▄ █░░ █▀▀     ▄▀▄ █▀▀▄     █▀▄ ▀ ▄▀▀ ▄▀▄ █▀▄ █░░ █▀▀
**█▀▀ █░▀█ █▀█ █▀█ █░▄ █▀▀     █░█ █▐█▀     █░█ █ ░▀▄ █▀█ █▀█ █░▄ █▀▀
**▀▀▀ ▀░░▀ ▀░▀ ▀▀░ ▀▀▀ ▀▀▀     ░▀░ ▀░▀▀     ▀▀░ ▀ ▀▀░ ▀░▀ ▀▀░ ▀▀▀ ▀▀▀
***********************************************************************************/

stock void EnableMode() {
	CreateSuperbot();
	ChangeTeams();
	botActivated = true;
}

stock void CreateSuperbot() {
	char botname[255];
	GetConVarString(g_botName, botname, sizeof(botname));
	ServerCommand("mp_autoteambalance 0");
	ServerCommand("tf_bot_add 1 Pyro red easy \"%s\"", botname);
	ServerCommand("tf_bot_difficulty 0");
	ServerCommand("tf_bot_keep_class_after_death 1");
	ServerCommand("tf_bot_taunt_victim_chance 0");
	ServerCommand("tf_bot_join_after_player 0");
}

stock void DisableMode() {
	ServerCommand("mp_autoteambalance 1");
	ServerCommand("tf_bot_kick all");
	for (int i = 1; i <= MaxClients; i++) {
		if (bVoted[i]) {
			bVoted[i] = false;
		}
	}
	iVotes = 0;
	botActivated = false;
	TargetOwner = false;
}

/*
** ▄▀ ▄▀▄ █░█ █▄░█ ▀█▀
** █░ █░█ █░█ █░▀█ ░█░
** ░▀ ░▀░ ░▀░ ▀░░▀ ░▀░
***********************************/
stock int GetAllClientCount() {
	int count = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) > 1) {
			count += 1;
		}
	}
	return count;
}

/*
**▀█▀ █▀▀ ▄▀▄ █▄░▄█ ▄▀▀
**░█░ █▀▀ █▀█ █░█░█ ░▀▄
**░▀░ ▀▀▀ ▀░▀ ▀░░░▀ ▀▀░
****************************/
stock void ChangeTeams() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i)) {
			if (i != bot && GetClientTeam(i) == 2) {
				ChangeClientTeam(i, 3);
			}
		}
	}
}

/*
**█▀▄ ▄▀▄ ▀█▀     ▄▀▀ ▀█▀ ▄▀▄ ▄▀ █░▄▀ ▄▀▀     ▄▀ ▄▀▄ █▀▀▄ █▀▀
**█▀█ █░█ ░█░     ░▀▄ ░█░ █░█ █░ █▀▄░ ░▀▄     █░ █░█ █▐█▀ █▀▀
**▀▀░ ░▀░ ░▀░     ▀▀░ ░▀░ ░▀░ ░▀ ▀░▀▀ ▀▀░     ░▀ ░▀░ ▀░▀▀ ▀▀▀
****************************************************************/
stock void FollowClient(int client, int &buttons)
{
	float fOriginPlayer[3];
	//Get origin, raise the z vector, inv the vector.
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fOriginPlayer);
	fOriginPlayer[2] = 300.0;
	NegateVector(fOriginPlayer);
	//Get buttons, sync the bot with the client moves.
	if (!IsBotOrbiting)
	{
		if (buttons & IN_FORWARD || IN_BACK || IN_MOVELEFT || IN_MOVERIGHT)
		{
			TeleportEntity(bot, NULL_VECTOR, NULL_VECTOR, fOriginPlayer);
		}
	}
}

stock Action AutoReflect(int iClient, int &buttons, int iEntity = -1)
{
	float fEntityOrigin[3], fBotOrigin[3], fEnemyOrigin[3], fRocketDistance[3], fFinalAngle[3], fEnemyDistCQC, fRocketDistAuto;
	static float fNextAimTime;
	while ((iEntity = FindEntityByClassname(iEntity, "tf_projectile_*")) != INVALID_ENT_REFERENCE)
	{
		int iCurrentWeapon = GetEntPropEnt(bot, Prop_Send,"m_hActiveWeapon");
		int iTeamRocket = GetEntProp(iEntity,	Prop_Send, "m_iTeamNum");
		//Distance between the rocket and the bot eyes.
		GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
		GetClientEyePosition(bot, fBotOrigin);
		MakeVectorFromPoints(fBotOrigin, fEntityOrigin, fRocketDistance);
		GetClientEyePosition(TargetClient(), fEnemyOrigin);
		//Transform the vectors into angles
		GetVectorAngles(fRocketDistance, fFinalAngle);
		// fix for clamping spam
		//Define the distance and the airblast of the bot.
		fRocketDistAuto = GetVectorDistance(fBotOrigin, fEntityOrigin, false);
		fEnemyDistCQC = GetVectorDistance(fBotOrigin, fEnemyOrigin, false);
		if (!IsBotOrbiting && fRocketDistAuto < 250.0 && iTeamRocket != 2)
		{
			FixAngle(fFinalAngle);
			if (!IsBotBeatable)
			{
				FireRate(iCurrentWeapon);
			}
			TeleportEntity(bot, NULL_VECTOR, fFinalAngle, NULL_VECTOR);
			buttons |= IN_ATTACK2;
			HasBotFlicked = false;
			return Plugin_Changed;
		}
		else
		{
			// No Flick
			if (!HasBotFlicked)
			{
				if (!(GetRandomFloat() <= (FlickChances[0] / 100)))
				{
					if (fEnemyDistCQC < 500.0)
					{
						GetFlickAngle(bot, iEntity, fFinalAngle, true);
					}
					else
					{
						GetFlickAngle(bot, iEntity, fFinalAngle, false);
					}
				}
				FixAngle(fFinalAngle);
				TeleportEntity(bot, NULL_VECTOR, fFinalAngle, NULL_VECTOR);
				HasBotFlicked = true;
				fNextAimTime = GetEngineTime() + 0.35;
			}
			if (fNextAimTime <= GetEngineTime())
			{
				AimClient(iClient);
			}
		}
	}
	if ((iEntity = FindEntityByClassname(iEntity, "tf_projectile_*")) == INVALID_ENT_REFERENCE)
	{
		if (fNextAimTime <= GetEngineTime())
		{
			AimClient(iClient); //Add this to search the client even if the rocket is an INVALID_ENT_REFERENCE
		}
	}
	return Plugin_Continue;
}

/*
**▄▀▄ █▀▀▄ █▀▄ ▀ ▀█▀
**█░█ █▐█▀ █▀█ █ ░█░
**░▀░ ▀░▀▀ ▀▀░ ▀ ░▀░
******************************/

stock void OrbitRocket() {
	int iEntity = -1;
	float fBotOrigin[3], angles[3], fEntityOrigin[3], fAngleToRocket[3], fRocketAngles[3], fRocketVelocity[3], fDistance;
	static float fBotStopOrbitTime;
	while ((iEntity = FindEntityByClassname(iEntity, "tf_projectile_*")) != INVALID_ENT_REFERENCE) {
		int iTeamRocket = GetEntProp(iEntity, Prop_Send, "m_iTeamNum");
		GetClientEyeAngles(bot, angles);
		GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
		GetEntPropVector(iEntity, Prop_Data, "m_vecAbsVelocity", fRocketVelocity);
		int iCurrentWeapon = GetEntPropEnt(bot, Prop_Send, "m_hActiveWeapon");
		float m_flNextSecondaryAttack = GetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flNextSecondaryAttack");
		float fGameTime = GetGameTime();
		GetClientEyePosition(bot, fBotOrigin);
		fDistance = GetVectorDistance(fBotOrigin, fEntityOrigin, false);
		GetEntPropVector(iEntity, Prop_Send, "m_angRotation", fRocketAngles);
		GetAngleVectors(fRocketAngles, fRocketAngles, NULL_VECTOR, NULL_VECTOR);
		
		fAngleToRocket[0] = 0.0 - RadToDeg(ArcTangent((fEntityOrigin[2] - fBotOrigin[2]) / (FloatAbs(SquareRoot(Pow(fBotOrigin[0] - fEntityOrigin[0], 2.0) + Pow(fEntityOrigin[1] - fBotOrigin[1], 2.0))))));
		fAngleToRocket[1] = GetAngleX(fBotOrigin, fEntityOrigin);
		AnglesNormalize(fAngleToRocket);
		float randFloat = GetRandomFloat();
		if (fDistance < 500.0 && iTeamRocket != 2 && ((RoundFloat(GetVectorLength(fRocketVelocity) * (15.0/352.0)) <= MaxOrbitSpeed || MaxOrbitSpeed == -1.0) && (randFloat <= (OrbitChance/100.0) || fBotStopOrbitTime > GetEngineTime())) || m_flNextSecondaryAttack > fGameTime) {
			if (fBotStopOrbitTime <= GetEngineTime() && !IsBotOrbiting)
			{
				fBotStopOrbitTime = GetEngineTime() + GetRandomFloat(MinOrbitTime, MaxOrbitTime);
			}
			if (m_flNextSecondaryAttack > fGameTime)
			{
				fBotStopOrbitTime = m_flNextSecondaryAttack - GetGameTime();
			}
			IsBotOrbiting = true;
			float fOrbitVelocity[3];
			NormalizeVector(fRocketAngles, fOrbitVelocity);
			float velx = fOrbitVelocity[0];
			float velz = fOrbitVelocity[1];
			if (((angles[1] - fAngleToRocket[1]) < 0.0 || IsBotOrbitingRight) && !IsBotOrbitingLeft)
			{
				IsBotOrbitingRight = true;
				fOrbitVelocity[0] = -velz;
				fOrbitVelocity[1] = velx;
			}
			else if (((angles[1] - fAngleToRocket[1]) >= 0.0 || IsBotOrbitingLeft) && !IsBotOrbitingRight)
			{
				IsBotOrbitingLeft = true;
				fOrbitVelocity[0] = velz;
				fOrbitVelocity[1] = -velx;
			}
			fOrbitVelocity[2] = 0.0;
			
			ScaleVector(fOrbitVelocity, 300.0);
			TeleportEntity(bot, NULL_VECTOR, NULL_VECTOR, fOrbitVelocity);
		}
		else {
			IsBotOrbiting = false;
			IsBotOrbitingRight = false;
			IsBotOrbitingLeft = false;
		}
	}
}

public Action OnStartTouchBot(int entity, int other)
{
	if ((other == bot || ScaryPlayer[other]) && entity != INVALID_ENT_REFERENCE)
	{
		SDKHook(entity, SDKHook_Touch, OnTouchBot);
		return Plugin_Continue;
	}
	else if (entity == INVALID_ENT_REFERENCE)
	{
		SDKUnhook(entity, SDKHook_StartTouch, OnStartTouchBot);
	}
	
	return Plugin_Continue;
}

public Action OnTouchBot(int entity, int other)
{
	int iCurrentWeapon = GetEntPropEnt(other, Prop_Send, "m_hActiveWeapon");
	float m_flNextSecondaryAttack = GetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flNextSecondaryAttack");
	float fGameTime = GetGameTime();
	if (m_flNextSecondaryAttack > fGameTime)
	{
		SDKUnhook(entity, SDKHook_Touch, OnTouchBot);
		return Plugin_Handled;
	}
	float vec[3] = 0.0;
	TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vec);
	IsBotTouched = true;
	if (other == bot)
	{
		SDKHook(other, SDKHook_PreThink, OnPreThinkBot);
	}
	SDKUnhook(entity, SDKHook_Touch, OnTouchBot);
	return Plugin_Handled;
}

public bool TEF_ExcludeEntity(int entity, int contentsMask, any data)
{
	return (entity != data);
}

/*
**▀█▀ ▄▀▄ █▀▀▄ ▄▀▀░ █▀▀ ▀█▀     █▀▄ █░░ ▄▀▄ ▀▄░▄▀ █▀▀ █▀▀▄
**░█░ █▀█ █▐█▀ █░▀▌ █▀▀ ░█░     █░█ █░▄ █▀█ ░░█░░ █▀▀ █▐█▀
**░▀░ ▀░▀ ▀░▀▀ ▀▀▀░ ▀▀▀ ░▀░     █▀░ ▀▀▀ ▀░▀ ░░▀░░ ▀▀▀ ▀░▀▀
**************************************************************/
stock int ChooseClient() {
	int iPlayer = -1;
	if (!TargetOwner) {
		iPlayer = TargetClient();
	} else {
		iPlayer = iOldOwner;
	}
	return iPlayer;
}

stock int TargetClient() {
	int iPlayer = -1;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && IsValidClient(bot) && IsPlayerAlive(i) && GetClientTeam(i) == 3) {
			iPlayer = GetClosestClient();
		}
	}
	return iPlayer;
}

stock int GetClosestClient() {
	int iPlayer = -1;
	float fPlayerOrigin[3], fBotLocation[3], fClosestDistance = -1.0, fDistance;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && IsValidClient(bot) && IsPlayerAlive(i) && !IsFakeClient(i) && GetClientTeam(i) > 2) {
			GetClientAbsOrigin(i, fPlayerOrigin);
			GetClientAbsOrigin(bot, fBotLocation);
			fDistance = GetVectorDistance(fBotLocation, fPlayerOrigin);
			if ((fDistance < fClosestDistance) || fClosestDistance == -1.0) {
				fClosestDistance = fDistance;
				iPlayer = i;
			}
		}
	}
	return iPlayer;
}

stock void AimClient(int client) {
	float fLocationPlayer[3], fLocationBot[3], fLocationPlayerFinal[3], fLocationAngle[3];
	GetClientAbsOrigin(bot, fLocationBot);
	GetClientAbsOrigin(client, fLocationPlayer);
	MakeVectorFromPoints(fLocationBot, fLocationPlayer, fLocationPlayerFinal);
	GetVectorAngles(fLocationPlayerFinal, fLocationAngle);
	FixAngle(fLocationAngle);
	TeleportEntity(bot, NULL_VECTOR, fLocationAngle, NULL_VECTOR);
}

/*
**█▀ ▀ █▀▀▄ █▀▀     █▀▀▄ ▄▀▄ ▀█▀ █▀▀
**█▀ █ █▐█▀ █▀▀     █▐█▀ █▀█ ░█░ █▀▀
**▀░ ▀ ▀░▀▀ ▀▀▀     ▀░▀▀ ▀░▀ ░▀░ ▀▀▀
*************************************/
stock void FireRate(int weapon) {
	float m_flNextPrimaryAttack = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
	float m_flNextSecondaryAttack = GetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack");
	SetEntPropFloat(weapon, Prop_Send, "m_flPlaybackRate", 10.0);
	float fGameTime = GetGameTime();

	float fTimePrimary = (m_flNextPrimaryAttack - fGameTime) - 0.99;
	float fTimeSecondary = (m_flNextSecondaryAttack - fGameTime) - 0.99;
	float fFinalPrimary = fTimePrimary + fGameTime;
	float fFinalSecondary = fTimeSecondary + fGameTime;

	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", fFinalPrimary);
	SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", fFinalSecondary);
}

/*
**▄▀▄ █▄░█ ▄▀▀░ █░░ █▀▀ ▄▀▀     █▀ ▀ █░█
**█▀█ █░▀█ █░▀▌ █░▄ █▀▀ ░▀▄     █▀ █ ▄▀▄
**▀░▀ ▀░░▀ ▀▀▀░ ▀▀▀ ▀▀▀ ▀▀░     ▀░ ▀ ▀░▀
********************************************/
stock void FixAngle(float Angle[3]) {
	if (Angle[0] >= 90.0) {
		Angle[0] -= 360.0;
	}
}

public void AnglesNormalize(float vAngles[3])
{
	while(vAngles[0] > 89.0) vAngles[0] -= 360.0;
	while(vAngles[0] < -89.0) vAngles[0] += 360.0;
	while(vAngles[1] > 180.0) vAngles[1] -= 360.0;
	while(vAngles[1] < -180.0) vAngles[1] += 360.0;
}

stock float GetAngleX(const float coords1[3], const float coords2[3])
{
	float angle = RadToDeg(ArcTangent((coords2[1] - coords1[1]) / (coords2[0] - coords1[0])));
	if (coords2[0] < coords1[0])
	{
	if (angle > 0.0) angle -= 180.0;
	else angle += 180.0;
	}
	return angle;
}

public float AngleDistance(const float angle1, const float angle2, bool YAxis)
{
	float tempAng1 = angle1;
	float tempAng2 = angle2;
	float distance;
	if (!YAxis)
	{
		if (tempAng1 < 0.0)
			tempAng1 += 360.0;
		if (tempAng2 < 0.0)
			tempAng2 += 360.0;
		if(tempAng1 >= tempAng2) {
			distance = FloatAbs(tempAng1 - tempAng2);
		} else {
			distance = FloatAbs(tempAng2 - tempAng1);
		}
    }
	else
	{
		if (tempAng1 < 0.0 || tempAng2 < 0.0)
		{
			tempAng1 += 360.0;
			tempAng2 += 360.0;
		}
		if(tempAng1 >= tempAng2) {
 			distance = FloatAbs(tempAng1 - tempAng2);
		} else {
			distance = FloatAbs(tempAng2 - tempAng1);
		}
	}
	return distance;
}

/*
**█▀ █░░ ▀ ▄▀ █░▄▀ ▄▀▀
**█▀ █░▄ █ █░ █▀▄░ ░▀▄
**▀░ ▀▀▀ ▀ ░▀ ▀░▀▀ ▀▀░
*************************************/
public GetFlickAngle(int entity, int rocket, float angles[3], bool cqc)
{
	float flickChances[7];
	if (cqc)
	{
		Array_Copy(CQCFlickChances, flickChances, 7);
	}
	else
	{
		Array_Copy(FlickChances, flickChances, 7);
	}
	float fEntityOrigin[3];
	GetEntPropVector(rocket, Prop_Data, "m_vecOrigin", fEntityOrigin);
	float fRand = GetRandomFloat(0.0, 1.0 - (FlickChances[0] / 100));
	// Regular Wave
	if (fRand <= (FlickChances[1] / 100) || angles[0] <= -40.0)
	{
		float fLocationPlayer[3], fLocationPlayerFinal[3];
		GetClientAbsOrigin(entity, fLocationPlayer);
		MakeVectorFromPoints(fEntityOrigin, fLocationPlayer, fLocationPlayerFinal);
		GetVectorAngles(fLocationPlayerFinal, angles);
	}
	// Up Spike
	else if (fRand - (FlickChances[1]/100) <= (FlickChances[2]/100))
	{
		angles[0] = -89.00;
	}
	// Down Spike
	else if (fRand - ((FlickChances[1]+FlickChances[2])/100) <= (FlickChances[3]/100))
	{
		if (angles[0] <= 50.00 && angles[0] >= 0.00)
		{
			angles[0] = 89.00;
		}
	}
	// Left Spike
	else if (fRand - ((FlickChances[1]+FlickChances[2]+FlickChances[3])/100) <= (FlickChances[4]/100))
	{
		angles[1] += 90.0;
	}
	// Right Spike
	else if (fRand - ((FlickChances[1]+FlickChances[2]+FlickChances[3]+FlickChances[4])/100) <= (FlickChances[5]/100))
	{
		angles[1] -= 90.0;
	}
	// Back Shot
	else if (fRand - ((FlickChances[1]+FlickChances[2]+FlickChances[3]+FlickChances[4]+FlickChances[5])/100) <= (FlickChances[6]/100))
	{
		angles[1] += 180.0;
	}
}

//Valid client
stock bool IsValidClient(int client) {
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}