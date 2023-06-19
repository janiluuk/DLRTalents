#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION	"0.2"
#define CVAR_FLAGS		FCVAR_NONE
#define PLUGIN_SKILL_NAME = "healing_ball"
#define PLUGIN_SKILL_DESCRIPTION "Summons health orb around player to heal others."
public Plugin myinfo =
{
	name = "[DLR] Healing ball plugin version",
	author = "zonde306, Yani",
	description = PLUGIN_SKILL_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = ""
};

#define HealingBall_Particle_Effect	"st_elmos_fire_cp0"
#define HealingBall_Sound_Lanuch	"ambient/fire/gascan_ignite1.wav"
#define HealingBall_Sound_Heal		"buttons/bell1.wav"
#define SPRITE_BEAM		"materials/sprites/laserbeam.vmt"
#define SPRITE_HALO		"materials/sprites/halo01.vmt"
#define SPRITE_GLOW		"materials/sprites/glow01.vmt"

new BlueColor[4] = {80, 80, 255, 255};
new Handle:HealingBallTimer[MAXPLAYERS+1];
new g_BeamSprite, g_HaloSprite, g_GlowSprite;

new Float:HealingBallInterval[MAXPLAYERS+1], Float:HealingBallEffect[MAXPLAYERS+1],
	Float:HealingBallRadius[MAXPLAYERS+1], Float:HealingBallDuration[MAXPLAYERS+1];

public void OnSpecialSkillUsed(int client, const char[] skillName)
{
	if(!StrEqual(skillName, PLUGIN_SKILL_NAME, false))
		return;
	
	HealingBallInterval[client] = 1.0;
	HealingBallEffect[client] = 1.5);
	HealingBallRadius[client] = 130.0);
	HealingBallDuration[client] = 8.0;
	HealingBallFunction(client);
	PrintToChat(client, "\x03[DLR]\x01 Healing ball now active\x01", HealingBallDuration[client]);
}

public void OnMapStart()
{
	PrecacheSound(HealingBall_Sound_Lanuch, true);
	PrecacheSound(HealingBall_Sound_Heal, true);
	PrecacheParticle(HealingBall_Particle_Effect);
	g_BeamSprite = PrecacheModel(SPRITE_BEAM);
	g_HaloSprite = PrecacheModel(SPRITE_HALO);
	g_GlowSprite = PrecacheModel(SPRITE_GLOW);
}

public void OnMapEnd()
{
	for(new i = 1; i <= MaxClients; ++i)
	{
		if(HealingBallTimer[i] != INVALID_HANDLE)
			KillTimer(HealingBallTimer[i]);
		
		HealingBallTimer[i] = INVALID_HANDLE;
	}
}

public Action:HealingBallFunction(Client)
{
	new Float:Radius=HealingBallRadius[Client];
	new Float:pos[3];
	GetTracePosition(Client, pos);
	pos[2] += 50.0;
	EmitAmbientSound(HealingBall_Sound_Lanuch, pos);
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 10, 1.0, 5.0, 5.0, BlueColor, 5, 0);//固定外圈BuleColor
	TE_SendToAll();
	
	for(new i = 1; i<5; i++)
	{
		TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 2.5, 1000);
		TE_SendToAll();
	}

	if(HealingBallTimer[Client] != INVALID_HANDLE)
		KillTimer(HealingBallTimer[Client]);
	
	HealingBallTimer[Client] = INVALID_HANDLE;
	
	new Handle:pack;
	HealingBallTimer[Client] = CreateDataTimer(HealingBallInterval[Client], HealingBallTimerFunction, pack, TIMER_REPEAT);
	WritePackCell(pack, Client);
	WritePackFloat(pack, pos[0]);
	WritePackFloat(pack, pos[1]);
	WritePackFloat(pack, pos[2]);
	WritePackFloat(pack, GetEngineTime());

	return Plugin_Handled;
}

public Action:HealingBallTimerFunction(Handle:timer, Handle:pack)
{
	decl Float:pos[3], Float:entpos[3], Float:distance[3];
	
	ResetPack(pack);
	new Client = ReadPackCell(pack);
	pos[0] = ReadPackFloat(pack);
	pos[1] = ReadPackFloat(pack);
	pos[2] = ReadPackFloat(pack);
	new Float:time=ReadPackFloat(pack);
	
	EmitAmbientSound(HealingBall_Sound_Heal, pos);
	for(new i = 1; i<5; i++)
	{
		TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 2.5, 1000);
		TE_SendToAll();
	}
	
	//new iMaxEntities = GetMaxEntities();
	new Float:Radius=HealingBallRadius[Client];
	
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 10, 1.0, 10.0, 5.0, BlueColor, 5, 0);//固定外圈BuleColor
	TE_SendToAll();

	new team = GetClientTeam(Client);
	if(GetEngineTime() - time < HealingBallDuration[Client])
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				if(GetClientTeam(i) == team && IsPlayerAlive(i))
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						new HP = GetClientHealth(i);
						
						if(IsPlayerIncapped(i))
						{
							SetEntProp(i, Prop_Data, "m_iHealth", HP+RoundToCeil(HealingBallEffect[Client]));
						}
						else
						{
							new MaxHP = GetEntProp(i, Prop_Data, "m_iMaxHealth");
							HP += RoundToCeil(HealingBallEffect[Client]);
							if(HP > MaxHP)
								HP = MaxHP;
							
							SetEntProp(i, Prop_Data, "m_iHealth", HP);
							/*
							if(MaxHP > HP+HealingBallEffect[i])
							{
								SetEntProp(i, Prop_Data, "m_iHealth", HP+HealingBallEffect[Client]);
							}
							else if(MaxHP < HP+HealingBallEffect[Client])
							{
								SetEntProp(i, Prop_Data, "m_iHealth", MaxHP);
							}
							*/
						}
						
						ShowParticle(entpos, HealingBall_Particle_Effect, 0.5);
						TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 0.5, BlueColor, 0);
						TE_SendToAll();
					}
				}
			}
		}
	}
	else
	{
		KillTimer(HealingBallTimer[Client]);
		HealingBallTimer[Client] = INVALID_HANDLE;
	}
}

stock bool:IsPlayerIncapped(Client)
{
	if(GetEntProp(Client, Prop_Send, "m_isIncapacitated")==1)
		return true;
	return false;
}

/* 读取準心位置 */
public GetTracePosition(client, Float:TracePos[3])
{
	decl Float:clientPos[3], Float:clientAng[3];

	GetClientEyePosition(client, clientPos);
	GetClientEyeAngles(client, clientAng);
	new Handle:trace = TR_TraceRayFilterEx(clientPos, clientAng, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer, client);
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(TracePos, trace);
	}
	CloseHandle(trace);
}

public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
	return entity > MaxClients || !entity;
}

public ShowParticle(Float:pos[3], String:particlename[], Float:time)
{
	/* Show particle effect you like */
	new particle = CreateEntityByName("info_particle_system");
	if(IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle);
	}
}

public AttachParticle(ent, String:particleType[], Float:time)
{
	decl String:tName[64];
	new particle = CreateEntityByName("info_particle_system");
	if(IsValidEdict(particle) && IsValidEdict(ent))
	{
		new Float:pos[3];
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		GetEntPropString(ent, Prop_Data, "m_iName", tName, sizeof(tName));
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "parentname", tName); 
		DispatchKeyValue(particle, "effect_name", particleType);
		DispatchSpawn(particle);
		SetVariantString(tName);
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle);
	}
}

public Action:DeleteParticles(Handle:timer, any:particle)
{
	/* Delete particle */
    if(IsValidEdict(particle) && IsValidEntity(particle))
	{
		new String:classname[64];
		GetEdictClassname(particle, classname, sizeof(classname));
		if(StrEqual(classname, "info_particle_system", false))
		{
			AcceptEntityInput(particle, "stop");
			AcceptEntityInput(particle, "kill");
			RemoveEdict(particle);
		}
	}
}

public PrecacheParticle(String:particlename[])
{
	/* Precache particle */
	new particle = CreateEntityByName("info_particle_system");
	if(IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(0.01, DeleteParticles, particle);
	}
}

