#pragma semicolon 1
#pragma newdecls required

//#define DEBUG

#define MAIN_TIMER_INTERVAL_S 5.0
#define PLUGIN_VERSION "1.0"
#define ANTI_RUSH_DEFAULT_FREQUENCY 30.0
#define ANTI_RUSH_FREQ_INC 0.5

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <jutils>
#include <left4dhooks>
#tryinclude <sceneprocessor>
#tryinclude <actions>
#include <basecomm>
#include <perks>
#include <multicolors>

#tryinclude <l4d_anti_rush>


public Plugin myinfo = 
{
	name = "DLR Perks", 
	author = "", 
	description = "", 
	version = PLUGIN_VERSION, 
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	CreateNative("ApplyPerk", Native_ApplyPerk);
	return APLRes_Success;
}


public void OnPluginStart() {
	EngineVersion g_Game = GetEngineVersion();
	if(g_Game != Engine_Left4Dead2) {
		SetFailState("This plugin is for L4D2 only.");	
	}
	LoadTranslations("common.phrases");

	g_PlayerMarkedForward = new GlobalForward("OnPerkMarked", ET_Ignore, Param_Cell, Param_Cell);
	g_PerkAppliedForward = new GlobalForward("OnPerkApplied", ET_Ignore, Param_Cell, Param_Cell);


	// Load core things (perks & phrases):
	REPLACEMENT_PHRASES = new StringMap();
	TYPOS_DICT = new StringMap();
	LoadPhrases();
	LoadTypos();
	SetupPerks();
	SetupsPerkCombos();

	CreateTimer(1.0, Timer_DecreaseAntiRush, TIMER_REPEAT);

	g_spSpawnQueue = new ArrayList(sizeof(SpecialSpawnRequest));

	// Witch target overwrite stuff:
	GameData data = new GameData("feedtheperks");
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(data, SDKConf_Signature, "WitchAttack::WitchAttack");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	g_hWitchAttack = EndPrepSDKCall();
	delete data;
	
	hThrowItemInterval = CreateConVar("sm_perks_throw_interval", "30", "The interval in seconds to throw items. 0 to disable", FCVAR_NONE, true, 0.0);
	hThrowItemInterval.AddChangeHook(Change_ThrowInterval);
	hAutoPunish 		= CreateConVar("sm_perks_autopunish_action", "0", "Setup automatic punishment of players. Add bits together\n0=Disabled, 1=Tank magnet, 2=Special magnet, 4=Swarm, 8=InstantVomit", FCVAR_NONE, true, 0.0);
	hAutoPunishExpire 	= CreateConVar("sm_perks_autopunish_expire", "0", "How many minutes of gametime until autopunish is turned off? 0 for never.", FCVAR_NONE, true, 0.0);
	hMagnetChance 	 	= CreateConVar("sm_perks_magnet_chance", "1.0", "% of the time that the magnet will work on a player.", FCVAR_NONE, true, 0.0, true, 1.0);
	hMagnetTargetMode   = CreateConVar("sm_perks_magnet_targetting", "6", "How does the specials target players. Add bits together\n0=Incapped are ignored, 1=Specials targets incapped, 2=Tank targets incapped 4=Witch targets incapped");
	hShoveFailChance 	= CreateConVar("sm_perks_shove_fail_chance", "0.65", "The % chance that a shove fails", FCVAR_NONE, true, 0.0, true, 1.0);
	hBadThrowHitSelf    = CreateConVar("sm_perks_badthrow_fail_chance", "1", "The % chance that on a throw, they will instead hit themselves. 0 to disable", FCVAR_NONE, true, 0.0, true, 1.0);
	hBotReverseFFDefend = CreateConVar("sm_perks_bot_defend", "0", "Should bots defend themselves?\n0 = OFF\n1 = Will retaliate against non-admins\n2 = Anyone", FCVAR_NONE, true, 0.0, true, 2.0);
	hBotDefendChance = CreateConVar("sm_perks_bot_defend_chance", "0.75", "% Chance bots will defend themselves.", FCVAR_NONE, true, 0.0, true, 1.0);

	hSbFriendlyFire = FindConVar("sb_friendlyfire");

	if(hBotReverseFFDefend.IntValue > 0) hSbFriendlyFire.BoolValue = true;
	hBotReverseFFDefend.AddChangeHook(Change_BotDefend);

	RegAdminCmd("sm_perkl",  Command_ListThePerks, ADMFLAG_GENERIC, "Lists all the perks currently ingame.");
	RegAdminCmd("sm_perkm",  Command_ListModes,     ADMFLAG_KICK, "Lists all the perk modes and their description");
	RegAdminCmd("sm_perkr",  Command_ResetUser, 	  ADMFLAG_GENERIC, "Resets user of any perk effects.");
	RegAdminCmd("sm_perka",  Command_ApplyUser,     ADMFLAG_KICK, "Apply a perk mod to a player, or shows menu if no parameters.");
	RegAdminCmd("sm_perkas", Command_ApplyUserSilent,  ADMFLAG_ROOT, "Apply a perk mod to a player, or shows menu if no parameters.");
	RegAdminCmd("sm_perks",  Command_PerkMenu, ADMFLAG_GENERIC, "Opens a list that shows all the commands");
	RegAdminCmd("sm_mark", Command_MarkPendingPerk, ADMFLAG_KICK, "Marks a player as to be banned on disconnect");
	RegAdminCmd("sm_perkp",  Command_CrescendoPerk, ADMFLAG_KICK, "Applies a manual punish on the last crescendo activator");
	RegAdminCmd("sm_perkc",  Command_ApplyComboPerks, ADMFLAG_KICK, "Applies predefined combinations of perks");
	#if defined _actions_included
	RegAdminCmd("sm_witch_attack", Command_WitchAttack, ADMFLAG_BAN, "Makes all witches target a player");
	#endif
	RegAdminCmd("sm_insta", Command_InstaSpecial, ADMFLAG_KICK, "Spawns a special that targets them, close to them.");
	RegAdminCmd("sm_stagger", Command_Stagger, ADMFLAG_KICK, "Stagger a player");
	RegAdminCmd("sm_inface", Command_InstaSpecialFace, ADMFLAG_KICK, "Spawns a special that targets them, right in their face.");
	RegAdminCmd("sm_bots_attack", Command_BotsAttack, ADMFLAG_BAN, "Instructs all bots to attack a player until they have X health.");
	RegAdminCmd("sm_scharge", Command_SmartCharge, ADMFLAG_BAN, "Auto Smart charge");
	RegAdminCmd("sm_healbots", Command_HealTarget, ADMFLAG_BAN, "Make bots heal a player");

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_first_spawn", Event_PlayerFirstSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("triggered_car_alarm", Event_CarAlarm);
	HookEvent("witch_harasser_set", Event_WitchVictimSet);
	HookEvent("door_open", Event_DoorToggle);
	HookEvent("door_close", Event_DoorToggle);
	HookEvent("adrenaline_used", Event_SecondaryHealthUsed);
	HookEvent("pills_used", Event_SecondaryHealthUsed);
	HookEvent("entered_spit", Event_EnteredSpit);
	HookEvent("bot_player_replace", Event_BotPlayerSwap);
	HookEvent("heal_success", Event_HealSuccess);
	
	AddNormalSoundHook(SoundHook);

	AutoExecConfig(true, "l4d2_feedtheperks");

	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientConnected(i) && IsClientInGame(i)) {
			SDKHook(i, SDKHook_OnTakeDamage, Event_TakeDamage);
		}
	}
}
///////////////////////////////////////////////////////////////////////////////
// CVAR CHANGES
///////////////////////////////////////////////////////////////////////////////

public void Change_ThrowInterval(ConVar convar, const char[] oldValue, const char[] newValue) {
	//If a throw timer exists (someone has mode 11), destroy & recreate w/ new interval
	if(hThrowTimer != INVALID_HANDLE) {
		delete hThrowTimer;
		hThrowTimer = CreateTimer(convar.FloatValue, Timer_ThrowTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

// Turn on bot FF if bot defend enabled
public void Change_BotDefend(ConVar convar, const char[] oldValue, const char[] newValue) {
	hSbFriendlyFire.IntValue = convar.IntValue != 0;
}

///////////////////////////////////////////////////////////////////////////////
// METHODS - Old methods, some are also in feedtheperks/misc.inc
///////////////////////////////////////////////////////////////////////////////


void ThrowAllItems(int victim) {
	float vicPos[3], destPos[3];
	int clients[4];
	GetClientAbsOrigin(victim, vicPos);
	//Find a survivor to throw to (grabs the first nearest non-self survivor)
	int clientCount = GetClientsInRange(vicPos, RangeType_Visibility, clients, sizeof(clients));
	for(int i = 0; i < clientCount; i++) {
		if(clients[i] != victim) {
			GetClientAbsOrigin(clients[i], destPos);
			break;
		}
	}

	//Loop all item slots
	for(int slot = 0; slot <= 4; slot++) {
		Handle pack;
		CreateDataTimer(0.22 * float(slot), Timer_ThrowWeapon, pack);

		WritePackFloat(pack, destPos[0]);
		WritePackFloat(pack, destPos[1]);
		WritePackFloat(pack, destPos[2]);
		WritePackCell(pack, slot);
		WritePackCell(pack, victim);
	}
}

bool IsPlayerFarDistance(int client, float distance) {
	int farthestClient = -1, secondClient = -1;
	float highestFlow, secondHighestFlow;
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2) {
			float flow = L4D2Direct_GetFlowDistance(i);
			if(flow > highestFlow || farthestClient == -1) {
				secondHighestFlow = highestFlow;
				secondClient = farthestClient;
				farthestClient = i;
				highestFlow = flow;
			}
		}
	}
	//Incase the first player checked is the farthest:
	if(secondClient == -1) {
		for(int i = 1; i <= MaxClients; i++) {
			if(IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2) {
				float flow = L4D2Direct_GetFlowDistance(i);
				if(farthestClient != i && ((flow < highestFlow && flow > secondHighestFlow) || secondClient == -1)) {
					secondClient = i;
					secondHighestFlow = flow;
				}
			}
		}
	}
	float difference = highestFlow - secondHighestFlow;
	PrintToConsoleAll("Flow Check | Player1=%N Flow1=%f Delta=%f", farthestClient, highestFlow, difference);
	PrintToConsoleAll("Flow Check | Player2=%N Flow2=%f", secondClient, secondHighestFlow);
	return client == farthestClient && difference > distance;
}

BehaviorAction CreateWitchAttackAction(int target = 0) {
    BehaviorAction action = ActionsManager.Allocate(18556);    
    SDKCall(g_hWitchAttack, action, target);
    return action;
}  

Action OnWitchActionUpdate(BehaviorAction action, int actor, float interval, ActionResult result) {
    /* Change to witch attack */
    result.type = CHANGE_TO;
    result.action = CreateWitchAttackAction(g_iWitchAttackVictim);
    result.SetReason("FTT");
    return Plugin_Handled;
} 
