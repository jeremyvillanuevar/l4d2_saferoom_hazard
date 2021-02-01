
//=== Constructor Move Type =======//
enum
{
	MOVE_DELETE,
	MOVE_THICK,
	MOVE_WIDTH,
	MOVE_SIDE1,
	MOVE_SIDE2,
	MOVE_HEIGHT,
	MOVE_ANGLE,
	MOVE_LENGTH
}

//=== Map Vector Config ==========//
enum 
{
	VEC_POS,
	VEC_ANG,
	VEC_MIN,
	VEC_MAX,
	VEC_LEN
}

//=== Dummy Model ================//
enum
{
	MDL_REFERANCE1,
	MDL_REFERANCE2,
	MDL_REFERANCE3,
	MDL_SENSOR1,
	MDL_LENGTH
}
char g_sDummyModel[MDL_LENGTH][] =
{
	"models/props_fairgrounds/elephant.mdl",
	"models/props_fairgrounds/alligator.mdl",
	"models/props_fairgrounds/giraffe.mdl",
	"models/editor/overlay_helper.mdl",
};

//=== Client Room State =========//
enum
{
	ROOM_STATE_OUTDOOR,
	ROOM_STATE_SPAWN,
	ROOM_STATE_RESCUE,
	ROOM_STATE_LEN
}

enum struct ClientManager
{
	int  iSpawnCount;
	int	 iStateRoom;
	bool bIsSoundBurn;
	bool bIsUsingDefib;
	bool bIsJoinGame;
	
	void Reset()
	{
		this.iSpawnCount 		= 0;
		this.iStateRoom 		= ROOM_STATE_OUTDOOR;
		this.bIsSoundBurn		= false;
		this.bIsUsingDefib	= false;
		this.bIsJoinGame		= true;
	}
}
ClientManager g_CMClient[MAXPLAYERS+1];

//=== Global Timer ==============//
enum
{
	TIMER_GLOBAL,
	TIMER_RESCUE,
	TIMER_LASER1,
	TIMER_LASER2,
	TIMER_LENGTH
}

enum struct EntityManager
{
	float	fPos_Spawn[3];
	float	fPos_Rescue[3];
	float	fBoxPos[3];
	float	fBoxAng[3];
	float	fBoxMin[3];
	float	fBoxMax[3];
	bool	bIsCfgLoaded;
	int		iDoor_Spawn;
	int		iDoor_Rescue;
	int		iRefs_Spawn;
	int		iRefs_Rescue;
	int		iEntTrigger;
	int		iIndexRotate;
	int		iIndexModel;
	bool	bIsRound_Finale;
	bool	bIsRound_End;
	bool	bIsDamage_Rescue;
	bool	bIsFindDoorInit;
	
	Handle	hTimer[TIMER_LENGTH];
	char	sCurrentMap[PLATFORM_MAX_PATH];
	
	void Reset()
	{
		this.fPos_Spawn			= view_as<float>({ 0.0, 0.0, 0.0 });
		this.fPos_Rescue		= view_as<float>({ 0.0, 0.0, 0.0 });
		
		this.iDoor_Spawn 		= -1;
		this.iDoor_Rescue 		= -1;
		this.iRefs_Spawn 		= -1;
		this.iRefs_Rescue 		= -1;
		this.iEntTrigger 		= -1;
		this.iIndexRotate		= -1;
		this.iIndexModel 		= -1;
		
		this.bIsRound_Finale 	= false;
		this.bIsRound_End 		= true;
		this.bIsDamage_Rescue	= false;
		this.bIsFindDoorInit	= false;
		
		for( int i = 0; i < TIMER_LENGTH; i++ )
		{
			this.hTimer[i] = null;
		}
	}
	
	void TimerKill()
	{
		for( int i = 0; i < TIMER_LENGTH; i++ )
		{
			delete this.hTimer[i];
		}
	}
}
EntityManager g_EMEntity;

//=== Rescue door rotation ======//
char  g_sCheckpointMapName[][] =
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

float g_fCheckpointDoorAngle[] =
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





