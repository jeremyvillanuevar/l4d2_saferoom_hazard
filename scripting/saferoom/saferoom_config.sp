
enum //=== Constructor Move Type =======//
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

enum //=== Map Vector Config ==========//
{
	VEC_POS,
	VEC_ANG,
	VEC_MIN,
	VEC_MAX,
	VEC_LEN
}

enum //=== Global Timer ==============//
{
	TIMER_GLOBAL,
	TIMER_RESCUE,
	TIMER_LASER1,
	TIMER_LASER2,
	TIMER_LENGTH
}

enum //=== Client Room State =========//
{
	ROOM_STATE_OUTDOOR,
	ROOM_STATE_SPAWN,
	ROOM_STATE_RESCUE,
	ROOM_STATE_LEN
}

enum //=== Dummy Model ================//
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

enum struct EntityManager
{
	float	fPos_Spawn[3];
	float	fPos_Rescue[3];
	float	fBoxPos[3];
	float	fBoxAng[3];
	float	fBoxMin[3];
	float	fBoxMax[3];
	float	fCPRotate;
	bool	bIsCfgLoaded;
	int		iDoor_Spawn;
	int		iDoor_Rescue;
	int		iRefs_Spawn;
	int		iRefs_Rescue;
	int		iEntTrigger;
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





