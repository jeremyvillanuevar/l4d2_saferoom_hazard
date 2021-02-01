
//=== Constructor Movement =======//
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
	bool bIsUseDefib;
	bool bIsJoinGame;
	
	void Reset()
	{
		this.iSpawnCount 	= 0;
		this.iStateRoom 	= ROOM_STATE_OUTDOOR;
		this.bIsSoundBurn	= false;
		this.bIsUseDefib	= false;
		this.bIsJoinGame	= true;
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
	int		iDoor_Spawn;
	int		iDoor_Rescue;
	int		iRefs_Spawn;
	int		iRefs_Rescue;
	int		iEntTrigger;
	int		iIndexRotate;
	int		iIndexSpawn;
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
		this.iIndexSpawn 		= -1;
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


//== Special Spawn door offsets ==//
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

//=== Map Vector Config ==========//
enum 
{
	VEC_POS,
	VEC_ANG,
	VEC_MIN,
	VEC_MAX,
	VEC_LEN
}

char  g_sMapConfig[][] = 
{
	"c1m1_hotel",
	"c1m2_streets",
	"c1m3_mall",
	"c1m4_atrium",
	"c2m1_highway",
	"c2m2_fairgrounds",
	"c2m3_coaster",
	"c2m4_barns",
	"c2m5_concert",			//<< rotation 
	"c3m1_plankcountry",	//<< rotation 
	"c3m2_swamp",
	"c3m3_shantytown",
	"c3m4_plantation",
	"c4m1_milltown_a",
	"c4m2_sugarmill_a",
	"c4m3_sugarmill_b",
	"c4m4_milltown_b",
	"c4m5_milltown_escape",
	"c5m1_waterfront",
	"c5m2_park",
	"c5m3_cemetery",
	"c5m4_quarter",
	"c5m5_bridge",
	"c6m1_riverbank",
	"c6m2_bedlam",
	"c6m3_port",
	"c7m1_docks",
	"c7m2_barge",
	"c7m3_port",
	"c8m1_apartment",
	"c8m2_subway",
	"c8m3_sewers",
	"c8m4_interior",
	"c8m5_rooftop",
	"c9m1_alleys",
	"c9m2_lots",
	"c10m1_caves",
	"c10m2_drainage",
	"c10m3_ranchhouse",
	"c10m4_mainstreet",
	"c10m5_houseboat",
	"c11m1_greenhouse",
	"c11m2_offices",
	"c11m3_garage",
	"c11m4_terminal",
	"c11m5_runway",
	"c12m1_hilltop",
	"c12m2_traintunnel",
	"c12m3_bridge",
	"c12m4_barn",
	"c12m5_cornfield",
	"c13m1_alpinecreek",
	"c13m2_southpinestream",
	"c13m3_memorialbridge",
	"c13m4_cutthroatcreek",
};

float g_fMapsVec[][][] = 
{
	{
		// c1m1_hotel
		{ 582.85, 5801.80, 2848.00 },	// position
		{ 0.00, 0.00, 0.00 },			// angle
		{ -190.0, -430.0, 0.0 },		// vecMins
		{ 190.0, 430.0, 200.0 }			// vecMaxs
	},
	{
		// c1m2_streets
		{ 2439.92, 5122.20, 448.00 },
		{ 0.00, 0.00, 0.00 },
		{ -210.0, -180.0, 0.0 },
		{ 210.0, 180.0, 200.0 }
	},
	{
		// c1m3_mall
		{ 6760.55, -1428.20, 24.00 },
		{ 0.00, 0.00, 0.00 },
		{ -260.0, -100.0, 0.0 },
		{ 260.0, 100.0, 200.0 }
	},
	{
		// c1m4_atrium
		{ -2045.70, -4639.00, 536.00 },
		{ 0.00, 0.00, 0.00 },
		{ -180.0, -130.0, 0.0 },
		{ 180.0, 130.0, 200.0 }
	},
	{
		// c2m1_highway
		{ 10855.0, 7868.0, -553.0 },
		{ 0.00, 0.00, 0.00 },
		{ -350.0, -250.0, 0.0 },
		{ 350.0, 250.0, 200.0 }
	},
	{
		// c2m2_fairgrounds
		{ 1651.65, 2791.30, 4.00 },
		{ 0.00, 0.00, 0.00 },
		{ -90.0, -210.0, 0.0 },
		{ 90.0, 210.0, 125.0 }
	},
	{
		// c2m3_coaster
		{ 4221.14, 2054.27, -63.96 },
		{ 0.00, 0.00, 0.00 },
		{ -380.0, -120.0, 0.0 },
		{ 380.0, 120.0, 220.0 }
	},
	{
		// c2m4_barns
		{ 3121.81, 3587.04, -187.96 },
		{ 0.00, 0.00, 0.00 },
		{ -250.00, -340.00, 0.00 },
		{ 250.00, 340.00, 160.00 }
	},
	{
		// c2m5_concert
		{ -825.85, 2210.85, -256.00 },
		{ 0.00, 0.00, 0.00 },
		{ -270.00, -210.00, 0.00 },
		{ 270.00, 210.00, 150.00 }
	},
	{
		// c3m1_plankcountry
		{ -12547.90, 10485.10, 240.00 },
		{ 0.00, 0.00, 0.00 },
		{ -190.00, -270.00, 0.00 },
		{ 190.00, 270.00, 120.00 }
	},
	{
		// c3m2_swamp
		{ -8180.17, 7508.09, 12.03 },
		{ 0.00, 0.00, 0.00 },
		{ -70.00, -250.00, 0.00 },
		{ 70.00, 250.00, 110.00 }
	},
	{
		// c3m3_shantytown
		{ -5798.24, 2131.63, 136.03 },
		{ 0.00, 0.00, 0.00 },
		{ -210.00, -140.00, 0.00 },
		{ 210.00, 140.00, 140.00 }
	},
	{
		// c3m4_plantation
		{ -5041.79, -1669.81, -96.81 },
		{ 0.00, 0.00, 0.00 },
		{ -160.00, -100.00, 0.00 },
		{ 160.00, 100.00, 190.00 }
	},
	{
		// c4m1_milltown_a
		{ -6777.68, 7601.40, 96.65 },
		{ 0.00, 0.00, 0.00 },
		{ -410.00, -1000.00, 0.00 },
		{ 410.00, 1000.00, 310.00 }
	},
	{
		// c4m2_sugarmill_a
		{ 3737.32, -1768.49, 104.53 },
		{ 0.00, 0.00, 0.00 },
		{ -230.00, -200.00, 0.00 },
		{ 230.00, 200.00, 250.00 }
	},
	{
		// c4m3_sugarmill_b
		{ -1788.34, -13695.41, 130.03 },
		{ 0.00, 0.00, 0.00 },
		{ -100.00, -110.00, 0.00 },
		{ 100.00, 110.00, 120.00 }
	},
	{
		// c4m4_milltown_b
		{ 3982.69, -1636.86, 104.28 },
		{ 0.00, 0.00, 0.00 },
		{ -230.00, -190.00, 0.00 },
		{ 230.00, 190.00, 250.00 }
	},
	{
		// c4m5_milltown_escape
		{ -3271.28, 7954.07, 120.03 },
		{ 0.00, 0.00, 0.00 },
		{ -400.00, -190.00, 0.00 },
		{ 400.00, 190.00, 150.00 }
	},
	{
		// c5m1_waterfront
		{ 779.48, 545.59, -481.96 },
		{ 0.00, 0.00, 0.00 },
		{ -140.00, -630.00, 0.00 },
		{ 140.00, 630.00, 270.00 }
	},
	{
		// c5m2_park
		{ -4202.95, -1268.66, -343.96 },
		{ 0.00, 0.00, 0.00 },
		{ -440.00, -150.00, 0.00 },
		{ 440.00, 150.00, 300.00 }
	},
	{
		// c5m3_cemetery
		{ 6396.55, 8427.28, 0.03 },
		{ 0.00, 0.00, 0.00 },
		{ -170.00, -230.00, 0.00 },
		{ 170.00, 230.00, 170.00 }
	},
	{
		// c5m4_quarter
		{ -3205.47, 4862.40, 68.03 },
		{ 0.00, 0.00, 0.00 },
		{ -230.00, -110.00, 0.00 },
		{ 230.00, 110.00, 150.00 }
	},
	{
		// c5m5_bridge
		{ -12032.78, 5819.51, 128.03 },
		{ 0.00, 0.00, 0.00 },
		{ -170.00, -170.00, 0.00 },
		{ 170.00, 170.00, 560.00 }
	},
	{
		// c6m1_riverbank
		{ 954.52, 3864.39, 93.85 },
		{ 0.00, 0.00, 0.00 },
		{ -230.00, -780.00, 0.00 },
		{ 230.00, 780.00, 200.00 }
	},
	{
		// c6m2_bedlam
		{ 3085.83, -1214.43, -295.96 },
		{ 0.00, 0.00, 0.00 },
		{ -170.00, -110.00, 0.00 },
		{ 170.00, 110.00, 130.00 }
	},
	{
		// c6m3_port
		{ -2385.49, -463.99, -255.96 },
		{ 0.00, 0.00, 0.00 },
		{ -150.00, -180.00, 0.00 },
		{ 150.00, 180.00, 240.00 }
	},
	{
		// c7m1_docks
		{ 13353.96, 2719.08, 32.54 },
		{ 0.00, 0.00, 0.00 },
		{ -660.00, -290.00, 0.00 },
		{ 660.00, 290.00, 200.00 }
	},
	{
		// c7m2_barge
		{ 10727.62, 2430.83, 176.03 },
		{ 0.00, 0.00, 0.00 },
		{ -150.00, -110.00, 0.00 },
		{ 150.00, 110.00, 140.00 }
	},
	{
		// c7m3_port
		{ 1151.40, 3227.69, 169.00 },
		{ 0.00, 0.00, 0.00 },
		{ -200.00, -150.00, 0.00 },
		{ 200.00, 150.00, 190.00 }
	},
	{
		// c8m1_apartment
		{ 1922.53, 1128.65, 432.03 },
		{ 0.00, 0.00, 0.00 },
		{ -370.00, -340.00, 0.00 },
		{ 370.00, 340.00, 350.00 }
	},
	{
		// c8m2_subway
		{ 2939.04, 3080.09, 16.03 },
		{ 0.00, 0.00, 0.00 },
		{ -100.00, -240.00, 0.00 },
		{ 100.00, 240.00, 120.00 }
	},
	{
		// c8m3_sewers
		{ 10933.85, 4750.88, 16.03 },
		{ 0.00, 0.00, 0.00 },
		{ -150.00, -120.00, 0.00 },
		{ 150.00, 120.00, 120.00 }
	},
	{
		// c8m4_interior
		{ 12368.82, 12430.00, 16.03 },
		{ 0.00, 0.00, 0.00 },
		{ -100.00, -240.00, 0.00 },
		{ 100.00, 240.00, 120.00 }
	},
	{
		// c8m5_rooftop
		{ 5474.04, 8420.84, 5536.03 },
		{ 0.00, 0.00, 0.00 },
		{ -200.00, -160.00, 0.00 },
		{ 200.00, 160.00, 120.00 }
	},
	{
		// c9m1_alleys
		{ -9914.10, -8568.14, -6.92 },
		{ 0.00, 0.00, 0.00 },
		{ -380.00, -370.00, 0.00 },
		{ 380.00, 370.00, 200.00 }
	},
	{
		// c9m2_lots
		{ 279.30, -1295.21, -175.96 },
		{ 0.00, 0.00, 0.00 },
		{ -150.00, -170.00, 0.00 },
		{ 150.00, 170.00, 120.00 }
	},
	{
		// c10m1_caves
		{ -11809.01, -14728.80, -210.99 },
		{ 0.00, 0.00, 0.00 },
		{ -600.00, -360.00, 0.00 },
		{ 600.00, 360.00, 380.00 }
	},
	{
		// c10m2_drainage
		{ -11198.41, -8991.14, -591.96 },
		{ 0.00, 0.00, 0.00 },
		{ -260.00, -150.00, 0.00 },
		{ 260.00, 150.00, 280.00 }
	},
	{
		// c10m3_ranchhouse
		{ -8432.55, -5550.97, -24.96 },
		{ 0.00, 0.00, 0.00 },
		{ -230.00, -50.00, 0.00 },
		{ 230.00, 50.00, 110.00 }
	},
	{
		// c10m4_mainstreet
		{ -3065.61, 22.79, 160.03 },
		{ 0.00, 0.00, 0.00 },
		{ -170.00, -150.00, 0.00 },
		{ 170.00, 150.00, 360.00 }
	},
	{
		// c10m5_houseboat
		{ 2021.90, 4663.65, -63.96 },
		{ 0.00, 0.00, 0.00 },
		{ -200.00, -150.00, 0.00 },
		{ 200.00, 150.00, 120.00 }
	},
	{
		// c11m1_greenhouse
		{ 6644.38, -548.72, 768.03 },
		{ 0.00, 0.00, 0.00 },
		{ -350.00, -340.00, 0.00 },
		{ 350.00, 340.00, 240.00 }
	},
	{
		// c11m2_offices
		{ 5226.05, 2708.22, 48.03 },
		{ 0.00, 0.00, 0.00 },
		{ -220.00, -160.00, 0.00 },
		{ 220.00, 160.00, 180.00 }
	},
	{
		// c11m3_garage
		{ -5371.70, -3092.58, 16.03 },
		{ 0.00, 0.00, 0.00 },
		{ -170.00, -180.00, 0.00 },
		{ 170.00, 180.00, 260.00 }
	},
	{
		// c11m4_terminal
		{ -406.92, 3560.91, 296.03 },
		{ 0.00, 0.00, 0.00 },
		{ -100.00, -130.00, 0.00 },
		{ 100.00, 130.00, 190.00 }
	},
	{
		// c11m5_runway
		{ -6586.96, 12041.95, 150.75 },
		{ 0.00, 0.00, 0.00 },
		{ -220.00, -110.00, 0.00 },
		{ 220.00, 110.00, 140.00 }
	},
	{
		// c12m1_hilltop
		{ -8115.71, -15162.32, 277.02 },
		{ 0.00, 0.00, 0.00 },
		{ -480.00, -530.00, 0.00 },
		{ 480.00, 530.00, 210.00 }
	},
	{
		// c12m2_traintunnel
		{ -6513.84, -6795.21, 348.03 },
		{ 0.00, 0.00, 0.00 },
		{ -170.00, -170.00, 0.00 },
		{ 170.00, 170.00, 120.00 }
	},
	{
		// c12m3_bridge
		{ -955.93, -10382.31, -63.96 },
		{ 0.00, 0.00, 0.00 },
		{ -140.00, -120.00, 0.00 },
		{ 140.00, 120.00, 160.00 }
	},
	{
		// c12m4_barn
		{ 7705.90, -11361.32, 440.03 },
		{ 0.00, 0.00, 0.00 },
		{ -160.00, -110.00, 0.00 },
		{ 160.00, 110.00, 210.00 }
	},
	{
		// c12m5_cornfield
		{ 10443.42, -393.26, -28.96 },
		{ 0.00, 0.00, 0.00 },
		{ -90.00, -230.00, 0.00 },
		{ 90.00, 230.00, 110.00 }
	},
	{
		// c13m1_alpinecreek
		{ -3008.64, -646.04, 64.00 },
		{ 0.00, 0.00, 0.00 },
		{ -230.00, -510.00, 0.00 },
		{ 230.00, 510.00, 240.00 }
	},
	{
		// c13m2_southpinestream
		{ 8623.11, 7325.53, 496.03 },
		{ 0.00, 0.00, 0.00 },
		{ -260.00, -300.00, 0.00 },
		{ 260.00, 300.00, 140.00 }
	},
	{
		// c13m3_memorialbridge
		{ -4328.56, -5158.04, 96.03 },
		{ 0.00, 0.00, 0.00 },
		{ -160.00, -130.00, 0.00 },
		{ 160.00, 130.00, 120.00 }
	},
	{
		// c13m4_cutthroatcreek
		{ -3389.23, -9122.20, 360.03 },
		{ 0.00, 0.00, 0.00 },
		{ -230.00, -240.00, 0.00 },
		{ 230.00, 240.00, 130.00 }
	},
};


