class GGNpcSlice extends GGNpc;

var Material mSliceMaterial;
var Material mBlackMaterial;

var bool mIsBlue;
var bool mIsYellow;
var bool mIsRed;
var bool mIsTartine;

var SoundCue mEatSound;

var bool mHideImmediately;

var SlicePark mLastPark;

function InitSlice()
{
	mesh.SetMaterial(0, mSliceMaterial);
	if(MaterialInstanceConstant(mesh.GetMaterial(0)) == none)
	{
		mesh.CreateAndSetMaterialInstanceConstant( 0 );
	}

	UpdateColor();

	if(Controller == none)
	{
		SpawnDefaultController();
	}
}

function UpdateColor()
{
	local MaterialInstanceConstant mic;
	local color blue, yellow, red, green, orange, purple;
	local LinearColor newColor;

	mIsTartine = mIsBlue && mIsYellow && mIsRed;

	if(mIsTartine)
	{
		mesh.SetMaterial(0, mBlackMaterial);
		return;
	}

	mic=MaterialInstanceConstant(mesh.GetMaterial(0));

	blue = MakeColor( 0, 0, 255, 255 );
	yellow = MakeColor( 255, 255, 0, 255 );
	red = MakeColor( 255, 0, 0, 255 );
	green = MakeColor( 0, 80, 0, 255 );
	orange = MakeColor( 255, 69, 0, 255 );
	purple = MakeColor( 128, 0, 128, 255 );

	if(mIsBlue && mIsYellow)
	{
		newColor = ColorToLinearColor( green );
	}
	else if(mIsBlue && mIsRed)
	{
		newColor = ColorToLinearColor( purple );
	}
	else if(mIsRed && mIsYellow)
	{
		newColor = ColorToLinearColor( orange );
	}
	else if(mIsBlue)
	{
		newColor = ColorToLinearColor( blue );
	}
	else if(mIsYellow)
	{
		newColor = ColorToLinearColor( yellow );
	}
	else if(mIsRed)
	{
		newColor = ColorToLinearColor( red );
	}
	mic.SetVectorParameterValue( 'color', newColor );
}

/**
 * Human readable name of this actor.
 */
function string GetActorName()
{
	if(mIsTartine) return "Tartine";
	if(mIsBlue && mIsYellow) return "Green Slice";
	if(mIsBlue && mIsRed) return "Purple Slice";
	if(mIsYellow && mIsRed) return "Orange Slice";
	if(mIsBlue) return "Blue Slice";
	if(mIsYellow) return "Yellow Slice";
	if(mIsRed) return "Red Slice";

	return "Slice";
}

/**
 * How much score this actor gives.
 */
function int GetScore()
{
	return 10;
}

function bool IsValidFood(Actor newFood)
{
	//Tartines eat any other non-tartine slice
	if(mIsTartine && GGNpcSlice(newFood) != none && !GGNpcSlice(newFood).mIsTartine) return true;
	if(!mIsTartine)
	{
		if(Blort(newFood) != none)//Can eat blorts from colors they don't have yet
		{
			if(!mIsBlue && Blort(newFood).mIsBlue) return true;
			if(!mIsYellow && Blort(newFood).mIsYellow) return true;
			if(!mIsRed && Blort(newFood).mIsRed) return true;
		}
		else//Blue eat solid, yellow eat beakable, red eat explosive
		{
			if(mIsBlue && GGKactor(newFood) != none && GGExplosiveActorAbstract(newFood) == none && GGKactor(newFood).mApexActor == none) return true;
			if(mIsYellow && GGKactor(newFood) != none && GGKactor(newFood).mApexActor != none) return true;
			if(mIsRed && GGExplosiveActorAbstract(newFood) != none) return true;
		}
	}

	return false;
}

function EatActor(Actor newFood)
{
	local Blort newBlort;
	local GGNpcSlice newTartine;

	if(!IsValidFood(newFood))
		return;

	if(mIsTartine)
	{
		newTartine=GGNpcSlice(newFood);
		if(newTartine == none)
		{
			newTartine=Spawn(class'GGNpcSlice',,, Location, Rotation + rot(0, 32768, 0),,true);
			newFood.ShutDown();
			newFood.Destroy();
		}
		else
		{
			newTartine.SetLocation(Location);
			newTartine.SetRotation(Rotation + rot(0, 32768, 0));
		}
		newTartine.mIsBlue=true;
		newTartine.mIsYellow=true;
		newTartine.mIsRed=true;

		newTartine.InitSlice();
	}
	else
	{
		if(Blort(newFood) != none)
		{
			if(Blort(newFood).mIsBlue) mIsBlue=true;
			if(Blort(newFood).mIsYellow) mIsYellow=true;
			if(Blort(newFood).mIsRed) mIsRed=true;

			UpdateColor();
		}
		else
		{
			if(mIsBlue)
			{
				newBlort=Spawn(class'Blort',,, Location + (vect(1, 0, 0) * (GetCollisionRadius() + 1.f)), Rotation,,true);
				newBlort.mIsBlue=true;
				newBlort.InitBlort();
			}
			if(mIsYellow)
			{
				newBlort=Spawn(class'Blort',,, Location + (vect(-1, 0, 0) * (GetCollisionRadius() + 1.f)), Rotation,,true);
				newBlort.mIsYellow=true;
				newBlort.InitBlort();
			}
			if(mIsRed)
			{
				newBlort=Spawn(class'Blort',,, Location + (vect(0, 1, 0) * (GetCollisionRadius() + 1.f)), Rotation,,true);
				newBlort.mIsRed=true;
				newBlort.InitBlort();
			}
		}

		newFood.ShutDown();
		newFood.Destroy();
	}

	if(IsGoatNear())//Cheap test to avoid editing the sound manually
	{
		PlaySound(mEatSound, false);
	}
}

function bool IsGoatNear()
{
	local GGPlayerControllerGame pc;

	foreach WorldInfo.AllControllers( class'GGPlayerControllerGame', pc )
	{
		if( pc.IsLocalPlayerController() && pc.Pawn != none )
		{
			if(VSize(pc.Pawn.Mesh.GetPosition() - mesh.GetPosition()) <= HearingThreshold)
			{
				return true;
			}
		}
	}

	return false;
}

/**
 * Called when the inventory wants to add us to it.
 */
function bool OnAddToInventory()
{
	SetHidden( true );//Make sure we won't be added to the recycling pool
	mLastPark=none;
	return super.OnAddToInventory();
}

/**
 * Called when the inventory wants to remove us from it.
 */
function bool OnRemoveFromInventory( vector spawnLocation )
{
	SetHidden( false );
	return super.OnRemoveFromInventory(spawnLocation);
}

function OnGrabbed( Actor grabbedByActor )
{
	mLastPark=none;
	super.OnGrabbed(grabbedByActor);
}

event Tick( float deltaTime )
{
	Super.Tick( deltaTime );

	PreventParkEscape();
}

function PreventParkEscape()
{
	local vector hitLocation, hitNormal;
	local vector traceStart, traceEnd, traceExtent;
	local float traceOffsetZ;
	local Actor hitActor;

	if(Controller == none || mIsRagdoll)
	{
		return;
	}

	traceExtent = GetCollisionExtent() * 0.75f;
	traceExtent.Y = traceExtent.X;
	traceExtent.Z = traceExtent.X;

	traceOffsetZ = traceExtent.Z + 10.0f;
	traceStart = Location + vect( 0.0f, 0.0f, 1.0f ) * traceOffsetZ;
	traceEnd = traceStart - vect( 0.0f, 0.0f, 1.0f ) * 100000.0f;

	hitActor = Trace( hitLocation, hitNormal, traceEnd, traceStart,, traceExtent );

	if(SlicePark(hitActor) != none)
	{
		SetPhysics(PHYS_Falling);
		Velocity=Normal2D(hitActor.Location - Location) * 1000;
		//WorldInfo.Game.Broadcast(self, self @ "tried to escape!");
	}
}

function RagdollDetected(bool isRagdoll)
{
	//Make sure the slice didn't gilitch out of a park after ragdolling
	if(isRagdoll)
	{
		mLastPark=class'SlicePark'.static.GetParkContaining(self);
	}
	else
	{
		if(mLastPark != none && mLastPark != class'SlicePark'.static.GetParkContaining(self))
		{
			SetLocation(mLastPark.Location + vect(0, 0, 100));//Teleport the slice back to its park
		}
		mLastPark=none;
	}
}

DefaultProperties
{
	ControllerClass=class'GGAIControllerSlice'

	Begin Object name=WPawnSkeletalMeshComponent
		SkeletalMesh=SkeletalMesh'I_Am_Bread.mesh.Slice_02'
		AnimSets(0)=AnimSet'I_Am_Bread.Anim.Slice_Anim_01'
		Materials(0)=Material'Slice_Rancher.Slice_Material'
		AnimTreeTemplate=AnimTree'I_Am_Bread.Anim.Slice_AnimTree'
		PhysicsAsset=PhysicsAsset'I_Am_Bread.mesh.Slice_01_Physics'
		Translation=(Z=-85)
	End Object
	mesh=WPawnSkeletalMeshComponent
	Components.Add(WPawnSkeletalMeshComponent)

	mSliceMaterial=Material'Slice_Rancher.Slice_Material'
	mBlackMaterial=Material'Vehicles.Materials.Boat.Boat_Master_Mat_01'//black

	Begin Object name=CollisionCylinder
		CollisionRadius=25.0f
		CollisionHeight=85.0f
		CollideActors=true
		BlockActors=true
		BlockRigidBody=true
		BlockZeroExtent=true
		BlockNonZeroExtent=true
	End Object

	mRunAnimationInfo=(AnimationNames=(Run_01),AnimationRate=1.0f,MovementSpeed=118.0f,LoopAnimation=true)
	mDefaultAnimationInfo=(AnimationNames=(Run_01),AnimationRate=1.0f,MovementSpeed=118.0f,LoopAnimation=true)
	mPanicAnimationInfo=(AnimationNames=(Run,Sprintburning),AnimationRate=1.0f,MovementSpeed=700.0f,LoopAnimation=true)
	mAngryAnimationInfo=(AnimationNames=(Baa),AnimationRate=1.0f,MovementSpeed=0.0f,SoundToPlay=(),LoopAnimation=false)
	//SoundCue'Space_UI_Sounds.PDA.PDA_Open_Cue'

	mAutoSetReactionSounds=false

	mKnockedOverSounds=(SoundCue'Zombie_Impact_Sounds.SurvivalMode.Brain_Impact_Cue')
	mAllKnockedOverSounds=(SoundCue'Zombie_Impact_Sounds.SurvivalMode.Brain_Impact_Cue')
	mEatSound=SoundCue'Zombie_Sounds.ZombieGameMode.Goat_HungerPickUp_Cue'

	SightRadius=1500.0f
	HearingThreshold=1500.0f

	mStandUpDelay=3.f

	mAttackRange=200.0f;
	mAttackMomentum=1000.0f

	mTimesKnockedByGoatStayDownLimit=1000000
}