#define PLUGIN_VERSION "1.1.0"
/*
=================== TODO ==================
- radio use waiting teleport, damage.
- rescue vehicle ready teleport, damage.
- saferoom burning effect/particle by LUX@ChocolateCat


============= version history =============
v 1.1.0
- creadit:
	@GL_INS beta tester
	@Mart
	@Impact
	@Silver
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
#include <saferoom_config.sp>

//======== Global ConVar ========//
ConVar	g_ConVarSafeHazard_PluginEnable,	g_ConVarSafeHazard_NotifySpawn1,		g_ConVarSafeHazard_NotifySpawn2,	g_ConVarSafeHazard_Radius,		g_ConVarSafeHazard_DamageAlive,
		g_ConVarSafeHazard_DamageIncap,		g_ConVarSafeHazard_LeaveSpawnMsg,		g_ConVarSafeHazard_EventDoor,		g_ConVarSafeHazard_EventNumber,	g_ConVarSafeHazard_CmdDoor,
		g_ConVarSafeHazard_ReferanceToy,	g_ConVarSafeHazard_CheckpoinCountdown,	g_ConVarSafeHazard_ExitMsg, 		g_ConVarSafeHazard_IsDamageBot,	g_ConVarSafeHazard_BloodColor,
		g_ConVarSafeHazard_IsDebugging,		g_ConVarSafeHazard_DisableEnemy;


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
float	g_fCvar_DoorNumber;
bool	g_bCvar_DoorWinState;
bool	g_bCvar_ReferanceToy;
int		g_iCvar_ToyAlpha;
float	g_fCvar_CheckpoinCountdown;
bool	g_bCvar_NotifyExit;
bool	g_bCvar_DamageBot;
bool	g_bCvar_EnableEnemy;
int		g_iCvar_BloodColor[4];
bool	g_bCvar_IsDebugging;


//========= Plugin Start ========//
public Plugin myinfo = 
{
	name		= "Safe Room Hazard",
	author		= "GsiX",
	description	= "Prevent player from camp in the safe room",
	version		= PLUGIN_VERSION,
	url			= "https://forums.alliedmods.net/showthread.php?p=1836806#post1836806"	
}

public void OnPluginStart()
{
	CreateConVar( "hazard_version", PLUGIN_VERSION, " ", FCVAR_DONTRECORD);
	g_ConVarSafeHazard_PluginEnable			= CreateConVar( "hazard_plugin_enable",		"1",	"0:Off,  1:On,  Toggle plugin On/Off.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_NotifySpawn1			= CreateConVar( "hazard_notify_leave1",		"20",	"Timer first notify to player to leave safe room.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 1.0, true, 60.0 );
	g_ConVarSafeHazard_NotifySpawn2			= CreateConVar( "hazard_notify_leave2",		"10",	"Timer damage countdown after 'hazard_notify_leave1'", FCVAR_SPONLY|FCVAR_NOTIFY, true, 1.0, true, 60.0 );
	g_ConVarSafeHazard_Radius				= CreateConVar( "hazard_checkpoint_radius",	"600",	"Player distance from checkpoint door consider near.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 300.0, true, 1000.0 );
	g_ConVarSafeHazard_DamageAlive			= CreateConVar( "hazard_damage_alive",		"1",	"Health we knock off player per hit if he alive.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 1.0, true, 100.0 );
	g_ConVarSafeHazard_DamageIncap			= CreateConVar( "hazard_damage_incap",		"10",	"Health we knock off player per hit if he incap.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 1.0, true, 100.0 );
	g_ConVarSafeHazard_LeaveSpawnMsg		= CreateConVar( "hazard_leave_message",		"1",	"0:Off  | 1:On, Announce spawn area damage message.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_EventDoor			= CreateConVar( "hazard_manual_safe",		"0",	"0:Off  | 1:On, Checkpoint door manually closed, all player force teleport inside.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_EventNumber			= CreateConVar( "hazard_manual_number",		"0",	"0:Off  | Checkpoint door manually closed, this percentage of players inside checkpoint area will force teleport everyone", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 100.0 );
	g_ConVarSafeHazard_CmdDoor				= CreateConVar( "hazard_command_door",		"0",	"0:Open | 1:Closed, command 'srh_enter' will open/closed checkpoint door after force teleport all player.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_ReferanceToy			= CreateConVar( "hazard_saferoom_toy",		"1",	"0:Off, 1:On, If on, developer teleport reference visible inside safe room.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_CheckpoinCountdown	= CreateConVar( "hazard_warning",			"30",	"If player refuse to enter second area, do damage after this long(seconds).", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 60.0 );
	g_ConVarSafeHazard_ExitMsg				= CreateConVar( "hazard_exit_message",		"1",	"0:Off, 1:On, Display hint text everytime player enter/exit.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_IsDamageBot			= CreateConVar( "hazard_damage_bot",		"0",	"0:Off, 1:On, Apply damage to survivor bot.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_BloodColor			= CreateConVar( "hazard_blood_color",		"0,255,0",	"Damage blood color RGB separated by commas", FCVAR_SPONLY|FCVAR_NOTIFY );
	g_ConVarSafeHazard_IsDebugging			= CreateConVar( "hazard_debugging_enable",	"0",	"0:Off, 1:On, Toggle debugging on/off.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVarSafeHazard_DisableEnemy			= CreateConVar( "hazard_debugging_enemy",	"1",	"0:No enemy, 1:With enemy, Toggle enable enemy in debugging mode..", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	AutoExecConfig( true, "l4d2_saferoom_hazard" );

	
	HookEvent( "survivor_rescued",			EVENT_PlayerRescued );
	HookEvent( "player_spawn",				EVENT_PlayerSpawn );
	HookEvent( "round_end",					EVENT_RoundEnd );
	//HookEvent( "mission_lost",			EVENT_RoundEnd );
	HookEvent( "finale_start",				EVENT_Finale );
	HookEvent( "door_close",				EVENT_DoorClose );
	HookEvent( "player_death",				EVENT_PlayerDeath );
	HookEvent( "bot_player_replace",		EVENT_BotPlayerReplace );
	HookEvent( "player_bot_replace",		EVENT_BotPlayerReplace );
	HookEvent( "defibrillator_begin",		EVENT_Defibrillator );
	HookEvent( "defibrillator_used_fail",	EVENT_Defibrillator );
	HookEvent( "defibrillator_interrupted",	EVENT_Defibrillator );
	HookEvent( "defibrillator_used",		EVENT_Defibrillator );
	HookEvent( "finale_escape_start",		EVENT_FinaleStart );
	HookEvent( "finale_vehicle_ready",		EVENT_FinaleStart );
	

	//================= Admin and developer command =================//
	RegAdminCmd( "srh_enter",		Command_ForceEnter_CheckpointRoom,		ADMFLAG_GENERIC, "Admin jump command. Force everyone into checkpoint saferoom." );
	RegAdminCmd( "srh_jump",		Command_ForceEnter_JumpSaferoom,		ADMFLAG_GENERIC, "Admin jump command. 0: spawn | 1: checkpoint | 2: current position." );
	RegAdminCmd( "srh_box",			Command_DeveloperBoundingBox_Create,	ADMFLAG_GENERIC, "Admin command. Prototype trigger touch bounding box. Range 0 ~ 6" );
	RegAdminCmd( "srh_spawnsave",	Command_DeveloperBoundingBox_Save,		ADMFLAG_GENERIC, "Admin command. Save generated bounding box" );
	
	/*
		bind home			"say !srh_box 1 10"
		bind end			"say !srh_box 1 -10"
		
		bind pgup			"say !srh_box 2 10"
		bind pgdn 			"say !srh_box 2 -10"
		
		bind kp_home		"say !srh_box 3 10"
		bind kp_leftarrow	"say !srh_box 3 -10"
		
		bind kp_uparrow		"say !srh_box 4 10"
		bind kp_5			"say !srh_box 4 -10"
		
		bind kp_pgup		"say !srh_box 5 10"
		bind kp_rightarrow	"say !srh_box 5 -10"
		
		bind kp_end			"say !srh_box 6 15" 	//<< cant rotate trigger
		bind kp_pgdn		"say !srh_box 6 -15" 	//<< cant rotate trigger
		
		
		
		bind kp_home		"say !srh_box 3 10"
		bind kp_leftarrow	"say !srh_box 3 -10"
		
		bind kp_uparrow		"say !srh_box 4 10"
		bind kp_5			"say !srh_box 4 -10"
		
		bind kp_pgup		"say !srh_box 5 10"
		bind kp_rightarrow	"say !srh_box 5 -10"
		
		bind kp_end			"say !srh_box 6 15" 	//<< cant rotate trigger
		bind kp_pgdn		"say !srh_box 6 -15" 	//<< cant rotate trigger
	*/

	//=================== Checkpoint room trigger ===================//
	HookEntityOutput( "info_changelevel",		"OnStartTouch",		EntityOutput_RescueArea_OnStartTouch );
	HookEntityOutput( "info_changelevel",		"OnEndTouch",		EntityOutput_RescueArea_OnEndTouch );
	HookEntityOutput( "trigger_changelevel",	"OnStartTouch",		EntityOutput_RescueArea_OnStartTouch );
	HookEntityOutput( "trigger_changelevel",	"OnEndTouch",		EntityOutput_RescueArea_OnEndTouch );

	
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
	g_ConVarSafeHazard_DisableEnemy.AddChangeHook( ConVar_Changed );
	
	UpdateCvar();
}

public void OnMapStart()
{
	g_iEntityTest = -1;
	g_iEntityReff = -1;
	
	g_EMEntity.Reset();
	
	for ( int i = 0; i < MDL_LENGTH; i++ )
	{
		g_EMEntity.iIndexModel = PrecacheModel( g_sDummyModel[i] );
	}
	
	PrecacheSound( SND_TELEPORT, true );
	PrecacheSound( SND_BURNING, true );
	PrecacheSound( SND_WARNING, true );
	
	PrecacheParticle( PAT_FIRE );
	
	g_iMaterialLaser	= PrecacheModel( MAT_BEAM );
	g_iMaterialHalo		= PrecacheModel( MAT_HALO );
	g_iMaterialBlood	= PrecacheModel( MAT_BLOOD );
	
	GetCurrentMap( g_EMEntity.sCurrentMap, sizeof( g_EMEntity.sCurrentMap ));
	
	
	// get checkpoint door angle special rotation offsets
	char cpBuff[8];
	g_EMEntity.fCPRotate = -1.0;
	if( ReadConfig_Cpdoor( FILE_CPDOOR, g_EMEntity.sCurrentMap, cpBuff ))
	{
		g_EMEntity.fCPRotate = StringToFloat( cpBuff );
	}
	
	
	// get spawn area bounding box config
	char keyBuff[VEC_LEN][32];
	g_EMEntity.bIsCfgLoaded = ReadConfig_Spawn( FILE_SPAWN, g_EMEntity.sCurrentMap, keyBuff );
	if( g_EMEntity.bIsCfgLoaded )
	{
		char valBuff[3][32];
		ExplodeString( keyBuff[VEC_POS], ",", valBuff, sizeof( valBuff ), sizeof( valBuff[] ));
		ConvertStringToFloat( valBuff, sizeof( valBuff ), g_EMEntity.fBoxPos );
		
		ExplodeString( keyBuff[VEC_ANG], ",", valBuff, sizeof( valBuff ), sizeof( valBuff[] ));
		ConvertStringToFloat( valBuff, sizeof( valBuff ), g_EMEntity.fBoxAng );
		
		ExplodeString( keyBuff[VEC_MIN], ",", valBuff, sizeof( valBuff ), sizeof( valBuff[] ));
		ConvertStringToFloat( valBuff, sizeof( valBuff ), g_EMEntity.fBoxMin );
		
		ExplodeString( keyBuff[VEC_MAX], ",", valBuff, sizeof( valBuff ), sizeof( valBuff[] ));
		ConvertStringToFloat( valBuff, sizeof( valBuff ), g_EMEntity.fBoxMax );
	}
	
	char mapname[128];
	Format( mapname, sizeof( mapname ), "Map Start: %s", g_EMEntity.sCurrentMap );
	Print_ServerText( mapname, g_bCvar_IsDebugging );
}

public void OnMapEnd()
{
	g_EMEntity.TimerKill();
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

public void OnEntityCreated( int entity, const char[] classname )
{
	if( !g_bCvar_IsDebugging || g_bCvar_EnableEnemy ) return;
	
	if( IsValidEntity( entity ))
	{
		if( ChrCmp( classname, "infected" ) || ChrCmp( classname, "witch" ))
		{
			CreateTimer( 0.3, Timer_KillICommonWitch, EntIndexToEntRef( entity ), TIMER_FLAG_NO_MAPCHANGE );
		}
	}
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
	g_bCvar_ReferanceToy		= g_ConVarSafeHazard_ReferanceToy.BoolValue;
	g_fCvar_DoorNumber			= g_ConVarSafeHazard_EventNumber.FloatValue;
	g_bCvar_DoorWinState		= g_ConVarSafeHazard_CmdDoor.BoolValue;
	g_fCvar_CheckpoinCountdown	= g_ConVarSafeHazard_CheckpoinCountdown.FloatValue;
	g_bCvar_NotifyExit			= g_ConVarSafeHazard_ExitMsg.BoolValue;
	g_bCvar_DamageBot			= g_ConVarSafeHazard_IsDamageBot.BoolValue;
	g_bCvar_EnableEnemy			= g_ConVarSafeHazard_DisableEnemy.BoolValue;
	
	g_iCvar_Notify_Total = g_iCvar_NotifySpawn1 + g_iCvar_NotifySpawn2;
	
	if( g_bCvar_ReferanceToy )
	{
		g_iCvar_ToyAlpha = 255;
	}
	else
	{
		g_iCvar_ToyAlpha = 0;
	}
	

	char colorBuff[32];
	char colorName[8][3];
	g_ConVarSafeHazard_BloodColor.GetString( colorBuff, sizeof( colorBuff ));
	ExplodeString( colorBuff, ",", colorName, sizeof( colorName ), sizeof( colorName[] ));
	g_iCvar_BloodColor[0] = StringToInt( colorName[0] );
	g_iCvar_BloodColor[1] = StringToInt( colorName[1] );
	g_iCvar_BloodColor[2] = StringToInt( colorName[2] );
	g_iCvar_BloodColor[3] = 100;
	
	// toggle live entity debug and development
	if( g_bCvar_IsDebugging != g_ConVarSafeHazard_IsDebugging.BoolValue )
	{
		g_bCvar_IsDebugging = g_ConVarSafeHazard_IsDebugging.BoolValue;
		
		if( g_bCvar_IsDebugging )
		{
			if( g_EMEntity.iEntTrigger != -1 )
			{
				//ToggleGlowEnable( g_EMEntity.iEntTrigger, view_as<int>({ 000, 255, 000 }), true );
				delete g_EMEntity.hTimer[TIMER_LASER1];
				g_EMEntity.hTimer[TIMER_LASER1] = CreateTimer( 0.3, Timer_DeveloperShowBeam1, EntIndexToEntRef( g_EMEntity.iEntTrigger ), TIMER_REPEAT );
			}
			if( g_EMEntity.iDoor_Spawn > MaxClients )
			{
				ToggleGlowEnable( g_EMEntity.iDoor_Spawn, view_as<int>({ 000, 255, 000 }), true );
			}
			if( g_EMEntity.iDoor_Rescue > MaxClients )
			{
				ToggleGlowEnable( g_EMEntity.iDoor_Rescue, view_as<int>({ 000, 255, 000 }), true );
			}
			if( g_EMEntity.iRefs_Spawn > MaxClients )
			{
				ToggleGlowEnable( g_EMEntity.iRefs_Spawn, view_as<int>({ 000, 255, 000 }), true );
				SetEntityRenderColor( g_EMEntity.iRefs_Spawn, 255, 255, 255, 255 );
			}
			if( g_EMEntity.iRefs_Rescue > MaxClients )
			{
				ToggleGlowEnable( g_EMEntity.iRefs_Rescue, view_as<int>({ 000, 255, 000 }), true );
				SetEntityRenderColor( g_EMEntity.iRefs_Rescue, 255, 255, 255, 255 );
			}
		}
		else
		{
			delete g_EMEntity.hTimer[TIMER_LASER1];
			
			if( g_EMEntity.iDoor_Spawn > MaxClients )
			{
				ToggleGlowEnable( g_EMEntity.iDoor_Spawn, view_as<int>({ 0, 0, 0 }), false );
			}
			if( g_EMEntity.iDoor_Rescue > MaxClients )
			{
				ToggleGlowEnable( g_EMEntity.iDoor_Rescue, view_as<int>({ 0, 0, 0 }), false );
			}
			if( g_EMEntity.iRefs_Spawn > MaxClients )
			{
				ToggleGlowEnable( g_EMEntity.iRefs_Spawn, view_as<int>({ 000, 255, 000 }), false );
				SetEntityRenderColor( g_EMEntity.iRefs_Spawn, 255, 255, 255, g_iCvar_ToyAlpha );
			}
			if( g_EMEntity.iRefs_Rescue > MaxClients )
			{
				ToggleGlowEnable( g_EMEntity.iRefs_Rescue, view_as<int>({ 000, 255, 000 }), false );
				SetEntityRenderColor( g_EMEntity.iRefs_Rescue, 255, 255, 255, g_iCvar_ToyAlpha );
			}
		}
	}
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
		ReplyToCommand( client, "\x01[SAFEROOM]: usage \x04srh_jump 0 \x01for spawn area jump" );
		ReplyToCommand( client, "\x01[SAFEROOM]: usage \x04srh_jump 1 \x01for checkpoint area jump" );
		return Plugin_Handled;
	}
	
	char arg1[8];
	GetCmdArg( 1, arg1, sizeof( arg1 ));
	int type = StringToInt( arg1 );
	if( type == 0 )
	{
		if ( g_EMEntity.iRefs_Spawn != -1 )
		{
			float pos[3];
			pos = view_as<float>( g_EMEntity.fPos_Spawn );
			pos[2] += 15.0;
			
			TeleportPlayer( client, pos, SND_TELEPORT );
		}
		else
		{
			ReplyToCommand( client, "[SAFEROOM]: Invalid Spawn pos referance!!" );
		}
	}
	else if( type == 1 )
	{
		if ( g_EMEntity.iRefs_Rescue != -1 )
		{
			float pos[3];
			pos = view_as<float>( g_EMEntity.fPos_Rescue );
			pos[2] += 15.0;
			
			TeleportPlayer( client, pos, SND_TELEPORT );
		}
		else
		{
			ReplyToCommand( client, "[SAFEROOM]: Invalid Checkpoint pos referance!!" );
		}
	}
	else if( type == 2 )
	{
		float pos[3];
		GetEntPropVector( client, Prop_Send, "m_vecOrigin", pos );
		pos[2] += 10.0;
		
		for ( int i = 1; i <= MaxClients; i++ )
		{
			if ( i != client && IsClientInGame( i ) && IsPlayerAlive( i ) && GetClientTeam( i ) == TEAM_SURVIVOR )
			{
				StopBurningSound( i );
				TeleportPlayer( i, pos, SND_TELEPORT );
				g_CMClient[i].iStateRoom = g_CMClient[client].iStateRoom;
			}
		}
	}
	else
	{
		ReplyToCommand( client, "\x01[SAFEROOM]: only \x04srh_jump 0 \x01or \x04srh_jump 1 \x01or \x04srh_jump 2\x01valid command" );
	}
	return Plugin_Handled;
}

public Action Command_DeveloperBoundingBox_Create( int client, int args )
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
	
	if( g_iEntityTest == -1 || !IsValidEntity( g_iEntityTest ))
	{
		float eyePos[3];
		float eyeAng[3];
		GetClientEyePosition( client, eyePos );
		GetClientEyeAngles( client, eyeAng );
		
		if( TraceRay_GetEndpoint( eyePos, eyeAng, client, g_fVecPos ))
		{
			g_iEntityTest = Create_TouchTrigger( g_sDummyModel[MDL_SENSOR1], g_fVecPos, g_fVecMin , g_fVecMax );
			if( g_iEntityTest != -1 )
			{
				delete g_EMEntity.hTimer[TIMER_LASER2];
				g_EMEntity.hTimer[TIMER_LASER2] = CreateTimer( 0.3, Timer_DeveloperShowBeam2, EntIndexToEntRef( g_iEntityTest ), TIMER_REPEAT);
				
				int rand = GetRandomInt( 0, 2 );
				g_iEntityReff = Create_Reference( g_sDummyModel[rand], g_fVecPos, view_as<float>({ 0.0, 0.0, 0.0 }), 255, true );
				
				Print_BoundingBoxResult( client, g_EMEntity.sCurrentMap, g_fVecPos, g_fVecAng, g_fVecMin, g_fVecMax );
				
				ReplyToCommand( client, "\x01[SAFEROOM]: Bounding box created!!" );
			}
			else
			{
				ReplyToCommand( client, "\x01[SAFEROOM]: Bounding box failed!!" );
			}
		}
		return Plugin_Handled;
	}
	
	if ( args < 1 )
	{
		ReplyToCommand( client, "\x01[SAFEROOM]: \x04srh_box 0 100 \x01moving, arg1: move type | arg2: value/-value" );
		ReplyToCommand( client, "\x01[SAFEROOM]: \x04!srh_box 0 -100" );
		return Plugin_Handled;
	}
	
	char arg1[8];
	GetCmdArg( 1, arg1, sizeof( arg1 ));
	int move = StringToInt( arg1 );
	if( move < MOVE_DELETE || MOVE_DELETE > MOVE_ANGLE )
	{
		ReplyToCommand( client, "\x01[SAFEROOM]: \x04srh_box \x01arg1 out of range. Value 0 ~ 6" );
		return Plugin_Handled;
	}
	
	//====== reverse nojutsu ========//
	if( move == MOVE_DELETE )
	{
		delete g_EMEntity.hTimer[TIMER_LASER2];
		
		AcceptEntityInput( g_iEntityTest, "Kill" );
		AcceptEntityInput( g_iEntityReff, "Kill" );
		
		g_iEntityTest = -1;
		g_iEntityReff = -1;
		
		g_fVecMin = view_as<float>({ -100.0, -100.0, 0.0 });
		g_fVecMax = view_as<float>({ 100.0, 100.0, 200.0 });
		
		ReplyToCommand( client, "\x01[SAFEROOM]: \x01custom bounding box deleted." );
		return Plugin_Handled;
	}
	else
	{
		GetCmdArg( 2, arg1, sizeof( arg1 ));
		float size = StringToFloat( arg1 );
		
		Get_EntityLocation( g_iEntityTest, g_fVecPos, g_fVecAng );
		if( move < MOVE_ANGLE )
		{
			delete g_EMEntity.hTimer[TIMER_LASER2];
			AcceptEntityInput( g_iEntityTest, "kill" );
			AcceptEntityInput( g_iEntityReff, "kill" );
			
			//====== thick =========//
			if( move == MOVE_THICK )
			{
				g_fVecMin[0] -= size;
				g_fVecMax[0] += size;
			}
			//====== width =========//
			else if( move == MOVE_WIDTH )
			{
				g_fVecMin[1] -= size;
				g_fVecMax[1] += size;
			}
			//=== position ========//
			else if( move == MOVE_SIDE1 )
			{
				g_fVecPos[0] += size;
			}
			else if( move == MOVE_SIDE2 )
			{
				g_fVecPos[1] += size;
			}
			//====== height =======//
			else if( move == MOVE_HEIGHT )
			{
				g_fVecMax[2] += size;
			}
			
			g_iEntityTest = Create_TouchTrigger( g_sDummyModel[MDL_SENSOR1], g_fVecPos, g_fVecMin , g_fVecMax );
			if( g_iEntityTest != -1 )
			{
				g_EMEntity.hTimer[TIMER_LASER2] = CreateTimer( 0.3, Timer_DeveloperShowBeam2, EntIndexToEntRef( g_iEntityTest ), TIMER_REPEAT);
				
				int rand = GetRandomInt( 0, 2 );
				g_iEntityReff = Create_Reference( g_sDummyModel[rand], g_fVecPos, view_as<float>({ 0.0, 0.0, 0.0 }), 255, true );
			}
		}
		else
		{
			//=== rotate ==========//
			if( move == MOVE_ANGLE )
			{
				g_fVecAng[1] += size;
				TeleportEntity( g_iEntityTest, NULL_VECTOR, g_fVecAng, NULL_VECTOR );
				TeleportEntity( g_iEntityReff, NULL_VECTOR, g_fVecAng, NULL_VECTOR );
			}
		}
	}
	return Plugin_Handled;
}

void Print_BoundingBoxResult( int client, const char[] mapname, float pos[3], float ang[3], float min[3], float max[3] )
{
	PrintToChat( client, " " );
	PrintToChat( client, "{" );
	PrintToChat( client, "	// %s", mapname );
	PrintToChat( client, "	{ %.2f, %.2f, %.2f },", pos[0], pos[1], pos[2] );
	PrintToChat( client, "	{ %.2f, %.2f, %.2f },", ang[0], ang[1], ang[2] );
	PrintToChat( client, "	{ %.2f, %.2f, %.2f },", min[0], min[1], min[2] );
	PrintToChat( client, "	{ %.2f, %.2f, %.2f }",  max[0], max[1], max[2] );
	PrintToChat( client, "}," );
	PrintToChat( client, " " );
}

public Action Command_DeveloperBoundingBox_Save( int client, int args )
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
	
	if( g_iEntityTest == -1 || !IsValidEntity( g_iEntityTest ))
	{
		ReplyToCommand( client, "[SAFEROOM]: No Bounding Box to save!!" );
		return Plugin_Handled;
	}
	SaveConfig_Spawn( client, FILE_SPAWN, g_EMEntity.sCurrentMap, g_fVecPos, g_fVecAng, g_fVecMin, g_fVecMax );
	return Plugin_Handled;
}

public void EVENT_RoundEnd( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	OnMapEnd();
	
	g_EMEntity.Reset();
	
	Print_ServerText( "Round End!!", g_bCvar_IsDebugging );
}

public void EVENT_Finale( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	g_EMEntity.bIsRound_Finale = true;
}

public void EVENT_DoorClose( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable || g_bCvar_EventDoorWin || g_fCvar_DoorNumber == 0.0 ) return;
	
	bool close	= event.GetBool( "checkpoint" );
	int	 client = GetClientOfUserId( event.GetInt( "userid" ));
	if ( close && Survivor_IsValid( client ))
	{
		// only human player closing area door from inside count
		if( !IsFakeClient( client ) && g_CMClient[client].iStateRoom == ROOM_STATE_RESCUE )
		{
			float total, count;
			for( int i = 1; i <= MaxClients; i++ )
			{
				if( Survivor_InGame( i ) && !IsFakeClient( i ))
				{
					total += 1.0;
				}
			}
			
			for( int i = 1; i <= MaxClients; i++ )
			{
				if( Survivor_InGame( i ) && !IsFakeClient( i ) && g_CMClient[i].iStateRoom == ROOM_STATE_RESCUE )
				{
					count += 1.0;
				}
			}
			
			float perc = count / total * 100.0;
			if( perc >= g_fCvar_DoorNumber )
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

public void EVENT_PlayerRescued( Event event, const char[] name, bool dontBroadcast )
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

public void EVENT_PlayerDeath( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	int client = GetClientOfUserId( event.GetInt( "userid" ));
	if ( Survivor_IsValid( client ))
	{
		StopBurningSound( client );
	}
}

public void EVENT_BotPlayerReplace( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	int player 	= GetClientOfUserId( event.GetInt( "player" ));
	int bot 	= GetClientOfUserId( event.GetInt( "bot" ));
	if ( Client_IsValid( player ) && Client_IsValid( bot ))
	{
		// player takeover bot
		if( ChrCmp( name, "bot_player_replace" ))
		{
			g_CMClient[player].iStateRoom = g_CMClient[bot].iStateRoom;
			g_CMClient[player].iSpawnCount = g_CMClient[bot].iSpawnCount;
			
			Print_RespawnMessage( player );
			
			Print_ServerText( "Player takeover Bot", g_bCvar_IsDebugging );
		}
		// bot takeover player
		else if( ChrCmp( name, "player_bot_replace" ))
		{
			g_CMClient[bot].iStateRoom	= g_CMClient[player].iStateRoom;
			g_CMClient[bot].iSpawnCount = g_CMClient[player].iSpawnCount;
			StopBurningSound( player );
			Print_ServerText( "Bot takeover Player", g_bCvar_IsDebugging );
		}
	}
}

public void EVENT_Defibrillator( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	int subject	= GetClientOfUserId( event.GetInt( "subject" ));
	if ( Client_IsValid( subject ))
	{
		if( ChrCmp( name, "defibrillator_begin" ))
		{
			g_CMClient[subject].bIsUsingDefib = true;
			Print_ServerText( "Defibrillator Begin", g_bCvar_IsDebugging );
		}
		else if( ChrCmp( name, "defibrillator_used_fail" ) || ChrCmp( name, "defibrillator_interrupted" ))
		{
			g_CMClient[subject].bIsUsingDefib = false;
			Print_ServerText( "Defibrillator Fail/Interrupted", g_bCvar_IsDebugging );
		}
		else if( ChrCmp( name, "defibrillator_used" ))
		{
			g_CMClient[subject].bIsUsingDefib = false;
			if( !IsFakeClient( subject ))
			{
				Print_RespawnMessage( subject );
			}
			Print_ServerText( "Defibrillator Used", g_bCvar_IsDebugging );
		}
	}
}

public void EVENT_FinaleStart( Event event, const char[] name, bool dontBroadcast ) // finale damage under development
{
	if ( !g_bCvar_PluginEnable ) return;
	
	bool finale = false;
	if( ChrCmp( name, "finale_escape_start" ))
	{
		finale = true;
		Print_ServerText( "finale_escape_start", g_bCvar_IsDebugging );
	}
	else if( ChrCmp( name, "finale_vehicle_ready" ))
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
				//PrintToChatAll( "className: %s", entity_name );
				if( ChrCmp( entity_name, "stadium_exit_right_escape_trigger" ) || ChrCmp( entity_name, "escape_right_relay" ))
				{
					//PrintToChatAll( "Trigger: %s", entity_name );
					
					SDKHook( entity, SDKHook_StartTouch, FinaleArea_OnStartTouch );
					SDKHook( entity, SDKHook_EndTouch, FinaleArea_OnEndTouch );
				}
			}
		}
	}
}

public void EVENT_PlayerSpawn( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_PluginEnable ) return;
	
	int userid = event.GetInt( "userid" );
	int client = GetClientOfUserId( userid );
	if ( client > 0 && client <= MaxClients && IsClientInGame( client ))
	{
		switch( GetClientTeam( client ))
		{
			case TEAM_SURVIVOR:
			{
				if( g_CMClient[client].bIsUsingDefib ) return;
				
				if( !IsFakeClient( client ))
				{
					Print_ServerText( "Player Spawn", g_bCvar_IsDebugging );
				}
				
				// create spawn area trigger and teleport referance
				Create_MapTouchTrigger( client );
				
				// set player spawn room max stay count.
				g_CMClient[client].iSpawnCount = g_iCvar_Notify_Total;
			}
			case TEAM_INFECTED:
			{
				if( g_bCvar_IsDebugging && !g_bCvar_EnableEnemy )
				{
					CreateTimer( 0.1, Timer_KillIInfectedTank, userid, TIMER_FLAG_NO_MAPCHANGE );
				}
			}
		}
	}
}


/////////////////////////////////////////////////////////////
//================ Finale Vehicle Trigger =================//
/////////////////////////////////////////////////////////////
public Action FinaleArea_OnStartTouch( int entity, int client )
{
	if( !Survivor_IsValid( client )) return Plugin_Continue;
	
	//PrintToChatAll( "OnEscapeTrigger_Touched" );
	return Plugin_Continue;
}

public Action FinaleArea_OnEndTouch( int entity, int client )
{
	if( !Survivor_IsValid( client )) return Plugin_Continue;
	
	//PrintToChatAll( "OnEscapeTrigger_EndTouch" );
	return Plugin_Continue;
}


/////////////////////////////////////////////////////////////
//================== Rescue Area Trigger ==================// @Mart
/////////////////////////////////////////////////////////////
public void EntityOutput_RescueArea_OnStartTouch( const char[] output, int caller, int client, float time )
{
	if( !Survivor_IsValid( client )) return;
	
	float pos[3];
	GetEntPropVector( client, Prop_Send, "m_vecOrigin", pos );
	if( GetVectorDistance( pos, g_EMEntity.fPos_Rescue ) < DIST_RADIUS )
	{
		// set client no longer joined in midgame and damage applied
		SetClientJoinStatus( client );
		
		StopBurningSound( client );
		g_CMClient[client].iStateRoom = ROOM_STATE_RESCUE;
		
		if( g_bCvar_NotifyExit ) PrintHintText( client, "%N Entering Checkpoint Area", client );
		
		CheckRescueArea();
	}
}

public void EntityOutput_RescueArea_OnEndTouch( const char[] output, int caller, int client, float time )
{
	if( !Survivor_IsValid( client )) return;
	
	float pos[3];
	GetEntPropVector( client, Prop_Send, "m_vecOrigin", pos );
	if( GetVectorDistance( pos, g_EMEntity.fPos_Rescue ) < DIST_RADIUS )
	{
		// set client no longer joined in midgame and damage applied
		SetClientJoinStatus( client );
		
		g_CMClient[client].iStateRoom = ROOM_STATE_OUTDOOR;
		if( g_bCvar_NotifyExit ) PrintHintText( client, "%N Left Checkpoint Area", client );
		
		CheckRescueArea();
	}
}


/////////////////////////////////////////////////////////////
//=================== Spawn Area Trigger ==================//
/////////////////////////////////////////////////////////////
public Action SpawnArea_OnStartTouched( int entity, int client )
{
	if( !Survivor_IsValid( client )) return Plugin_Continue;
	
	if( entity == g_iEntityTest )
	{
		PrintHintText( client, "%N Entering Constructor Area", client );
	}
	else
	{
		float pos[3];
		GetEntPropVector( client, Prop_Send, "m_vecOrigin", pos );
		if( GetVectorDistance( pos, g_EMEntity.fPos_Spawn ) < DIST_RADIUS )
		{
			// set client no longer joined in midgame and damage applied
			SetClientJoinStatus( client );
			
			g_CMClient[client].iStateRoom = ROOM_STATE_SPAWN;
			if( g_bCvar_NotifyExit ) PrintHintText( client, "%N Entering Spawn Area", client );
		}
	}
	return Plugin_Continue;
}

public Action SpawnArea_OnEndTouch( int entity, int client )
{
	if( !Survivor_IsValid( client )) return Plugin_Continue;
	
	if( entity == g_iEntityTest )
	{
		PrintHintText( client, "%N Exiting Constructor Area", client );
	}
	else
	{
		float pos[3];
		GetEntPropVector( client, Prop_Send, "m_vecOrigin", pos );
		if( GetVectorDistance( pos, g_EMEntity.fPos_Spawn ) < DIST_RADIUS )
		{
			g_CMClient[client].iStateRoom = ROOM_STATE_OUTDOOR;
			
			// set client no longer joined in midgame and damage applied
			SetClientJoinStatus( client );
			
			if( g_bCvar_NotifyExit ) PrintHintText( client, "%N Left Spawn Area", client );
			
			// first player left spawn area and are not finale, start spawn rea damage timer
			if( client != g_iEntityTest && g_EMEntity.hTimer[TIMER_GLOBAL] == null && !g_EMEntity.bIsRound_Finale )
			{
				g_EMEntity.hTimer[TIMER_GLOBAL] = CreateTimer( 1.0, Timer_GlobalDamage, _, TIMER_REPEAT );
				
				Print_ServerText( "Timer Spawn Damage has started", g_bCvar_IsDebugging );
			}
		}
	}
	return Plugin_Continue;
}


/////////////////////////////////////////////////////////////
//========================= Timers ========================//
/////////////////////////////////////////////////////////////
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
			if( g_CMClient[i].iSpawnCount > -1 )
			{
				g_CMClient[i].iSpawnCount -= 1;
			}
			
			if( !IsPlayerAlive( i ) || ( IsFakeClient( i ) && !g_bCvar_DamageBot )) continue;
			
			// checkpoint area damage
			if( g_EMEntity.bIsDamage_Rescue )
			{	
				// survivor not in state just joined the game and outside rescue area
				if( !g_CMClient[i].bIsJoinGame && g_CMClient[i].iStateRoom != ROOM_STATE_RESCUE )
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
			// spawn area damage
			else
			{
				// timer rescue damage countdown still not start, damage still not shifted to rescue area.
				if( g_EMEntity.hTimer[TIMER_RESCUE] == null )
				{
					if( g_CMClient[i].iSpawnCount < 0 )
					{
						// survivor not in state just joined the game and inside spawn area
						if( !g_CMClient[i].bIsJoinGame && g_CMClient[i].iStateRoom == ROOM_STATE_SPAWN )
						{
							// survivor has attacker, skip damage.
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
					else
					{
						if( g_bCvar_LeaveSpawnMsg && !IsFakeClient( i ))
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
									PrintToChat( i, "\x05[\x04WARNING\x05]: \x01Spawn Area Hazard in \x04%0.0f \x01sec(s)", float( g_iCvar_NotifySpawn2 ));
								}
							}
							else if( g_CMClient[i].iSpawnCount == 0 )
							{
								if( g_CMClient[i].iStateRoom == ROOM_STATE_SPAWN )
								{
									PrintToChat( i, "\x05[\x04WARNING\x05]: \x01Spawn Area Hazard effecting you!!" );
								}
								else
								{
									PrintToChat( i, "\x05[\x04WARNING\x05]: \x01Spawn Area Hazard has started!!" );
								}
								EmitSoundToClient( i, SND_WARNING );
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_KillICommonWitch( Handle timer, any entref )
{
	int infected = EntRefToEntIndex( entref );
	if( IsValidEntity( infected ))
	{
		float pos[3];
		GetEntPropVector( infected, Prop_Send, "m_vecOrigin", pos );
		pos[0] = 0.0;
		pos[1] = 0.0;
		pos[2] -= 5000.0;
		TeleportEntity( infected, pos, NULL_VECTOR, NULL_VECTOR );
		Create_PointHurt( infected, FindRandomHumanPlayers(), DMG_VALUE, DMG_GENERIC, "" );
	}
}

public Action Timer_KillIInfectedTank( Handle timer, any userid )
{
	int victim = GetClientOfUserId( userid );
	if ( Infected_IsValid( victim ))
	{
		float pos[3];
		GetEntPropVector( victim, Prop_Send, "m_vecOrigin", pos );
		pos[0] = 0.0;
		pos[1] = 0.0;
		pos[2] -= 5000.0;
		TeleportEntity( victim, pos, NULL_VECTOR, NULL_VECTOR );
		Create_PointHurt( victim, FindRandomHumanPlayers(), DMG_VALUE, DMG_GENERIC, "" );
	}
	return Plugin_Stop;
}


/////////////////////////////////////////////////////////////
//====================== Function =========================//
/////////////////////////////////////////////////////////////
void CheckRescueArea()
{
	if( !g_EMEntity.bIsDamage_Rescue && g_EMEntity.hTimer[TIMER_RESCUE] == null )
	{
		float pos[3];
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
			Print_ServerText( "Timer Rescue Damage has started", g_bCvar_IsDebugging );
		}
	}
}

void SetClientJoinStatus( int client )
{
	// set client no longer joined in midgame and damage applied
	if( g_CMClient[client].bIsJoinGame )
	{
		g_CMClient[client].bIsJoinGame = false;
	}
}

void Create_MapTouchTrigger( int client )
{
	// dont create ref area twice
	if( g_EMEntity.bIsFindDoorInit ) return;
	
	g_EMEntity.bIsRound_End		= false;
	g_EMEntity.bIsFindDoorInit	= true;
	
	
	/////////////////////////////////////////////////
	//====== find and register saferoom door =======//
	/////////////////////////////////////////////////
	float doorPos[3];
	float playPos[3];
	GetEntPropVector( client, Prop_Send, "m_vecOrigin", playPos );
	
	char m_ModelName[PLATFORM_MAX_PATH];
	
	int entity = -1;
	while (( entity = FindEntityByClassname( entity, "prop_door_rotating_checkpoint")) != -1 )
	{
		GetEntPropVector( entity, Prop_Send, "m_vecOrigin", doorPos );
		float distance = GetVectorDistance( playPos, doorPos );
		if ( distance <= DIST_RADIUS )
		{
			// register spawn area saferoom door
			if( g_EMEntity.iDoor_Spawn == -1 )
			{
				GetEntPropString( entity, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
				if( ChrCmp( m_ModelName, MDL_SPAWNROOM1 ) || ChrCmp( m_ModelName, MDL_SPAWNROOM2 ))
				{
					g_EMEntity.iDoor_Spawn = entity;
					Print_ServerText( "Spawn Door found", g_bCvar_IsDebugging );
					
					if( g_bCvar_IsDebugging )
					{
						ToggleGlowEnable( entity, view_as<int>({ 000, 255, 000 }), true );
					}
				}
			}
		}
		else
		{
			// register checkpoint area saferoom door
			if( g_EMEntity.iDoor_Rescue == -1 )
			{
				GetEntPropString( entity, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
				if( ChrCmp( m_ModelName, MDL_CHECKROOM1 ) || ChrCmp( m_ModelName, MDL_CHECKROOM2 ))
				{
					g_EMEntity.iDoor_Rescue = entity;
					Print_ServerText( "Checkpoint Door found", g_bCvar_IsDebugging );
					
					if( g_bCvar_IsDebugging )
					{
						ToggleGlowEnable( entity, view_as<int>({ 000, 255, 000 }), true );
					}
				}
			}
		}
	}
	
	
	/////////////////////////////////////////////////
	//======== create spawn area referance ========//
	/////////////////////////////////////////////////
	if( g_EMEntity.iDoor_Spawn != -1 )
	{
		GetEntPropString( g_EMEntity.iDoor_Spawn, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
		
		// spawn door offset setting
		int type;
		if( ChrCmp( m_ModelName, MDL_SPAWNROOM1 ))
		{
			type = 1;
		}
		
		float ang[3];
		Get_EntityLocation( g_EMEntity.iDoor_Spawn, g_EMEntity.fPos_Spawn, ang );
		
		// create teleport position
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
		int rand = GetRandomInt( 0, 2 );
		g_EMEntity.iRefs_Spawn = Create_Reference( g_sDummyModel[rand], g_EMEntity.fPos_Spawn, ang, g_iCvar_ToyAlpha, g_bCvar_IsDebugging );
	}
	
	
	/////////////////////////////////////////////////
	//===== create checkpoint area referance =====//
	/////////////////////////////////////////////////
	if( g_EMEntity.iDoor_Rescue != -1 )
	{
		GetEntPropString( g_EMEntity.iDoor_Rescue, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
		
		// create teleport position
		float ang[3];
		Get_EntityLocation( g_EMEntity.iDoor_Rescue, g_EMEntity.fPos_Rescue, ang );
		g_EMEntity.fPos_Rescue[2] += DIST_DUMMYHEIGHT;
		
		if( g_EMEntity.fCPRotate != -1.0 )
		{
			ang[1] += g_EMEntity.fCPRotate;
		}
		else
		{
			ang[1] += 90.0;
		}
		
		g_EMEntity.fPos_Rescue[0] += DIST_REFERENCE * Cosine( DegToRad( ang[1] ));
		g_EMEntity.fPos_Rescue[1] += DIST_REFERENCE * Sine( DegToRad( ang[1] ));
		
		// create toy referance
		int rand = GetRandomInt( 0, 2 );
		g_EMEntity.iRefs_Rescue = Create_Reference( g_sDummyModel[rand], g_EMEntity.fPos_Rescue, ang, g_iCvar_ToyAlpha, g_bCvar_IsDebugging );
	}
	
	
	/////////////////////////////////////////////////
	//========= create spawn touch trigger ========//
	/////////////////////////////////////////////////
	if( !g_EMEntity.bIsCfgLoaded )
	{
		// current map name not in trigger touch list
		Print_ServerText( "Current map not in the trigger config list!!", g_bCvar_IsDebugging );
		return;
	}

	int sensor = Create_TouchTrigger( g_sDummyModel[MDL_SENSOR1], g_EMEntity.fBoxPos, g_EMEntity.fBoxMin , g_EMEntity.fBoxMax );
	if( sensor != -1 )
	{
		g_EMEntity.iEntTrigger = sensor;
		
		// first map of the campaign, mean no spawn door referance.
		if( g_EMEntity.iDoor_Spawn == -1 )
		{
			// create toy referance based on trigger touch position
			g_EMEntity.fPos_Spawn = view_as<float>( g_EMEntity.fBoxPos );
			
			int rand = GetRandomInt( 0, 2 );
			g_EMEntity.iRefs_Spawn = Create_Reference( g_sDummyModel[rand], g_EMEntity.fBoxPos, g_EMEntity.fBoxAng, g_iCvar_ToyAlpha, g_bCvar_IsDebugging );
		}
		
		if( g_bCvar_IsDebugging )
		{
			delete g_EMEntity.hTimer[TIMER_LASER1];
			g_EMEntity.hTimer[TIMER_LASER1] = CreateTimer( 0.3, Timer_DeveloperShowBeam1, EntIndexToEntRef( sensor ), TIMER_REPEAT );
		}
		Print_ServerText( "Spawn area trigger created!!", g_bCvar_IsDebugging );
	}
}

int Create_Reference( const char[] model, float pos[3], float ang[3], int alpha, bool glow )
{
	int entity = CreateEntityByName( "prop_dynamic_override" );
	if ( entity == -1 ) return entity;
	
	DispatchKeyValue( entity, "model", model );
	DispatchKeyValueVector( entity, "origin", pos );
	DispatchKeyValueVector( entity, "angles", ang );
	DispatchSpawn( entity );
	SetEntityRenderMode( entity, RENDER_TRANSALPHA );
	SetEntityRenderColor( entity, 255, 255, 255, alpha );
	ToggleGlowEnable( entity, view_as<int>({ 000, 255, 000 }), glow );
	return entity;
}

int Create_TouchTrigger( const char[] model, float pos[3], float m_vecMins[3], float m_vecMaxs[3] )
{
	int sensor = CreateEntityByName( "trigger_multiple" );
	if( sensor == -1 ) return sensor;
	
	DispatchKeyValue( sensor, "model", model );
	DispatchKeyValue( sensor, "spawnflags", "257" );
	DispatchKeyValue( sensor, "StartDisabled", "0" );
	DispatchKeyValueVector( sensor, "Origin", pos );
	DispatchSpawn( sensor );
	
	SetEntProp( sensor, Prop_Send, "m_nSolidType", 2 );
	SetEntPropVector( sensor, Prop_Send, "m_vecMins", m_vecMins );
	SetEntPropVector( sensor, Prop_Send, "m_vecMaxs", m_vecMaxs );
	
	SDKHook( sensor, SDKHook_StartTouch, SpawnArea_OnStartTouched );
	SDKHook( sensor, SDKHook_EndTouch, SpawnArea_OnEndTouch );
	return sensor;
}

void Create_DamageEffect( int victim, int attacker, int damage )
{
	Create_PointHurt( victim, attacker, damage, DMG_GENERIC, "" );
	Create_BloodEffect( victim, g_iMaterialBlood, g_iCvar_BloodColor );
	Create_ScreenParticle( victim, PAT_FIRE );

	if( !IsFakeClient( victim ))
	{
		if( !g_CMClient[victim].bIsSoundBurn )
		{
			g_CMClient[victim].bIsSoundBurn = true;
			EmitSoundToClient( victim, SND_BURNING );
		}
	}
}

void Create_PointHurt( int victim, int attacker, int damage, int dmg_type, const char[] weapon ) // Because I love you.
{
	// event "player_hurt" trigged by this point hurt
	if( victim > 0 && damage > 0 )
	{
		int pointHurt = CreateEntityByName( "point_hurt" );
		if ( pointHurt == -1 ) return;
		
		char buff[32];
		Format( buff, sizeof( buff ), "pointhurt_%d", pointHurt );
		DispatchKeyValue( victim, "targetname", buff );
		DispatchKeyValue( pointHurt, "DamageTarget", buff );
		
		IntToString( damage, buff, sizeof( buff ));
		DispatchKeyValue( pointHurt, "Damage", buff );
		
		IntToString( dmg_type, buff, sizeof( buff ));
		DispatchKeyValue( pointHurt, "DamageType", buff );
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
    int entity = CreateEntityByName( "info_particle_system" );
    if( IsValidEdict( entity ))
    {
		DispatchKeyValue( entity, "effect_name", particleType );
		SetVariantString( "!activator" );
		AcceptEntityInput( entity, "SetParent", client );
		SetVariantString( "spine" );
		AcceptEntityInput( entity, "SetParentAttachment" );
		DispatchSpawn( entity );
		
		ActivateEntity( entity );
		AcceptEntityInput( entity, "start" );
		
		SetVariantString( "OnUser1 !self:Kill::0.9:1" );
		AcceptEntityInput( entity, "AddOutput" );
		AcceptEntityInput( entity, "FireUser1" );
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
	if( g_CMClient[client].bIsSoundBurn )
	{
		StopSound( client, SNDCHAN_AUTO, SND_BURNING );
		g_CMClient[client].bIsSoundBurn = false;
	}
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


/////////////////////////////////////////////////////////////
//======================== Stock ==========================//
/////////////////////////////////////////////////////////////
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

void TeleportPlayer( int client, float pos[3], const char[] sound )
{
	float pos_new[3];
	pos_new	= view_as<float>(pos);
	pos_new[2] += 10.0;
	
	TeleportEntity( client, pos_new, NULL_VECTOR, NULL_VECTOR );
	EmitSoundToAll( sound, client, SNDCHAN_AUTO );
}

void Get_EntityLocation( int entity, float pos[3], float ang[3] )
{
	GetEntPropVector( entity, Prop_Send, "m_vecOrigin", pos );
	GetEntPropVector( entity, Prop_Data, "m_angRotation", ang );
}

bool ChrCmp( const char[] str1, const char[] str2 )
{
	return ( strcmp( str1, str2, false ) == 0 );
}

void Print_ServerText( const char[] text, bool print )
{
	if( !print ) return;
	
	char gauge_none[2]  = "";
	char gauge_tags[16] = "[SAFEROOM]:";
	char gauge_char[99] = "===========================================================================";
	char gauge_side[64];
	FormatEx( gauge_side, sizeof( gauge_side ), "" );
	
	int len_char = strlen( gauge_char );
	int len_text = strlen( text );
	int len_tags = strlen( gauge_tags );
	int len_diff = len_char - len_text - len_tags - 2;
	
	for( int i = 0; i < len_diff; i++ )
	{
		gauge_side[i] = gauge_char[0];
	}
	
	char gauge_buff[99];
	Format( gauge_buff, sizeof( gauge_buff ), "== %s %s %s", gauge_tags, text, gauge_side );
	
	int len1 = strlen( gauge_buff );
	if( len1 > len_char )
	{
		for( int i = len_char; i < sizeof( gauge_char ); i++ )
		{
			gauge_buff[i] = gauge_none[0];
		}
	}
	
	// ( "===========================================================================" );
	// ( "== [SAFEROOM]: Timer damage terminated for finale =========================" );
	// ( "===========================================================================" );
	
	PrintToServer( " " );
	PrintToServer( "%s", gauge_char );
	PrintToServer( "%s", gauge_buff );
	PrintToServer( "%s", gauge_char );
	PrintToServer( " " );
}

void ConvertStringToFloat( const char[][] source, int source_size, float[] buff )
{
	for( int i = 0; i < source_size; i++ )
	{
		buff[i] = StringToFloat( source[i] );
	}
}

bool SaveConfig_Spawn( int client, const char[] filename, const char[] mapname, float pos[3], float ang[3], float min[3], float max[3] )
{
	char filepath[PLATFORM_MAX_PATH];
	BuildPath( Path_SM, filepath, sizeof( filepath ), "data/%s.cfg", filename );
	
	char buff[64];
	KeyValues kv = new KeyValues( filename );
	if( !kv.ImportFromFile( filepath ))
	{
		Print_ServerText( "Spawn file import failed", true );
		delete kv;
		return false;
	}
	if( !kv.JumpToKey( mapname, true ))
	{
		Print_ServerText( "Spawn read config failed.", true );
		delete kv;
		return false;
	}
	
	Format( buff, sizeof( buff ), "%.2f, %.2f, %.2f", pos[0], pos[1], pos[2] );
	kv.SetString( "pos", buff );
	
	Format( buff, sizeof( buff ), "%.2f, %.2f, %.2f", ang[0], ang[1], ang[2] );
	kv.SetString( "ang", buff );
	
	Format( buff, sizeof( buff ), "%.2f, %.2f, %.2f", min[0], min[1], min[2] );
	kv.SetString( "min", buff );
	
	Format( buff, sizeof( buff ), "%.2f, %.2f, %.2f", max[0], max[1], max[2] );
	kv.SetString( "max", buff );
	kv.Rewind();
	kv.ExportToFile( filepath );
	delete kv;
	
	if( client > 0 )
	{
		Format( buff, sizeof( buff ), "[SAFEROOM]: Map Config Saved: %s", mapname );
		PrintToChat( client, buff );
	}
	return true;
}

bool ReadConfig_Spawn( const char[] filename, const char[] mapname, char[][] buffer )
{
	KeyValues kv = new KeyValues( filename );
	char filepath[PLATFORM_MAX_PATH];
	BuildPath( Path_SM, filepath, sizeof( filepath ), "data/%s.cfg", filename );
	if( !kv.ImportFromFile( filepath ))
	{
		Print_ServerText( "Spawn file import failed", true );
		delete kv;
		return false;
	}

	if( !kv.JumpToKey( mapname ))
	{
		Print_ServerText( "Spawn read config failed.", true );
		delete kv;
		return false;
	}
	
	kv.GetString( "pos", buffer[0], 32 );
	kv.GetString( "ang", buffer[1], 32 );
	kv.GetString( "min", buffer[2], 32 );
	kv.GetString( "max", buffer[3], 32 );
	kv.Rewind();
	kv.ExportToFile( filepath );
	delete kv;
	Print_ServerText( "Spawn box loaded succsesfully.", g_bCvar_IsDebugging );
	return true;
}

bool ReadConfig_Cpdoor( const char[] filename, const char[] mapname, char[] buffer )
{
	KeyValues kv = new KeyValues( filename );
	char filepath[PLATFORM_MAX_PATH];
	BuildPath( Path_SM, filepath, sizeof( filepath ), "data/%s.cfg", filename );
	if( !kv.ImportFromFile( filepath ))
	{
		Print_ServerText( "File import failed | Spawn", true );
		delete kv;
		return false;
	}

	if( !kv.JumpToKey( mapname ))
	{
		delete kv;
		return false;
	}
	
	kv.GetString( "rotate", buffer, 8 ); //error 035: argument type mismatch (argument 3)
	kv.Rewind();
	kv.ExportToFile( filepath );
	delete kv;
	Print_ServerText( "CPDoor loaded succsesfully.", g_bCvar_IsDebugging );
	return true;
}

stock bool DeleteConfig( int client, const char[] filename, const char[] mapname )
{
	KeyValues kv = new KeyValues( filename );
	char filepath[PLATFORM_MAX_PATH];
	BuildPath( Path_SM, filepath, sizeof( filepath ), "data/%s.cfg", filename );
	if( !kv.ImportFromFile( filepath ))
	{
		PrintToChat( client, "[SAFEROOM]: Delete failed. Unable to find file." );
		delete kv;
		return false;
	}

	if( !kv.JumpToKey( mapname ))
	{
		PrintToChat( client, "[SAFEROOM]: Unable to delete. Map name don't exist." );
		delete kv;
		return false;
	}

	kv.DeleteThis();
	kv.Rewind();
	kv.ExportToFile( filepath );
	delete kv;
	PrintToChat( client, "\x01[SAFEROOM]: Map \x05%s \x01deleted.", mapname );
	return true;
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
	Handle trace = TR_TraceRayFilterEx( startPos, startAng, MASK_SOLID_BRUSHONLY, RayType_Infinite, TraceFilterPlayers, data );
	if( TR_DidHit( trace ))
	{ 
		TR_GetEndPosition( outputPos, trace );
		havepos = true;
	}
	delete trace;
	return havepos;
}

stock bool TraceFilterPlayers( int entity, int contentsMask, any data )
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

stock int FindRandomHumanPlayers()
{
	int count = -1;
	int buff[MAXPLAYERS+1];
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame( i ) && !IsFakeClient( i ) && GetClientTeam( i ) == 2 )
		{
			if( count == -1 )
			{
				count = 0;
			}
			buff[count] = i;
			count++;
		}
	}
	
	// no human players
	if( count == -1 )
	{
		return count;
	}
	
	count -= 1;
	return buff[ GetRandomInt( 0, count ) ];
}

// @silver [ANY] Trigger Multiple Commands
public Action Timer_DeveloperShowBeam1( Handle timer, any entref )	
{
	int entity = EntRefToEntIndex( entref );
	if( IsValidEntity( entity ))
	{
		if( g_EMEntity.hTimer[TIMER_LASER1] == timer ) // development sanity check, functionality dosent matter, handle leak matters.
		{
			float vecMaxs[3], vecMins[3], vecPos[3];
			GetEntPropVector( entity, Prop_Send, "m_vecOrigin", vecPos );
			GetEntPropVector( entity, Prop_Send, "m_vecMins", vecMins );
			GetEntPropVector( entity, Prop_Send, "m_vecMaxs", vecMaxs );
			AddVectors( vecPos, vecMins, vecMins );
			AddVectors( vecPos, vecMaxs, vecMaxs );
			TE_SendBox( vecMins, vecMaxs );
			return Plugin_Continue;
		}
		AcceptEntityInput( entity, "kill" );
	}
	g_EMEntity.hTimer[TIMER_LASER1] = null;
	return Plugin_Stop;
}

public Action Timer_DeveloperShowBeam2( Handle timer, any entref )
{
	int entity = EntRefToEntIndex( entref );
	if( IsValidEntity( entity ))
	{
		if( g_EMEntity.hTimer[TIMER_LASER2] == timer ) // development sanity check, functionality dosent matter, handle leak matters.
		{
			float vecMaxs[3], vecMins[3], vecPos[3];
			GetEntPropVector( entity, Prop_Send, "m_vecOrigin", vecPos );
			GetEntPropVector( entity, Prop_Send, "m_vecMins", vecMins );
			GetEntPropVector( entity, Prop_Send, "m_vecMaxs", vecMaxs );
			AddVectors( vecPos, vecMins, vecMins );
			AddVectors( vecPos, vecMaxs, vecMaxs );
			TE_SendBox( vecMins, vecMaxs );
			return Plugin_Continue;
		}
		AcceptEntityInput( entity, "kill" );
	}
	g_EMEntity.hTimer[TIMER_LASER2] = null;
	return Plugin_Stop;
}

stock void TE_SendBox( float vecMins[3], float vecMaxs[3] )
{
	float vPos1[3], vPos2[3], vPos3[3], vPos4[3], vPos5[3], vPos6[3];
	vPos1 = vecMaxs;
	vPos1[0] = vecMins[0];
	vPos2 = vecMaxs;
	vPos2[1] = vecMins[1];
	vPos3 = vecMaxs;
	vPos3[2] = vecMins[2];
	vPos4 = vecMins;
	vPos4[0] = vecMaxs[0];
	vPos5 = vecMins;
	vPos5[1] = vecMaxs[1];
	vPos6 = vecMins;
	vPos6[2] = vecMaxs[2];
	TE_SendBeam( vecMaxs, vPos1 );
	TE_SendBeam( vecMaxs, vPos2 );
	TE_SendBeam( vecMaxs, vPos3);
	TE_SendBeam( vPos6, vPos1 );
	TE_SendBeam( vPos6, vPos2 );
	TE_SendBeam( vPos6, vecMins );
	TE_SendBeam( vPos4, vecMins );
	TE_SendBeam( vPos5, vecMins );
	TE_SendBeam( vPos5, vPos1 );
	TE_SendBeam( vPos5, vPos3 );
	TE_SendBeam( vPos4, vPos3 );
	TE_SendBeam( vPos4, vPos2 );
}

stock void TE_SendBeam( const float vecMins[3], const float vecMaxs[3] )
{
	TE_SetupBeamPoints( vecMins, vecMaxs, g_iMaterialLaser, g_iMaterialHalo, 0, 0, 0.3 + 0.1, 1.0, 1.0, 1, 0.0, view_as<int>({ 0, 255, 0, 255 }), 0 );
	TE_SendToAll();
}

