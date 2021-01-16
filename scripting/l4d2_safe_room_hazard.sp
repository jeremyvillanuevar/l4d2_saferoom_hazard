#define PLUGIN_VERSION "1.0.3"
/*
================== todo ===================
take damage when they refuse to enter the second saferoom


============= version history =============
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

#define TEAM_SURVIVOR		2
#define TEAM_INFECTED		3
#define TEAM_SPECTATOR		4

#define	REFERENCE_1			"models/props_fairgrounds/elephant.mdl"
#define REFERENCE_2			"models/props_fairgrounds/alligator.mdl"
#define REFERENCE_3			"models/props_fairgrounds/giraffe.mdl"
#define TELEPORT_SND		"ui/menu_horror01.wav"
#define DMG_GENERIC			0

ConVar	g_hSafeHazard_Enable, g_hSafeHazard_Notify1, g_hSafeHazard_Notify2, g_hSafeHazard_Radius, g_hSafeHazard_Interval, g_hSafeHazard_Damage, g_hSafeHazard_Type, g_hSafeHazard_Msg,
		g_hSafeHazard_Safe, g_hSafeHazard_Door, g_hSafeHazard_Toy, g_hSafeHazard_Tank;

Handle g_hTimer_0				= INVALID_HANDLE;
Handle g_hTimer_1				= INVALID_HANDLE;
Handle g_hTimer_2				= INVALID_HANDLE;
Handle g_hTimer_3				= INVALID_HANDLE;
Handle g_hTimer_Effect			= INVALID_HANDLE;
Handle g_hTimer_Force			= INVALID_HANDLE;
Handle g_hTimer_SafeCheck		= INVALID_HANDLE;

float	g_fInfoPos[3]			= { 0.0, 0.0, 0.0 };
float	g_fInfoPos2[3]			= { 0.0, 0.0, 0.0 };
float	g_fCampPos[3]			= { 0.0, 0.0, 0.0 };
float	g_fRadius				= 0.0;
float	g_fRadius2				= 0.0;
bool	g_bStart				= false;
bool	g_bFinale				= false;
bool	g_bFind					= false;
bool	g_bFound				= false;
bool	g_bFound2				= false;
bool	g_bPause				= false;
bool	g_bSafeCheck			= false;
bool	g_bEnter[MAXPLAYERS+1]	= { false, ... };
int		g_iRescueDoor			= -1;


// cvar
bool	g_bCvar_Enable;
int		g_iCvar_HPhit;
int		g_iCvar_Type;
bool	g_bCvar_Msg;
int		g_iCvar_Safe;
int		g_iCvar_Door;
bool	g_bCvar_Toy;
float	g_fCvar_Tank;
float	g_fCvar_Notify1;
float	g_fCvar_Notify2;
float	g_fCvar_Radius;
float	g_fCvar_Interval;

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
	g_hSafeHazard_Enable		= CreateConVar( "saferoomhazard_enable",	"1",	"0:Off,  1:On,  Toggle plugin On/Off.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_hSafeHazard_Notify1		= CreateConVar( "saferoomhazard_notify1",	"30",	"Timer first notify to player to leave safe room.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 1.0, true, 120.0 );
	g_hSafeHazard_Notify2		= CreateConVar( "saferoomhazard_notify2",	"30",	"Timer damage to kick in count start from 'saferoomhazard_notify1'..   >_<.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 1.0, true, 120.0 );
	g_hSafeHazard_Radius		= CreateConVar( "saferoomhazard_radius",	"0.0",	"Value added to the default radius damage (Effect all map).", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_hSafeHazard_Interval		= CreateConVar( "saferoomhazard_interval",	"1.0",	"Interval between damage to player (Seconds).", FCVAR_SPONLY|FCVAR_NOTIFY, true, 1.0, true, 60.0 );
	g_hSafeHazard_Damage		= CreateConVar( "saferoomhazard_damage",	"1",	"How much HP we knock on player per hit.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 1.0, true, 100.0 );
	g_hSafeHazard_Type			= CreateConVar( "saferoomhazard_type",		"0",	"0:Knock HP, 1:Knock HP + Teleport to Survivor if any, 2:Knock HP + Teleport to Infected if any.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 2.0 );
	g_hSafeHazard_Msg			= CreateConVar( "saferoomhazard_notify",	"1",	"0:Off | 1:On, Toggle announce to chat to warn player.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_hSafeHazard_Safe			= CreateConVar( "saferoomhazard_safe",		"1",	"0:Off | 1:On, If on, player that are refuse to enter safe room will be teleport to force end the round (Safe room door must be close at least once and all player must enter next safe room at least once).", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_hSafeHazard_Door			= CreateConVar( "saferoomhazard_door",		"1",	"0:Closed | 1:Open, If close, Safe Room door will be force closed after teleport, Open otherwise.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_hSafeHazard_Toy			= CreateConVar( "saferoomhazard_toy",		"1",	"0:Off, 1:On, If on, Developer reference will visible inside safe room in form of toy  >_<", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_hSafeHazard_Tank			= CreateConVar( "saferoomhazard_tank",		"500",	"0:Off, 1 or above, If tank distance less than this from safe room door, disable the Hazard.", FCVAR_SPONLY|FCVAR_NOTIFY);
	
	AutoExecConfig( true, "l4d2_safe_room_hazard" );
	
	HookEvent( "player_spawn",		EVENT_PlayerSpawn );
	HookEvent( "round_end",			EVENT_RoundEnd );
	HookEvent( "finale_start",		EVENT_Finale );
	HookEvent( "door_close",		EVENT_DoorClose );
	HookEvent( "survivor_rescued",	EVENT_SurvivorRescued );

	RegAdminCmd( "force_enter",	CommandForceEnter, ADMFLAG_GENERIC );
	
	g_hSafeHazard_Enable.AddChangeHook(	ConVar_Changed );
	g_hSafeHazard_Notify1.AddChangeHook( ConVar_Changed );
	g_hSafeHazard_Notify2.AddChangeHook( ConVar_Changed );
	g_hSafeHazard_Radius.AddChangeHook( ConVar_Changed );
	g_hSafeHazard_Interval.AddChangeHook( ConVar_Changed );
	g_hSafeHazard_Damage.AddChangeHook( ConVar_Changed );
	g_hSafeHazard_Type.AddChangeHook( ConVar_Changed );
	g_hSafeHazard_Msg.AddChangeHook( ConVar_Changed );
	g_hSafeHazard_Safe.AddChangeHook( ConVar_Changed );
	g_hSafeHazard_Door.AddChangeHook( ConVar_Changed );
	g_hSafeHazard_Toy.AddChangeHook( ConVar_Changed );
	g_hSafeHazard_Tank.AddChangeHook( ConVar_Changed );
	
	UpdateCvar();
}

public Action CommandForceEnter( int client, int args )
{
	if ( client < 1 )
	{
		ReplyToCommand( client, "[SAFEROOMHAZARD]: Command only valid in game!!" );
		return Plugin_Handled;
	}
	
	if ( !g_bFound2 )
	{
		ReplyToCommand( client, "[SAFEROOMHAZARD]: This map has no valid check point!!" );
		return Plugin_Handled;
	}
	
	float roAng[3];
	if ( IsPlayerAlive( client ) && GetClientTeam( client ) == TEAM_SURVIVOR )
	{
		if ( g_iRescueDoor != -1 )
		{
			if ( g_iCvar_Door == 0 )
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
			if ( i == client ) continue;
			
			if ( IsClientInGame( i ))
			{
				GetEntPropVector( i, Prop_Data, "m_angRotation", roAng );
				TeleportEntity( i, g_fInfoPos2, roAng, NULL_VECTOR );
				EmitSoundToClient( i, TELEPORT_SND );
			}
		}
	}
	else
	{
		ReplyToCommand( client, "[SAFEROOMHAZARD]: You must be alive and in Survivor team to use command!!" );
	}
	return Plugin_Handled;
}

public void OnMapStart()
{
	for ( int i = 1; i <= MAXPLAYERS; i++ )
	{
		g_bEnter[i]	= false;
	}
	
	g_hTimer_0			= INVALID_HANDLE;
	g_hTimer_1			= INVALID_HANDLE;
	g_hTimer_2			= INVALID_HANDLE;
	g_hTimer_3			= INVALID_HANDLE;
	g_hTimer_Effect		= INVALID_HANDLE;
	g_hTimer_Force		= INVALID_HANDLE;
	g_hTimer_SafeCheck	= INVALID_HANDLE;
	g_fRadius			= 0.0;
	g_fRadius2			= 0.0;
	g_bStart			= false;
	g_bFinale			= false;
	g_bFind				= false;
	g_bFound			= false;
	g_bFound2			= false;
	g_bPause			= false;
	g_bSafeCheck		= false;
	g_iRescueDoor		= -1;
	
	for ( int i = 0; i <= 2; i++ )
	{
		g_fInfoPos[i]	= 0.0;
		g_fInfoPos2[i]	= 0.0;
		g_fCampPos[i]	= 0.0;
	}
	
	PrecacheModel( REFERENCE_1 );
	PrecacheModel( REFERENCE_2 );
	PrecacheModel( REFERENCE_3 );
	PrecacheSound( TELEPORT_SND, true );
}

public void OnClientDisconnect( int client )
{
	if ( client > 0 )
	{
		g_bEnter[client]	= false;
	}
}

public void ConVar_Changed( Handle convar, const char[] oldValue, const char[] newValue )
{
	UpdateCvar();
}

void UpdateCvar()
{
	g_bCvar_Enable		= g_hSafeHazard_Enable.BoolValue;
	g_fCvar_Notify1		= g_hSafeHazard_Notify1.FloatValue;
	g_fCvar_Notify2		= g_hSafeHazard_Notify2.FloatValue;
	g_fCvar_Radius		= g_hSafeHazard_Radius.FloatValue;
	g_fCvar_Interval	= g_hSafeHazard_Interval.FloatValue;
	g_iCvar_HPhit		= g_hSafeHazard_Damage.IntValue;
	g_iCvar_Type		= g_hSafeHazard_Type.IntValue;
	g_bCvar_Msg			= g_hSafeHazard_Msg.BoolValue;
	g_iCvar_Safe		= g_hSafeHazard_Safe.IntValue;
	g_iCvar_Door		= g_hSafeHazard_Door.IntValue;
	g_bCvar_Toy			= g_hSafeHazard_Toy.BoolValue;
	g_fCvar_Tank		= g_hSafeHazard_Tank.FloatValue;
}

public void EVENT_RoundEnd( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_Enable ) return;
	
	g_bStart		= false;
	g_bFinale		= false;
	g_bPause		= false;
	g_bSafeCheck	= false;
	
	if ( g_hTimer_0 != INVALID_HANDLE )
	{
		KillTimer( g_hTimer_0 );
		g_hTimer_0	= INVALID_HANDLE;
	}
	if ( g_hTimer_1 != INVALID_HANDLE )
	{
		KillTimer( g_hTimer_1 );
		g_hTimer_1	= INVALID_HANDLE;
	}
	
	if ( g_hTimer_2 != INVALID_HANDLE )
	{
		KillTimer( g_hTimer_2 );
		g_hTimer_2	= INVALID_HANDLE;
	}
	
	if ( g_hTimer_3 != INVALID_HANDLE )
	{
		KillTimer( g_hTimer_3 );
		g_hTimer_3	= INVALID_HANDLE;
	}
	
	if ( g_hTimer_Effect != INVALID_HANDLE )
	{
		KillTimer( g_hTimer_Effect );
		g_hTimer_Effect = INVALID_HANDLE;
	}
	
	if ( g_hTimer_Force != INVALID_HANDLE )
	{
		KillTimer( g_hTimer_Force );
		g_hTimer_Force = INVALID_HANDLE;
	}
	
	if ( g_hTimer_SafeCheck != INVALID_HANDLE )
	{
		KillTimer( g_hTimer_SafeCheck );
		g_hTimer_SafeCheck = INVALID_HANDLE;
	}
	
	for ( int i = 1; i <= MaxClients; i++ )
	{
		g_bEnter[i]	= false;
	}
}

public void EVENT_SurvivorRescued( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_Enable ) return;
	
	int client = GetClientOfUserId( event.GetInt( "subject" ));
	
	if ( client > 0 )
	{
		g_bEnter[client] = false;
	}
}

public void EVENT_PlayerSpawn( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_Enable ) return;
	
	int client = GetClientOfUserId( event.GetInt( "userid" ));
	if ( IsValidSurvivor( client ))
	{
		// If player joint at mid game we halt the damage.
		if ( !IsFakeClient( client ) && g_hTimer_3 != INVALID_HANDLE )
		{
			GetEntPropVector( client, Prop_Send, "m_vecOrigin", g_fCampPos );
			if ( GetVectorDistance( g_fInfoPos, g_fCampPos ) <= ( g_fRadius + g_fCvar_Radius ))
			{
				g_bPause	= true;
				
				if ( g_hTimer_Effect != INVALID_HANDLE )
				{
					KillTimer( g_hTimer_Effect );
					g_hTimer_Effect = INVALID_HANDLE;
				}
				
				g_hTimer_Effect = CreateTimer( g_fCvar_Notify2, Timer_RestoreEffect, _, TIMER_FLAG_NO_MAPCHANGE );
				
				if ( g_bCvar_Msg ) PrintToChat( client, "\x05[\x04WARNING\x05]: \x05You have \x04%0.0f \x05second(s) to leave safe room!!", g_fCvar_Notify2 );
			}
		}
		
		if ( g_bStart || g_bFinale ) return;
		
		g_bStart = true;
		// we don't look for reference twice at same map that the round has end.
		if ( !g_bFind )
		{
			g_bFind		= true;
			g_bFound	= FindEntityReference( g_fInfoPos );
			g_bFound2	= FindRescueReference( g_fInfoPos2 );
		}
		
		if ( g_bFound )
		{
			// Look for idle player
			if ( g_bCvar_Toy ) CreateReference( g_fInfoPos );
			g_hTimer_0 = CreateTimer( 2.0, Timer_CheckClient, _, TIMER_FLAG_NO_MAPCHANGE );
		}
		
		if ( g_bFound2 && g_iCvar_Safe > 0 )
		{
			// Start our saferoom teleport
			if ( g_bCvar_Toy ) CreateReference( g_fInfoPos2 );
			g_iRescueDoor = FindRescueDoor();
			g_hTimer_SafeCheck = CreateTimer(( g_fCvar_Notify1 + g_fCvar_Notify2 ), Timer_EnableSafeCheck, _, TIMER_FLAG_NO_MAPCHANGE );
		}
	}
}

public void EVENT_Finale( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_Enable ) return;
	
	g_bFinale = true;
}

public void EVENT_DoorClose( Event event, const char[] name, bool dontBroadcast )
{
	if ( !g_bCvar_Enable || !g_bFound2 || !g_bSafeCheck || g_iCvar_Safe == 0 ) return;
	
	bool close = event.GetBool( "checkpoint" );
	if ( close )
	{
		if ( g_hTimer_Force == INVALID_HANDLE )
		{
			g_hTimer_Force = CreateTimer( 1.0, Timer_CheckSafeStatus, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
		}
	}
}

public Action Timer_CheckClient( Handle timer )
{
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && IsFakeClient( i ))
		{
			if ( GetHumanSpectator( i ) > 0 )
			{
				return Plugin_Continue;
			}
		}
	}
	
	//PrintToServer( "[SAFEROOMHAZARD]: Count down started!!" );
	g_hTimer_1 = CreateTimer( g_fCvar_Notify1, Timer_Notify_1, _, TIMER_FLAG_NO_MAPCHANGE );
	g_hTimer_0 = INVALID_HANDLE;
	return Plugin_Stop;
}

public Action Timer_CheckSafeStatus( Handle timer )
{
	int i;
	float forPos[3];
	bool condition = true;
	
	for ( i = 1; i <= MaxClients; i++ )
	{
		if ( g_bEnter[i] ) continue;
		
		if ( IsValidSurvivor( i ))
		{
			GetEntPropVector( i, Prop_Send, "m_vecOrigin", forPos );
			if ( GetVectorDistance( g_fInfoPos2, forPos ) <= g_fRadius2 )
			{
				g_bEnter[i] = true;
			}
		}
	}
	
	// check if all player have enter safe room at least once.
	for ( i = 1; i <= MaxClients; i++ )
	{
		if ( IsValidSurvivor( i ))
		{
			if ( !g_bEnter[i] )
			{
				condition = false;
				break;
			}
		}
	}
	
	if ( condition )
	{
		g_fInfoPos2[2] += 2.0;	// Don't let player stuck on the floor.
		
		if ( g_iRescueDoor != -1 )
		{
			if ( g_iCvar_Door == 0 )
			{
				AcceptEntityInput( g_iRescueDoor, "Close" );
			}
			else
			{
				AcceptEntityInput( g_iRescueDoor, "Open" );
			}
		}
		
		for ( i = 1; i <= MaxClients; i++ )
		{
			if ( IsClientInGame( i ) && IsPlayerAlive( i ))
			{
				GetEntPropVector( i, Prop_Send, "m_vecOrigin", forPos );
				if ( GetVectorDistance( g_fInfoPos2, forPos ) >= g_fRadius2 )
				{
					GetEntPropVector( i, Prop_Data, "m_angRotation", forPos );
					TeleportEntity( i, g_fInfoPos2, forPos, NULL_VECTOR );
					EmitSoundToClient( i, TELEPORT_SND );
				}
			}
		}
		
		g_hTimer_Force = INVALID_HANDLE;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action Timer_RestoreEffect( Handle timer )
{
	g_bPause		= false;
	g_hTimer_Effect = INVALID_HANDLE;
}

public Action Timer_EnableSafeCheck( Handle timer )
{
	g_bSafeCheck		= true;
	g_hTimer_SafeCheck	= INVALID_HANDLE;
}

public Action Timer_Notify_1( Handle timer )
{
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && !IsFakeClient( i ))
		{
			GetEntPropVector( i, Prop_Send, "m_vecOrigin", g_fCampPos );
			if ( GetVectorDistance( g_fInfoPos, g_fCampPos ) <= ( g_fRadius + g_fCvar_Radius ))
			{
				if ( g_bCvar_Msg ) PrintToChat( i, "\x05[\x04WARNING\x05]: \x05You have \x04%0.0f \x05second(s) to leave safe room!!", g_fCvar_Notify2 );
			}
			else
			{
				if ( g_bCvar_Msg ) PrintToChat( i, "\x05[\x04WARNING\x05]: \x05Remaining \x04%0.0f \x05second(s) untill Safe Room Hazard in effect!!", g_fCvar_Notify2 );
			}
		}
	}
	g_hTimer_1 = INVALID_HANDLE;
	g_hTimer_2 = CreateTimer( g_fCvar_Notify2, Timer_Notify_2, _, TIMER_FLAG_NO_MAPCHANGE );
}

public Action Timer_Notify_2( Handle timer )
{
	g_hTimer_2 = INVALID_HANDLE;
	
	int Tele = -1;
	switch( g_iCvar_Type )
	{
		case 1: { Tele = FindTeleportSurvivor();	}
		case 2: { Tele = FindTeleportEntity();		}
	}
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && !IsFakeClient( i ))
		{
			GetEntPropVector( i, Prop_Send, "m_vecOrigin", g_fCampPos );
			if ( GetVectorDistance( g_fInfoPos, g_fCampPos ) <= ( g_fRadius + g_fCvar_Radius ))
			{
				if ( Tele < 1 )
				{
					if ( g_bCvar_Msg ) PrintToChat( i, "\x05[\x04WARNING\x05]: You inside Safe Room Hazard.. leave now!!" );
				}
				else
				{
					TeleportPlayer( i, Tele );
					if ( g_bCvar_Msg ) PrintToChat( i, "\x05[\x04WARNING\x05]: Side effect of Safe Room Hazard!!" );
				}
			}
			else
			{
				if ( g_bCvar_Msg ) PrintToChat( i, "\x05[\x04WARNING\x05]: Safe Room Hazard in effect!!" );
			}
		}
	}
	
	g_hTimer_3 = CreateTimer( g_fCvar_Interval, Timer_Notify_3, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
}

public Action Timer_Notify_3( Handle timer )
{
	g_hTimer_2 = INVALID_HANDLE;
	
	if ( g_bFinale )
	{
		g_hTimer_3 = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	if ( g_bPause ) return Plugin_Continue;
	
	int i;
	if ( g_fCvar_Tank > 0.0 )
	{
		for ( i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame( i ) && IsTank( i ))
			{
				GetEntPropVector( i, Prop_Send, "m_vecOrigin", g_fCampPos );
				if ( GetVectorDistance( g_fInfoPos, g_fCampPos ) <= ( g_fRadius + g_fCvar_Tank ))
				{
					return Plugin_Continue;
				}
			}
		}
	}
	
	for ( i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && !IsFakeClient( i ) && IsPlayerAlive( i ) && GetClientTeam( i ) == TEAM_SURVIVOR )
		{
			GetEntPropVector( i, Prop_Send, "m_vecOrigin", g_fCampPos );
			if ( GetVectorDistance( g_fInfoPos, g_fCampPos ) <= ( g_fRadius + g_fCvar_Radius ))
			{
				DealDamage( i, g_iCvar_HPhit, i, DMG_GENERIC, "" );
			}
		}
	}
	
	return Plugin_Continue;
}

bool FindEntityReference( float refPos[3] )
{
	float Radius = 0.0;
	float Pos[3];
	char mapName[128];
	GetCurrentMap( mapName, sizeof( mapName ));
	//
	if ( StrEqual( mapName, "c1m2_streets", false ))
	{
		Pos[0] = 2454.248779;
		Pos[1] = 5147.631347;
		Pos[2] = 448.031250;
		Radius = 265.9;
	}
	else if ( StrEqual( mapName, "c1m3_mall", false ))
	{
		Pos[0] = 6684.659179;
		Pos[1] = -1422.387329;
		Pos[2] = 24.031250;
		Radius = 278.3 + 50.0;
	}
	else if ( StrEqual( mapName, "c1m4_atrium", false ))
	{
		Pos[0] = -2084.390136;
		Pos[1] = -4588.168457;
		Pos[2] = 536.031250;
		Radius = 207.4 + 60.0;
	}
	//
	else if ( StrEqual( mapName, "c2m2_fairgrounds", false ))
	{
		Pos[0] = 1581.031250;
		Pos[1] = 2797.585937;
		Pos[2] = 4.031250;
		Radius = 178.2 + 80.0;
	}
	else if ( StrEqual( mapName, "c2m3_coaster", false ))
	{
		Pos[0] = 4262.798339;
		Pos[1] = 2042.455932;
		Pos[2] = -63.968750;
		Radius = 419.0;
	}
	else if ( StrEqual( mapName, "c2m4_barns", false ))
	{
		Pos[0] = 3135.401367;
		Pos[1] = 3604.727050;
		Pos[2] = -187.968750;
		Radius = 363.6 + 60.0;
	}
	else if ( StrEqual( mapName, "c2m5_concert", false ))
	{
		Pos[0] = -842.493896;
		Pos[1] = 2247.106201;
		Pos[2] = -255.968978;
		Radius = 250.9 + 55.0;
	}
	//
	else if ( StrEqual( mapName, "c3m2_swamp", false ))
	{
		Pos[0] = -8173.997070;
		Pos[1] = 7531.213867;
		Pos[2] = 12.031250;
		Radius = 275.6;
	}
	else if ( StrEqual( mapName, "c3m3_shantytown", false ))
	{
		Pos[0] = -5789.206542;
		Pos[1] = 2192.547363;
		Pos[2] = 136.031250;
		Radius = 284.5;
	}
	else if ( StrEqual( mapName, "c3m4_plantation", false ))
	{
		Pos[0] = -5068.428222;
		Pos[1] = -1674.808593;
		Pos[2] = -96.811752;
		Radius = 200.1 + 10.0;
	}
	//
	else if ( StrEqual( mapName, "c4m2_sugarmill_a", false ))
	{
		Pos[0] = 3795.042236;
		Pos[1] = -1614.056274;
		Pos[2] = 232.531250;
		Radius = 381.2 + 20.0;
	}
	else if ( StrEqual( mapName, "c4m3_sugarmill_b", false ))
	{
		Pos[0] = -1796.072875;
		Pos[1] = -13677.507812;
		Pos[2] = 130.031250;
		Radius = 116.4 + 60.0;
	}
	else if ( StrEqual( mapName, "c4m4_milltown_b", false ))
	{
		Pos[0] = 4039.968750;
		Pos[1] = -1711.968750;
		Pos[2] = 264.567199;
		Radius = 281.8 + 100.0;
	}
	else if ( StrEqual( mapName, "c4m5_milltown_escape", false ))
	{
		Pos[0] = -3155.084716;
		Pos[1] = 7946.947265;
		Pos[2] = 120.031250;
		Radius = 536.6 + 10.0;
	}
	//
	else if ( StrEqual( mapName, "c5m2_park", false ))
	{
		Pos[0] = -4278.839843;
		Pos[1] = -1280.031250;
		Pos[2] = -343.968750;
		Radius = 510.2;
	}
	else if ( StrEqual( mapName, "c5m3_cemetery", false ))
	{
		Pos[0] = 6509.377441;
		Pos[1] = 8442.528320;
		Pos[2] = 0.031250;
		Radius = 299.8 + 40.0;
	}
	else if ( StrEqual( mapName, "c5m4_quarter", false ))
	{
		Pos[0] = -3157.473144;
		Pos[1] = 4959.968750;
		Pos[2] = 68.031250;
		Radius = 270.2 + 65.0;
	}
	else if ( StrEqual( mapName, "c5m5_bridge", false ))
	{
		Pos[0] = -12041.167968;
		Pos[1] = 5868.073242;
		Pos[2] = 128.031250;
		Radius = 384.8 + 80.0;
	}
	//
	else if ( StrEqual( mapName, "c6m2_bedlam", false ))
	{
		Pos[0] = 3113.642578;
		Pos[1] = -1272.868896;
		Pos[2] = -295.968750;
		Radius = 210.7 + 40.0;
	}
	else if ( StrEqual( mapName, "c6m3_port", false ))
	{
		Pos[0] = -2527.968750;
		Pos[1] = -627.968750;
		Pos[2] = -255.968750;
		Radius = 421.1 + 10.0;
	}
	//
	else if ( StrEqual( mapName, "c7m2_barge", false ))
	{
		Pos[0] = 10847.968750;
		Pos[1] = 2527.968750;
		Pos[2] = 176.031250;
		Radius = 291.8 + 30.0;
	}
	else if ( StrEqual( mapName, "c7m3_port", false ))
	{
		Pos[0] = 1248.394531;
		Pos[1] = 3367.968750;
		Pos[2] = 168.031250;
		Radius = 337.4 + 60.0;
	}
	//
	else if ( StrEqual( mapName, "c8m2_subway", false ))
	{
		Pos[0] = 2848.031250;
		Pos[1] = 3090.854736;
		Pos[2] = 16.031250;
		Radius = 281.1 + 20.0 ;
	}
	else if ( StrEqual( mapName, "c8m3_sewers", false ))
	{
		Pos[0] = 10853.767578;
		Pos[1] = 4829.805175;
		Pos[2] = 16.031250;
		Radius = 264.5 + 30.0;
	}
	else if ( StrEqual( mapName, "c8m4_interior", false ))
	{
		Pos[0] = 12423.989257;
		Pos[1] = 12415.215820;
		Pos[2] = 16.031250;
		Radius = 204.8 + 60.0;
	}
	else if ( StrEqual( mapName, "c8m5_rooftop", false ))
	{
		Pos[0] = 5494.252441;
		Pos[1] = 8286.669921;
		Pos[2] = 5546.031250;
		Radius = 362.2;
	}
	//
	else if ( StrEqual( mapName, "c9m2_lots", false ))
	{
		Pos[0] = 144.031250;
		Pos[1] = -1310.527465;
		Pos[2] = -139.968750;
		Radius = 294.7 + 35.0;
	}
	//
	else if ( StrEqual( mapName, "c10m2_drainage", false ))
	{
		Pos[0] = -11171.067382;
		Pos[1] = -9133.698242;
		Pos[2] = -591.968750;
		Radius = 358.5 + 80.0;
	}
	else if ( StrEqual( mapName, "c10m3_ranchhouse", false ))
	{
		Pos[0] = -8219.132812;
		Pos[1] = -5566.748535;
		Pos[2] = -22.968751;
		Radius = 453.6;
	}
	else if ( StrEqual( mapName, "c10m4_mainstreet", false ))
	{
		Pos[0] = -3089.227783;
		Pos[1] = -12.810158;
		Pos[2] = 160.031250;
		Radius = 213.8 + 80.0;
	}
	else if ( StrEqual( mapName, "c10m5_houseboat", false ))
	{
		Pos[0] = 1918.031250;
		Pos[1] = 4799.968750;
		Pos[2] = -63.968750;
		Radius = 354.6 + 55.0;
	}
	//
	else if ( StrEqual( mapName, "c11m2_offices", false ))
	{
		Pos[0] = 5049.384277;
		Pos[1] = 2552.031250;
		Pos[2] = 48.031250;
		Radius = 433.0 + 45.0;
	}
	else if ( StrEqual( mapName, "c11m3_garage", false ))
	{
		Pos[0] = -5487.250000;
		Pos[1] = -3197.968750;
		Pos[2] = 16.031250;
		Radius = 322.5 + 80.0;
	}
	else if ( StrEqual( mapName, "c11m4_terminal", false ))
	{
		Pos[0] = -495.968750;
		Pos[1] = 3598.897705;
		Pos[2] = 296.031250;
		Radius = 237.1 + 5.0;
	}
	else if ( StrEqual( mapName, "c11m5_runway", false ))
	{
		Pos[0] = -6753.384277;
		Pos[1] = 12084.808593;
		Pos[2] = 152.031250;
		Radius = 402.0;
	}
	//
	else if ( StrEqual( mapName, "c12m2_traintunnel", false ))
	{
		Pos[0] = -6671.968750;
		Pos[1] = -6898.817871;
		Pos[2] = 348.031250;
		Radius = 399.6 + 20.0;
	}
	else if ( StrEqual( mapName, "c12m3_bridge", false ))
	{
		Pos[0] = -1087.968750;
		Pos[1] = -10264.031250;
		Pos[2] = -63.968750;
		Radius = 309.6 + 50.0;
	}
	else if ( StrEqual( mapName, "c12m4_barn", false ))
	{
		Pos[0] = 7667.998046;
		Pos[1] = -11459.968750;
		Pos[2] = 440.031250;
		Radius = 225.3 + 20.0;
	}
	else if ( StrEqual( mapName, "c12m5_cornfield", false ))
	{
		Pos[0] = 10477.929687;
		Pos[1] = -608.488159;
		Pos[2] = -28.968750;
		Radius = 451.5;
	}
	//
	else if ( StrEqual( mapName, "c13m2_southpinestream", false ))
	{
		Pos[0] = 8878.442382;
		Pos[1] = 7256.321289;
		Pos[2] = 496.031250;
		Radius = 539.4 + 50.0;
	}
	else if ( StrEqual( mapName, "c13m3_memorialbridge", false ))
	{
		Pos[0] = -4483.968750;
		Pos[1] = -5191.672363;
		Pos[2] = 96.031250;
		Radius = 328.8 + 10.0;
	}
	else if ( StrEqual( mapName, "c13m4_cutthroatcreek", false ))
	{
		Pos[0] = -3595.291748;
		Pos[1] = -9349.568359;
		Pos[2] = 360.031250;
		Radius = 477.1 + 190.0;
	}
	
	if ( Radius > 0.0 )
	{
		refPos[0] = Pos[0];
		refPos[1] = Pos[1];
		refPos[2] = Pos[2];
		g_fRadius = Radius;
		return true;
	}
	return false;
}

bool FindRescueReference( float refPos2[3] )
{
	float Distance = 0.0;
	float Pos2[3];
	char mapName2[128];
	GetCurrentMap( mapName2, sizeof( mapName2 ));
	
	if ( StrEqual( mapName2, "c1m1_hotel", false ))
	{
		Pos2[0] = 2271.968750;
		Pos2[1] = 4517.132324;
		Pos2[2] = 1184.031250;
		Distance = 454.407470;
	}
	else if ( StrEqual( mapName2, "c1m2_streets", false ))
	{
		Pos2[0] = -7208.031250;
		Pos2[1] = -4771.968750;
		Pos2[2] = 384.281250;
		Distance = 354.704742;
	}
	else if ( StrEqual( mapName2, "c1m3_mall", false ))
	{
		Pos2[0] = -2050.689453;
		Pos2[1] = -4709.358398;
		Pos2[2] = 536.031250;
		Distance = 211.567321;
	}

	else if ( StrEqual( mapName2, "c2m1_highway", false ))
	{
		Pos2[0] = -808.031250;
		Pos2[1] = -2625.709472;
		Pos2[2] = -1083.968750;
		Distance = 256.133392;
	}
	else if ( StrEqual( mapName2, "c2m2_fairgrounds", false ))
	{
		Pos2[0] = -5077.301757;
		Pos2[1] = -5523.968750;
		Pos2[2] = -63.968750;
		Distance = 752.387634;
	}
	else if ( StrEqual( mapName2, "c2m3_coaster", false ))
	{
		Pos2[0] = -5491.968750;
		Pos2[1] = 1633.576660;
		Pos2[2] = 4.031250;
		Distance = 498.143829;
	}
	else if ( StrEqual( mapName2, "c2m4_barns", false ))
	{
		Pos2[0] = -1044.831665;
		Pos2[1] = 2028.873657;
		Pos2[2] = -255.969268;
		Distance = 456.138122;
	}

	else if ( StrEqual( mapName2, "c3m1_plankcountry", false ))
	{
		Pos2[0] = -2664.090820;
		Pos2[1] = 209.512680;
		Pos2[2] = 56.031250;
		Distance = 498.324707;
	}
	else if ( StrEqual( mapName2, "c3m2_swamp", false ))
	{
		Pos2[0] = 7514.342285;
		Pos2[1] = -1072.968750;
		Pos2[2] = 171.226287;
		Distance = 293.506347;
	}
	else if ( StrEqual( mapName2, "c3m3_shantytown", false ))
	{
		Pos2[0] = 5082.641601;
		Pos2[1] = -3681.031250;
		Pos2[2] = 383.435241;
		Distance = 218.058654;
	}

	else if ( StrEqual( mapName2, "c4m1_milltown_a", false ))
	{
		Pos2[0] = 4039.993652;
		Pos2[1] = -1711.968750;
		Pos2[2] = 264.567199;
		Distance = 281.843566;
	}
	else if ( StrEqual( mapName2, "c4m2_sugarmill_a", false ))
	{
		Pos2[0] = -1859.503051;
		Pos2[1] = -13775.684570;
		Pos2[2] = 130.281250;
		Distance = 226.429122;
	}
	else if ( StrEqual( mapName2, "c4m3_sugarmill_b", false ))
	{
		Pos2[0] = 3794.906982;
		Pos2[1] = -1585.031250;
		Pos2[2] = 232.281250;
		Distance = 410.023742;
	}
	else if ( StrEqual( mapName2, "c4m4_milltown_b", false ))
	{
		Pos2[0] = -3329.052734;
		Pos2[1] = 7959.712890;
		Pos2[2] = 158.421661;
		Distance = 480.293243;
	}
	
	else if ( StrEqual( mapName2, "c5m1_waterfront", false ))
	{
		Pos2[0] = -4606.271972;
		Pos2[1] = -1407.968750;
		Pos2[2] = -308.047637;
		Distance = 870.384521;
	}
	else if ( StrEqual( mapName2, "c5m2_park", false ))
	{
		Pos2[0] = -9887.968750;
		Pos2[1] = -7910.847167;
		Pos2[2] = -255.968750;
		Distance = 376.437896;
	}
	else if ( StrEqual( mapName2, "c5m3_cemetery", false ))
	{
		Pos2[0] = 7311.395019;
		Pos2[1] = -9687.968750;
		Pos2[2] = 104.031250;
		Distance = 229.356216;
	}
	else if ( StrEqual( mapName2, "c5m4_quarter", false ))
	{
		Pos2[0] = 1518.990112;
		Pos2[1] = -3703.968750;
		Pos2[2] = 99.226280;
		Distance = 347.434814;
	}

	else if ( StrEqual( mapName2, "c6m1_riverbank", false ))
	{
		Pos2[0] = -4275.815429;
		Pos2[1] = 1400.897949;
		Pos2[2] = 728.031250;
		Distance = 349.816955;
	}
	else if ( StrEqual( mapName2, "c6m2_bedlam", false ))
	{
		Pos2[0] = 11415.968750;
		Pos2[1] = 5063.603027;
		Pos2[2] = -631.968750;
		Distance = 333.794189;
	}

	else if ( StrEqual( mapName2, "c7m1_docks", false ))
	{
		Pos2[0] = 1760.031250;
		Pos2[1] = 2459.968750;
		Pos2[2] = 202.315383;
		Distance = 306.872619;
	}
	else if ( StrEqual( mapName2, "c7m2_barge", false ))
	{
		Pos2[0] = -11295.968750;
		Pos2[1] = 3127.282958;
		Pos2[2] = 208.430130;
		Distance = 402.977722;
	}

	else if ( StrEqual( mapName2, "c8m1_apartment", false ))
	{
		Pos2[0] = 2883.323974;
		Pos2[1] = 2886.820556;
		Pos2[2] = -239.968750;
		Distance = 464.966796;
	}
	else if ( StrEqual( mapName2, "c8m2_subway", false ))
	{
		Pos2[0] = 10938.594726;
		Pos2[1] = 4665.031250;
		Pos2[2] = 16.031250;
		Distance = 262.275207;
	}
	else if ( StrEqual( mapName2, "c8m3_sewers", false ))
	{
		Pos2[0] = 12288.015625;
		Pos2[1] = 12357.073242;
		Pos2[2] = 52.233203;
		Distance = 158.694229;
	}
	else if ( StrEqual( mapName2, "c8m4_interior", false ))
	{
		Pos2[0] = 11296.757812;
		Pos2[1] = 14928.592773;
		Pos2[2] = 5574.681152;
		Distance = 427.455474;
	}

	else if ( StrEqual( mapName2, "c9m1_alleys", false ))
	{
		Pos2[0] = 297.169769;
		Pos2[1] = -1250.517822;
		Pos2[2] = -175.968750;
		Distance = 304.196716;
	}

	else if ( StrEqual( mapName2, "c10m1_caves", false ))
	{
		Pos2[0] = -10977.627929;
		Pos2[1] = -4816.031250;
		Pos2[2] = 416.031250;
		Distance = 426.586914;
	}
	else if ( StrEqual( mapName2, "c10m2_drainage", false ))
	{
		Pos2[0] = -8623.968750;
		Pos2[1] = -5560.515625;
		Pos2[2] = -30.968748;
		Distance = 428.623504;
	}
	else if ( StrEqual( mapName2, "c10m3_ranchhouse", false ))
	{
		Pos2[0] = -2564.681396;
		Pos2[1] = -96.723190;
		Pos2[2] = 160.031250;
		Distance = 153.321487;
	}
	else if ( StrEqual( mapName2, "c10m4_mainstreet", false ))
	{
		Pos2[0] = 1429.064331;
		Pos2[1] = -5313.519042;
		Pos2[2] = -55.968750;
		Distance = 345.105133;
	}

	else if ( StrEqual( mapName2, "c11m1_greenhouse", false ))
	{
		Pos2[0] = 5423.968750;
		Pos2[1] = 2684.568359;
		Pos2[2] = 48.031250;
		Distance = 443.961273;
	}
	else if ( StrEqual( mapName2, "c11m2_offices", false ))
	{
		Pos2[0] = 8096.787597;
		Pos2[1] = 6235.245605;
		Pos2[2] = 16.031250;
		Distance = 322.922729;
	}
	else if ( StrEqual( mapName2, "c11m3_garage", false ))
	{
		Pos2[0] = -399.031250;
		Pos2[1] = 3657.404296;
		Pos2[2] = 296.031250;
		Distance = 241.146347;
	}
	else if ( StrEqual( mapName2, "c11m4_terminal", false ))
	{
		Pos2[0] = 3615.411865;
		Pos2[1] = 4497.607910;
		Pos2[2] = 132.270767;
		Distance = 469.571411;
	}

	else if ( StrEqual( mapName2, "c12m1_hilltop", false ))
	{
		Pos2[0] = -6528.145507;
		Pos2[1] = -6641.368652;
		Pos2[2] = 348.031250;
		Distance = 356.717926;
	}
	else if ( StrEqual( mapName2, "c12m2_traintunnel", false ))
	{
		Pos2[0] = -833.807983;
		Pos2[1] = -10373.415039;
		Pos2[2] = -40.482017;
		Distance = 282.858428;
	}
	else if ( StrEqual( mapName2, "c12m3_bridge", false ))
	{
		Pos2[0] = 7713.733886;
		Pos2[1] = -11276.980468;
		Pos2[2] = 440.031250;
		Distance = 238.389389;
	}
	else if ( StrEqual( mapName2, "c12m4_barn", false ))
	{
		Pos2[0] = 10414.402343;
		Pos2[1] = -186.478363;
		Pos2[2] = -28.968750;
		Distance = 450.704772;
	}

	else if ( StrEqual( mapName2, "c13m1_alpinecreek", false ))
	{
		Pos2[0] = 1121.677124;
		Pos2[1] = -1263.968750;
		Pos2[2] = 352.031250;
		Distance = 623.190856;
	}
	else if ( StrEqual( mapName2, "c13m2_southpinestream", false ))
	{
		Pos2[0] = 465.807983;
		Pos2[1] = 8842.041992;
		Pos2[2] = -368.968750;
		Distance = 319.544830;
	}
	else if ( StrEqual( mapName2, "c13m3_memorialbridge", false ))
	{
		Pos2[0] = 6089.592285;
		Pos2[1] = -6511.964843;
		Pos2[2] = 386.031250;
		Distance = 193.981369 + 485.091186;
	}
	
	if ( Distance > 0.0 )
	{
		refPos2[0]	= Pos2[0];
		refPos2[1]	= Pos2[1];
		refPos2[2]	= Pos2[2];
		g_fRadius2	= Distance;
		return true;
	}
	return false;
}

void CreateReference( float myRef[3] )
{
	// Don't tell anyone this is Developer reference for future debug.. Ssshh..
	// Make it random so player won't notice it.. again, Ssshh..
	if ( !IsModelPrecached( REFERENCE_1 ))	PrecacheModel( REFERENCE_1 );
	if ( !IsModelPrecached( REFERENCE_2 ))	PrecacheModel( REFERENCE_2 );
	if ( !IsModelPrecached( REFERENCE_3 ))	PrecacheModel( REFERENCE_3 );
	
	int model = CreateEntityByName( "prop_dynamic_override" );
	if ( model != -1 )
	{
		char Mdl[128];
		switch( GetRandomInt( 1, 3 ))
		{
			case 1: { Mdl = REFERENCE_1;	}
			case 2: { Mdl = REFERENCE_2;	}
			case 3: { Mdl = REFERENCE_3;	}
		}
		DispatchKeyValue( model, "model", Mdl );  
		DispatchKeyValueVector( model, "origin", myRef );
		DispatchSpawn( model );
	}
}

int FindRescueDoor()
{
	float doorPos[3];
	int ent = -1;
	while (( ent = FindEntityByClassname( ent, "prop_door_rotating_checkpoint")) != -1)
	{
		GetEntPropVector( ent, Prop_Send, "m_vecOrigin", doorPos );
		if ( GetVectorDistance( g_fInfoPos2, doorPos ) <= ( g_fRadius2 + 30.0 ))
		{
			return ent;
		}
	}
	return -1;
}

// Because I love you.
void DealDamage( int victim, int damage, int attacker = 0, int dmg_type = DMG_GENERIC, const char[] weapon )
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

int FindTeleportEntity()
{
	int i;
	
	// Option 1
	for ( i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && IsPlayerAlive( i ) && GetClientTeam( i ) == TEAM_INFECTED && IsTank( i ))
		{
			return i;
		}
	}
	
	// Option 2
	int ent = -1;
	while (( ent = FindEntityByClassname( ent, "witch")) != -1)
	{
		return ent;
	}
	
	// Option 3
	for ( i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && IsPlayerAlive( i ) && GetClientTeam( i ) == TEAM_INFECTED )
		{
			return i;
		}
	}
	
	return -1;
}

int FindTeleportSurvivor()
{
	int sur = -1;

	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && IsPlayerAlive( i ) && GetClientTeam( i ) == TEAM_SURVIVOR )
		{
			GetEntPropVector( i, Prop_Send, "m_vecOrigin", g_fCampPos );
			if ( GetVectorDistance( g_fInfoPos, g_fCampPos ) > ( g_fRadius + g_fCvar_Radius ))
			{
				sur = i;
				break;
			}
		}
	}
	return sur;
}

void TeleportPlayer( int caller, int subject )
{
	float Loc[3];
	GetEntPropVector( subject, Prop_Send, "m_vecOrigin", Loc );
	Loc[2] += 5.0;
	TeleportEntity( caller, Loc, NULL_VECTOR, NULL_VECTOR );
	EmitSoundToClient( caller, TELEPORT_SND );
}

bool IsValidSurvivor( int client )
{
	return ( client > 0 && client <= MaxClients && IsClientInGame( client ) && GetClientTeam( client ) == TEAM_SURVIVOR );
}

bool IsTank( int client )
{
	return ( GetEntProp( client, Prop_Send, "m_zombieClass") == 8 );
}

int GetHumanSpectator( int bot )
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

