#define PLUGIN_VERSION "1.1.0"
/*
============= version history =============
v 1.1.0
- plugins conversion to new syntax.
- changed command for force enter.
- change detection from radius to sdkhook sensor.
- renaming cvar
- added damage for checkpoint area if player refuse to enter




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
#define TEAM_SPECTATOR		4

#define DIST_RADIUS			600.0
#define DIST_SENSOR			20.0
#define DIST_REFERENCE		80.0

#define TELEPORT_SND		"ui/menu_horror01.wav"


//======== Global ConVar ========//
ConVar	g_ConVarSafeHazard_PluginEnable,	g_ConVarSafeHazard_NotifySpawn1,		g_ConVarSafeHazard_NotifySpawn2,	g_ConVarSafeHazard_Radius,		g_ConVarSafeHazard_DamageAlive,
		g_ConVarSafeHazard_DamageIncap,		g_ConVarSafeHazard_LeaveSpawnMsg,		g_ConVarSafeHazard_EventDoor,		g_ConVarSafeHazard_EventNumber,	g_ConVarSafeHazard_CmdDoor,
		g_ConVarSafeHazard_ReferanceToy,	g_ConVarSafeHazard_CheckpoinCountdown,	g_ConVarSafeHazard_ExitMsg, 		g_ConVarSafeHazard_IsDebugging;


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
bool	g_bCvar_IsDebugging;


//== Spawn Door Area Sensor Type ==//
#define SENSOR_ENTER			0
#define SENSOR_EXIT				1
int 	g_iDoorSensorType[2]	= { -1, ... };


//========== Door Model =========//
#define DOOR_HANDSIDE_RIGHT		0
#define DOOR_HANDSIDE_LEFT		1
#define DOOR_HANDSIDE_LENGTH	2
char g_sDoorModel[][] =
{
	// right handside model
	"models/props_doors/checkpoint_door_-01.mdl",
	"models/props_doors/checkpoint_door_02.mdl",

	// left handside model
	"models/props_doors/checkpoint_door_01.mdl"
};


//========= Dummy Model =========//
enum
{
	MDL_REFERANCE1,
	MDL_REFERANCE2,
	MDL_REFERANCE3,
	MDL_SENSOR,
	MDL_LENGTH,
}
char g_sSpawnModel[MDL_LENGTH][] =
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
enum	{
	ROOM_STATE_OUTSIDE,
	ROOM_STATE_SPAWN,
	ROOM_STATE_RESCUE,
	ROOM_STATE_LENGTH
}
int g_iSaferoomState[MAXPLAYERS+1];


//========= Spawn damage ========//
int		g_iSpawnCount[MAXPLAYERS+1];
float	g_fSpawnPos[3];
int		g_iSpawnDoor		= -1;
int		g_iSpawnRef			= -1;


//====== Checkpoint damage ======//
float	g_fRescuePos[3];
bool	g_bRescueDamage;
int		g_iRescueDoor		= -1;
int		g_iRescueRef		= -1;


//========= Misc check ==========//
bool	g_bIsFinale;
bool	g_bIsFindDoorInit;



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
	g_ConVarSafeHazard_Radius				= CreateConVar( "hazard_checkpoint_radius",	"300",	"Player distance from checkpoint door consider near.", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_ConVarSafeHazard_DamageAlive			= CreateConVar( "hazard_damage_alive",		"1",	"Health we knock off player per hit if he alive.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 1.0, true, 100.0 );
	g_ConVarSafeHazard_DamageIncap			= CreateConVar( "hazard_damage_incap",		"10",	"Health we knock off player per hit if he incap.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 1.0, true, 100.0 );
	g_ConVarSafeHazard_LeaveSpawnMsg		= CreateConVar( "hazard_leave_message",		"1",	"0:Off  | 1:On, Announce spawn saferoom damage message.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_EventDoor			= CreateConVar( "hazard_manual_safe",		"0",	"0:Off  | 1:On, Checkpoint door manually closed, all player force teleport inside.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_EventNumber			= CreateConVar( "hazard_manual_number",		"3",	"0:Off  | 1:On, Checkpoint door manually closed, this number of players inside checkpoint will force teleport all players", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 64.0 );
	g_ConVarSafeHazard_CmdDoor				= CreateConVar( "hazard_command_door",		"0",	"0:Open | 1:Closed, command 'srh_enter' will open/closed checkpoint door after force teleport all player.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_ReferanceToy			= CreateConVar( "hazard_saferoom_toy",		"1",	"0:Off, 1:On, If on, developer teleport reference visible inside safe room.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_CheckpoinCountdown	= CreateConVar( "hazard_warning",			"15",	"If player refuse to enter second saferoom, do damage after this long(seconds).", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 60.0 );
	g_ConVarSafeHazard_ExitMsg				= CreateConVar( "hazard_exit_message",		"1",	"0:Off, 1:On, Display hint text everytime player enter/exit.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_IsDebugging			= CreateConVar( "hazard_debugging_enable",	"1",	"0:Off, 1:On, Toggle debugging.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	//AutoExecConfig( true, "l4d2_saferoom_hazard" );
	
	HookEvent( "player_spawn",		EVENT_PlayerSpawn );
	HookEvent( "round_end",			EVENT_RoundEnd );
	HookEvent( "finale_start",		EVENT_Finale );
	HookEvent( "door_close",		EVENT_DoorClose );

	RegAdminCmd( "srh_enter",	Command_ForceEnter_CheckpointRoom, ADMFLAG_GENERIC );
	RegAdminCmd( "srh_jump",	Command_ForceEnter_Saferoom, ADMFLAG_GENERIC );
	RegAdminCmd( "srh_check",	Command_CheckEntity, ADMFLAG_GENERIC );
	
	//=================== Rescue room trigger ===================//
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
	g_bCvar_IsDebugging			= g_ConVarSafeHazard_IsDebugging.BoolValue;
	
	g_iCvar_Notify_Total = g_iCvar_NotifySpawn1 + g_iCvar_NotifySpawn2;
}

public Action Command_ForceEnter_CheckpointRoom( int client, int args )
{
	if ( client < 1 )
	{
		ReplyToCommand( client, "[SAFEROOMHAZARD]: Command only valid in game!!" );
		return Plugin_Handled;
	}
	
	if ( g_iRescueRef == -1 || !IsValidEntity( g_iRescueRef ))
	{
		ReplyToCommand( client, "[SAFEROOMHAZARD]: Teleport referance not found!!" );
		return Plugin_Handled;
	}
	
	if ( GetClientTeam( client ) != TEAM_SURVIVOR )
	{
		ReplyToCommand( client, "[SAFEROOMHAZARD]: Command only for Survivor!!" );
		return Plugin_Handled;
	}
	
	if ( g_iRescueDoor != -1 )
	{
		if ( g_bCvar_DoorWinState )
		{
			AcceptEntityInput( g_iRescueDoor, "Close" );
		}
		else
		{
			AcceptEntityInput( g_iRescueDoor, "Open" );
		}
	}
	
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && IsPlayerAlive( i ) && GetClientTeam( i ) == TEAM_SURVIVOR )
		{
			TeleportPlayer( i, g_iRescueRef );
		}
	}
	return Plugin_Handled;
}

public Action Command_ForceEnter_Saferoom( int client, int args )
{
	if ( client < 1 )
	{
		ReplyToCommand( client, "[SAFEROOMHAZARD]: Command only valid in game!!" );
		return Plugin_Handled;
	}
	
	if ( g_iSpawnRef == -1 || !IsValidEntity( g_iSpawnRef ))
	{
		ReplyToCommand( client, "[SAFEROOMHAZARD]: Teleport referance not found!!" );
		return Plugin_Handled;
	}
	
	if ( GetClientTeam( client ) != TEAM_SURVIVOR )
	{
		ReplyToCommand( client, "[SAFEROOMHAZARD]: Command only for Survivor!!" );
		return Plugin_Handled;
	}
	
	if ( args < 1 )
	{
		ReplyToCommand( client, "\x01[SAFEROOMHAZARD]: usage \x04srh_jump 0 \x01for spawn are jump" );
		ReplyToCommand( client, "\x01[SAFEROOMHAZARD]: usage \x04srh_jump 1 \x01for checkpoint are jump" );
		return Plugin_Handled;
	}
	
	char arg1[8];
	GetCmdArg( 1, arg1, sizeof( arg1 ));
	int type = StringToInt( arg1 );
	if( type == 0 )
	{
		if ( g_iSpawnRef != -1 && IsValidEntity( g_iSpawnRef ))
		{
			TeleportPlayer( client, g_iSpawnRef );
		}
		else
		{
			ReplyToCommand( client, "[SAFEROOMHAZARD]: Spawn room referance not found!!" );
		}
	}
	else if( type == 1 )
	{
		if ( g_iRescueRef != -1 && IsValidEntity( g_iRescueRef ))
		{
			TeleportPlayer( client, g_iRescueRef );
		}
		else
		{
			ReplyToCommand( client, "[SAFEROOMHAZARD]: Checkpoint referance not found!!" );
		}
	}
	else
	{
		ReplyToCommand( client, "\x01[SAFEROOMHAZARD]: only \x04srh_jump 0 \x01or \x04srh_jump 1 \x01valid command" );
	}
	
	return Plugin_Handled;
}

public Action Command_CheckEntity( int client, int args )
{
	if ( client < 1 )
	{
		ReplyToCommand( client, "[SAFEROOMHAZARD]: Command only valid in game!!" );
		return Plugin_Handled;
	}
	
	if ( !g_bCvar_IsDebugging )
	{
		ReplyToCommand( client, "[SAFEROOMHAZARD]: Debugging mode disabled!!" );
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
	PrintToChatAll( "nameClass: %s", nameClass );
	
	char m_ModelName[PLATFORM_MAX_PATH];
	GetEntPropString( entity, Prop_Data, "m_ModelName", m_ModelName, sizeof( m_ModelName ));
	PrintToChatAll( "m_ModelName: %s", m_ModelName );
	
	return Plugin_Handled;
}

public void OnMapStart()
{
	int i;
	for ( i = 0; i < TIMER_LENGTH; i++ )
	{
		g_hTimer[i] = INVALID_HANDLE;
	}
	
	g_iDoorSensorType[0]	= -1;
	g_iDoorSensorType[1]	= -1;
	
	g_fSpawnPos			= view_as<float>({ 0.0, 0.0, 0.0 });
	g_fRescuePos		= view_as<float>({ 0.0, 0.0, 0.0 });
	
	g_bIsFinale			= false;
	g_bRescueDamage		= false;
	g_iSpawnDoor		= -1;
	g_iRescueDoor		= -1;
	g_iRescueRef		= -1;
	g_bIsFindDoorInit	= false;
	
	for ( i = 0; i < MDL_LENGTH; i++ )
	{
		PrecacheModel( g_sSpawnModel[i] );
	}
	PrecacheSound( TELEPORT_SND, true );
}

public void OnClientPutInServer( int client )
{
	if ( client > 0 )
	{
		g_iSaferoomState[client] = -1;
		g_iSaferoomState[client] = -1;
	}
}

public void OnClientDisconnect( int client )
{
	OnClientPutInServer( client );
}

public void EVENT_RoundEnd( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	g_bIsFinale 		= false;
	g_bRescueDamage 	= false;
	g_iSpawnDoor		= -1;
	g_iRescueDoor		= -1;
	g_bIsFindDoorInit = false;
	
	for ( int i = 0; i < TIMER_LENGTH; i++ )
	{
		if( g_hTimer[i] != INVALID_HANDLE )
		{
			KillTimer( g_hTimer[i] );
		}
		g_hTimer[i] = INVALID_HANDLE;
	}
}

public void EVENT_Finale( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	g_bIsFinale = true;
}

public void EVENT_DoorClose( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable || g_bCvar_EventDoorWin ) return;
	
	bool close = event.GetBool( "checkpoint" );
	if ( close )
	{
		int count;
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( g_iSaferoomState[i] == ROOM_STATE_RESCUE )
			{
				count++;
			}
		}
		
		if( count >= g_iCvar_DoorNumber )
		{
			for( int i = 1; i <= MaxClients; i++ )
			{
				if( Survivor_InGame( i ))
				{
					TeleportPlayer( i, g_iRescueRef );
				}
			}
		}
	}
}



//=================== Rescue room Damage ===================//
//==================== code from @Mart =====================//
public void EntityOutput_OnStartTouch_Rescueroom( const char[] output, int caller, int activator, float time )
{
	if( Survivor_IsValid( activator ))
	{
		if( g_iSaferoomState[activator] != ROOM_STATE_RESCUE )
		{
			g_iSaferoomState[activator] = ROOM_STATE_RESCUE;
			if( g_bCvar_NotifyExit )
			{
				PrintHintText( activator, "%N Entering Checkpoint Area", activator );
			}
		}
		
		if( !g_bRescueDamage && g_hTimer[TIMER_RESCUE] == INVALID_HANDLE )
		{
			bool start = true;
			float pos[3];
			for( int i = 1; i <= MaxClients; i++ )
			{
				if( Survivor_InGame( i ))
				{
					GetEntPropVector( i, Prop_Send, "m_vecOrigin", pos );
					if( GetVectorDistance( pos, g_fRescuePos ) > g_fCvar_Radius )
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
						if( Survivor_InGame( i ))
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
	g_bRescueDamage			= true;
	g_hTimer[TIMER_RESCUE]	= INVALID_HANDLE;
	return Plugin_Stop;
}

public void EntityOutput_OnEndTouch_Rescueroom( const char[] output, int caller, int activator, float time )
{
	if( Survivor_IsValid( activator ))
	{
		if( g_iSaferoomState[activator] != ROOM_STATE_OUTSIDE )
		{
			g_iSaferoomState[activator] = ROOM_STATE_OUTSIDE;
			if( g_bCvar_NotifyExit )
			{
				PrintHintText( activator, "%N Leaving Checkpoint Area", activator );
			}
		}
    }
}



//=================== Spawn room Damage ===================//
public void EVENT_PlayerSpawn( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	int userid = event.GetInt( "userid" );
	int client = GetClientOfUserId( userid );
	if ( Survivor_IsValid( client ))
	{
		if( !IsFakeClient( client ))
		{
			// create spawn saferoom door sensor and teleport referance
			SpawnSaferoomSensor( client );
			
			// set player spawn room max stay count.
			g_iSpawnCount[client] = g_iCvar_Notify_Total;
			
			// set player state inside spawn saferoom.
			g_iSaferoomState[client] = ROOM_STATE_SPAWN;
			
			// if map has spawn saferoom door or rescue saferoom door, start timer
			if( g_iSpawnDoor != -1 || g_iRescueDoor != -1 )
			{
				if( g_hTimer[TIMER_GLOBAL] == INVALID_HANDLE )
				{
					g_hTimer[TIMER_GLOBAL] = CreateTimer( 1.0, Timer_Global, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
				}
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
	Init_SaferoomDoorSearch( client );
	

	//======== create spawn door sensor ========//
	if( g_iSpawnDoor != -1 )
	{
		char m_ModelName[PLATFORM_MAX_PATH];
		GetEntPropString( g_iSpawnDoor, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
		int type = GetDoorType( m_ModelName );
		if( type != -1 )
		{
			// create spawn saferoomdoor sensor first layer
			float buf[3];
			float pos[3];
			float ang[3];
			Get_EntityLocation( g_iSpawnDoor, pos, ang );
			
			buf = view_as<float>(pos);
			if( type == DOOR_HANDSIDE_RIGHT )
			{
				buf[0] += DIST_SENSOR * Cosine( DegToRad( ang[1] ));
				buf[1] += DIST_SENSOR * Sine( DegToRad( ang[1] ));
			}
			else if( type == DOOR_HANDSIDE_LEFT )
			{
				buf[0] -= DIST_SENSOR * Cosine( DegToRad( ang[1] ));
				buf[1] -= DIST_SENSOR * Sine( DegToRad( ang[1] ));
			}
			
			g_iDoorSensorType[SENSOR_ENTER] = Create_SensorModel( buf, ang, g_sSpawnModel[MDL_SENSOR], 0 );
			if( g_iDoorSensorType[SENSOR_ENTER] != -1 )
			{
				SDKHook( g_iDoorSensorType[SENSOR_ENTER], SDKHook_StartTouch, OnDoorSensorTouch );
				SDKHook( g_iDoorSensorType[SENSOR_ENTER], SDKHook_EndTouch, OnDoorSensorTouch );
			}
			
			
			// create spawn saferoomdoor sensor second layer
			buf = view_as<float>(pos);
			if( type == DOOR_HANDSIDE_RIGHT )
			{
				buf[0] -= DIST_SENSOR * Cosine( DegToRad( ang[1] ));
				buf[1] -= DIST_SENSOR * Sine( DegToRad( ang[1] ));
			}
			else if( type == DOOR_HANDSIDE_LEFT )
			{
				buf[0] += DIST_SENSOR * Cosine( DegToRad( ang[1] ));
				buf[1] += DIST_SENSOR * Sine( DegToRad( ang[1] ));
			}
			
			g_iDoorSensorType[SENSOR_EXIT] = Create_SensorModel( buf, ang, g_sSpawnModel[MDL_SENSOR], 0 );
			if( g_iDoorSensorType[SENSOR_EXIT] != -1 )
			{
				SDKHook( g_iDoorSensorType[SENSOR_EXIT], SDKHook_StartTouch, OnDoorSensorTouch );
				SDKHook( g_iDoorSensorType[SENSOR_EXIT], SDKHook_EndTouch, OnDoorSensorTouch );
			}
			
			
			
			// create entity model for teleport referance
			g_fSpawnPos		= view_as<float>(pos);
			g_fSpawnPos[2]	-= 53.0;
			
			if( type == DOOR_HANDSIDE_RIGHT )
			{
				g_fSpawnPos[0] += DIST_REFERENCE * Cosine( DegToRad( ang[1] ));
				g_fSpawnPos[1] += DIST_REFERENCE * Sine( DegToRad( ang[1] ));
			}
			else if( type == DOOR_HANDSIDE_LEFT )
			{
				g_fSpawnPos[0] -= DIST_REFERENCE * Cosine( DegToRad( ang[1] ));
				g_fSpawnPos[1] -= DIST_REFERENCE * Sine( DegToRad( ang[1] ));
			}
			
			int rand = GetRandomInt( 0, ( sizeof(g_sSpawnModel) - 1 ));
			if( g_bCvar_ReferanceToy )
			{
				g_iSpawnRef = Create_Reference( g_fSpawnPos, g_sSpawnModel[rand], 255 );
			}
			else
			{
				g_iSpawnRef = Create_Reference( g_fSpawnPos, g_sSpawnModel[rand], 0 );
			}
			
			if( g_bCvar_IsDebugging )
			{
				PrintToChatAll( "g_iSpawnDoor model:  %s", m_ModelName );
			}
		}
		else
		{
			if( g_bCvar_IsDebugging )
			{
				PrintToServer( "*********** SAFEROOMHAZARD: g_iSpawnDoor model NOT FOUND ***********" );
			}
		}
	}
	
	//===== create checkpoint door referance =====//
	if( g_iRescueDoor != -1 )
	{
		char m_ModelName[PLATFORM_MAX_PATH];
		GetEntPropString( g_iRescueDoor, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
		int type = GetDoorType( m_ModelName );
		if( type != -1 )
		{
			AcceptEntityInput( g_iRescueDoor, "open" );
			
			// create entity model for teleport referance
			float pos[3];
			float ang[3];
			Get_EntityLocation( g_iRescueDoor, pos, ang );
			ang[1] += 90.0;
			
			g_fRescuePos	= view_as<float>(pos);
			g_fRescuePos[2]	-= 53.0;
			
			if( type == DOOR_HANDSIDE_RIGHT )
			{
				g_fRescuePos[0] += DIST_REFERENCE * Cosine( DegToRad( ang[1] ));
				g_fRescuePos[1] += DIST_REFERENCE * Sine( DegToRad( ang[1] ));
			}
			else if( type == DOOR_HANDSIDE_LEFT )
			{
				g_fRescuePos[0] -= DIST_REFERENCE * Cosine( DegToRad( ang[1] ));
				g_fRescuePos[1] -= DIST_REFERENCE * Sine( DegToRad( ang[1] ));
			}
			
			int rand = GetRandomInt( 0, ( sizeof(g_sSpawnModel) - 1 ));
			if( g_bCvar_ReferanceToy )
			{
				g_iRescueRef = Create_Reference( g_fRescuePos, g_sSpawnModel[rand], 255 );
			}
			else
			{
				g_iRescueRef = Create_Reference( g_fRescuePos, g_sSpawnModel[rand], 0 );
			}
			
			
			if( g_bCvar_IsDebugging )
			{
				PrintToChatAll( "g_iRescueDoor model:  %s", m_ModelName );
			}
		}
		else
		{
			if( g_bCvar_IsDebugging )
			{
				PrintToServer( "*********** SAFEROOMHAZARD: g_iRescueDoor model NOT FOUND ***********" );
			}
		}
	}
}

public Action OnDoorSensorTouch( int entity, int client )
{
	if( !Survivor_IsValid( client )) return Plugin_Continue;
	
	//========= spawn saferoom sensor logic =========//
	if( entity == g_iDoorSensorType[SENSOR_ENTER] )
	{
		if( g_iSaferoomState[client] != ROOM_STATE_SPAWN )
		{
			g_iSaferoomState[client] = ROOM_STATE_SPAWN;
			if( g_bCvar_NotifyExit )
			{
				PrintHintText( client, "%N Entering Spawn Saferoom!!", client );
			}
		}
	}
	else if( entity == g_iDoorSensorType[SENSOR_EXIT] )
	{
		if( g_iSaferoomState[client] != ROOM_STATE_OUTSIDE )
		{
			g_iSaferoomState[client] = ROOM_STATE_OUTSIDE;
			if( g_bCvar_NotifyExit )
			{
				PrintHintText( client, "%N Leaving Spawn Saferoom", client );
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_Global( Handle timer )
{
	if( g_bIsFinale )
	{
		g_hTimer[TIMER_GLOBAL] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	for( int i = 1; i <= MaxClients; i ++ )
	{
		if( Survivor_InGame( i ))
		{
			if( g_bRescueDamage )
			{	
				// checkpoint area damage
				if( g_iSaferoomState[i] != ROOM_STATE_RESCUE )
				{
					// survivor has no attacker, continue damag.
					if( !Survivor_IsPinned( i ))
					{
						// incap or ledge, kill him even faster.
						if( Survivor_IsHopeless( i ))
						{
							DealDamage( i, i, g_iCvar_DamageIncap, DMG_GENERIC, "" );
						}
						else
						{
							DealDamage( i, i, g_iCvar_DamageAlive, DMG_GENERIC, "" );
						}
					}
				}
			}
			else
			{
				// spawn area damage
				g_iSpawnCount[i] -= 1;
				if( g_iSpawnCount[i] < -1 )
				{
					g_iSpawnCount[i] = -1;
				}
				
				if( g_bCvar_LeaveSpawnMsg )
				{
					if( g_iSpawnCount[i] == (g_iCvar_Notify_Total - 1))
					{
						PrintToChat( i, "\x05[\x04WARNING\x05]: \x01You have \x04%0.0f sec(s) \x01to leave Saferoom!!", float( g_iCvar_Notify_Total ));
					}
					else if( g_iSpawnCount[i] == g_iCvar_NotifySpawn2 )
					{
						if( g_iSaferoomState[i] == ROOM_STATE_SPAWN )
						{
							PrintToChat( i, "\x05[\x04WARNING\x05]: \x01You have \x04%0.0f sec(s) \x01to leave Saferoom!!", float( g_iCvar_NotifySpawn2 ));
						}
						else
						{
							PrintToChat( i, "\x05[\x04WARNING\x05]: \x01Saferoom Hazard in \x04%0.0f \x01sec(s)", float( g_iCvar_NotifySpawn2 ));
						}
					}
					else if( g_iSpawnCount[i] == 0 )
					{
						if( g_iSaferoomState[i] == ROOM_STATE_SPAWN )
						{
							PrintToChat( i, "\x05[\x04WARNING\x05]: \x01Saferoom Hazard effecting you!!" );
						}
						else
						{
							PrintToChat( i, "\x05[\x04WARNING\x05]: \x01Saferoom Hazard has started!!" );
						}
					}
				}
				
				if( g_iSpawnCount[i] < 0 )
				{
					if( g_iSaferoomState[i] == ROOM_STATE_SPAWN )
					{
						// survivor has no attacker, continue damag.
						if( !Survivor_IsPinned( i ))
						{
							// incap or ledge, kill him even faster.
							if( Survivor_IsHopeless( i ))
							{
								DealDamage( i, i, g_iCvar_DamageIncap, DMG_GENERIC, "" );
							}
							else
							{
								DealDamage( i, i, g_iCvar_DamageAlive, DMG_GENERIC, "" );
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

int GetDoorType( const char[] doormodle )
{
	for( int i = 0; i < sizeof( g_sDoorModel ); i++ )
	{
		if( StrEqual( doormodle, g_sDoorModel[i], false ))
		{
			if( i < DOOR_HANDSIDE_LENGTH )
			{
				return DOOR_HANDSIDE_RIGHT;
			}
			else
			{
				return DOOR_HANDSIDE_LEFT;
			}
		}
	}
	return -1;
}



//======================== Stock ==========================//
void Init_SaferoomDoorSearch( int client )
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
			g_iSpawnDoor = entity;
			if( g_bCvar_IsDebugging )
			{
				PrintToServer( "=================== [SAFEROOMHAZARD]: Spawn Door found ==================" );
			}
		}
		else
		{
			g_iRescueDoor = entity;
			if( g_bCvar_IsDebugging )
			{
				PrintToServer( "================ [SAFEROOMHAZARD]: Checkpoint Door found ================" );
			}
		}
	}
}

void Get_EntityLocation( int entity, float pos[3], float ang[3] )
{
	GetEntPropVector( entity, Prop_Send, "m_vecOrigin", pos );
	GetEntPropVector( entity, Prop_Data, "m_angRotation", ang );
}

void TeleportPlayer( int client, int entity_reference )
{
	float pos[3];
	GetEntPropVector( entity_reference, Prop_Send, "m_vecOrigin", pos );
	pos[2] += 10.0;
	TeleportEntity( client, pos, NULL_VECTOR, NULL_VECTOR );
	EmitSoundToClient( client, TELEPORT_SND );
}

int Create_Reference( float pos[3], const char[] model, int alpha )
{
	int entity = CreateEntityByName( "prop_dynamic_override" );
	if ( entity == -1 ) return entity;
	
	DispatchKeyValue( entity, "model", model );
	DispatchKeyValueVector( entity, "origin", pos );
	DispatchSpawn( entity );
	SetEntityRenderMode( entity, RENDER_TRANSALPHA );
	SetEntityRenderColor( entity, 255, 255, 255, alpha );
	return entity;
}

int Create_SensorModel( float pos[3], float ang[3], const char[] model, int alpha )
{
	int door = CreateEntityByName( "prop_dynamic_override" );
	if( door == -1 ) return door;
	
	char entName[20];
	Format( entName, sizeof( entName ), "srh%d", door );
	DispatchKeyValue( door, "targetname", entName );
	
	DispatchKeyValueVector( door, "origin", pos );
	DispatchKeyValueVector( door, "angles", ang );
	DispatchKeyValue( door, "model", model );
	SetEntPropFloat( door, Prop_Send,"m_flModelScale", 1.0 );
	SetEntProp( door, Prop_Send, "m_usSolidFlags", 12 );
	SetEntProp( door, Prop_Data, "m_nSolidType", 6 );
	SetEntProp( door, Prop_Send, "m_CollisionGroup", 1 );
	DispatchSpawn( door );
	SetEntityRenderMode( door, RENDER_TRANSALPHA );
	SetEntityRenderColor( door, 255, 255, 255, alpha );
	
	if( g_bCvar_IsDebugging )
	{
		ToggleGlowEnable( door, view_as<int>({ 000, 255, 000 }), true );
	}
	return door;
}

// Because I love you.
void DealDamage( int victim, int attacker, int damage, int dmg_type, const char[] weapon )
{
	if( victim > 0 && GetEntProp( victim, Prop_Data, "m_iHealth" ) > 0 && attacker > 0 && damage > 0 )
	{
		char dmg_str[16];
		IntToString( damage, dmg_str, 16 );
		char dmg_type_str[32];
		IntToString( dmg_type, dmg_type_str, 32 );
		int pointHurt = CreateEntityByName( "point_hurt" );
		if ( pointHurt )
		{
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
}

bool Survivor_IsValid( int client )
{
	return ( client > 0 && client <= MaxClients && IsClientInGame( client ) && GetClientTeam( client ) == TEAM_SURVIVOR );
}

bool Survivor_InGame( int client )
{
	return ( IsClientInGame( client ) && IsPlayerAlive( client ) && !IsFakeClient( client ) && GetClientTeam( client ) == TEAM_SURVIVOR );
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





