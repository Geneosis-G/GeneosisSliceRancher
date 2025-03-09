class SliceRancher extends GGMutator
	config(Geneosis);

var array<GGGoat> mGoats;
var float timeElapsed;
var float managementTimer;
var float SRTimeElapsed;
var float spawnRemoveTimer;
var float spawnRadius;
var int minSliceCount;
var int maxSliceCount;

var bool mIsBlue;
var bool mIsYellow;
var bool mIsRed;
var vector mCurrentSpawnSpot;
var int mSpawnCountForSpot;
var int mMaxSpawnForSpot;

var array<GGNpcSlice> mSlicePool;
var float mTimeNotLookingForHide;
var array<GGNpcSlice> delayedRemovableNPCs;
var int mSliceNPCCount;
var array<int> mSliceNPCsToSpawnForPlayer;

struct SliceInfos
{
	var vector location;
	var bool isBlue;
	var bool isYellow;
	var bool isRed;
};

struct SliceParkInfos
{
	var int rancher;
	var vector location;
	var rotator rotation;
	var array<SliceInfos> slices;
};

struct SliceMapInfos
{
	var string mapName;
	var array<SliceParkInfos> parks;
};

var config array<SliceMapInfos> mMaps;
var int mMapIndex;

/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;

	goat = GGGoat( other );
	if( goat != none )
	{
		if( IsValidForPlayer( goat ) )
		{
			mGoats.AddItem(goat);
			if(mGoats.Length == 1)
			{
				SetTimer(3.f, false, NameOf(LoadSlicesInParks));
				SetTimer(10.f, true, NameOf(SaveSlicesInParks));
			}
		}
	}
	super.ModifyPlayer( other );
}

function LoadSlicesInParks()
{
	local int i, j;
	local SliceMapInfos newMap;
	local SlicePark tmpPark;
	local GGGoat parkOwner;
	local string mapName;

	mapName=class'WorldInfo'.static.GetWorldInfo().GetMapName();
	mMapIndex=mMaps.Find('mapName', mapName);
	if(mMapIndex == INDEX_NONE)//if this map was never visited before, create a new entry
	{
		mMapIndex=mMaps.Length;
		newMap.mapName=mapName;
		mMaps.AddItem(newMap);
		return;
	}

	for(i=0 ; i<mMaps[mMapIndex].parks.Length ; i++)
	{
		parkOwner=GetGoatForPlayer(mMaps[mMapIndex].parks[i].rancher);
		tmpPark=Spawn(class'SlicePark', parkOwner,, mMaps[mMapIndex].parks[i].location, mMaps[mMapIndex].parks[i].rotation,, true);
		tmpPark.InitPark(mMaps[mMapIndex].parks[i].rancher);

		for(j=0 ; j<mMaps[mMapIndex].parks[i].slices.Length ; j++)
		{
			SpawnSliceFromPool(	mMaps[mMapIndex].parks[i].slices[j].location,
								GetRandomRotation(),
								mMaps[mMapIndex].parks[i].slices[j].isBlue,
								mMaps[mMapIndex].parks[i].slices[j].isYellow,
								mMaps[mMapIndex].parks[i].slices[j].isRed);
		}
	}
}

function SaveSlicesInParks()
{
	local SliceParkInfos newPark;
	local SliceInfos newSlice;
	local SlicePark tmpPark;
	local GGNpcSlice tmpSlice;

	//WorldInfo.Game.Broadcast(self, "Saving...");
	mMaps[mMapIndex].parks.Length=0;
	foreach AllActors(class'SlicePark', tmpPark)
	{
		newPark.location=tmpPark.Location;
		newPark.rotation=tmpPark.Rotation;
		newPark.rancher=tmpPark.mRancher;
		newPark.slices.Length=0;
		foreach CollidingActors(class'GGNpcSlice', tmpSlice, tmpPark.mRadius, tmpPark.Location)
		{
			//WorldInfo.Game.Broadcast(self, tmpSlice $ " colliding");
			if(tmpPark.IsInPark(tmpSlice) && !tmpSlice.mIsTartine)
			{
				newSlice.location=tmpSlice.Location;
				newSlice.isBlue=tmpSlice.mIsBlue;
				newSlice.isYellow=tmpSlice.mIsYellow;
				newSlice.isRed=tmpSlice.mIsRed;
				newPark.slices.AddItem(newSlice);
				//WorldInfo.Game.Broadcast(self, tmpSlice $ " saved");
			}
		}
		mMaps[mMapIndex].parks.AddItem(newPark);
		//WorldInfo.Game.Broadcast(self, "Saved " $ tmpPark $ " with " $ newPark.slices.Length $ " slices");
	}

	SaveConfig();
}

function GGGoat GetGoatForPlayer(int playerSlot)
{
	local PlayerController pc;

	foreach WorldInfo.AllControllers( class'PlayerController', pc )
	{
		if( pc.IsLocalPlayerController() && pc.Pawn != none && GGLocalPlayer( pc.Player ).mPlayerSlot == playerSlot)
		{
			return GGGoat(pc.Pawn);
		}
	}

	return none;
}

simulated event Tick( float deltaTime )
{
	super.Tick( deltaTime );

	timeElapsed=timeElapsed+deltaTime;
	if(timeElapsed > managementTimer)
	{
		timeElapsed=0.f;
		//ManageSliceNPCs();
		GenerateSliceLists();
	}
	SRTimeElapsed=SRTimeElapsed+deltaTime;
	if(SRTimeElapsed > spawnRemoveTimer)
	{
		SRTimeElapsed=0.f;
		RemoveSliceFromList();//Remove first to get new Slices in the pool
		SpawnSliceFromList();
	}
}

function GenerateSliceLists()
{
	local GGNpcSlice sliceNPC;
	local array<int> sliceNPCsForPlayer;
	local bool isRemovable;
	local int nbPlayers, i;
	local vector dist;

	nbPlayers=mGoats.Length;
	mSliceNPCsToSpawnForPlayer.Length = 0;
	mSliceNPCsToSpawnForPlayer.Length = nbPlayers;
	sliceNPCsForPlayer.Length = nbPlayers;
	mSliceNPCCount=0;
	//Find all Slice close to each player
	foreach WorldInfo.AllPawns(class'GGNpcSlice', sliceNPC)
	{
		if(!CanBeRecycled(sliceNPC))
			continue;

		//WorldInfo.Game.Broadcast(self, SliceAI $ " possess " $ SliceNPC);
		mSliceNPCCount++;
		isRemovable=true;

		for(i=0 ; i<nbPlayers ; i++)
		{
			dist=mGoats[i].Location - sliceNPC.Location;
			if(VSize2D(dist) < spawnRadius)
			{
				sliceNPCsForPlayer[i]++;
				isRemovable=false;
			}
		}

		if(isRemovable)
		{
			sliceNPC.mHideImmediately=true;//Make sure the NPC dissapear
			DelayedHideNPC(sliceNPC);
		}
	}

	for(i=0 ; i<nbPlayers ; i++)
	{
		mSliceNPCsToSpawnForPlayer[i]=minSliceCount-SliceNPCsForPlayer[i];
	}
	//WorldInfo.Game.Broadcast(self, "Slices to spawn " $ mSliceNPCsToSpawnForPlayer[0]);
}

function AddSliceToPool(GGNpcSlice sliceNPC)
{
	local vector randomLoc;

	if(!CanBeRecycled(sliceNPC)
	|| mSlicePool.Find(sliceNPC) != INDEX_NONE)
		return;
	//WorldInfo.Game.Broadcast(self, "Add Slice to pool " $ SliceNPC $ ", size=" $ mSlicePool.Length+1);
	sliceNPC.SetHidden(true);
	sliceNPC.SetCollision( false, false, false );
	sliceNPC.SetTickIsDisabled( true );
	if(!sliceNPC.mIsRagdoll)
	{
		sliceNPC.SetRagdoll(true);
	}
	sliceNPC.DisableStandUp(class'GGNpc'.const.SOURCE_EDITOR);
	sliceNPC.SetPhysics(PHYS_None);
	randomLoc=vect(0, 0, -900) + (vect(10, 0, 0) * int(GetRightMost(sliceNPC.name))) + (vect(0, 1, 0) * (Rand(2000)-1000));
	sliceNPC.SetLocation(randomLoc);
	mSlicePool.AddItem(sliceNPC);
	//WorldInfo.Game.Broadcast(self, sliceNPC $ " was recycled");
}

function bool CanBeRecycled(GGNpcSlice sliceNPC)
{
	return sliceNPC != none
		&& !sliceNPC.bPendingDelete
		&& !sliceNPC.bHidden
		&& GGAIControllerSlice(sliceNPC.Controller) != none
		&& class'SlicePark'.static.GetParkContaining(sliceNPC) == none
		&& sliceNPC.mLastPark == none;
}

function bool SpawnSliceFromPool(vector spawnLoc, rotator spawnRot, bool isBlue, bool isYellow, bool isRed)
{
	local GGNpcSlice spawnedNPC;

	if(mSlicePool.Length == 0)
	{
		spawnedNPC=Spawn(class'GGNpcSlice',,, spawnLoc, spawnRot,, true);
		//WorldInfo.Game.Broadcast(self, "Spawn new Slice " $ spawnedNPC);
	}
	else
	{
		spawnedNPC=mSlicePool[mSlicePool.Length-1];
		mSlicePool.RemoveItem(spawnedNPC);
		//WorldInfo.Game.Broadcast(self, "Get Slice from pool " $ spawnedNPC);
		//Force unragdoll instantly
		spawnedNPC.SetLocation(spawnLoc);
		spawnedNPC.SetPhysics(PHYS_RigidBody);
		spawnedNPC.SetCollision( true, true, true );
		spawnedNPC.EnableStandUp(class'GGNpc'.const.SOURCE_EDITOR);
		spawnedNPC.SetOnFire(false);
		spawnedNPC.SetIsInWater(false);
		spawnedNPC.ReleaseFromHogtie();
		if(spawnedNPC.mIsRagdoll)
		{
			spawnedNPC.Velocity=vect(0, 0, 0);
			spawnedNPC.StandUp();
			spawnedNPC.mesh.PhysicsWeight=0;
			spawnedNPC.TerminateRagdoll(0.f);
		}
		spawnedNPC.SetDrawScale(1.f);
		spawnedNPC.SetLocation(spawnLoc);
		spawnedNPC.SetRotation(spawnRot);
		spawnedNPC.SetTickIsDisabled( false );
		spawnedNPC.SetHidden(false);
	}

	if(spawnedNPC == none
	|| spawnedNPC.bPendingDelete
	|| !spawnedNPC.IsAliveAndWell())
	{
		DestroyNPC(spawnedNPC);
		return false;
	}

	spawnedNPC.mIsBlue=isBlue;
	spawnedNPC.mIsYellow=isYellow;
	spawnedNPC.mIsRed=isRed;
	spawnedNPC.InitSlice();
	spawnedNPC.SetPhysics( PHYS_Falling );

	return true;
}

function SpawnSliceFromList()
{
	local int nbPlayers, i;

	//Spawn new Slices NPCs if needed
	nbPlayers=mGoats.Length;
	for(i=0 ; i<nbPlayers ; i++)
	{
		if(mSliceNPCsToSpawnForPlayer.Length > 0 && mSliceNPCsToSpawnForPlayer[i] > 0)
		{
			if(mSpawnCountForSpot >= mMaxSpawnForSpot)
			{
				FindNewSpawnSpotNearPlayer(mGoats[i]);
			}
			if(SpawnSliceFromPool(GetRandomSpawnLocation(mGoats[i]), GetRandomRotation(), mIsBlue, mIsYellow, mIsRed))
			{
				mSliceNPCsToSpawnForPlayer[i]--;
				mSliceNPCCount++;
				mSpawnCountForSpot++;
			}
			break;
		}
	}
}

function RemoveSliceFromList()//Remove dead Slices when out of view (add them back to pool)
{
	local int i;

	for(i=delayedRemovableNPCs.Length-1 ; i>=0 ; i--)
	{
		if(`TimeSince( delayedRemovableNPCs[i].LastRenderTime ) > mTimeNotLookingForHide
		|| (delayedRemovableNPCs[i].mHideImmediately))
		{
			AddSliceToPool(delayedRemovableNPCs[i]);
			delayedRemovableNPCs.RemoveItem(delayedRemovableNPCs[i]);
		}
	}
}

function DelayedHideNPC(GGNpcSlice npc)
{
	delayedRemovableNPCs.AddItem(npc);
}

function DestroyNPC(GGPawn gpawn)
{
	local int i;

	if(gpawn == none || gpawn.bPendingDelete)
		return;

	for( i = 0; i < gpawn.Attached.Length; i++ )
	{
		if(GGGoat(gpawn.Attached[i]) == none)
		{
			gpawn.Attached[i].ShutDown();
			gpawn.Attached[i].Destroy();
		}
	}
	gpawn.ShutDown();
	gpawn.Destroy();
}

function FindNewSpawnSpotNearPlayer(GGPawn pawnCenter)
{
	local vector center;
	local float dist;
	local int randColor;

	center=pawnCenter.mIsRagdoll?pawnCenter.mesh.GetPosition():pawnCenter.Location;
	dist=spawnRadius;
	dist=RandRange(dist/2.f, dist);

	//Set new spawn spot
	mCurrentSpawnSpot=GetRandomValidLocation(pawnCenter, center, dist);
	//Reset spawn count
	mMaxSpawnForSpot=Rand(5) + 5;//Rand(5, 10)
	mSpawnCountForSpot=0;
	//Select new random color for slices
	mIsBlue=false;
	mIsYellow=false;
	mIsRed=false;
	randColor=Rand(3);
	if(randColor == 0) mIsBlue=true;
	else if(randColor == 1) mIsYellow=true;
	else mIsRed=true;
}

function vector GetRandomSpawnLocation(GGPawn pawnCenter)
{
	local vector dest, center;
	local float dist;

	center=mCurrentSpawnSpot;
	dist=spawnRadius/10.f;
	dist=RandRange(dist/2.f, dist);

	dest=GetRandomValidLocation(pawnCenter, center, dist);
	dest.Z+=85;

	return dest;
}

function vector GetRandomValidLocation(GGPawn dummyPawn, vector center, float dist)
{
	local vector dest;
	local rotator rot;
	local Actor hitActor;
	local vector hitLocation, hitLocationWater, hitNormal, traceEnd, traceStart;
	local int i;

	rot=GetRandomRotation();
	for(i=0 ; i<4 ; i++)
	{
		dest=center+Normal(vector(rot))*dist;
		traceStart=dest;
		traceEnd=dest;
		traceStart.Z=10000.f;
		traceEnd.Z=-3000;

		hitActor = Trace( hitLocation, hitNormal, traceEnd, traceStart, true);
		if( hitActor == none )
		{
			hitLocation = traceEnd;
		}
		//Don't spawn in slice parks
		if(class'SlicePark'.static.GetParkContainingPos(hitLocation) == none)
		{
			//Try to avoid spawning Slices in water because it's laggy
			hitActor = Trace( hitLocationWater, hitNormal, traceEnd, traceStart, false,,, TRACEFLAG_PhysicsVolumes );
			if(WaterVolume( hitActor ) != none || (Volume( hitActor ) != none && dummyPawn.IsWaterMaterial( hitActor.Tag )))
			{
				if(hitLocationWater.Z < hitLocation.Z)//Ok we are not in water
				{
					break;
				}
			}
		}
		rot.Yaw+=16384;//+1/4 of circle
	}

	return hitLocation;
}

function rotator GetRandomRotation()
{
	local rotator rot;

	rot=Rotator(vect(1, 0, 0));
	rot.Yaw+=RandRange(0.f, 65536.f);

	return rot;
}

/**
 * Called when an actor begins to ragdoll
 */
function OnRagdoll( Actor ragdolledActor, bool isRagdoll )
{
	super.OnRagdoll( ragdolledActor, isRagdoll );
	//Try to prevent slices from escaping parks because of glitches
	if(GGNpcSlice(ragdolledActor) != none)
	{
		GGNpcSlice(ragdolledActor).RagdollDetected(isRagdoll);
	}
}

DefaultProperties
{
	mMutatorComponentClass=class'SliceRancherComponent'

	managementTimer=1.f
	spawnRemoveTimer=0.1f
	spawnRadius=5000.f
	minSliceCount=30 // 20
	maxSliceCount=120 // 40
	mTimeNotLookingForHide=0.5f
}