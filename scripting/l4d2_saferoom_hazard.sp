#define PLUGIN_VERSION "1.1.0"
/*
============= version history =============
v 1.1.0
- creadit to @GL_INS v1.1.0 beta tester
- plugins conversion to new syntax.
- changed command for force enter.
- change detection from radius to sdkhook sensor.
- renaming cvar
- added damage for checkpoint area if player refuse to enter



last edited 15/Dec/2013
v 1.0.3
- Fixed round restart at same map, door index is changing.
v 1.0.2
- Little code clean up.
- Added rescue room force teleport for player who refuse to go in.
- Added Tank check.

v 1.0.1
- Fixed infected teleport script error..
*/

#pragma	newdecls required
#pragma	semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define TEAM_SURVIVOR		2
#define TEAM_INFECTED		3

#define DIST_RADIUS			600.0
#define DIST_SENSOR			20.0
#define DIST_REFERENCE		80.0
#define DIST_DUMMYHEIGHT	-53.0

#define SPR_BLOOD			"materials/sprites/bloodspray.vmt"

#define SND_TELEPORT		"ui/menu_horror01.wav"
#define SND_BURNING			"ambient/fire/fire_small_loop2.wav"
#define SND_WARNING			"items/suitchargeok1.wav"

#define MDL_SPAWNROOM1		"models/props_doors/checkpoint_door_01.mdl"
#define MDL_SPAWNROOM2		"models/props_doors/checkpoint_door_-01.mdl"
#define MDL_CHECKROOM1		"models/props_doors/checkpoint_door_02.mdl"
#define MDL_CHECKROOM2		"models/props_doors/checkpoint_door_-02.mdl"
#define MDL_PARTICLEFIRE	"burning_character_screen"	// @Silver [L4D2] Hud Splatter


//======== Global ConVar ========//
ConVar	g_ConVarSafeHazard_PluginEnable,	g_ConVarSafeHazard_NotifySpawn1,		g_ConVarSafeHazard_NotifySpawn2,	g_ConVarSafeHazard_Radius,		g_ConVarSafeHazard_DamageAlive,
		g_ConVarSafeHazard_DamageIncap,		g_ConVarSafeHazard_LeaveSpawnMsg,		g_ConVarSafeHazard_EventDoor,		g_ConVarSafeHazard_EventNumber,	g_ConVarSafeHazard_CmdDoor,
		g_ConVarSafeHazard_ReferanceToy,	g_ConVarSafeHazard_CheckpoinCountdown,	g_ConVarSafeHazard_ExitMsg, 		g_ConVarSafeHazard_IsDamageBot,	g_ConVarSafeHazard_BloodColor,
		g_ConVarSafeHazard_IsDebugging;


//========== Global Cvar ========//
bool	g_bCvar_PluginEnable;
int		g_iCvar_NotifySpawn1;
int		g_iCvar_NotifySpawn2;
int		g_iCvar_Notify_Total;
float	g_fCvar_Radius;
int		g_iCvar_DamageAlive;
int		g_iCvar_DamageIncap;
bool	g_bCvar_LeaveSpawnMsg;
bool	g_bCvar_EventDoorWin;
int		g_iCvar_DoorNumber;
bool	g_bCvar_DoorWinState;
bool	g_bCvar_ReferanceToy;
float	g_fCvar_CheckpoinCountdown;
bool	g_bCvar_NotifyExit;
bool	g_bCvar_DamageBot;
int		g_iCvar_BloodColor[4];
bool	g_bCvar_IsDebugging;


//== Spawn Door Area Sensor Type ==//
enum {
	SENSOR_ENTER,
	SENSOR_EXIT,
	SENSOR_LENGTH
}
int g_iSensorType_Spawn[SENSOR_LENGTH] = { -1, ... };


//========= Dummy Model =========//
enum {
	MDL_REFERANCE1,
	MDL_REFERANCE2,
	MDL_REFERANCE3,
	MDL_SENSOR,
	MDL_LENGTH
}
char g_sDummyModel[MDL_LENGTH][] =
{
	"models/props_fairgrounds/elephant.mdl",
	"models/props_fairgrounds/alligator.mdl",
	"models/props_fairgrounds/giraffe.mdl",
	"models/props_doors/checkpoint_door_02.mdl"
};


//======== Global Timer =========//
enum {
	TIMER_GLOBAL,
	TIMER_RESCUE,
	TIMER_LENGTH
}
Handle g_hTimer[TIMER_LENGTH];


//== Client Last Door Touched ===//
enum
{
	ROOM_STATE_OUTDOOR,
	ROOM_STATE_SPAWN,
	ROOM_STATE_RESCUE,
	ROOM_STATE_LENGTH
}
int g_iStateRoom[MAXPLAYERS+1];


//=== Special Map door offsets ==//
char g_sCheckpointMapName[][] =
{
	"c2m3_coaster",
	"c2m4_barns",
	"c4m1_milltown_a",
	"c4m2_sugarmill_a",
	"c4m4_milltown_b",
	"c5m2_park",
	"c6m1_riverbank",
	"c7m1_docks",
	"c7m2_barge",
	"c8m1_apartment",
	"c8m3_sewers",
	"c8m4_interior",
	"c9m1_alleys",
	"c10m1_caves",
	"c10m2_drainage",
	"c10m3_ranchhouse",
	"c11m1_greenhouse",
	"c11m2_offices",
	"c11m3_garage",
	"c11m4_terminal",
	"c12m1_hilltop",
	"c12m2_traintunnel",
	"c12m3_bridge",
	"c12m4_barn"
};
float g_fCheckpointMapRotation[] =
{
	-90.0,	// c2m3_coaster
	-90.0,	// c2m4_barns
	-90.0,	// c4m1_milltown_a
	-90.0,	// c4m2_sugarmill_a
	0.0,	// c4m4_milltown_b
	-90.0,	// c5m2_park
	-90.0,	// c6m1_riverbank
	-90.0,	// c7m1_docks
	-90.0,	// c7m2_barge
	-90.0,	// c8m1_apartment
	-90.0,	// c8m3_sewers
	-90.0,	// c8m4_interior
	-90.0,	// c9m1_alleys
	  0.0,	// c10m1_caves
	  0.0,	// c10m2_drainage
	180.0,	// c10m3_ranchhouse << door with civilian.
	-90.0,	// c11m1_greenhouse
	-90.0,	// c11m2_offices
	-90.0,	// c11m3_garage
	-90.0,	// c11m4_terminal
	-90.0,	// c12m1_hilltop
	-90.0,	// c12m2_traintunnel
	-90.0,	// c12m3_bridge
	-90.0	// c12m4_barn
};


//========= Spawn damage ========//
int		g_iSpawnCount[MAXPLAYERS+1];
float	g_fPos_Spawn[3];
int		g_iDoor_Spawn;


//====== Checkpoint damage ======//
float	g_fPos_Rescue[3];
bool	g_bIsDamage_Rescue;
int		g_iDoor_Rescue;


//========= Misc check ==========//
bool	g_bIsRound_End;
bool	g_bIsRound_Finale;
bool	g_bIsFindDoorInit;
bool	g_bStateJump[MAXPLAYERS+1];
char 	g_sCurrentMap[PLATFORM_MAX_PATH];
Handle 	g_hStopSound[MAXPLAYERS+1];
int 	g_iBloodSprite;


public Plugin myinfo = 
{
	name		= "Safe Room Hazard",
	author		= " GsiX ",
	description	= "Prevent player from camp in the safe room",
	version		= PLUGIN_VERSION,
	url			= "https://forums.alliedmods.net/showthread.php?p=1836806#post1836806"	
}

public void OnPluginStart()
{
	CreateConVar( "saferoomhazard_version", PLUGIN_VERSION, " ", FCVAR_DONTRECORD);
	g_ConVarSafeHazard_PluginEnable			= CreateConVar( "hazard_plugin_enable",		"1",	"0:Off,  1:On,  Toggle plugin On/Off.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_NotifySpawn1			= CreateConVar( "hazard_notify_leave1",		"30",	"Timer first notify to player to leave safe room.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 1.0, true, 60.0 );
	g_ConVarSafeHazard_NotifySpawn2			= CreateConVar( "hazard_notify_leave2",		"10",	"Timer damage countdown after 'hazard_notify_leave1'", FCVAR_SPONLY|FCVAR_NOTIFY, true, 1.0, true, 60.0 );
	g_ConVarSafeHazard_Radius				= CreateConVar( "hazard_checkpoint_radius",	"600",	"Player distance from checkpoint door consider near.", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_ConVarSafeHazard_DamageAlive			= CreateConVar( "hazard_damage_alive",		"1",	"Health we knock off player per hit if he alive.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 1.0, true, 100.0 );
	g_ConVarSafeHazard_DamageIncap			= CreateConVar( "hazard_damage_incap",		"10",	"Health we knock off player per hit if he incap.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 1.0, true, 100.0 );
	g_ConVarSafeHazard_LeaveSpawnMsg		= CreateConVar( "hazard_leave_message",		"1",	"0:Off  | 1:On, Announce spawn saferoom damage message.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_EventDoor			= CreateConVar( "hazard_manual_safe",		"0",	"0:Off  | 1:On, Checkpoint door manually closed, all player force teleport inside.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_EventNumber			= CreateConVar( "hazard_manual_number",		"3",	"0:Off  | 1:On, Checkpoint door manually closed, this number of players inside checkpoint will force teleport all players", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 64.0 );
	g_ConVarSafeHazard_CmdDoor				= CreateConVar( "hazard_command_door",		"0",	"0:Open | 1:Closed, command 'srh_enter' will open/closed checkpoint door after force teleport all player.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_ReferanceToy			= CreateConVar( "hazard_saferoom_toy",		"1",	"0:Off, 1:On, If on, developer teleport reference visible inside safe room.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_CheckpoinCountdown	= CreateConVar( "hazard_warning",			"30",	"If player refuse to enter second saferoom, do damage after this long(seconds).", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 60.0 );
	g_ConVarSafeHazard_ExitMsg				= CreateConVar( "hazard_exit_message",		"1",	"0:Off, 1:On, Display hint text everytime player enter/exit.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_IsDamageBot			= CreateConVar( "hazard_damage_bot",		"0",	"0:Off, 1:On, Apply damage to survivor bot.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_BloodColor			= CreateConVar( "hazard_blood_color",		"0,255,0",	"Damage blood color RGB separated by commas", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_IsDebugging			= CreateConVar( "hazard_debugging_enable",	"0",	"0:Off, 1:On, Toggle debugging.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	AutoExecConfig( true, "l4d2_saferoom_hazard" );

	
	HookEvent( "survivor_rescued",			Event_PlayerRescued );
	HookEvent( "player_spawn",				EVENT_PlayerSpawn );
	HookEvent( "round_end",					EVENT_RoundEnd );
	HookEvent( "finale_start",				EVENT_Finale );
	HookEvent( "door_close",				EVENT_DoorClose );
	HookEvent( "player_left_start_area",	EVENT_PlayerLeft );
	HookEvent( "player_death",				Event_PlayerDeath );

	//================= Admin and developer command =================//
	RegAdminCmd( "srh_enter",	Command_ForceEnter_CheckpointRoom, ADMFLAG_GENERIC );
	RegAdminCmd( "srh_jump",	Command_ForceEnter_Saferoom, ADMFLAG_GENERIC );
	RegAdminCmd( "srh_check",	Command_CheckEntity, ADMFLAG_GENERIC );
	

	//=================== Checkpoint room trigger ===================//
	HookEntityOutput( "info_changelevel",		"OnStartTouch",		EntityOutput_OnStartTouch_Rescueroom );
	HookEntityOutput( "info_changelevel",		"OnEndTouch",		EntityOutput_OnEndTouch_Rescueroom );
	HookEntityOutput( "trigger_changelevel",	"OnStartTouch",		EntityOutput_OnStartTouch_Rescueroom );
	HookEntityOutput( "trigger_changelevel",	"OnEndTouch",		EntityOutput_OnEndTouch_Rescueroom );
	
	g_ConVarSafeHazard_PluginEnable.AddChangeHook(	ConVar_Changed );
	g_ConVarSafeHazard_NotifySpawn1.AddChangeHook( ConVar_Changed );
	g_ConVarSafeHazard_NotifySpawn2.AddChangeHook( ConVar_Changed );
	g_ConVarSafeHazard_Radius.AddChangeHook( ConVar_Changed );
	g_ConVarSafeHazard_DamageAlive.AddChangeHook( ConVar_Changed );
	g_ConVarSafeHazard_DamageIncap.AddChangeHook( ConVar_Changed );
	g_ConVarSafeHazard_LeaveSpawnMsg.AddChangeHook( ConVar_Changed );
	g_ConVarSafeHazard_EventDoor.AddChangeHook( ConVar_Changed );
	g_ConVarSafeHazard_EventNumber.AddChangeHook( ConVar_Changed );
	g_ConVarSafeHazard_CmdDoor.AddChangeHook( ConVar_Changed );
	g_ConVarSafeHazard_ReferanceToy.AddChangeHook( ConVar_Changed );
	g_ConVarSafeHazard_CheckpoinCountdown.AddChangeHook( ConVar_Changed );
	g_ConVarSafeHazard_ExitMsg.AddChangeHook( ConVar_Changed );
	g_ConVarSafeHazard_IsDamageBot.AddChangeHook( ConVar_Changed );
	g_ConVarSafeHazard_BloodColor.AddChangeHook( ConVar_Changed );
	g_ConVarSafeHazard_IsDebugging.AddChangeHook( ConVar_Changed );
	
	UpdateCvar();
}

public void ConVar_Changed( ConVar convar, const char[] oldValue, const char[] newValue )
{
	UpdateCvar();
}

void UpdateCvar()
{
	g_bCvar_PluginEnable		= g_ConVarSafeHazard_PluginEnable.BoolValue;
	g_iCvar_NotifySpawn1		= g_ConVarSafeHazard_NotifySpawn1.IntValue;
	g_iCvar_NotifySpawn2		= g_ConVarSafeHazard_NotifySpawn2.IntValue;
	g_fCvar_Radius				= g_ConVarSafeHazard_Radius.FloatValue;
	g_iCvar_DamageAlive			= g_ConVarSafeHazard_DamageAlive.IntValue;
	g_iCvar_DamageIncap			= g_ConVarSafeHazard_DamageIncap.IntValue;
	g_bCvar_LeaveSpawnMsg		= g_ConVarSafeHazard_LeaveSpawnMsg.BoolValue;
	g_bCvar_EventDoorWin		= g_ConVarSafeHazard_EventDoor.BoolValue;
	g_iCvar_DoorNumber			= g_ConVarSafeHazard_EventNumber.IntValue;
	g_bCvar_DoorWinState		= g_ConVarSafeHazard_CmdDoor.BoolValue;
	g_bCvar_ReferanceToy		= g_ConVarSafeHazard_ReferanceToy.BoolValue;
	g_fCvar_CheckpoinCountdown	= g_ConVarSafeHazard_CheckpoinCountdown.FloatValue;
	g_bCvar_NotifyExit			= g_ConVarSafeHazard_ExitMsg.BoolValue;
	g_bCvar_DamageBot			= g_ConVarSafeHazard_IsDamageBot.BoolValue;
	g_bCvar_IsDebugging			= g_ConVarSafeHazard_IsDebugging.BoolValue;
	g_iCvar_Notify_Total = g_iCvar_NotifySpawn1 + g_iCvar_NotifySpawn2;
	
	char colorBuff[32];
	char colorName[8][3];
	g_ConVarSafeHazard_BloodColor.GetString( colorBuff, sizeof( colorBuff ));
	ExplodeString( colorBuff, ",", colorName, sizeof( colorName ), sizeof( colorName[] ));
	g_iCvar_BloodColor[0] = StringToInt( colorName[0] );
	g_iCvar_BloodColor[1] = StringToInt( colorName[1] );
	g_iCvar_BloodColor[2] = StringToInt( colorName[2] );
	g_iCvar_BloodColor[3] = 50;
}

public Action Command_ForceEnter_CheckpointRoom( int client, int args )
{
	if ( client < 1 )
	{
		ReplyToCommand( client, "[SAFEROOM]: Command only valid in game!!" );
		return Plugin_Handled;
	}
	
	if ( g_iDoor_Rescue == -1 )
	{
		ReplyToCommand( client, "[SAFEROOM]: Teleport referance not found!!" );
		return Plugin_Handled;
	}
	
	if ( GetClientTeam( client ) != TEAM_SURVIVOR )
	{
		ReplyToCommand( client, "[SAFEROOM]: Command only for Survivor!!" );
		return Plugin_Handled;
	}
	
	if ( g_bCvar_DoorWinState )
	{
		AcceptEntityInput( g_iDoor_Rescue, "Close" );
	}
	else
	{
		AcceptEntityInput( g_iDoor_Rescue, "Open" );
	}
	
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && IsPlayerAlive( i ) && GetClientTeam( i ) == TEAM_SURVIVOR )
		{
			TeleportPlayer( i, g_fPos_Rescue, SND_TELEPORT );
		}
	}
	return Plugin_Handled;
}

public Action Command_ForceEnter_Saferoom( int client, int args )
{
	if ( client < 1 )
	{
		ReplyToCommand( client, "[SAFEROOM]: Command only valid in game!!" );
		return Plugin_Handled;
	}

	if ( GetClientTeam( client ) != TEAM_SURVIVOR )
	{
		ReplyToCommand( client, "[SAFEROOM]: Command only for Survivor!!" );
		return Plugin_Handled;
	}
	
	if ( args < 1 )
	{
		ReplyToCommand( client, "\x01[SAFEROOM]: usage \x04srh_jump 0 \x01for spawn are jump" );
		ReplyToCommand( client, "\x01[SAFEROOM]: usage \x04srh_jump 1 \x01for checkpoint are jump" );
		return Plugin_Handled;
	}
	
	char arg1[8];
	GetCmdArg( 1, arg1, sizeof( arg1 ));
	int type = StringToInt( arg1 );
	if( type == 0 )
	{
		if ( g_iDoor_Spawn != -1 )
		{
			g_bStateJump[client]     = true;
			g_iStateRoom[client] = ROOM_STATE_SPAWN;
			
			if( g_bCvar_NotifyExit )
			{
				PrintHintText( client, "%N Entering Spawn Saferoom!!", client );
			}
			TeleportPlayer( client, g_fPos_Spawn, SND_TELEPORT );
		}
		else
		{
			ReplyToCommand( client, "[SAFEROOM]: Spawn room referance not found!!" );
		}
	}
	else if( type == 1 )
	{
		if ( g_iDoor_Rescue != -1 )
		{
			g_iStateRoom[client] = ROOM_STATE_OUTDOOR;
			TeleportPlayer( client, g_fPos_Rescue, SND_TELEPORT );
		}
		else
		{
			ReplyToCommand( client, "[SAFEROOM]: Checkpoint referance not found!!" );
		}
	}
	else if( type == 2 )
	{
		float pos[3];
		GetEntPropVector( client, Prop_Send, "m_vecOrigin", pos );
		
		for ( int i = 1; i <= MaxClients; i++ )
		{
			if ( IsClientInGame( i ) && IsPlayerAlive( i ) && GetClientTeam( i ) == TEAM_SURVIVOR )
			{
				TeleportPlayer( i, pos, SND_TELEPORT );
			}
		}
	}
	else
	{
		ReplyToCommand( client, "\x01[SAFEROOM]: only \x04srh_jump 0 \x01or \x04srh_jump 1 \x01or \x04srh_jump 2\x01valid command" );
	}
	
	return Plugin_Handled;
}

public Action Command_CheckEntity( int client, int args )
{
	if ( client < 1 )
	{
		ReplyToCommand( client, "[SAFEROOM]: Command only valid in game!!" );
		return Plugin_Handled;
	}
	
	if ( !g_bCvar_IsDebugging )
	{
		ReplyToCommand( client, "[SAFEROOM]: Debugging mode disabled!!" );
		return Plugin_Handled;
	}
	
	float eyePos[3];
	float eyeAng[3];
	GetClientEyePosition( client, eyePos );
	GetClientEyeAngles( client, eyeAng );
	
	int entity = TraceRay_GetEntity( eyePos, eyeAng, client );
	if( entity == -1 ) return Plugin_Handled;
	
	char nameClass[PLATFORM_MAX_PATH];
	GetEntityClassname( entity, nameClass, sizeof( nameClass ));
	PrintToChat( client, "nameClass: %s", nameClass );
	
	char m_ModelName[PLATFORM_MAX_PATH];
	GetEntPropString( entity, Prop_Data, "m_ModelName", m_ModelName, sizeof( m_ModelName ));
	PrintToChat( client, "m_ModelName: %s", m_ModelName );
	return Plugin_Handled;
}

public void OnMapStart()
{
	OnMapEnd();
	
	for ( int i = 0; i < MDL_LENGTH; i++ )
	{
		PrecacheModel( g_sDummyModel[i] );
	}
	
	g_iBloodSprite = PrecacheModel( SPR_BLOOD );
	
	PrecacheSound( SND_TELEPORT, true );
	PrecacheSound( SND_BURNING, true );
	PrecacheSound( SND_WARNING, true );
	PrecacheParticle( MDL_PARTICLEFIRE );
	
	GetCurrentMap( g_sCurrentMap, sizeof( g_sCurrentMap ));
}

public void OnMapEnd()
{
	g_iSensorType_Spawn[0]	= -1;
	g_iSensorType_Spawn[1]	= -1;
	
	g_bIsRound_End 		= true;
	g_bIsRound_Finale 	= false;
	g_bIsDamage_Rescue 	= false;
	g_iDoor_Spawn		= -1;
	g_iDoor_Rescue		= -1;
	g_fPos_Spawn		= view_as<float>({ 0.0, 0.0, 0.0 });
	g_fPos_Rescue		= view_as<float>({ 0.0, 0.0, 0.0 });
	g_bIsFindDoorInit 	= false;
	
	for( int i = 0; i < TIMER_LENGTH; i++ )
	{
		delete g_hTimer[i];
	}
}

public void OnClientPutInServer( int client )
{
	if ( client > 0 )
	{
		g_iStateRoom[client] = -1;
		g_bStateJump[client] = false;
		
		delete g_hStopSound[client];
	}
}

public void OnClientDisconnect( int client )
{
	OnClientPutInServer( client );
}

public void EVENT_RoundEnd( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;

	OnMapEnd();
}

public void EVENT_Finale( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	g_bIsRound_Finale = true;
}

public void EVENT_DoorClose( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable || g_bCvar_EventDoorWin ) return;
	
	bool close	= event.GetBool( "checkpoint" );
	int	 client = GetClientOfUserId( event.GetInt( "userid" ));
	if ( close && Survivor_IsValid( client ))
	{
		// only human player closing saferoom door from inside count
		if( !IsFakeClient( client ) && g_iStateRoom[client] == ROOM_STATE_RESCUE )
		{
			int count;
			for( int i = 1; i <= MaxClients; i++ )
			{
				if( !IsFakeClient( i ) && g_iStateRoom[i] == ROOM_STATE_RESCUE )
				{
					count++;
				}
			}
			
			if( count >= g_iCvar_DoorNumber )
			{
				for( int i = 1; i <= MaxClients; i++ )
				{
					if( Survivor_InGame( i ) && g_iStateRoom[i] != ROOM_STATE_RESCUE )
					{
						TeleportPlayer( i, g_fPos_Rescue, SND_TELEPORT );
					}
				}
				
				PrintTextToServer( "Event door closed all players teleported", g_bCvar_IsDebugging );
			}
		}
	}
}

public void Event_PlayerRescued( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	int client = GetClientOfUserId( event.GetInt( "userid" ));
	if ( Survivor_IsValid( client ))
	{
		// closet rescue, set player position outdoor
		g_iStateRoom[client] = ROOM_STATE_OUTDOOR;
	}
}

public void EVENT_PlayerLeft( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	int client = GetClientOfUserId( event.GetInt( "userid" ));
	if ( Survivor_IsValid( client ))
	{
		StartGlobalDamageTimer();
	}
}

public void Event_PlayerDeath( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	int client = GetClientOfUserId( event.GetInt( "userid" ));
	if ( Survivor_IsValid( client ))
	{
		StopBurningSound( client );
	}
}



//=================== Rescue room Damage ===================//
//==================== code from @Mart =====================//
public void EntityOutput_OnStartTouch_Rescueroom( const char[] output, int caller, int activator, float time )
{
	if( !g_bCvar_PluginEnable || g_iDoor_Rescue == -1 || !Survivor_IsValid( activator )) return;
	
	float pos[3];
	GetEntPropVector( activator, Prop_Send, "m_vecOrigin", pos );
	if( GetVectorDistance( pos, g_fPos_Rescue ) > ( DIST_REFERENCE + 50.0 ))
	{
		// false alarm, mid map mission area
		if( g_bCvar_NotifyExit ) PrintHintText( activator, "%N Entering Mission Area", activator );	
	}
	else
	{
		// entering actual saferoom door
		SetClientRoom( activator, ROOM_STATE_RESCUE );
		
		if( !g_bIsDamage_Rescue && g_hTimer[TIMER_RESCUE] == null )
		{
			bool start = true;
			for( int i = 1; i <= MaxClients; i++ )
			{
				if( Survivor_InGame( i ))
				{
					GetEntPropVector( i, Prop_Send, "m_vecOrigin", pos );
					if( GetVectorDistance( pos, g_fPos_Rescue ) > g_fCvar_Radius )
					{
						start = false;
						break;
					}
				}
			}
			
			if( start )
			{
				g_hTimer[TIMER_RESCUE] = CreateTimer( g_fCvar_CheckpoinCountdown, Timer_RescueCountdown, _, TIMER_FLAG_NO_MAPCHANGE );
				if( g_bCvar_LeaveSpawnMsg )
				{
					for( int i = 1; i <= MaxClients; i ++ )
					{
						if( Survivor_InGame( i ) && !IsFakeClient( i ))
						{
							PrintToChat( i, "\x05[\x04WARNING\x05]: \x01You have \x04%0.0f sec(s) \x01to enter Checkpoint area!!", g_fCvar_CheckpoinCountdown );
						}
					}
				}
			}
		}
	}
}

public Action Timer_RescueCountdown( Handle timer )
{
	for( int i = 1; i <= MaxClients; i ++ )
	{
		if( Survivor_InGame( i ) && !IsFakeClient( i ))
		{
			PrintToChat( i, "\x05[\x04WARNING\x05]: \x01Checkpoint area damage has started!!" );
			EmitSoundToClient( i, SND_WARNING );
		}
	}
	
	g_bIsDamage_Rescue		= true;
	g_hTimer[TIMER_RESCUE]	= null;
	return Plugin_Stop;
}

public void EntityOutput_OnEndTouch_Rescueroom( const char[] output, int caller, int activator, float time )
{
	if( !g_bCvar_PluginEnable || g_iDoor_Rescue == -1 || !Survivor_IsValid( activator )) return;
	
	float pos[3];
	GetEntPropVector( activator, Prop_Send, "m_vecOrigin", pos );
	if( GetVectorDistance( pos, g_fPos_Rescue ) > ( DIST_REFERENCE + 50.0 ))
	{
		// false alarm, mid map mission area
		if( g_bCvar_NotifyExit ) PrintHintText( activator, "%N Exiting Mission Area", activator );	
	}
	else
	{
		// entering actual saferoom door
		SetClientRoom( activator, ROOM_STATE_OUTDOOR );
	}
}

void SetClientRoom( int client, int room )
{
	// player use 'Command_ForceEnter_Saferoom' developer command to move around, ignore check.
	if( g_bStateJump[client] )
	{
		g_bStateJump[client] = false;
	}
	else
	{
		// door touched is not equal to the previous door touched
		if( g_iStateRoom[client] != room )
		{
			switch( room )
			{
				case ROOM_STATE_OUTDOOR:
				{ 
					// from spawn saferoom to outdoor
					if( g_iStateRoom[client] == ROOM_STATE_SPAWN )
					{
						StopBurningSound( client );
						
						StartGlobalDamageTimer();
						
						if( g_bCvar_NotifyExit ) PrintHintText( client, "%N Left Spawn Saferoom", client );	
					}
					// from rescue saferoom to outdoor
					else if( g_iStateRoom[client] == ROOM_STATE_RESCUE )
					{
						if( g_bCvar_NotifyExit ) PrintHintText( client, "%N Left Checkpoint Are", client );	
					}
				}
				case ROOM_STATE_SPAWN:
				{
					// from outdoor entering spawn saferoom
					if( g_bCvar_NotifyExit ) PrintHintText( client, "%N Entering Spawn Saferoom", client );
				}
				case ROOM_STATE_RESCUE:
				{
					// from outdoor or spawn saferoom entering spawn rescue saferoom
					if( g_iStateRoom[client] == ROOM_STATE_OUTDOOR || g_iStateRoom[client] == ROOM_STATE_SPAWN )
					{
						StopBurningSound( client );
					}
					if( g_bCvar_NotifyExit ) PrintHintText( client, "%N Entering Checkpoint Area", client );
				}
			}
			
			// update new door touched
			g_iStateRoom[client] = room;
		}
	}
}



//=================== Spawn room Damage ===================//
public void EVENT_PlayerSpawn( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	int userid = event.GetInt( "userid" );
	int client = GetClientOfUserId( userid );
	if ( client > 0 && client <= MaxClients && IsClientInGame( client ))
	{
		int team = GetClientTeam( client );
		if( team == TEAM_SURVIVOR )
		{
			// create spawn saferoom door sensor and teleport referance
			SpawnSaferoomSensor( client );
			
			// set player spawn room max stay count.
			g_iSpawnCount[client] = g_iCvar_Notify_Total;
			
			// set player state inside spawn saferoom.
			g_iStateRoom[client] = ROOM_STATE_SPAWN;
		}
		else if( team == TEAM_INFECTED )
		{
			if( g_bCvar_IsDebugging )
			{
				CreateTimer( 1.0, Timer_ForceInfectedSuicide, userid, TIMER_FLAG_NO_MAPCHANGE );
			}
		}
	}
}

void SpawnSaferoomSensor( int client )
{
	//===== dont search saferoom door twice =====//
	if( g_bIsFindDoorInit ) { return; }
	
	g_bIsFindDoorInit = true;
	
	
	//===== find and register saferoom door =====//
	Get_SaferoomDoor( client );
	

	//======== create spawn door sensor ========//
	if( g_iDoor_Spawn != -1 )
	{
		char m_ModelName[PLATFORM_MAX_PATH];
		GetEntPropString( g_iDoor_Spawn, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
		
		// spawn door offset setting
		int type = 1;
		if( StrContains( m_ModelName, "_-", false ) != -1 )
		{
			type = 0;
		}
		
		
		// create spawn saferoom door sensor first layer
		float buf[3];
		float pos[3];
		float ang[3];
		Get_EntityLocation( g_iDoor_Spawn, pos, ang );
		
		buf = view_as<float>(pos);
		if( type == 0 )
		{
			buf[0] += DIST_SENSOR * Cosine( DegToRad( ang[1] ));
			buf[1] += DIST_SENSOR * Sine( DegToRad( ang[1] ));
		}
		else if( type == 1 )
		{
			buf[0] -= DIST_SENSOR * Cosine( DegToRad( ang[1] ));
			buf[1] -= DIST_SENSOR * Sine( DegToRad( ang[1] ));
		}
		
		g_iSensorType_Spawn[SENSOR_ENTER] = Create_SensorModel( buf, ang, g_sDummyModel[MDL_SENSOR] );
		if( g_iSensorType_Spawn[SENSOR_ENTER] != -1 )
		{
			SDKHook( g_iSensorType_Spawn[SENSOR_ENTER], SDKHook_StartTouch, OnDoorSensorTouched );
			SDKHook( g_iSensorType_Spawn[SENSOR_ENTER], SDKHook_EndTouch, OnDoorSensorTouched );
		}
		
		
		// create spawn saferoom door sensor second layer
		buf = view_as<float>(pos);
		if( type == 0 )
		{
			buf[0] -= DIST_SENSOR * Cosine( DegToRad( ang[1] ));
			buf[1] -= DIST_SENSOR * Sine( DegToRad( ang[1] ));
		}
		else if( type == 1 )
		{
			buf[0] += DIST_SENSOR * Cosine( DegToRad( ang[1] ));
			buf[1] += DIST_SENSOR * Sine( DegToRad( ang[1] ));
		}
		
		g_iSensorType_Spawn[SENSOR_EXIT] = Create_SensorModel( buf, ang, g_sDummyModel[MDL_SENSOR] );
		if( g_iSensorType_Spawn[SENSOR_EXIT] != -1 )
		{
			SDKHook( g_iSensorType_Spawn[SENSOR_EXIT], SDKHook_StartTouch, OnDoorSensorTouched );
			SDKHook( g_iSensorType_Spawn[SENSOR_EXIT], SDKHook_EndTouch, OnDoorSensorTouched );
		}
		
		// create teleport position
		g_fPos_Spawn	= view_as<float>(pos);
		g_fPos_Spawn[2]	+= DIST_DUMMYHEIGHT;
		
		if( type == 0 )
		{
			g_fPos_Spawn[0] += DIST_REFERENCE * Cosine( DegToRad( ang[1] ));
			g_fPos_Spawn[1] += DIST_REFERENCE * Sine( DegToRad( ang[1] ));
		}
		else if( type == 1 )
		{
			g_fPos_Spawn[0] -= DIST_REFERENCE * Cosine( DegToRad( ang[1] ));
			g_fPos_Spawn[1] -= DIST_REFERENCE * Sine( DegToRad( ang[1] ));
		}
		
		// create toy referance
		if( g_bCvar_ReferanceToy )
		{
			int rand = GetRandomInt( 0, 2 );
			Create_Reference( g_fPos_Spawn, ang, g_sDummyModel[rand] );
		}
	}
	
	
	//===== create checkpoint door referance =====//
	if( g_iDoor_Rescue != -1 )
	{
		char m_ModelName[PLATFORM_MAX_PATH];
		GetEntPropString( g_iDoor_Rescue, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
		
		// create teleport position
		float ang[3];
		Get_EntityLocation( g_iDoor_Rescue, g_fPos_Rescue, ang );
		g_fPos_Rescue[2] += DIST_DUMMYHEIGHT;
		
		int position = LoadDoorConfig( g_sCheckpointMapName, sizeof( g_sCheckpointMapName ), g_sCurrentMap );
		if( position != -1 )
		{
			ang[1] += g_fCheckpointMapRotation[position];
		}
		else
		{
			ang[1] += 90.0;
		}
		
		g_fPos_Rescue[0] += DIST_REFERENCE * Cosine( DegToRad( ang[1] ));
		g_fPos_Rescue[1] += DIST_REFERENCE * Sine( DegToRad( ang[1] ));
		
		// create toy referance
		if( g_bCvar_ReferanceToy )
		{
			int rand = GetRandomInt( 0, 2 );
			Create_Reference( g_fPos_Rescue, ang, g_sDummyModel[rand] );
		}
	}
}

public Action OnDoorSensorTouched( int entity, int client )
{
	if( !Survivor_IsValid( client )) return Plugin_Continue;
	
	//========= spawn saferoom sensor logic =========//
	if( entity == g_iSensorType_Spawn[SENSOR_ENTER] )
	{
		SetClientRoom( client, ROOM_STATE_SPAWN );
	}
	else if( entity == g_iSensorType_Spawn[SENSOR_EXIT] )
	{
		SetClientRoom( client, ROOM_STATE_OUTDOOR );
	}
	return Plugin_Continue;
}

void StartGlobalDamageTimer()
{
	// if map has spawn saferoom door or rescue saferoom door and are not finale, start damage timer
	if( g_hTimer[TIMER_GLOBAL] == null && !g_bIsRound_Finale && ( g_iDoor_Spawn != -1 || g_iDoor_Rescue != -1 ))
	{
		g_bIsRound_End = false;
		
		g_hTimer[TIMER_GLOBAL] = CreateTimer( 1.0, Timer_GlobalDamage, _, TIMER_REPEAT );
		
		PrintTextToServer( "Timer Damage has started", g_bCvar_IsDebugging );
	}
}

public Action Timer_GlobalDamage( Handle timer )
{
	if( g_hTimer[TIMER_GLOBAL] != timer )
	{
		PrintTextToServer( "Timer damage lost track and terminated", true );
		
		return Plugin_Stop;
	}
	
	if( g_bIsRound_Finale || g_bIsRound_End )
	{
		g_hTimer[TIMER_GLOBAL] = null;
		PrintTextToServer( "Timer damage terminated for finale", g_bCvar_IsDebugging );
		
		return Plugin_Stop;
	}
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( Survivor_InGame( i ))
		{
			if( IsFakeClient( i ) && !g_bCvar_DamageBot ) continue;
			
			if( g_bIsDamage_Rescue )
			{	
				// checkpoint area damage
				if( g_iStateRoom[i] != ROOM_STATE_RESCUE )
				{
					// survivor has no attacker, continue damag.
					if( !Survivor_IsPinned( i ))
					{
						// incap or ledge, kill him even faster.
						if( Survivor_IsHopeless( i ))
						{
							Create_DamageEffect( i, 0, g_iCvar_DamageIncap );
						}
						else
						{
							Create_DamageEffect( i, 0, g_iCvar_DamageAlive );
						}
					}
				}
			}
			else
			{
				if( g_iDoor_Spawn != -1 )
				{
					// spawn area damage
					g_iSpawnCount[i] -= 1;
					if( g_iSpawnCount[i] < -1 )
					{
						g_iSpawnCount[i] = -1;
					}
					
					if( g_bCvar_LeaveSpawnMsg && !IsFakeClient( i ))
					{
						if( g_iSpawnCount[i] == (g_iCvar_Notify_Total - 1))
						{
							PrintToChat( i, "\x05[\x04WARNING\x05]: \x01You have \x04%0.0f sec(s) \x01to leave Spawn Saferoom!!", float( g_iCvar_Notify_Total ));
						}
						else if( g_iSpawnCount[i] == g_iCvar_NotifySpawn2 )
						{
							if( g_iStateRoom[i] == ROOM_STATE_SPAWN )
							{
								PrintToChat( i, "\x05[\x04WARNING\x05]: \x01You have \x04%0.0f sec(s) \x01to leave Spawn Saferoom!!", float( g_iCvar_NotifySpawn2 ));
							}
							else
							{
								PrintToChat( i, "\x05[\x04WARNING\x05]: \x01Spawn Saferoom Hazard in \x04%0.0f \x01sec(s)", float( g_iCvar_NotifySpawn2 ));
							}
						}
						else if( g_iSpawnCount[i] == 0 )
						{
							if( g_iStateRoom[i] == ROOM_STATE_SPAWN )
							{
								PrintToChat( i, "\x05[\x04WARNING\x05]: \x01Spawn Saferoom Hazard effecting you!!" );
							}
							else
							{
								PrintToChat( i, "\x05[\x04WARNING\x05]: \x01Spawn Saferoom Hazard has started!!" );
							}
							EmitSoundToClient( i, SND_WARNING );
						}
					}
					
					if( g_iSpawnCount[i] < 0 )
					{
						if( g_iStateRoom[i] == ROOM_STATE_SPAWN )
						{
							// survivor has no attacker, continue damag.
							if( !Survivor_IsPinned( i ))
							{
								// incap or ledge, kill him even faster.
								if( Survivor_IsHopeless( i ))
								{
									Create_DamageEffect( i, 0, g_iCvar_DamageIncap );
								}
								else
								{
									Create_DamageEffect( i, 0, g_iCvar_DamageAlive );
								}
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_ForceInfectedSuicide( Handle timer, any userid )
{
	int client = GetClientOfUserId( userid );
	if ( Infected_IsValid( client ))
	{
		ForcePlayerSuicide( client );
		PrintToServer( "Player %N Commited Suicide", client );
	}
	return Plugin_Stop;
}



//====================== Function =========================//
void Get_SaferoomDoor( int client )
{
	float doorPos[3];
	float playPos[3];
	GetEntPropVector( client, Prop_Send, "m_vecOrigin", playPos );
	
	int entity = -1;
	while (( entity = FindEntityByClassname( entity, "prop_door_rotating_checkpoint")) != -1 )
	{
		GetEntPropVector( entity, Prop_Send, "m_vecOrigin", doorPos );
		float distance = GetVectorDistance( playPos, doorPos );
		if ( distance <= DIST_RADIUS )
		{
			if( g_iDoor_Spawn == -1 )
			{
				char m_ModelName[PLATFORM_MAX_PATH];
				GetEntPropString( entity, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
				if( StrEqual( m_ModelName, MDL_SPAWNROOM1, false ) || StrEqual( m_ModelName, MDL_SPAWNROOM2, false ))
				{
					g_iDoor_Spawn = entity;
					PrintTextToServer( "Spawn Door found", g_bCvar_IsDebugging );
				}
			}
		}
		else
		{
			if( g_iDoor_Rescue == -1 )
			{
				char m_ModelName[PLATFORM_MAX_PATH];
				GetEntPropString( entity, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
				if( StrEqual( m_ModelName, MDL_CHECKROOM1, false ) || StrEqual( m_ModelName, MDL_CHECKROOM2, false ))
				{
					g_iDoor_Rescue = entity;
					AcceptEntityInput( entity, "close" );
					PrintTextToServer( "Checkpoint Door found", g_bCvar_IsDebugging );
				}
			}
		}
	}
}

void Get_EntityLocation( int entity, float pos[3], float ang[3] )
{
	GetEntPropVector( entity, Prop_Send, "m_vecOrigin", pos );
	GetEntPropVector( entity, Prop_Data, "m_angRotation", ang );
}

int Create_Reference( float pos[3], float ang[3], const char[] model )
{
	int entity = CreateEntityByName( "prop_dynamic_override" );
	if ( entity == -1 ) return entity;
	
	DispatchKeyValue( entity, "model", model );
	DispatchKeyValueVector( entity, "origin", pos );
	DispatchKeyValueVector( entity, "angles", ang );
	DispatchSpawn( entity );
	SetEntityRenderMode( entity, RENDER_TRANSALPHA );
	SetEntityRenderColor( entity, 255, 255, 255, 255 );
	
	if( g_bCvar_IsDebugging )
	{
		ToggleGlowEnable( entity, view_as<int>({ 000, 255, 000 }), true );
	}
	return entity;
}

int Create_SensorModel( float pos[3], float ang[3], const char[] model )
{
	int door = CreateEntityByName( "prop_dynamic_override" );
	if( door == -1 ) return door;
	
	DispatchKeyValueVector( door, "origin", pos );
	DispatchKeyValueVector( door, "angles", ang );
	DispatchKeyValue( door, "model", model );
	//SetEntPropFloat( door, Prop_Send,"m_flModelScale", 1.0 );
	SetEntProp( door, Prop_Send, "m_usSolidFlags", 12 );
	SetEntProp( door, Prop_Data, "m_nSolidType", 6 );
	SetEntProp( door, Prop_Send, "m_CollisionGroup", 1 );
	SetEntityRenderMode( door, RENDER_TRANSALPHA );
	SetEntityRenderColor( door, 255, 255, 255, 0 );
	DispatchSpawn( door );
	
	if( g_bCvar_IsDebugging )
	{
		ToggleGlowEnable( door, view_as<int>({ 000, 255, 000 }), true );
	}
	return door;
}

void Create_DamageEffect( int victim, int attacker, int damage )
{
	DealDamage( victim, attacker, damage, DMG_GENERIC, "" );
	SetupBloodEffect( victim, g_iBloodSprite, g_iCvar_BloodColor );
	AttachParticle( victim, MDL_PARTICLEFIRE );

	if( !IsFakeClient( victim ))
	{
		delete g_hStopSound[victim];
		EmitSoundToClient( victim, SND_BURNING );
	}
}

// Because I love you.
void DealDamage( int victim, int attacker, int damage, int dmg_type, const char[] weapon )
{
	// event "player_hurt" trigged by this point hurt
	if( victim > 0 && GetEntProp( victim, Prop_Data, "m_iHealth" ) > 0 && attacker != -1 && damage > 0 )
	{
		char dmg_str[16];
		IntToString( damage, dmg_str, 16 );
		char dmg_type_str[32];
		IntToString( dmg_type, dmg_type_str, 32 );
		int pointHurt = CreateEntityByName( "point_hurt" );
		if ( pointHurt == -1 ) return;
		
		DispatchKeyValue( victim,"targetname","war3_hurtme" );
		DispatchKeyValue( pointHurt, "DamageTarget","war3_hurtme" );
		DispatchKeyValue( pointHurt, "Damage",dmg_str );
		DispatchKeyValue( pointHurt,"DamageType", dmg_type_str );
		if ( !StrEqual( weapon, "" ))
		{
			DispatchKeyValue( pointHurt, "classname", weapon );
		}
		DispatchSpawn( pointHurt );
		AcceptEntityInput( pointHurt, "Hurt",( attacker > 0 ) ? attacker:-1 );
		DispatchKeyValue( pointHurt, "classname", "point_hurt" );
		DispatchKeyValue( victim, "targetname", "war3_donthurtme" );
		AcceptEntityInput( pointHurt, "Kill" );
	}
}

void SetupBloodEffect( int client, int sprite, int color[4] )
{
	float pos[3];
	GetEntPropVector( client, Prop_Send, "m_vecOrigin", pos );
	
	float temp[3];
	for( int i = 0; i < 10 ; i++ )
	{
		temp = view_as<float>(pos);
		temp[0] += GetRandomFloat( -30.0, 30.0 );
		temp[1] += GetRandomFloat( -30.0, 30.0 );
		temp[2] += GetRandomFloat( 10.0, 50.0 );
		TE_SetupBloodSprite( temp, NULL_VECTOR, color, 10, sprite, sprite );
		TE_SendToAll();
	}
}

//======================== @Silver ==========================//
void AttachParticle(int client, char[] particleType)
{
    int entity = CreateEntityByName("info_particle_system");
    if( IsValidEdict(entity) )
    {
		DispatchKeyValue(entity, "effect_name", particleType);
		DispatchSpawn(entity);

		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", client);

		ActivateEntity(entity);
		AcceptEntityInput(entity, "start");
		
		SetVariantString("OnUser1 !self:Kill::1.0:1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
    }
}

int PrecacheParticle(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	if( table == INVALID_STRING_TABLE )
	{
		table = FindStringTable("ParticleEffectNames");
	}

	int index = FindStringIndex(table, sEffectName);
	if( index == INVALID_STRING_INDEX )
	{
		bool save = LockStringTables(false);
		AddToStringTable(table, sEffectName);
		LockStringTables(save);
		index = FindStringIndex(table, sEffectName);
	}

	return index;
}

void StopBurningSound( int client )
{
	delete g_hStopSound[client];
	g_hStopSound[client] = CreateTimer( 1.0, Timer_StopSound, GetClientUserId( client ));
}

public Action Timer_StopSound( Handle timer, any userid )
{
	int client = GetClientOfUserId( userid );
	if( Survivor_IsValid( client ))
	{
		g_hStopSound[client] = null;
		StopSound( client, SNDCHAN_AUTO, SND_BURNING );
	}
	return Plugin_Stop;
}

int LoadDoorConfig( const char[][] settingname, int length, const char[] mapname )
{
	for( int i = 0; i < length; i++ )
	{
		if( StrEqual( settingname[i], mapname, false ))
		{
			return i;
		}
	}
	return -1;
}





//======================== Stock ==========================//
bool Infected_IsValid( int client )
{
	return ( client > 0 && client <= MaxClients && IsClientInGame( client ) && GetClientTeam( client ) == TEAM_INFECTED );
}

bool Survivor_IsValid( int client )
{
	return ( client > 0 && client <= MaxClients && IsClientInGame( client ) && GetClientTeam( client ) == TEAM_SURVIVOR );
}

bool Survivor_InGame( int client )
{
	return ( IsClientInGame( client ) && IsPlayerAlive( client ) && GetClientTeam( client ) == TEAM_SURVIVOR );
}

bool Survivor_IsHopeless( int client )
{
	return ( GetEntProp( client, Prop_Send, "m_isIncapacitated" ) == 1 || GetEntProp( client, Prop_Send, "m_isHangingFromLedge" ) == 1 );
}

bool Survivor_IsPinned( int client )
{
	return
	( 
		GetEntProp( client, Prop_Send, "m_tongueOwner" ) 		> 0 || 
		GetEntPropEnt( client, Prop_Send, "m_pounceAttacker" )	> 0 || 
		GetEntPropEnt( client, Prop_Send, "m_jockeyAttacker" )	> 0
	);
}

void PrintTextToServer( const char[] text, bool print )
{
	if( !print ) return;
	
	char gauge_tags[16] = "[SAFEROOM]:";
	char gauge_char[99] = "===========================================================================";
	char gauge_side[64];
	FormatEx( gauge_side, sizeof( gauge_side ), "" );
	
	float len_buff = float( strlen( gauge_char ));
	float len_text = float( strlen( text ));
	float len_tags = float( strlen( gauge_tags ));
	float len_diff = ( len_buff - len_text - len_tags ) / 2.0;
	
	for( int i = 0; i <= RoundToCeil(len_diff); i++ )
	{
		gauge_side[i] = gauge_char[0];
	}
	
	//PrintToServer( "=========== [SAFEROOM]: Timer damage terminated for finale ================" );
	
	PrintToServer( " " );
	PrintToServer( "%s", gauge_char );
	PrintToServer( "%s %s %s %s", gauge_side, gauge_tags, text, gauge_side );
	PrintToServer( "%s", gauge_char );
	PrintToServer( " " );
}

void TeleportPlayer( int client, float pos[3], const char[] sound )
{
	float pos_new[3];
	pos_new	= view_as<float>(pos);
	pos_new[2] += 10.0;
	
	TeleportEntity( client, pos_new, NULL_VECTOR, NULL_VECTOR );
	EmitSoundToClient( client, sound );
}













//==================== Unused Stock =======================//
stock int GetHumanSpectator( int bot )
{
	// return human ID of idle bot, -1 if found none.
	int userid = GetEntProp( bot, Prop_Send, "m_humanSpectatorUserID" );
	int client = GetClientOfUserId( userid );
	if ( client > 0 && client <= MaxClients && IsClientInGame( client ) && !IsFakeClient( client ))
	{
		return client;
	}
	return -1;
}

stock bool TraceRay_GetEndpoint( float startPos[3], float startAng[3], any data, float outputPos[3] )
{
	bool havepos = false;
	Handle trace = TR_TraceRayFilterEx( startPos, startAng, MASK_SOLID_BRUSHONLY, RayType_Infinite, TraceEntityFilterPlayers, data );
	if( TR_DidHit( trace ))
	{ 
		TR_GetEndPosition( outputPos, trace );
		havepos = true;
	}
	delete trace;
	return havepos;
}

stock int TraceRay_GetEntity( float startPos[3], float startAng[3], any data )
{
	int entity = -1;
	Handle trace = TR_TraceRayFilterEx( startPos, startAng, MASK_SOLID_BRUSHONLY, RayType_Infinite, TraceEntityFilterPlayers, data );
	if( TR_DidHit( trace ))
	{ 
		entity = TR_GetEntityIndex( trace );
	}
	delete trace;
	return entity;
}

stock bool TraceEntityFilterPlayers( int entity, int contentsMask, any data )
{
	return ( entity > MaxClients && entity != data );
}

stock void ToggleGlowEnable( int entity, int color[3], bool enable ) //<< ok
{
	int  m_glowtype = 0;
	int  m_glowcolor = 0;
	
	if ( enable )
	{
		m_glowtype = 3;
		m_glowcolor = color[0] + ( color[1] * 256 ) + ( color[2] * 65536 );
	}
	SetEntProp( entity, Prop_Send, "m_iGlowType", m_glowtype );
	SetEntProp( entity, Prop_Send, "m_nGlowRange", 0 );
	SetEntProp( entity, Prop_Send, "m_glowColorOverride", m_glowcolor );
}





