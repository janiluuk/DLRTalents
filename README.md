# L4D2_DLRTalents

This is anniversary update for the infamous DLR mode for Left 4 Dead 2. Original is from 2013

## Changes:

## Generic

- Sourcemod 11 compatible
- Rewrite for internal variable structure, variable naming and lot of faulty logic
- Plugin support, adding new features should be a matter of implementing hooks to a plugin you want to add.
- Underlying code has been separated into maintainable parts.

## Gameplay

- Modular perk system that eventually replaces current hardcoded functionality.
- Negative effect perks
- Each plugin can be flexibly configured as one or many perks that users can acquire through player class
- Combo support enables chained perk execution
- Keybinding support
- New playerclasses can be easily generated and configured
- Class based custom skins!
- New HUD interface, accomodates essential info, alerts, killcounter etc. Disabled by default.
- Includes modifiers for adrenaline/pills/revive/heal durations.
- Classes get notification if out of supplies.
- More helpful class descriptions and help system.
- Gun reload glitches fixed
- Invisibility rewrite, it never really worked properly before.
- Debug modes, dedicated admin menu and useful tools

## Class changes

- Soldier has faster moving speed and takes less damage.
- Soldier melee rate is ninja level.
- Soldier can order airstrikes. (Requires included example plugin)
- Athlete has faster moving speed and a parachute. configurable.
- Athlete can do jump karate kicks to knock othes down.
- Commando reload rate actually works now.
- Commando has berzerk mode available, stay out of that guys way during it.
- Commando damage modifiers are configurable per weapon, default one is used for rest.
- Commando is immune to tank knockdowns
- Commando can stomp downed infected
- Medic has more options to spawn. Has faster healing and revival times.
- Medic moves faster when in healing mode (crouched)
- Medic can throw healing orbs
- Announcement to other players when healing spot is active.
- Players get notified when theyre being healed.
- Players healed by medic have special glow
- Default health for players without class configurable. Menu does not spam you if you don't choose a class.
- Engineer spawns ready-to-use upgrade packs instead of deployable boxes.
- Engineer now spawns 2 different types of turrets. 8 different ammo types for various situations. 
- Engineer can spawn protective shield 
- Engineer can now barricade open doors & windows. 
- Turrets are smarter and bit more devastating. By default they can be blown up by infected.
- Turrets have now more helpful notifications.
- Turrets are by default non-blocking.
- "Single turret mode" enables oldschool mode.
- Engineer, medic and saboteur get countdown for next deployment when trying to deploy too early
- Saboteur moves faster when crouched and shows visibility status.
- Saboteur has visual effect on turning invisible and specific glow.
- Saboteur has nightvision.
- Redefined visual look and feedback with mines
- Saboteur has 20 different types of mines with cool effects. You can assign 7 of them at one time. 
- New types of mines include Antigravity, blackhole, freeze, vaporizer and many more. (Needs included grenades plugin example)
- Mines do less damage to survivors. Standing really close to the mine can still incap.
- Mines do more damage to infected, 1500hp. Some edge over tank
- Mines glow now so players know to avoid the spot or lure someone to it.
- Notifications on placing mines.
- Warnings for players that go near armed mine
- Countdown notification before mine becoming armed.

## Roadmap
- Cleaner UI, menu option to turn hint texts off. Common HUD component which manages, prioritizes and combines the hint texts properly.
- Integrate game instructor UI to be utilized for counters, and other live indicators. 
- Random Game modes: Melee only rounds, Jockey race. Horror movie mode with pitch black lights, common infected disabled and can only do damage by not seen by player.
- Show player class above their head / in HUD (Using "Hats" plugin + eddect)
- Saboteur can see infected outlines when in "predator mode". Instakill if manages to sneak up behind.
- Smoker should have much more visible and thick cloud when gets killed.
- Make turrets cfg option to allow having only 1 non destroyed turret at the time.
- Rewrite for missile plugin to fit better with this one and improve their function.
- Docker image with rcon web admin tool integrated and plug'n play server generation
- Skill editor to generate new perks / classes.
- Incap players can struggle with attacker on shared progressbar. if indicator goes back to zero, player is freed.
- When incapacitated without supplies and you have kit available, ask survivor if want to consume it.
- Revamp infected skills to match the added ones for survivors;
- Infected can bite survivors, after defined about of time player turns into a witch for 30 seconds. If the witch gets killed, player gets killed, otherwise transform back to playable character.
- Charger can drop survivor and continue running
- Hunter can use boost for ultra long jumps. 
- Jockey can make player shoot others with FF damage while riding. 
- Smoker can shove opponent to any direction when pinned, e.g throw out of window.
- Hunter can masquerade as survivor for 30 second time (Using LMC)
- More suggestions welcome!

See https://forums.alliedmods.net/showthread.php?t=273312 for more info

## Features available for testing

### New saboteur class. 

- Hold crouch 4 sec, and you'll get 20 sec total invisibility with decoy outline.
- Middle click to activate cloak mode 30 sec. If you get pinned, you leave a doppelganger ragdoll with fake weapon for them to toy with and have 10 seconds invisibility to make escape without ability to shoot.
- During cloak you can see outlines of all special infected.
- 7 minetypes to plant. Selection of best variation assigned as default.
- Nightvision

### Misc

- Each class have now own playermodel. Current ones are guidelines, final models TBD
-:3rd person with saveable preferences. Either always, melee only and disabled.
- Soldier now throws realistic marker grenade for airstrike
- Custom music player, includes free Doom 2 heavymetal remake album in playlist.

## Adding a plugin

Adding new plugin requires including DLRCore.sp file, and implementing following methods:
```
/**
 * Called when player changed class
 *
 * @param client         The client index of the player playing tetris.
 * @param className      Classname that user just selected
 * @param previousClass  Previous class of user
 * @noreturn
 */
forward OnPlayerClassChange(client, className, previousClass);  

/**
 * Called when player uses special skill. 
 * Plugin should react to this to initiate the skill, then call either or OnSpecialSkillFail / OnSpecialSkillSuccess
 * @param client         The client index of the player playing tetris.
 * @param skillName      Skill that user just used
 * @noreturn
 */
forward OnSpecialSkillUsed(client, skillName);  


/**
 * Called when player has successfully used special skill. 
 * This is required for plugin to implement
 *
 * @param client         The client index of the player playing tetris.
 * @param className      Skill that user just used
 * @noreturn
 */
native void OnSpecialSkillSuccess(int client, char[] skillName);  

/**
 * Called when player has failed using special skill. This prevents from affecting the inventory.
 *
 * @param client         The client index of the player playing tetris.
 * @param className      Skill that user just used
 * @param reason         Reason for failure
 * @noreturn
 */
native void OnSpecialSkillFail(int client, char[] skillName, char[] reason);  

/**
 * Register skill from plugin
 *
 * @param client         The client index of the player playing tetris.
 * @param className      Skill that user just used
 * @param reason         Reason for failure
 * @noreturn
 */
native int RegisterDLRSkill(char[] skillName);  

``` 

Native helper methods that are available:

```

/**
 * Called when player uses special skill. 
 * Plugin should react to this to initiate the skill, then call either or OnSpecialSkillFail / OnSpecialSkillSuccess
 * @param skillName         The client index of the player playing tetris.
 * @param skillId     Assign ID to this var
 * @noreturn
 */
forward FindSkillIdByName(skillName, skillId);  

/**
 * Get player classname
 *
 * @param client  Client index.
 * @return        Classname
 */
native int:GetPlayerClassName(client);

``` 

Add DLRCore.sp in your include folder and make sure you have dlr_talents.smx available.
Include this in the plugin file header that you want to implement


```
/****************************************************/
#tryinclude <DLRCore>
#if !defined _DLRCore_included
	// Optional native from DLR Talents
	native void OnSpecialSkillSuccess(int client, char[] skillName);
	native void OnSpecialSkillFail(int client, char[] skillName, char[] reason);
	native void GetPlayerSkillName(int client, char[] skillName, int size);
	native int  RegisterDLRSkill(char[] skillName, 0);  
#endif
static bool DLR_Available = false;
#define PLUGIN_SKILL_NAME "Plugin Name"
/****************************************************/
``` 

Include these functions;
``` 
public void DLR_OnPluginState(int pluginstate)
{
	DLR_Available = IntToBool(pluginstate);
	g_iClassID = DLR_Available ? RegisterDLRSkill(PLUGIN_SKILL_NAME, 0) : -1;
    ....
}

public void OnPluginStart()
{
....
	if (DLR_Available) {
		g_iClassID = RegisterDLRSkill(PLUGIN_SKILL_NAME);
}

public void OnSpecialSkillUsed(int iClient, int skill)
{
	if (skill == FindSkillIdByName(PLUGIN_SKILL_NAME) {

		CMD_MainMenu(iClient, 0);
	}
}
public void OnSpecialSkillSuccess(int iClient, int skill)
{
	if (skill == FindSkillIdByName(PLUGIN_SKILL_NAME) {

		CMD_MainMenu(iClient, 0);
	}
}
public void OnSpecialSkillFail(int iClient, int skill, char[] reason)
{
	if (skill == FindSkillIdByName(PLUGIN_SKILL_NAME) {
		CMD_MainMenu(iClient, 0);
	}
}


```

See Multiturret implementation as example

