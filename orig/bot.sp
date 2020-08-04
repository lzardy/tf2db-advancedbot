#pragma semicolon 1

#include <sourcemod>
#include <smlib/math>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>	
#include <morecolors>
#pragma newdecls required

/* ConVars */
Handle g_botName = null;
Handle g_percentVote = null;
Handle g_hMaxOrbitTime;
Handle g_hMaxOrbitSpeed;
Handle g_hOrbitAngleX;
Handle g_hOrbitAngleY;

/* Stuff */
int bot;
int iVotes;
int iOwner;
int iOldOwner;
//int iBotMode;
bool TargetOwner = false;
bool iVote[MAXPLAYERS + 1] = false;
bool botActivated = false;
bool IsSetupDone = false;
bool IsBotOrbiting = false;
float MaxOrbitTime;
float MaxOrbitSpeed;
float OrbitAngleX;
float OrbitAngleY;

public Plugin myinfo =
{
	name = "Advanced bot",
	author = "soul",
	description = "Advanced bot (orbit)",
	version = "v1.8 (BETA)",
	url = ""
};

public void OnPluginStart() {
	g_botName = CreateConVar("sm_botname", "Super Bot", "Set the bot's name.");
	
	g_percentVote = CreateConVar("sm_percentageVotes", "50.0", "Needed percentage to activate the superbot", _, true, 0.0, true, 100.0);
	
	g_hMaxOrbitTime = CreateConVar("sm_bot_orbittime", "3.00", "Maximum amount of time (in seconds) the bot can orbit, DEFAULT: 3 seconds.", FCVAR_NONE, true, 1.00, false);
	MaxOrbitTime = GetConVarFloat(g_hMaxOrbitTime);
	HookConVarChange(g_hMaxOrbitTime, OnConVarChange);
	
	g_hMaxOrbitSpeed = CreateConVar("sm_bot_orbitspeed", "-1.0", "Max speed bot can orbit, DEFAULT: Infinite, or -1.0.", FCVAR_NONE, true, -1.00, false);
	MaxOrbitSpeed = GetConVarFloat(g_hMaxOrbitSpeed);
	HookConVarChange(g_hMaxOrbitSpeed, OnConVarChange);
	
	g_hOrbitAngleX = CreateConVar("sm_bot_orbitangle_x", "15.0", "Angle (in degrees left/right) from bot->rocket needed for the bot to orbit, DEFAULT: 15.0.", FCVAR_NONE, true, 0.00, true, 179.99);
	OrbitAngleX = GetConVarFloat(g_hOrbitAngleX);
	HookConVarChange(g_hOrbitAngleX, OnConVarChange);
	
	g_hOrbitAngleY = CreateConVar("sm_bot_orbitangle_y", "30.0", "Angle (in degrees up/down) from bot->rocket where bot will no longer orbit, DEFAULT: 30.0.", FCVAR_NONE, true, 0.00, true, 179.99);
	OrbitAngleY = GetConVarFloat(g_hOrbitAngleY);
	HookConVarChange(g_hOrbitAngleY, OnConVarChange);

	HookEvent("object_deflected", OnDeflect, EventHookMode_Post);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("teamplay_setup_finished", OnSetupFinished, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_Post);

	RegAdminCmd("sm_pvb", Command_PVB, ADMFLAG_ROOT, "Enable PVB");
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
	if(hConvar == g_hMaxOrbitTime)
		MaxOrbitTime = StringToFloat(newValue);
	if(hConvar == g_hMaxOrbitSpeed)
		MaxOrbitSpeed = StringToFloat(newValue);
	if(hConvar == g_hOrbitAngleX)
		OrbitAngleX = StringToFloat(newValue);
	if(hConvar == g_hOrbitAngleY)
		OrbitAngleY = StringToFloat(newValue);
}

/*
**▄▀ ▄▀▄ █▄░▄█ █▄░▄█ ▄▀▄ █▄░█ █▀▄ ▄▀▀
**█░ █░█ █░█░█ █░█░█ █▀█ █░▀█ █░█ ░▀▄
**░▀ ░▀░ ▀░░░▀ ▀░░░▀ ▀░▀ ▀░░▀ ▀▀░ ▀▀░
**********************************************/
public Action Command_PVB(int client, int args) {
  if (IsValidClient(client)) {
    if (!botActivated) {
      CPrintToChatAll("{DEFAULT}Player vs Bot is now {TURQUOISE}activated");
      EnableMode();
    } else {
      CPrintToChatAll("{DEFAULT}Player vs Bot is now {TURQUOISE}disabled");
      DisableMode();
    }
  }
  return Plugin_Handled;
}

public Action Command_VotePVB(int client, int args) {
	int iNeededVotes = RoundToCeil((GetAllClientCount() * GetConVarFloat(g_percentVote)) / 100.0);
	if (!iVote[client] && IsValidClient(client)) {
		iVotes++;
		if (!botActivated) {
			CPrintToChatAll("{TURQUOISE}%N {DEFAULT}wants to enable Player Vs. Bot! ({TURQUOISE}%i {DEFAULT}votes), ({TURQUOISE}%i {DEFAULT}required).", client, iVotes, iNeededVotes);
		} else {
			CPrintToChatAll("{TURQUOISE}%N {DEFAULT}wants to disable Player Vs. Bot! ({TURQUOISE}%i {DEFAULT}votes), ({TURQUOISE}%i {DEFAULT}required).", client, iVotes, iNeededVotes);
		}
		iVote[client] = true;
	} else if (iVote[client] && IsValidClient(client)) {
		CPrintToChat(client, "{TURQUOISE}%N {DEFAULT}you can't vote twice!", client);
	}
	if (iVotes >= iNeededVotes) {
		if (!botActivated) {
			CPrintToChatAll("{DEFAULT}Player vs Bot is now {TURQUOISE}activated!");
			EnableMode();
		}
		else {
			CPrintToChatAll("{DEFAULT}Player vs Bot is now {TURQUOISE}disabled!");
			DisableMode();
		}
		iVote[client] = false;
		iVotes = 0;
	}
	return Plugin_Handled;
}

/*
**▄▀▀ █▀▀ ▀█▀ █░█ █▀▄
**░▀▄ █▀▀ ░█░ █░█ █░█
**▀▀░ ▀▀▀ ░▀░ ░▀░ █▀░
**************************/
public void OnClientPutInServer(int client) {
	if (IsFakeClient(client) && !botActivated) {
		DisableMode();
	}
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
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

public Action OnDeflect(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	if (botActivated) {
		iOwner = GetClientOfUserId(GetEventInt(hEvent, "userid"));
		int iEntity = GetEventInt(hEvent, "object_entindex");
		if (FindEntityByClassname(iEntity, "tf_projectile_rocket") && IsValidEntity(iEntity)) {
			if (iOwner != bot && IsValidClient(iOwner) && IsPlayerAlive(iOwner)) {
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
		/*if (iBotMode == 2)*/
		int iClient = ChooseClient();
		if (IsValidClient(iClient) && IsPlayerAlive(iClient) && IsPlayerAlive(bot) && IsValidClient(bot) && IsValidClient(client)) 
		{
			if (client == iClient/* && iBotMode == 2*/) {
				FollowClient(client, buttons);
			}
			else if (client == bot) 
			{
				AutoReflect(iClient, buttons);
				/*if (iBotMode == 2)*/ 
				OrbitRocket(angles);
			}
		}
	}
	return Plugin_Continue;
}

/*
**█▀▀ █▄░█ █▀▄
**█▀▀ █░▀█ █░█
**▀▀▀ ▀░░▀ ▀▀░
*****************/
public void OnClientDisconnect(int client) {
	if (iVote[client]) {
		if (iVotes > 0) {
			iVotes -= 1;
		}
		iVote[client] = false;
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
		if (iVote[i]) {
			iVote[i] = false;
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
stock void FollowClient(int client, int &buttons) {
	float fOriginPlayer[3];
	//Get origin, raise the z vector, inv the vector.
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fOriginPlayer);
	fOriginPlayer[2] = 300.0;
	NegateVector(fOriginPlayer);
	//Get buttons, sync the bot with the client moves.
	if (!(IsBotOrbiting)) {
		if (buttons & IN_FORWARD || IN_BACK || IN_MOVELEFT || IN_MOVERIGHT) {
			TeleportEntity(bot, NULL_VECTOR, NULL_VECTOR, fOriginPlayer);
		}
	}
}

stock Action AutoReflect(int iClient, int &buttons, int iEntity = -1) {
	static float flNextAirblastTime;
	float fEntityOrigin[3], fBotOrigin[3], fDistance[3], fFinalAngle[3], fDistAuto;
	while ((iEntity = FindEntityByClassname(iEntity, "tf_projectile_*")) != INVALID_ENT_REFERENCE) {
		int iCurrentWeapon = GetEntPropEnt(bot, Prop_Send,"m_hActiveWeapon");
		int iTeamRocket = GetEntProp(iEntity,	Prop_Send, "m_iTeamNum");
		//Distance between the rocket and the bot eyes.
		GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
		GetClientEyePosition(bot, fBotOrigin);
		MakeVectorFromPoints(fBotOrigin, fEntityOrigin, fDistance);
		//Transform the vectors into angles
		GetVectorAngles(fDistance, fFinalAngle);
		// fix for clamping spam
		FixAngle(fFinalAngle);
		//Define the distance and the airblast of the bot.
		fDistAuto = GetVectorDistance(fBotOrigin, fEntityOrigin, false);
		if (!IsBotOrbiting && fDistAuto < 250.0 && iTeamRocket == 3) {
			TeleportEntity(bot, NULL_VECTOR, fFinalAngle, NULL_VECTOR);
			FireRate(iCurrentWeapon);
			buttons |= IN_ATTACK2;
			flNextAirblastTime = GetEngineTime() + GetRandomFloat(1.00, MaxOrbitTime);
			return Plugin_Changed;
		}
		if (fDistAuto < 75.0 && iTeamRocket == 3) {
			TeleportEntity(bot, NULL_VECTOR, fFinalAngle, NULL_VECTOR);
			FireRate(iCurrentWeapon);
			buttons |= IN_ATTACK2;
			flNextAirblastTime = GetEngineTime() + GetRandomFloat(1.00, MaxOrbitTime);
			return Plugin_Changed;
		}
		else {
			AimClient(iClient);
		}
		if (IsBotOrbiting)
		{
			if(flNextAirblastTime <= GetEngineTime())
			{
				TeleportEntity(bot, NULL_VECTOR, fFinalAngle, NULL_VECTOR);
				FireRate(iCurrentWeapon);
				buttons |= IN_ATTACK2;
				flNextAirblastTime = GetEngineTime() + GetRandomFloat(1.00, MaxOrbitTime);
				//PrintToServer("Orbit over, airblasting. Next AB time: %f", flNextAirblastTime);
			}
		}
	}
	if ((iEntity = FindEntityByClassname(iEntity, "tf_projectile_*")) == INVALID_ENT_REFERENCE) {
		AimClient(iClient); //Add this to search the client even if the rocket is an INVALID_ENT_REFERENCE
	}
	return Plugin_Continue;
}

/*
**▄▀▄ █▀▀▄ █▀▄ ▀ ▀█▀
**█░█ █▐█▀ █▀█ █ ░█░
**░▀░ ▀░▀▀ ▀▀░ ▀ ░▀░
******************************/

stock void OrbitRocket(float angles[3]) {
	int iEntity = -1;
	float fBotOrigin[3], fEntityOrigin[3], fDistVector[3], fDistAngle[3], fRocketDistVector[3], fRocketAngle[3], fRocketVelocity[3], fDistance;
	while ((iEntity = FindEntityByClassname(iEntity, "tf_projectile_*")) != INVALID_ENT_REFERENCE) {
		int iTeamRocket = GetEntProp(iEntity,	Prop_Send, "m_iTeamNum");
		GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
		GetEntPropVector(iEntity, Prop_Data, "m_vecAbsVelocity", fRocketVelocity);
		GetClientEyePosition(bot, fBotOrigin);
		MakeVectorFromPoints(fEntityOrigin, fBotOrigin, fDistVector);
		GetVectorAngles(fDistVector, fDistAngle);
		fDistance = GetVectorDistance(fBotOrigin, fEntityOrigin, false);
		MakeVectorFromPoints(fBotOrigin, fEntityOrigin, fRocketDistVector);
		
		fRocketAngle[0] = 0.0 - RadToDeg(ArcTangent((fEntityOrigin[2] - fBotOrigin[2]) / (FloatAbs(SquareRoot(Pow(fBotOrigin[0] - fEntityOrigin[0], 2.0) + Pow(fEntityOrigin[1] - fBotOrigin[1], 2.0))))));
		fRocketAngle[1] = GetAngleX(fBotOrigin, fEntityOrigin);
		AnglesNormalize(fRocketAngle);
		
		if (fDistance < 400.0 && iTeamRocket == 3 && (RoundFloat(GetVectorLength(fRocketVelocity) * (15.0/352.0)) <= MaxOrbitSpeed || MaxOrbitSpeed == -1.0) && (AngleDistance(angles[1], fRocketAngle[1], false) >= OrbitAngleX && AngleDistance(angles[0], fRocketAngle[0], true) <= OrbitAngleY)) {
			IsBotOrbiting = true;
			
			float fOrbitVelocity[3];
			MakeVectorFromPoints(fBotOrigin, fEntityOrigin, fOrbitVelocity);
			NormalizeVector(fOrbitVelocity, fOrbitVelocity);
			ScaleVector(fOrbitVelocity, -300.0);
			TeleportEntity(bot, NULL_VECTOR, NULL_VECTOR, fOrbitVelocity);
		}
		else {
			IsBotOrbiting = false;
		}
	}
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
	while(vAngles[0] >  89.0) vAngles[0]-=360.0;
	while(vAngles[0] < -89.0) vAngles[0]+=360.0;
	while(vAngles[1] > 180.0) vAngles[1]-=360.0;
	while(vAngles[1] <-180.0) vAngles[1]+=360.0;
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
			distance = Math_Abs(tempAng1 - tempAng2);
		} else {
			distance = Math_Abs(tempAng2 - tempAng1);
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
 			distance = Math_Abs(tempAng1 - tempAng2);
		} else {
			distance = Math_Abs(tempAng2 - tempAng1);
		}
	}
	return distance;
}

//Valid client
stock bool IsValidClient(int client) {
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}