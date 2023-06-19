#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#define PLUGIN_SKILL_NAME "Jumper"
#define PLUGIN_VERSION			"0.0.2"
#include "modules/baseplugin.sp"

public Plugin myinfo =
{
	name = "[DLR] Jump perk",
	author = "zonde306, Yani",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/",
};

const float g_fHighJumpFactor = 0.0625;
const float g_fLongJumpFactor = 0.0625;
const float g_fSpeedFactor = 0.01;

int g_iSlotAbility;
int g_iLevelBHop[MAXPLAYERS+1], g_iLevelDouble[MAXPLAYERS+1], g_iLevelHigh[MAXPLAYERS+1], g_iLevelFar[MAXPLAYERS+1], g_iLevelSpeed[MAXPLAYERS+1];
ConVar g_hCvarGravity, g_pCvarJumpHeight, g_pCvarDuckHeight, g_pCvarCalmTime;
int g_iOffVelocity;

public OnPluginStart()
{
	InitPlugin("sfj");
	g_hCvarGravity = FindConVar("sv_gravity");
	g_pCvarJumpHeight = CreateConVar("l4d2_sfj_height", "35.0", "跳跃高度", CVAR_FLAGS, true, 0.0);
	g_pCvarDuckHeight = CreateConVar("l4d2_sfj_duck_height", "52.0", "蹲下跳跃高度", CVAR_FLAGS, true, 0.0);
	g_pCvarCalmTime = CreateConVar("l4d2_sfj_calm_time", "1.0", "重置计数时间", CVAR_FLAGS, true, 0.0);
	AutoExecConfig(true, "l4d2_sfj");
	
	UpdateCache(null, "", "");
	g_hCvarGravity.AddChangeHook(UpdateCache);
	g_pCvarJumpHeight.AddChangeHook(UpdateCache);
	g_pCvarDuckHeight.AddChangeHook(UpdateCache);
	g_pCvarCalmTime.AddChangeHook(UpdateCache);
		
	g_iOffVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_jump", Event_PlayerJump);
	HookEvent("player_jump_apex", Event_PlayerJumpApex);
	
	g_iSlotAbility = DLR_RegSlot("ability");
	DLR_RegPerk(g_iSlotAbility, "bunnyhop", 5, 70, 5, 0.1);
	DLR_RegPerk(g_iSlotAbility, "doublejump", 2, 80, 5, 0.1);
	DLR_RegPerk(g_iSlotAbility, "highjump", 4, 50, 5, 0.1);
	DLR_RegPerk(g_iSlotAbility, "longjump", 4, 60, 5, 0.1);
	DLR_RegPerk(g_iSlotAbility, "movespeed", 5, 90, 5, 0.1);
}

float g_fGravity, g_fJumpHeight, g_fDuckHeight, g_fCalmTime;

public void UpdateCache(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_fGravity = g_hCvarGravity.FloatValue;
	g_fJumpHeight = g_pCvarJumpHeight.FloatValue;
	g_fDuckHeight = g_pCvarDuckHeight.FloatValue;
	g_fCalmTime = g_pCvarCalmTime.FloatValue;
}

public Action DLR_OnGetPerkName(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "bunnyhop"))
		FormatEx(result, maxlen, "Bunnyhop");
	else if(!strcmp(name, "doublejump"))
		FormatEx(result, maxlen, "Double Jump");
	else if(!strcmp(name, "highjump"))
		FormatEx(result, maxlen, "High jump");
	else if(!strcmp(name, "longjump"))
		FormatEx(result, maxlen, "Jump far");
	else if(!strcmp(name, "movespeed"))
		FormatEx(result, maxlen, "Movement speed");
	else
		return Plugin_Continue;
	return Plugin_Changed;
}

public Action DLR_OnGetPerkDescription(int client, const char[] name, int level, char[] result, int maxlen)
{
	if(!strcmp(name, "bunnyhop"))
		FormatEx(result, maxlen, "Hold space to bunnyhop");
	else if(!strcmp(name, "doublejump"))
		FormatEx(result, maxlen, "You can jump twice");
	else if(!strcmp(name, "highjump"))
		FormatEx(result, maxlen, "You can jump high");
	else if(!strcmp(name, "longjump"))
		FormatEx(result, maxlen, "You can jump far");
	else if(!strcmp(name, "movespeed"))
		FormatEx(result, maxlen, "You move faster");
		return Plugin_Continue;
	return Plugin_Changed;
}

public void DLR_OnPerkPost(int client, int level, const char[] perk)
{
	if(!strcmp(perk, "bunnyhop"))
		g_iLevelBHop[client] = level;
	else if(!strcmp(perk, "doublejump"))
		g_iLevelDouble[client] = level;
	else if(!strcmp(perk, "highjump"))
		g_iLevelHigh[client] = level;
	else if(!strcmp(perk, "longjump"))
		g_iLevelFar[client] = level;
	else if(!strcmp(perk, "movespeed"))
		g_iLevelSpeed[client] = level;
}

bool g_bJumpReleased[MAXPLAYERS+1], g_bFirstJump[MAXPLAYERS+1];
int g_iCountBHop[MAXPLAYERS+1], g_iCountMulJmp[MAXPLAYERS+1];

public void DLR_OnLoad(int client)
{
	g_iLevelBHop[client] = DLR_GetClientPerk(client, "bunnyhop");
	g_iLevelDouble[client] = DLR_GetClientPerk(client, "doublejump");
	g_iLevelHigh[client] = DLR_GetClientPerk(client, "highjump");
	g_iLevelFar[client] = DLR_GetClientPerk(client, "longjump");
	g_iLevelSpeed[client] = DLR_GetClientPerk(client, "movespeed");
}

public void Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	g_iLevelBHop[client] = DLR_GetClientPerk(client, "bunnyhop");
	g_iLevelDouble[client] = DLR_GetClientPerk(client, "doublejump");
	g_iLevelHigh[client] = DLR_GetClientPerk(client, "highjump");
	g_iLevelFar[client] = DLR_GetClientPerk(client, "longjump");
	g_iLevelSpeed[client] = DLR_GetClientPerk(client, "movespeed");
	
	// SDKUnhook(client, SDKHook_PreThinkPost, EntHook_PreThinkPost);
	// SDKHook(client, SDKHook_PreThinkPost, EntHook_PreThinkPost);
}

public void Event_PlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	// SDKUnhook(client, SDKHook_PreThinkPost, EntHook_PreThinkPost);
}

public void Event_PlayerJump(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client))
		return;
	
	g_bFirstJump[client] = true;
	g_bJumpReleased[client] = false;
	g_iCountBHop[client] = 0;
	g_iCountMulJmp[client] = 0;
	
	RequestFrame(OnJumpPost, client);
	
	// PrintToChat(client, "player_jump");
}

public void Event_PlayerJumpApex(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidAliveClient(client))
		return;
	
	g_bFirstJump[client] = false;
	
	// PrintToChat(client, "player_jump_apex");
}

public void OnJumpPost(any client)
{
	if(!IsValidAliveClient(client))
		return;
	
	float velocity[3];
	bool changed = false;
	GetEntDataVector(client, g_iOffVelocity, velocity);
	
	if(g_iLevelFar[client] > 0)
	{
		float factor = 1.0 + (g_iLevelFar[client] * g_fLongJumpFactor);
		velocity[0] *= factor;
		velocity[1] *= factor;
		changed = true;
	}
	
	if(g_iLevelHigh[client] > 0)
	{
		float factor = 1.0 + (g_iLevelHigh[client] * g_fHighJumpFactor);
		velocity[2] *= factor;
		changed = true;
	}
	
	if(changed)
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
}

public void EntHook_PreThinkPost(int client)
{
	if(!IsValidAliveClient(client) || g_iLevelSpeed[client] < 1)
		return;
	
	float factor = 1.0 + (g_fSpeedFactor * g_iLevelSpeed[client]);
	float maxspeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", maxspeed * factor);
}

public Action L4D_OnGetRunTopSpeed(int client, float& speed)
{
	if(g_iLevelSpeed[client] < 1)
		return Plugin_Continue;
	
	float factor = 1.0 + (g_fSpeedFactor * g_iLevelSpeed[client]);
	speed *= factor;
	return Plugin_Handled;
}

public Action L4D_OnGetWalkTopSpeed(int client, float& speed)
{
	return L4D_OnGetRunTopSpeed(client, speed);
}

public Action L4D_OnGetCrouchTopSpeed(int client, float& speed)
{
	return L4D_OnGetRunTopSpeed(client, speed);
}

int IntBound(int v, int min, int max)
{
	if(v < min)
		v = min;
	if(v > max)
		v = max;
	return v;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3],
	int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if(!IsValidAliveClient(client) ||
		GetEntProp(client, Prop_Send, "m_isIncapacitated") ||
		GetEntProp(client, Prop_Send, "m_isHangingFromLedge") ||
		IsTrapped(client) || IsGettingUp(client) || IsStaggering(client))
		return;
	
	bool inWalk = (GetEntityMoveType(client) == MOVETYPE_WALK);
	bool inWater = (GetEntProp(client, Prop_Data, "m_nWaterLevel") > 1);
	bool inGround = (GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") > -1);
	bool canJump = (inWalk && !inWater);
	
	if(!inGround && !(buttons & IN_JUMP))
	{
		g_bJumpReleased[client] = true;
		
		// PrintToChat(client, "JumpReleased");
	}
	
	else if(!inGround && canJump && (buttons & IN_JUMP) && g_bJumpReleased[client] && g_iCountMulJmp[client] < g_iLevelDouble[client])
	{
		float velocity[3];
		GetEntDataVector(client, g_iOffVelocity, velocity);
		// velocity[0] = vel[0]; velocity[1] = vel[1]; velocity[2] = vel[2];
		
		float upVel = CaclJumpVelocity(client);
		if(velocity[2] < upVel)
			velocity[2] = upVel;
		
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
		
		g_bJumpReleased[client] = false;
		g_iCountMulJmp[client] += 1;
		
		// PrintToChat(client, "DoubleJump");
	}
	
	else if(inGround && canJump && (buttons & IN_JUMP) && !g_bFirstJump[client] && g_iCountBHop[client] < g_iLevelBHop[client])
	{
		float velocity[3];
		GetEntDataVector(client, g_iOffVelocity, velocity);
		// velocity[0] = vel[0]; velocity[1] = vel[1]; velocity[2] = vel[2];
		
		float upVel = CaclJumpVelocity(client);
		if(velocity[2] < upVel)
			velocity[2] = upVel;
		
		SetEntPropEnt(client, Prop_Send, "m_hGroundEntity", -1);
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
		
		g_bJumpReleased[client] = false;
		g_iCountBHop[client] += 1;
		
		// PrintToChat(client, "BunnyHop");
	}
	
	if(inGround && canJump)
	{
		g_iCountMulJmp[client] = 0;
	}
}

float CaclJumpVelocity(int client)
{
	bool ducking = ((GetClientButtons(client) & IN_DUCK) && (GetEntityFlags(client) & FL_DUCKING));
	
	float height = SquareRoot(2.0 * g_fGravity * (ducking ? g_fDuckHeight : g_fJumpHeight)/* / GetEntityGravity(client)*/);
	
	return height;
}

bool IsTrapped(int client)
{
	char result[64];
	L4D2_GetVScriptOutput(tr("PlayerInstanceFromIndex(%d).IsDominatedBySpecialInfected()", client), result, sizeof(result));
	return !strcmp(result, "true");
}

bool IsGettingUp(int client)
{
	char result[64];
	L4D2_GetVScriptOutput(tr("PlayerInstanceFromIndex(%d).IsGettingUp()", client), result, sizeof(result));
	return !strcmp(result, "true");
}

bool IsStaggering(int client)
{
	char result[64];
	L4D2_GetVScriptOutput(tr("PlayerInstanceFromIndex(%d).IsStaggering()", client), result, sizeof(result));
	return !strcmp(result, "true");
}
