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

#define DIST_RADIUS			800.0
#define DIST_SENSOR			20.0
#define DIST_REFERENCE		80.0
#define DIST_DUMMYHEIGHT	-53.0

//=== Client Room State ========//
#define ROOM_STATE_OUTDOOR	0
#define ROOM_STATE_SPAWN	1
#define ROOM_STATE_RESCUE	2

#define SND_TELEPORT		"ui/menu_horror01.wav"
#define SND_BURNING			"ambient/fire/fire_small_loop2.wav"
#define SND_WARNING			"items/suitchargeok1.wav"

#define MDL_SPAWNROOM1		"models/props_doors/checkpoint_door_01.mdl"
#define MDL_SPAWNROOM2		"models/props_doors/checkpoint_door_-01.mdl"
#define MDL_CHECKROOM1		"models/props_doors/checkpoint_door_02.mdl"
#define MDL_CHECKROOM2		"models/props_doors/checkpoint_door_-02.mdl"

#define PAT_FIRE			"burning_character_screen"			// @Silver [L4D2] Hud Splatter

#define MAT_BEAM			"materials/sprites/laserbeam.vmt"	// @silver [ANY] Trigger Multiple Commands
#define MAT_HALO			"materials/sprites/halo01.vmt"
#define MAT_BLOOD			"materials/sprites/bloodspray.vmt"


//== Special Spawn door offsets ==//
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

//=== Dummy Model ================//
enum {
	MDL_REFERANCE1,
	MDL_REFERANCE2,
	MDL_REFERANCE3,
	MDL_SENSOR1,
	MDL_SENSOR2,
	MDL_LENGTH
}
char g_sDummyModel[MDL_LENGTH][] =
{
	"models/props_fairgrounds/elephant.mdl",
	"models/props_fairgrounds/alligator.mdl",
	"models/props_fairgrounds/giraffe.mdl",
	"models/editor/overlay_helper.mdl",
	"models/props_doors/checkpoint_door_02.mdl"
};

//=== Global Timer ==============//
enum {
	TIMER_GLOBAL,
	TIMER_RESCUE,
	TIMER_LENGTH
}


enum struct ClientManager
{
	int  iSpawnCount;
	int	 iStateRoom;
	bool bIsPlaySound;
	bool bIsUseDefib;
	
	void Reset()
	{
		this.iSpawnCount 	= 0;
		this.iStateRoom 	= ROOM_STATE_OUTDOOR;
		this.bIsPlaySound	= false;
		this.bIsUseDefib	= false;
	}
}
ClientManager g_CMClient[MAXPLAYERS+1];


enum struct EntityManager
{
	float	fPos_Spawn[3];
	float	fPos_Rescue[3];
	int		iDoor_Spawn;
	int		iDoor_Rescue;
	bool	bIsDamage_Rescue;
	Handle	hTimer[TIMER_LENGTH];
	int		iConfPos;
	
	//========= Misc check ==========//
	bool	bIsRound_End;
	bool	bIsRound_Finale;
	bool	bIsFindDoorInit;
	
	char sCurrentMap[PLATFORM_MAX_PATH];
	
	void Reset()
	{
		this.iDoor_Spawn 		= -1;
		this.iDoor_Rescue 		= -1;
		this.bIsRound_End 		= true;
		this.bIsRound_Finale 	= false;
		this.bIsFindDoorInit	= false;
		this.bIsDamage_Rescue	= false;
		
		this.fPos_Spawn		= view_as<float>({ 0.0, 0.0, 0.0 });
		this.fPos_Rescue		= view_as<float>({ 0.0, 0.0, 0.0 });

		for( int i = 0; i < TIMER_LENGTH; i++ )
		{
			delete this.hTimer[i];
		}
	}
}
EntityManager g_EMEntity;


//=== Map Vac Config ============//
enum 
{
	VEC_POS,
	VEC_MIN,
	VEC_MAX,
	VEC_LEN
}
char g_sMapConfig[][] = 
{
	"c2m1_highway",
	"c2m2_",
};
float g_fMapsVec[][][] = 
{
	{
		// c2m1_highway
		{ 10855.0, 7868.0, -557.0 },	// position
		{ -350.0, -250.0, 0.0 },		// VecMins
		{ 350.0, 250.0, 200.0 },		// VecMaxs
	},
};


////// Developer Touch Area Constructor //////
int		g_iMaterialLaser;
int		g_iMaterialHalo;
int		g_iMaterialBlood;
int		g_iEntityTest;
float	g_mvecMins[3] = { -50.0, -50.0, 0.0 };
float	g_mvecMaxs[3] = { 50.0, 50.0, 200.0 };
float	g_fPos[3];
float	g_fAng[3];
/////////////////////////////////////////////




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


//========= Plugin Start ========//
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
	g_ConVarSafeHazard_Radius				= CreateConVar( "hazard_checkpoint_radius",	"600",	"Player distance from checkpoint door consider near.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 300.0, true, 1000.0 );
	g_ConVarSafeHazard_DamageAlive			= CreateConVar( "hazard_damage_alive",		"1",	"Health we knock off player per hit if he alive.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 1.0, true, 100.0 );
	g_ConVarSafeHazard_DamageIncap			= CreateConVar( "hazard_damage_incap",		"10",	"Health we knock off player per hit if he incap.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 1.0, true, 100.0 );
	g_ConVarSafeHazard_LeaveSpawnMsg		= CreateConVar( "hazard_leave_message",		"1",	"0:Off  | 1:On, Announce spawn area damage message.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_EventDoor			= CreateConVar( "hazard_manual_safe",		"0",	"0:Off  | 1:On, Checkpoint door manually closed, all player force teleport inside.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_EventNumber			= CreateConVar( "hazard_manual_number",		"3",	"0:Off  | 1:On, Checkpoint door manually closed, this number of players inside checkpoint will force teleport all players", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 64.0 );
	g_ConVarSafeHazard_CmdDoor				= CreateConVar( "hazard_command_door",		"0",	"0:Open | 1:Closed, command 'srh_enter' will open/closed checkpoint door after force teleport all player.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_ReferanceToy			= CreateConVar( "hazard_saferoom_toy",		"1",	"0:Off, 1:On, If on, developer teleport reference visible inside safe room.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_CheckpoinCountdown	= CreateConVar( "hazard_warning",			"30",	"If player refuse to enter second area, do damage after this long(seconds).", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 60.0 );
	g_ConVarSafeHazard_ExitMsg				= CreateConVar( "hazard_exit_message",		"1",	"0:Off, 1:On, Display hint text everytime player enter/exit.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_IsDamageBot			= CreateConVar( "hazard_damage_bot",		"0",	"0:Off, 1:On, Apply damage to survivor bot.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_BloodColor			= CreateConVar( "hazard_blood_color",		"0,255,0",	"Damage blood color RGB separated by commas", FCVAR_SPONLY|FCVAR_NOTIFY );
	g_ConVarSafeHazard_IsDebugging			= CreateConVar( "hazard_debugging_enable",	"0",	"0:Off, 1:On, Toggle debugging.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	AutoExecConfig( true, "l4d2_saferoom_hazard" );

	
	HookEvent( "survivor_rescued",			Event_PlayerRescued );
	HookEvent( "player_spawn",				EVENT_PlayerSpawn );
	HookEvent( "round_end",					EVENT_RoundEnd );
	//HookEvent( "mission_lost",			EVENT_RoundEnd );
	HookEvent( "finale_start",				EVENT_Finale );
	HookEvent( "door_close",				EVENT_DoorClose );
	HookEvent( "player_death",				Event_PlayerDeath );
	HookEvent( "bot_player_replace",		Event_PlayerReplace );
	HookEvent( "player_bot_replace",		Event_PlayerReplace );
	HookEvent( "defibrillator_begin",		Event_Defibrillator );
	HookEvent( "defibrillator_used_fail",	Event_Defibrillator );
	HookEvent( "defibrillator_interrupted",	Event_Defibrillator );
	HookEvent( "defibrillator_used",		Event_Defibrillator );
	HookEvent( "finale_escape_start",		Event_FinaleStart );
	HookEvent( "finale_vehicle_ready",		Event_FinaleStart );
	

	//================= Admin and developer command =================//
	RegAdminCmd( "srh_enter",	Command_ForceEnter_CheckpointRoom, ADMFLAG_GENERIC );
	RegAdminCmd( "srh_jump",	Command_ForceEnter_JumpSaferoom, ADMFLAG_GENERIC );
	RegAdminCmd( "srh_check",	Command_DeveloperCheck, ADMFLAG_GENERIC );
	RegAdminCmd( "srh_box",		Command_DeveloperBoundingBox, ADMFLAG_GENERIC );
	

	//=================== Checkpoint room trigger ===================//
	HookEntityOutput( "info_changelevel",		"OnStartTouch",		EntityOutput_OnStartTouch_RescueArea );
	HookEntityOutput( "info_changelevel",		"OnEndTouch",		EntityOutput_OnEndTouch_RescueArea );
	HookEntityOutput( "trigger_changelevel",	"OnStartTouch",		EntityOutput_OnStartTouch_RescueArea );
	HookEntityOutput( "trigger_changelevel",	"OnEndTouch",		EntityOutput_OnEndTouch_RescueArea );

	
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
	g_iCvar_BloodColor[3] = 100;
}

public Action Command_ForceEnter_CheckpointRoom( int client, int args )
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
	
	if ( g_bCvar_DoorWinState )
	{
		AcceptEntityInput( g_EMEntity.iDoor_Rescue, "Close" );
	}
	else
	{
		AcceptEntityInput( g_EMEntity.iDoor_Rescue, "Open" );
	}
	
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && IsPlayerAlive( i ) && GetClientTeam( i ) == TEAM_SURVIVOR )
		{
			TeleportPlayer( i, g_EMEntity.fPos_Rescue, SND_TELEPORT );
		}
	}
	return Plugin_Handled;
}

public Action Command_ForceEnter_JumpSaferoom( int client, int args )
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
	/*
	char arg1[8];
	GetCmdArg( 1, arg1, sizeof( arg1 ));
	int type = StringToInt( arg1 );
	if( type == 0 )
	{
		if ( g_EMEntity.iDoor_Spawn != -1 )
		{
			g_CMClient[client].iStateRoom = ROOM_STATE_SPAWN;
			
			if( g_bCvar_NotifyExit )
			{
				PrintHintText( client, "%N Entering Spawn Saferoom!!", client );
			}
			TeleportPlayer( client, g_EMEntity.fPos_Spawn, SND_TELEPORT );
		}
		else
		{
			ReplyToCommand( client, "[SAFEROOM]: Spawn room referance not found!!" );
		}
	}
	else if( type == 1 )
	{
		if ( g_EMEntity.iDoor_Rescue != -1 )
		{
			g_CMClient[client].iStateRoom = ROOM_STATE_OUTDOOR;
			TeleportPlayer( client, g_EMEntity.fPos_Rescue, SND_TELEPORT );
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
				g_CMClient[i].iStateRoom = g_CMClient[client].iStateRoom;
				StopBurningSound( i );
				TeleportPlayer( i, pos, SND_TELEPORT );
			}
		}
	}
	else
	{
		ReplyToCommand( client, "\x01[SAFEROOM]: only \x04srh_jump 0 \x01or \x04srh_jump 1 \x01or \x04srh_jump 2\x01valid command" );
	}
	*/
	return Plugin_Handled;
}

public Action Command_DeveloperCheck( int client, int args )
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
	PrintToChat( client, "Classname: %s", nameClass );
	
	char m_ModelName[PLATFORM_MAX_PATH];
	GetEntPropString( entity, Prop_Data, "m_ModelName", m_ModelName, sizeof( m_ModelName ));
	PrintToChat( client, "ModelName: %s", m_ModelName );
	return Plugin_Handled;
}

public Action Command_DeveloperBoundingBox( int client, int args )
{
	if ( client < 1 )
	{
		ReplyToCommand( client, "[SAFEROOM]: Command only valid in game!!" );
		return Plugin_Handled;
	}
	
	if ( args < 1 )
	{
		if( g_iEntityTest == -1 || !IsValidEntity( g_iEntityTest ))
		{
			float eyePos[3];
			float eyeAng[3];
			GetClientEyePosition( client, eyePos );
			GetClientEyeAngles( client, eyeAng );
			
			float eyeBuf[3];
			if( TraceRay_GetEndpoint( eyePos, eyeAng, client, eyeBuf ))
			{
				g_iEntityTest = CreateTouchTrigger( g_sDummyModel[MDL_SENSOR1], eyeBuf, g_mvecMins , g_mvecMaxs );
				if( g_iEntityTest != -1 )
				{
					CreateTimer( 0.3, TimerBeam, EntIndexToEntRef( g_iEntityTest ), TIMER_REPEAT);
					ReplyToCommand( client, "\x01[SAFEROOM]: Bounding box created!!" );
				}
				else
				{
					ReplyToCommand( client, "\x01[SAFEROOM]: Bounding box failed!!" );
				}
			}
			return Plugin_Handled;
		}
		else
		{
			ReplyToCommand( client, "\x01[SAFEROOM]: \x04srh_box \x01to create bounding box" );
			ReplyToCommand( client, "\x01[SAFEROOM]: \x04srh_box 0 \x01box movement, number is movement type" );
		}
		return Plugin_Handled;
	}
	
	char arg1[8];
	GetCmdArg( 1, arg1, sizeof( arg1 ));
	int type = StringToInt( arg1 );
	
	GetCmdArg( 2, arg1, sizeof( arg1 ));
	float size = StringToFloat( arg1 );
	
	Get_EntityLocation( g_iEntityTest, g_fPos, g_fAng );
	
	AcceptEntityInput( g_iEntityTest, "Kill" );
	
	//====== thick ==========
	if( type == 0 )
	{
		g_mvecMins[0] -= size;
		g_mvecMaxs[0] += size;
	}
	else if( type == 1 )
	{
		g_mvecMins[0] += size;
		g_mvecMaxs[0] -= size;
	}
	//====== width =========
	else if( type == 2 )
	{
		g_mvecMins[1] -= size;
		g_mvecMaxs[1] += size;
	}
	else if( type == 3 )
	{
		g_mvecMins[1] += size;
		g_mvecMaxs[1] -= size;
	}
	//====== height =======
	else if( type == 4 )
	{
		g_mvecMaxs[2] += size;
	}
	else if( type == 5 )
	{
		g_mvecMaxs[2] -= size;
	}
	
	//=== rotate ==========
	else if( type == 6 )
	{
		g_fAng[1] += size;
	}
	else if( type == 7 )
	{
		g_fAng[1] -= size;
	}
	
	//=== position ========
	else if( type == 8 )
	{
		g_fPos[0] += size;
	}
	else if( type == 9 )
	{
		g_fPos[0] -= size;
	}
	else if( type == 10 )
	{
		g_fPos[1] += size;
	}
	else if( type == 11 )
	{
		g_fPos[1] -= size;
	}
	
	g_iEntityTest = CreateTouchTrigger( g_sDummyModel[MDL_SENSOR1], g_fPos, g_mvecMins , g_mvecMaxs );
	if( g_iEntityTest != -1 )
	{
		CreateTimer( 0.3, TimerBeam, EntIndexToEntRef( g_iEntityTest ), TIMER_REPEAT );
	}
	
	PrintToChat( client, "Current Map:  %s", g_EMEntity.sCurrentMap );
	PrintToChat( client, "Pos: %f | %f | %f", g_fPos[0], g_fPos[1], g_fPos[2] );
	PrintToChat( client, "Min: %f | %f | %f", g_mvecMins[0], g_mvecMins[1], g_mvecMins[2] );
	PrintToChat( client, "Max: %f | %f | %f", g_mvecMaxs[0], g_mvecMaxs[1], g_mvecMaxs[2] );
	PrintToChat( client, " \n" );
	return Plugin_Handled;
}

public void OnMapStart()
{
	g_EMEntity.Reset();
	
	for ( int i = 0; i < MDL_LENGTH; i++ )
	{
		PrecacheModel( g_sDummyModel[i] );
	}
	
	PrecacheSound( SND_TELEPORT, true );
	PrecacheSound( SND_BURNING, true );
	PrecacheSound( SND_WARNING, true );
	
	PrecacheParticle( PAT_FIRE );
	
	g_iMaterialLaser	= PrecacheModel( MAT_BEAM );
	g_iMaterialHalo		= PrecacheModel( MAT_HALO );
	g_iMaterialBlood	= PrecacheModel( MAT_BLOOD );
	
	g_EMEntity.iConfPos = -1;
	for( int i = 0; i < sizeof( g_sMapConfig ); i++ )
	{
		if( StrCmp( g_sMapConfig[i], g_EMEntity.sCurrentMap ))
		{
			g_EMEntity.iConfPos = i;
			break;
		}
	}
	
	GetCurrentMap( g_EMEntity.sCurrentMap, sizeof( g_EMEntity.sCurrentMap ));
}

public void OnClientPutInServer( int client )
{
	if ( client > 0 )
	{
		g_CMClient[client].Reset();
	}
}

public void OnClientDisconnect( int client )
{
	OnClientPutInServer( client );
}

public void EVENT_RoundEnd( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	g_EMEntity.Reset();
}

public void EVENT_Finale( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	g_EMEntity.bIsRound_Finale = true;
}

public void EVENT_DoorClose( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable || g_bCvar_EventDoorWin ) return;
	
	bool close	= event.GetBool( "checkpoint" );
	int	 client = GetClientOfUserId( event.GetInt( "userid" ));
	if ( close && Survivor_IsValid( client ))
	{
		// only human player closing area door from inside count
		if( !IsFakeClient( client ) && g_CMClient[client].iStateRoom == ROOM_STATE_RESCUE )
		{
			int count;
			for( int i = 1; i <= MaxClients; i++ )
			{
				if( Survivor_InGame( i ) && !IsFakeClient( i ) && g_CMClient[i].iStateRoom == ROOM_STATE_RESCUE )
				{
					count++;
				}
			}
			
			if( count >= g_iCvar_DoorNumber )
			{
				for( int i = 1; i <= MaxClients; i++ )
				{
					if( Survivor_InGame( i ) && g_CMClient[i].iStateRoom != ROOM_STATE_RESCUE )
					{
						TeleportPlayer( i, g_EMEntity.fPos_Rescue, SND_TELEPORT );
					}
				}
				
				Print_ServerText( "Event door closed all players teleported", g_bCvar_IsDebugging );
			}
		}
	}
}

public void Event_PlayerRescued( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	int client = GetClientOfUserId( event.GetInt( "victim" ));
	if ( Survivor_IsValid( client ))
	{
		// closet rescue, set player position outdoor
		g_CMClient[client].iSpawnCount	= -1;
		g_CMClient[client].iStateRoom	= ROOM_STATE_OUTDOOR;
		
		if( !IsFakeClient( client ))
		{
			Print_RespawnMessage( client );
		}
		Print_ServerText( "Survivor Rescue", g_bCvar_IsDebugging );
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

public void Event_PlayerReplace( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	int player 	= GetClientOfUserId( event.GetInt( "player" ));
	int bot 	= GetClientOfUserId( event.GetInt( "bot" ));
	if ( Client_IsValid( player ) && Client_IsValid( bot ))
	{
		// player takeover bot
		if( StrCmp( name, "bot_player_replace" ))
		{
			g_CMClient[player].iStateRoom = g_CMClient[bot].iStateRoom;
			g_CMClient[player].iSpawnCount = g_CMClient[bot].iSpawnCount;
			
			Print_RespawnMessage( player );
			
			Print_ServerText( "Player takeover Bot", g_bCvar_IsDebugging );
		}
		// bot takeover player
		else if( StrCmp( name, "player_bot_replace" ))
		{
			g_CMClient[bot].iStateRoom	= g_CMClient[player].iStateRoom;
			g_CMClient[bot].iSpawnCount = g_CMClient[player].iSpawnCount;
			StopBurningSound( player );
			Print_ServerText( "Bot takeover Player", g_bCvar_IsDebugging );
		}
	}
}

public void Event_Defibrillator( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	int subject	= GetClientOfUserId( event.GetInt( "subject" ));
	if ( Client_IsValid( subject ))
	{
		if( StrCmp( name, "defibrillator_begin" ))
		{
			g_CMClient[subject].bIsUseDefib = true;
			Print_ServerText( "Defibrillator Begin", g_bCvar_IsDebugging );
		}
		else if( StrCmp( name, "defibrillator_used_fail" ) || StrCmp( name, "defibrillator_interrupted" ))
		{
			g_CMClient[subject].bIsUseDefib = false;
			Print_ServerText( "Defibrillator Fail/Interrupted", g_bCvar_IsDebugging );
		}
		else if( StrCmp( name, "defibrillator_used" ))
		{
			g_CMClient[subject].bIsUseDefib = false;
			if( !IsFakeClient( subject ))
			{
				Print_RespawnMessage( subject );
			}
			Print_ServerText( "Defibrillator Used", g_bCvar_IsDebugging );
		}
	}
}



// finale damage under development
public void Event_FinaleStart( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	bool finale = false;
	if( StrCmp( name, "finale_escape_start" ))
	{
		finale = true;
		Print_ServerText( "finale_escape_start", g_bCvar_IsDebugging );
	}
	else if( StrCmp( name, "finale_vehicle_ready" ))
	{
		finale = true;
		Print_ServerText( "finale_vehicle_ready", g_bCvar_IsDebugging );
	}
	
	if( finale )
	{
		// trigger_multiple
		// stadium_exit_right_escape_trigger
		// escape_right_relay
		
		int entity = -1;
		while (( entity = FindEntityByClassname( entity, "trigger_multiple")) != -1 )
		{
			if( IsValidEntity( entity ))
			{
				char entity_name[250];
				GetEntPropString( entity, Prop_Data, "m_iName", entity_name, sizeof( entity_name ));
				PrintToChatAll( "className: %s", entity_name );
				if( StrCmp( entity_name, "stadium_exit_right_escape_trigger" ) || StrCmp( entity_name, "escape_right_relay" ))
				{
					PrintToChatAll( "Trigger: %s", entity_name );
					
					SDKHook( entity, SDKHook_StartTouch, OnEscapeTriggerTouched );
					SDKHook( entity, SDKHook_EndTouch, OnEscapeTriggerEndTouch );
				}
			}
		}
	}
}

public Action OnEscapeTriggerTouched( int entity, int client )
{
	if( !Survivor_IsValid( client )) return Plugin_Continue;
	
	PrintToChatAll( "OnEscapeTrigger_Touched" );
	return Plugin_Continue;
}

public Action OnEscapeTriggerEndTouch( int entity, int client )
{
	if( !Survivor_IsValid( client )) return Plugin_Continue;
	
	PrintToChatAll( "OnEscapeTrigger_EndTouch" );
	return Plugin_Continue;
}

public void EVENT_PlayerSpawn( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	int userid = event.GetInt( "userid" );
	int client = GetClientOfUserId( userid );
	if ( client > 0 && client <= MaxClients && IsClientInGame( client ))
	{
		if( !IsFakeClient( client ))
		{
			Print_ServerText( "Player Spawn", g_bCvar_IsDebugging );
		}
		
		if( g_CMClient[client].bIsUseDefib ) return;
		
		switch( GetClientTeam( client ))
		{
			case TEAM_SURVIVOR:
			{
				// create spawn area door sensor and teleport referance
				// dont create ref area twice
				if( !g_EMEntity.bIsFindDoorInit )
				{
					g_EMEntity.bIsFindDoorInit = true;
					
					Create_EntityRef( client );
					
					if( g_EMEntity.iConfPos != -1 )
					{
						float pos[3];
						float min[3];
						float max[3];
						
						pos = view_as<float>( g_fMapsVec[g_EMEntity.iConfPos][VEC_POS] );
						min = view_as<float>( g_fMapsVec[g_EMEntity.iConfPos][VEC_MIN] );
						max = view_as<float>( g_fMapsVec[g_EMEntity.iConfPos][VEC_MAX] );
						
						int sensor = CreateTouchTrigger( g_sDummyModel[MDL_SENSOR1], pos, min , max );
						if( sensor != -1 && g_bCvar_IsDebugging )
						{
							CreateTimer( 0.3, TimerBeam, EntIndexToEntRef( sensor ), TIMER_REPEAT);
						}
					}
				}
				
				// set player spawn room max stay count.
				g_CMClient[client].iSpawnCount = g_iCvar_Notify_Total;
				
				// set player state inside spawn area.
				g_CMClient[client].iStateRoom = ROOM_STATE_SPAWN;
			}
			case TEAM_INFECTED:
			{
				if( g_bCvar_IsDebugging )
				{
					CreateTimer( 1.0, Timer_ForceInfectedSuicide, userid, TIMER_FLAG_NO_MAPCHANGE );
				}
			}
		}
	}
}



//=================== Rescue Arae Damage ===================// @Mart
public void EntityOutput_OnStartTouch_RescueArea( const char[] output, int caller, int activator, float time )
{
	if( !Survivor_IsValid( activator )) return;
	
	float pos[3];
	GetEntPropVector( activator, Prop_Send, "m_vecOrigin", pos );
	if( GetVectorDistance( pos, g_EMEntity.fPos_Rescue ) > 200.0 )
	{
		// false alarm, mid map mission area
		if( g_bCvar_NotifyExit ) PrintHintText( activator, "%N Entering Mission Area", activator );
	}
	else
	{
		StopBurningSound( activator );
		g_CMClient[activator].iStateRoom = ROOM_STATE_RESCUE;
		
		if( g_bCvar_NotifyExit ) PrintHintText( activator, "%N Entering Checkpoint Area", activator );
		
		if( !g_EMEntity.bIsDamage_Rescue && g_EMEntity.hTimer[TIMER_RESCUE] == null )
		{
			bool start = true;
			for( int i = 1; i <= MaxClients; i++ )
			{
				if( Survivor_InGame( i ))
				{
					GetEntPropVector( i, Prop_Send, "m_vecOrigin", pos );
					if( GetVectorDistance( pos, g_EMEntity.fPos_Rescue ) > g_fCvar_Radius )
					{
						start = false;
						break;
					}
				}
			}
			
			if( start )
			{
				g_EMEntity.hTimer[TIMER_RESCUE] = CreateTimer( g_fCvar_CheckpoinCountdown, Timer_RescueCountdown, _, TIMER_FLAG_NO_MAPCHANGE );
				if( g_bCvar_LeaveSpawnMsg )
				{
					for( int i = 1; i <= MaxClients; i ++ )
					{
						if( Survivor_InGame( i ) && !IsFakeClient( i ))
						{
							PrintToChat( i, "\x05[\x04WARNING\x05]: \x01You have \x04%0.0f sec(s) \x01to enter Checkpoint Area!!", g_fCvar_CheckpoinCountdown );
						}
					}
				}
			}
		}
	}
}

public void EntityOutput_OnEndTouch_RescueArea( const char[] output, int caller, int activator, float time )
{
	if( !Survivor_IsValid( activator )) return;
	
	float pos[3];
	GetEntPropVector( activator, Prop_Send, "m_vecOrigin", pos );
	if( GetVectorDistance( pos, g_EMEntity.fPos_Rescue ) > ( DIST_REFERENCE + 50.0 ))
	{
		// false alarm, mid map mission area
		if( g_bCvar_NotifyExit ) PrintHintText( activator, "%N Exiting Mission Area", activator );	
	}
	else
	{
		g_CMClient[activator].iStateRoom = ROOM_STATE_OUTDOOR;
		if( g_bCvar_NotifyExit ) PrintHintText( activator, "%N Left Checkpoint Area", activator );
	}
}

//=================== Spawn Area Damage ===================//
public void EntityOutput_OnStartTouch_SpawnArea( const char[] output, int caller, int activator, float delay )
{
	if( !Survivor_IsValid( activator )) return;
	
	g_CMClient[activator].iStateRoom = ROOM_STATE_SPAWN;
	
	if( g_bCvar_NotifyExit ) PrintHintText( activator, "%N Entering Spawn Area", activator );
}

public void EntityOutput_OnEndTouch_SpawnArea( const char[] output, int caller, int activator, float delay )
{
	if( !Survivor_IsValid( activator )) return;
	
	StopBurningSound( activator );
	
	g_CMClient[activator].iStateRoom = ROOM_STATE_OUTDOOR;
	
	if( g_bCvar_NotifyExit ) PrintHintText( activator, "%N Left Spawn Area", activator );
	
	// first player left spawn area and are not finale, start spawn rea damage timer
	if( g_EMEntity.hTimer[TIMER_GLOBAL] == null && !g_EMEntity.bIsRound_Finale )
	{
		g_EMEntity.bIsRound_End = false;
		
		g_EMEntity.hTimer[TIMER_GLOBAL] = CreateTimer( 1.0, Timer_GlobalDamage, _, TIMER_REPEAT );
		
		Print_ServerText( "Timer Damage has started", g_bCvar_IsDebugging );
	}
}

public Action Timer_RescueCountdown( Handle timer )
{
	for( int i = 1; i <= MaxClients; i ++ )
	{
		if( Survivor_InGame( i ) && !IsFakeClient( i ))
		{
			PrintToChat( i, "\x05[\x04WARNING\x05]: \x01Checkpoint Area damage has started!!" );
			EmitSoundToClient( i, SND_WARNING );
		}
	}
	
	g_EMEntity.bIsDamage_Rescue		= true;
	g_EMEntity.hTimer[TIMER_RESCUE]	= null;
	return Plugin_Stop;
}

public Action Timer_GlobalDamage( Handle timer )
{
	if( g_EMEntity.hTimer[TIMER_GLOBAL] != timer )
	{
		Print_ServerText( "Timer damage lost track and terminated", true );
		
		return Plugin_Stop;
	}
	
	if( g_EMEntity.bIsRound_Finale || g_EMEntity.bIsRound_End )
	{
		g_EMEntity.hTimer[TIMER_GLOBAL] = null;
		Print_ServerText( "Timer damage terminated for finale/round end", g_bCvar_IsDebugging );
		
		return Plugin_Stop;
	}
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame( i ) && GetClientTeam( i ) == TEAM_SURVIVOR )
		{
			// is damage shifted to rescue area?
			if( g_EMEntity.bIsDamage_Rescue )
			{	
				// checkpoint area damage
				if( g_CMClient[i].iStateRoom != ROOM_STATE_RESCUE )
				{
					// survivor has no attacker, continue damag.
					if( !Survivor_IsPinned( i ))
					{
						if( IsFakeClient( i ) && !g_bCvar_DamageBot ) continue;
						
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
				// spawn area damage
				g_CMClient[i].iSpawnCount -= 1;
				if( g_CMClient[i].iSpawnCount < -1 )
				{
					g_CMClient[i].iSpawnCount = -1;
				}
				
				if( IsFakeClient( i ) && !g_bCvar_DamageBot ) continue;
				
				if( g_bCvar_LeaveSpawnMsg && !IsFakeClient( i ) && IsPlayerAlive( i ))
				{
					if( g_CMClient[i].iSpawnCount == (g_iCvar_Notify_Total - 1))
					{
						PrintToChat( i, "\x05[\x04WARNING\x05]: \x01You have \x04%0.0f sec(s) \x01to leave Spawn Area!!", float( g_iCvar_Notify_Total ));
					}
					else if( g_CMClient[i].iSpawnCount == g_iCvar_NotifySpawn2 )
					{
						if( g_CMClient[i].iStateRoom == ROOM_STATE_SPAWN )
						{
							PrintToChat( i, "\x05[\x04WARNING\x05]: \x01You have \x04%0.0f sec(s) \x01to leave Spawn Area!!", float( g_iCvar_NotifySpawn2 ));
						}
						else
						{
							PrintToChat( i, "\x05[\x04WARNING\x05]: \x01Spawn Saferoom Hazard in \x04%0.0f \x01sec(s)", float( g_iCvar_NotifySpawn2 ));
						}
					}
					else if( g_CMClient[i].iSpawnCount == 0 )
					{
						if( g_CMClient[i].iStateRoom == ROOM_STATE_SPAWN )
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
				
				if( g_CMClient[i].iSpawnCount < 0 )
				{
					if( g_CMClient[i].iStateRoom == ROOM_STATE_SPAWN )
					{
						// survivor has attacker, stop damage.
						if( Survivor_IsPinned( i )) continue;
						
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
	return Plugin_Continue;
}

public Action Timer_ForceInfectedSuicide( Handle timer, any userid )
{
	int client = GetClientOfUserId( userid );
	if ( Infected_IsValid( client ))
	{
		ForcePlayerSuicide( client );
		PrintToServer( "[SAFEROOM]: Player %N Commited Suicide", client );
	}
	return Plugin_Stop;
}



//====================== Function =========================//
void Create_EntityRef( int client )
{
	//===== dont search area door twice =====//
	if( g_EMEntity.bIsFindDoorInit ) { return; }
	
	g_EMEntity.bIsFindDoorInit = true;
	
	//===== find and register area door =====//
	Get_SaferoomDoor( client );
	

	//======== create spawn door sensor ========//
	if( g_EMEntity.iDoor_Spawn != -1 )
	{
		char m_ModelName[PLATFORM_MAX_PATH];
		GetEntPropString( g_EMEntity.iDoor_Spawn, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
		
		// spawn door offset setting
		int type = 0;
		if( strcmp( m_ModelName, MDL_SPAWNROOM1, false ) == 0 )
		{
			type = 1;
		}
		
		// create spawn area door sensor first layer
		float pos[3];
		float ang[3];
		Get_EntityLocation( g_EMEntity.iDoor_Spawn, pos, ang );
		
		// create teleport position
		g_EMEntity.fPos_Spawn = view_as<float>(pos);
		
		g_EMEntity.fPos_Spawn[2] += DIST_DUMMYHEIGHT;
		
		if( type == 0 )
		{
			g_EMEntity.fPos_Spawn[0] += DIST_REFERENCE * Cosine( DegToRad( ang[1] ));
			g_EMEntity.fPos_Spawn[1] += DIST_REFERENCE * Sine( DegToRad( ang[1] ));
		}
		else if( type == 1 )
		{
			g_EMEntity.fPos_Spawn[0] -= DIST_REFERENCE * Cosine( DegToRad( ang[1] ));
			g_EMEntity.fPos_Spawn[1] -= DIST_REFERENCE * Sine( DegToRad( ang[1] ));
		}
		
		// create toy referance
		if( g_bCvar_ReferanceToy )
		{
			int rand = GetRandomInt( 0, 2 );
			Create_Reference( g_sDummyModel[rand], g_EMEntity.fPos_Spawn, ang );
		}
	}
	
	
	//===== create checkpoint door referance =====//
	if( g_EMEntity.iDoor_Rescue != -1 )
	{
		char m_ModelName[PLATFORM_MAX_PATH];
		GetEntPropString( g_EMEntity.iDoor_Rescue, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
		
		// create teleport position
		float ang[3];
		Get_EntityLocation( g_EMEntity.iDoor_Rescue, g_EMEntity.fPos_Rescue, ang );
		g_EMEntity.fPos_Rescue[2] += DIST_DUMMYHEIGHT;
		
		int position = LoadDoorConfig( g_sCheckpointMapName, sizeof( g_sCheckpointMapName ), g_EMEntity.sCurrentMap );
		if( position != -1 )
		{
			ang[1] += g_fCheckpointMapRotation[position];
		}
		else
		{
			ang[1] += 90.0;
		}
		
		g_EMEntity.fPos_Rescue[0] += DIST_REFERENCE * Cosine( DegToRad( ang[1] ));
		g_EMEntity.fPos_Rescue[1] += DIST_REFERENCE * Sine( DegToRad( ang[1] ));
		
		// create toy referance
		if( g_bCvar_ReferanceToy )
		{
			int rand = GetRandomInt( 0, 2 );
			Create_Reference( g_sDummyModel[rand], g_EMEntity.fPos_Rescue, ang );
		}
	}
}

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
			if( g_EMEntity.iDoor_Spawn == -1 )
			{
				char m_ModelName[PLATFORM_MAX_PATH];
				GetEntPropString( entity, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
				if( strcmp( m_ModelName, MDL_SPAWNROOM1, false ) == 0 || strcmp( m_ModelName, MDL_SPAWNROOM2, false ) == 0 )
				{
					g_EMEntity.iDoor_Spawn = entity;
					Print_ServerText( "Spawn Door found", g_bCvar_IsDebugging );
				}
			}
		}
		else
		{
			if( g_EMEntity.iDoor_Rescue == -1 )
			{
				char m_ModelName[PLATFORM_MAX_PATH];
				GetEntPropString( entity, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
				if( strcmp( m_ModelName, MDL_CHECKROOM1, false ) == 0 || strcmp( m_ModelName, MDL_CHECKROOM2, false ) == 0 )
				{
					g_EMEntity.iDoor_Rescue = entity;
					AcceptEntityInput( entity, "close" );
					Print_ServerText( "Checkpoint Door found", g_bCvar_IsDebugging );
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

int Create_Reference( const char[] model, float pos[3], float ang[3] )
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

void Create_DamageEffect( int victim, int attacker, int damage )
{
	Create_PointHurt( victim, attacker, damage, DMG_GENERIC, "" );
	Create_BloodEffect( victim, g_iMaterialBlood, g_iCvar_BloodColor );
	Create_ScreenParticle( victim, PAT_FIRE );

	if( !IsFakeClient( victim ))
	{
		if( !g_CMClient[victim].bIsPlaySound )
		{
			g_CMClient[victim].bIsPlaySound = true;
			EmitSoundToClient( victim, SND_BURNING );
		}
	}
}

// Because I love you.
void Create_PointHurt( int victim, int attacker, int damage, int dmg_type, const char[] weapon )
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

void Create_BloodEffect( int client, int sprite, int color[4] )
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

void Create_ScreenParticle( int client, char[] particleType )	// @Silver [L4D2] Hud Splatter
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

int PrecacheParticle( const char[] sEffectName )				// @Silver [L4D2] Hud Splatter
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
	if( g_CMClient[client].bIsPlaySound )
	{
		StopSound( client, SNDCHAN_AUTO, SND_BURNING );
		g_CMClient[client].bIsPlaySound = false;
	}
}

int LoadDoorConfig( const char[][] settingname, int length, const char[] mapname )
{
	for( int i = 0; i < length; i++ )
	{
		if( strcmp( settingname[i], mapname, false ) == 0 )
		{
			return i;
		}
	}
	return -1;
}

void Print_RespawnMessage( int client )
{
	if( g_EMEntity.hTimer[TIMER_RESCUE] != null && !g_EMEntity.bIsDamage_Rescue )
	{
		PrintToChat( client, "\x05[\x04WARNING\x05]: \x01Rescue Saferoom timer has started!!" );
	}
	else if( g_EMEntity.bIsDamage_Rescue )
	{
		PrintToChat( client, "\x05[\x04WARNING\x05]: \x01Rescue Saferoom Hazard has started!!" );
	}
	else if( g_CMClient[client].iSpawnCount <= 0 )
	{
		PrintToChat( client, "\x05[\x04WARNING\x05]: \x01Spawn Saferoom Hazard has started!!" );
	}
}



//======================== Stock ==========================//
bool Client_IsValid( int client )
{
	return ( client > 0 && client <= MaxClients && IsClientInGame( client ));
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

bool Infected_IsValid( int client )
{
	return ( client > 0 && client <= MaxClients && IsClientInGame( client ) && GetClientTeam( client ) == TEAM_INFECTED );
}

void Print_ServerText( const char[] text, bool print )
{
	if( !print ) return;
	
	char gauge_none[2]  = "";
	char gauge_tags[16] = "[SAFEROOM]:";
	char gauge_char[99] = "===========================================================================";
	char gauge_side[64];
	FormatEx( gauge_side, sizeof( gauge_side ), "" );
	
	float len_char = float( strlen( gauge_char ));
	float len_text = float( strlen( text ));
	float len_tags = float( strlen( gauge_tags ));
	float len_diff = (( len_char - len_text - len_tags ) / 2.0 ) - 1.0;
	
	for( int i = 0; i < RoundToFloor(len_diff); i++ )
	{
		gauge_side[i] = gauge_char[0];
	}
	
	char gauge_buff[99];
	Format( gauge_buff, sizeof( gauge_buff ), "%s %s %s %s", gauge_side, gauge_tags, text, gauge_side );
	int len1 = strlen( gauge_buff );
	int len2 = RoundToFloor( len_char );
	if( len1 > len2 )
	{
		for( int i = len2; i < sizeof( gauge_char ); i++ )
		{
			gauge_buff[i] = gauge_none[0];
		}
	}
	
	//PrintToServer( "===========================================================================" );
	//PrintToServer( "=========== [SAFEROOM]: Timer damage terminated for finale ================" );
	//PrintToServer( "===========================================================================" );
	
	PrintToServer( " " );
	PrintToServer( "%s", gauge_char );
	PrintToServer( "%s", gauge_buff );
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

int CreateTouchTrigger( const char[] model, float pos[3], float m_vecMins[3], float m_vecMaxs[3] )
{
	int sensor = CreateEntityByName( "trigger_multiple" );
	if( sensor == -1 ) return sensor;
	
	SetEntityModel( sensor, model );
	DispatchKeyValue( sensor, "spawnflags", "257" );
	DispatchKeyValue( sensor, "StartDisabled", "0" );
	DispatchKeyValueVector( sensor, "origin", pos );
	//DispatchKeyValueVector( sensor, "angles", ang );
	DispatchSpawn( sensor );
	
	SetEntPropVector( sensor, Prop_Send, "m_vecMins", m_vecMins );
	SetEntPropVector( sensor, Prop_Send, "m_vecMaxs", m_vecMaxs );
	SetEntProp( sensor, Prop_Send, "m_nSolidType", 2 );
	SetEntProp( sensor, Prop_Send, "m_fEffects", GetEntProp( sensor, Prop_Send, "m_fEffects") | 32 );

	HookSingleEntityOutput( sensor, "OnStartTouch", EntityOutput_OnStartTouch_SpawnArea );
	HookSingleEntityOutput( sensor, "OnEndTouch", EntityOutput_OnEndTouch_SpawnArea );
	return sensor;
}

bool StrCmp( const char[] str1, const char[] str2 )
{
	return ( strcmp( str1, str2, false ) == 0 );
}









//============= Unused Stock for Development =================//
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

stock void ToggleGlowEnable( int entity, int color[3], bool enable )
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

public Action TimerBeam( Handle timer, any entref )
{
	int entity = EntRefToEntIndex( entref );
	if( IsValidEntity( entity ))
	{
		float vMaxs[3], vMins[3], vPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
		GetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
		GetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);
		AddVectors(vPos, vMins, vMins);
		AddVectors(vPos, vMaxs, vMaxs);
		TE_SendBox(vMins, vMaxs);
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

void TE_SendBox( float vMins[3], float vMaxs[3] )
{
	float vPos1[3], vPos2[3], vPos3[3], vPos4[3], vPos5[3], vPos6[3];
	vPos1 = vMaxs;
	vPos1[0] = vMins[0];
	vPos2 = vMaxs;
	vPos2[1] = vMins[1];
	vPos3 = vMaxs;
	vPos3[2] = vMins[2];
	vPos4 = vMins;
	vPos4[0] = vMaxs[0];
	vPos5 = vMins;
	vPos5[1] = vMaxs[1];
	vPos6 = vMins;
	vPos6[2] = vMaxs[2];
	TE_SendBeam(vMaxs, vPos1);
	TE_SendBeam(vMaxs, vPos2);
	TE_SendBeam(vMaxs, vPos3);
	TE_SendBeam(vPos6, vPos1);
	TE_SendBeam(vPos6, vPos2);
	TE_SendBeam(vPos6, vMins);
	TE_SendBeam(vPos4, vMins);
	TE_SendBeam(vPos5, vMins);
	TE_SendBeam(vPos5, vPos1);
	TE_SendBeam(vPos5, vPos3);
	TE_SendBeam(vPos4, vPos3);
	TE_SendBeam(vPos4, vPos2);
}

void TE_SendBeam( const float vMins[3], const float vMaxs[3] )
{
	TE_SetupBeamPoints(vMins, vMaxs, g_iMaterialLaser, g_iMaterialHalo, 0, 0, 0.3 + 0.1, 1.0, 1.0, 1, 0.0, view_as<int>({ 0, 255, 0, 255 }), 0);
	TE_SendToAll();
}






