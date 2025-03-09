class RancherGoatComponent extends GGMutatorComponent;

var GGGoat gMe;
var GGMutator myMut;

var SkeletalMeshComponent mVacuumMesh;

var AudioComponent mAC;
var SoundCue mVacuumSound;
var SoundCue mSuckSound;
var SoundCue mThrowSound;

var ParticleSystemComponent mVacuumParticle;

var float mThrowForce;
var float mSuckForce;
var float mInventoryRadius;
var float mSuckRadius;

var array<Actor> mAttractedActors;

var GGCrosshairActor mCrosshairActor;

var bool mUseVacuum;
var bool mIsVacuumActive;
var bool mIsBaaPressed;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	local vector tmpLoc;

	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;
		GGGameInfo( gMe.WorldInfo.Game ).SpawnMutator( gMe, class'GGMutatorInventory' );

		gMe.mesh.GetSocketWorldLocationAndRotation( 'JetPackSocket', tmpLoc );
		if(!IsZero(tmpLoc))
		{
			gMe.mesh.AttachComponentToSocket( mVacuumMesh, 'JetPackSocket' );
		}
		else
		{
			gMe.AttachComponent(mVacuumMesh);
		}
		mVacuumMesh.SetLightEnvironment( gMe.mesh.lightenvironment );

		mVacuumMesh.AttachComponentToSocket( mVacuumParticle, 'PipeOpening' );
		mVacuumParticle.DeactivateSystem();
		mVacuumParticle.KillParticlesForced();

		gMe.AttachComponent(mAC);

		if(mCrosshairActor == none)
		{
			mCrosshairActor = gMe.Spawn(class'GGCrosshairActor');
			mCrosshairActor.SetColor(MakeLinearColor( 0.9f, 0.9f, 0.9f, 1.0f ));
		}
	}
}

function DetachFromPlayer()
{
	mCrosshairActor.DestroyCrosshair();
	mVacuumMesh.DetachFromAny();
	mVacuumParticle.DetachFromAny();
	mAC.DetachFromAny();
	super.DetachFromPlayer();
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if( localInput.IsKeyIsPressed( "GBA_AbilityBite", string( newKey ) ) )
		{
			ActivateVacuum();
		}

		if( localInput.IsKeyIsPressed( "GBA_Special", string( newKey ) ) )
		{
			ThrowItem();
		}

		if(localInput.IsKeyIsPressed("GBA_Baa", string( newKey )))
		{
			mIsBaaPressed=true;
		}

		if(localInput.IsKeyIsPressed("RightMouseButton", string( newKey )) || newKey == 'XboxTypeS_LeftTrigger')
		{
			if(mIsBaaPressed)
			{
				gMe.SetTimer(2.f, false, NameOf(ToggleVacuum), self);
			}
		}
	}
	else if( keyState == KS_Up )
	{
		if( localInput.IsKeyIsPressed( "GBA_AbilityBite", string( newKey ) ) )
		{
			DeactivateVacuum();
		}

		if(localInput.IsKeyIsPressed("GBA_Baa", string( newKey )))
		{
			mIsBaaPressed=false;
		}

		if(localInput.IsKeyIsPressed("RightMouseButton", string( newKey )) || newKey == 'XboxTypeS_LeftTrigger')
		{
			if(gMe.IsTimerActive(NameOf(ToggleVacuum), self))
			{
				gMe.ClearTimer(NameOf(ToggleVacuum), self);
			}
		}
	}
}

function ToggleVacuum()
{
	mUseVacuum=!mUseVacuum;

	if(!mUseVacuum && mIsVacuumActive)
	{
		DeactivateVacuum();
	}

	mVacuumMesh.SetHidden(!mUseVacuum);
	mCrosshairActor.SetHidden(!mUseVacuum);
}

function ActivateVacuum()
{
	if(mIsVacuumActive || !mUseVacuum)
		return;

	mIsVacuumActive=true;

	mVacuumParticle.KillParticlesForced();
	mVacuumParticle.ActivateSystem( true );
	//mVacuumParticle.RewindEmitterInstances();
	if(!mAC.IsPlaying())
	{
		mAC.Play();
	}
}

function DeactivateVacuum()
{
	if(!mIsVacuumActive)
		return;

	mIsVacuumActive=false;

	if(mVacuumParticle.bIsActive)
	{
		mVacuumParticle.DeactivateSystem();
	}
	if( mAC.IsPlaying() )
	{
		mAC.Stop();
	}
}

function ThrowItem()
{
	local Actor actToThrow;
	local GGPawn gpawn;
	local PrimitiveComponent throwComp;
	local vector dir;

	if(gMe.mIsRagdoll || !mUseVacuum)
		return;

	//Get first item from inventory
	if(gMe.mInventory.mInventorySlots.Length > 0)
	{
		gMe.mInventory.RemoveFromInventory(0);
		actToThrow=Actor(gMe.mInventory.mLastItemRemoved);
		if(GGPawn(actToThrow) != none)
		{
			GGPawn(actToThrow).SetRagdoll(true);
			GGPawn(actToThrow).mesh.SetRBLinearVelocity(vect(0, 0, 0));
		}
	}

	if(actToThrow == none)//TODO: play empty sound?
		return;

	dir=Normal(mCrosshairActor.Location-GetThrowLocation());

	gpawn = GGPawn(actToThrow);

	throwComp=actToThrow.CollisionComponent;
	if(gpawn != none)
	{
		throwComp=gpawn.mesh;
	}
	throwComp.SetRBLinearVelocity(dir*mThrowForce);

	gMe.PlaySound(mThrowSound);
}

function vector GetThrowLocation()
{
	local vector throwLocation;

	gMe.mesh.GetSocketWorldLocationAndRotation( 'Demonic', throwLocation );
	if(IsZero(throwLocation))
	{
		throwLocation=gMe.Location + (Normal(vector(gMe.Rotation)) * (gMe.GetCollisionRadius() + 30.f));
	}

	return throwLocation;
}

function vector GetSuckLocation()
{
	local vector suckLocation;

	mVacuumMesh.GetSocketWorldLocationAndRotation( 'PipeOpening', suckLocation );
	if(IsZero(suckLocation))
	{
		suckLocation=gMe.Location + vect(0, 0, 1) * gMe.GetCollisionHeight() + (Normal(vector(gMe.Rotation)) * gMe.GetCollisionRadius());
	}

	return suckLocation;
}

function TickMutatorComponent(float deltaTime)
{
	super.TickMutatorComponent(deltaTime);

	if(!IsZero(gMe.Velocity) && gMe.IsTimerActive(NameOf(ToggleVacuum), self))
	{
		gMe.ClearTimer(NameOf(ToggleVacuum), self);
	}

	UpdateCrosshair(GetThrowLocation());
	//Apply vacuum suck effect
	SuckItems();
}

function SuckItems()
{
	local GGInventoryActorInterface newItem;
	local GGPawn gpawn;
	local vector hitLocation, traceStart, traceEnd, hitNormal, dir, actorPos;
	local Actor hitActor;
	local float actRadius, tmp;
	local PrimitiveComponent suckComp;

	if(gMe.mIsRagdoll || !mIsVacuumActive)
		return;

	//Get all grabbable actors between the goat head and the crosshair
	traceStart=GetSuckLocation();
	traceEnd=traceStart + Normal(mCrosshairActor.Location-traceStart)*mSuckRadius;
	//gMe.DrawDebugLine (traceStart, traceEnd, 0, 0, 255, true);
	foreach gMe.TraceActors(class'Actor', hitActor, hitLocation, hitNormal, traceEnd, traceStart)
	{
		newItem=GGInventoryActorInterface(hitActor);
		if(hitActor == gMe || newItem == none)
			continue;
		//Attract Items
		actorPos=hitActor.Location;
		hitActor.GetBoundingCylinder(actRadius, tmp);
		actRadius=FMax(actRadius, tmp);
		suckComp=hitActor.CollisionComponent;
		gpawn=GGPawn(hitActor);
		if(gpawn != none)
		{
			gpawn.SetRagdoll(true);
			actorPos=gpawn.mesh.GetPosition();
			dir=Normal(gMe.Location-gpawn.mesh.GetPosition());
			suckComp=gpawn.mesh;
		}
		dir=Normal(gMe.Location-actorPos);
		suckComp.SetRBLinearVelocity(dir*mSuckForce);
		//if close enough add it to inventory
		/*if(VSize(gMe.Location-actorPos) <= gMe.GetCollisionRadius() + actRadius + mInventoryRadius)
		{
			gMe.mInventory.AddToInventory(newItem);
			gMe.PlaySound(mSuckSound);
		}*/
	}
	//Make sure closes items are added to inventory
	foreach gMe.OverlappingActors(class'Actor', hitActor, gMe.GetCollisionRadius() + mInventoryRadius, gMe.Location)
	{
		newItem=GGInventoryActorInterface(hitActor);
		if(hitActor == gMe || newItem == none)
			continue;
		//if aligned with crosshair
		if((mCrosshairActor.Location-gMe.Location) dot (hitActor.Location-gMe.Location) > 0.f)
		{
			gMe.mInventory.AddToInventory(newItem);
			gMe.PlaySound(mSuckSound);
		}
	}
}

function UpdateCrosshair(vector aimLocation)
{
	local vector			StartTrace, EndTrace, AdjustedAim, camLocation;
	local rotator 			camRotation;
	local Array<ImpactInfo>	ImpactList;
	local ImpactInfo 		RealImpact;
	local float 			Radius;

	if(gMe == none || GGPlayerControllerGame( gMe.Controller ) == none || mCrosshairActor == none)
		return;

	StartTrace = aimLocation;

	GGPlayerControllerGame( gMe.Controller ).PlayerCamera.GetCameraViewPoint( camLocation, camRotation );
	camRotation.Pitch+=1800.f;
	AdjustedAim = vector(camRotation);

	Radius = mCrosshairActor.SkeletalMeshComponent.SkeletalMesh.Bounds.SphereRadius;
	EndTrace = StartTrace + AdjustedAim * (mSuckRadius - Radius);

	RealImpact = CalcWeaponFire(StartTrace, EndTrace, ImpactList);

	mCrosshairActor.UpdateCrosshair(RealImpact.hitLocation, -AdjustedAim);
}

simulated function ImpactInfo CalcWeaponFire(vector StartTrace, vector EndTrace, optional out array<ImpactInfo> ImpactList)
{
	local vector			HitLocation, HitNormal;
	local Actor				HitActor;
	local TraceHitInfo		HitInfo;
	local ImpactInfo		CurrentImpact;

	HitActor = CustomTrace(HitLocation, HitNormal, EndTrace, StartTrace, HitInfo);

	if( HitActor == None )
	{
		HitLocation	= EndTrace;
	}

	CurrentImpact.HitActor		= HitActor;
	CurrentImpact.HitLocation	= HitLocation;
	CurrentImpact.HitNormal		= HitNormal;
	CurrentImpact.RayDir		= Normal(EndTrace-StartTrace);
	CurrentImpact.StartTrace	= StartTrace;
	CurrentImpact.HitInfo		= HitInfo;

	ImpactList[ImpactList.Length] = CurrentImpact;

	return CurrentImpact;
}

function Actor CustomTrace(out vector HitLocation, out vector HitNormal, vector EndTrace, vector StartTrace, out TraceHitInfo HitInfo)
{
	local Actor hitActor, retActor;

	foreach gMe.TraceActors(class'Actor', hitActor, HitLocation, HitNormal, EndTrace, StartTrace, ,HitInfo)
    {
		if(hitActor != gMe
		&& hitActor.Owner != gMe
		&& hitActor.Base != gMe
		&& hitActor != gMe.mGrabbedItem
		&& !hitActor.bHidden)
		{
			retActor=hitActor;
			break;
		}
    }

    return retActor;
}

function OnRagdoll( Actor ragdolledActor, bool isRagdoll )
{
	super.OnRagdoll(ragdolledActor, isRagdoll);

	if(ragdolledActor == gMe)
	{
		if(mIsVacuumActive)
		{
			DeactivateVacuum();
		}
	}
}

defaultproperties
{
	mUseVacuum=true

	mThrowForce=2000.f
	mSuckForce=1000.f;
	mInventoryRadius=10.f;
	mSuckRadius=10000.f

	Begin Object class=SkeletalMeshComponent Name=vacuumMesh
		SkeletalMesh=SkeletalMesh'Zombie_Weapons.mesh.GumShot'
		PhysicsAsset=PhysicsAsset'Zombie_Weapons.Mesh.GumShot_Physics_01'
		Materials(0)=Material'Zombie_Weapons.Materials.GumShot_Mat_01'
		Materials(1)=Material'Zombie_Weapons.Materials.GumShot_Glass_Mat_01'
		AnimTreeTemplate=AnimTree'Zombie_Weapons.Gumshot_AnimTree'
		AnimSets(0)=AnimSet'Zombie_Weapons.mesh.Gumshot_Anim'
	End Object
	mVacuumMesh=vacuumMesh

	Begin Object class=AudioComponent Name=VacuumAudioComponent
        bUseOwnerLocation=true
        SoundCue=SoundCue'MMO_AMB.Cue.AMB_Server_Room_Ventilation_Cue'
    End Object
    mAC=VacuumAudioComponent

    Begin Object class=ParticleSystemComponent Name=ParticleSystemComponent1
        Template=ParticleSystem'Goat_Effects.Effects.Effects_Tornado_01'
        Scale3D=(X=0.1f, Y=0.1f, Z=0.1f)
		bResetOnDetach=true
	End Object
	mVacuumParticle=ParticleSystemComponent1

	mSuckSound=SoundCue'Zombie_Weapon_Sounds.TheRelaxer.TheRelaxer_Fire_Cue'//SoundCue'Heist_Audio_Overkill.Cue.crime_net_startup_Cue'
	mThrowSound=SoundCue'Goat_Sounds_Impact.Cue.Impact_SolidWall_Cue'
}