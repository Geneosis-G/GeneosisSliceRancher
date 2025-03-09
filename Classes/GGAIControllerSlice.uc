class GGAIControllerSlice extends GGAIController;

var bool isPossessing;
var float mDestinationOffset;
var kActorSpawnable destActor;
var vector mSpawnPos;

var Actor mActorToAttack;
var float targetRadius;

var NPCAnimationInfo mDesiredAnimationInfo;
var float totalTime;
var float mAbandonTime;

var bool mIsHungry;
var int missCount;
var int maxMissAllowed;
var bool isArrived;

var rotator mLastMovementRotation;

/**
 * Cache the NPC and mOriginalPosition
 */
event Possess(Pawn inPawn, bool bVehicleTransition)
{
	local ProtectInfo destination;

	super.Possess(inPawn, bVehicleTransition);

	isPossessing=true;
	if(mMyPawn == none)
		return;

	mSpawnPos=mMyPawn.Location;

	mMyPawn.mProtectItems.Length=0;
	if(destActor == none)
	{
		destActor = Spawn(class'kActorSpawnable', mMyPawn,,,,,true);
		destActor.SetHidden(true);
		destActor.SetPhysics(PHYS_None);
		destActor.CollisionComponent=none;
	}
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " destActor=" $ destActor);
	destActor.SetLocation(mMyPawn.Location);
	destination.ProtectItem = mMyPawn;
	destination.ProtectRadius = 1000000.f;
	mMyPawn.mProtectItems.AddItem(destination);
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " mMyPawn.mProtectItems[0].ProtectItem=" $ mMyPawn.mProtectItems[0].ProtectItem);
	StandUp();
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " mOriginalRotation=" $ mOriginalRotation);
	mLastMovementRotation=mOriginalRotation;
}

event UnPossess()
{
	if(destActor != none)
	{
		destActor.ShutDown();
		destActor.Destroy();
	}
	isPossessing=false;
	super.UnPossess();
}

//Kill AI if slice is destroyed
function bool KillAIIfPawnDead()
{
	if(mMyPawn == none || mMyPawn.bPendingDelete || mMyPawn.Controller != self)
	{
		UnPossess();
		Destroy();
		return true;
	}

	return false;
}

event Tick( float deltaTime )
{
	//Kill destroyed bots
	if(isPossessing)
	{
		if(KillAIIfPawnDead())
		{
			return;
		}
	}

	// Optimisation
	if( mMyPawn.IsInState( 'UnrenderedState' ) )
	{
		return;
	}
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " state=" $ mCurrentState);
	super.Tick( deltaTime );

	// Fix dead eaten items
	if( mActorToAttack != none )
	{
		if( mActorToAttack.bPendingDelete )
		{
			mActorToAttack = none;
		}
	}

	if(!mMyPawn.mIsRagdoll)
	{
		//Fix NPC with no collisions
		if(mMyPawn.CollisionComponent == none)
		{
			mMyPawn.CollisionComponent = mMyPawn.Mesh;
		}

		//Fix NPC rotation
		UnlockDesiredRotation();
		//WorldInfo.Game.Broadcast(self, mMyPawn $ " attack " $ mActorToAttack);
		if(mActorToAttack != none)
		{
			Pawn.SetDesiredRotation( rotator( Normal2D( mActorToAttack.Location - Pawn.Location ) ) );
			mMyPawn.LockDesiredRotation( true );
		}
		else
		{
			if(IsZero(mMyPawn.Velocity))
			{
				Pawn.SetDesiredRotation(mLastMovementRotation);
				mMyPawn.LockDesiredRotation( true );
				if(isArrived && (mDesiredAnimationInfo == mMyPawn.mIdleAnimationInfo || !mMyPawn.isCurrentAnimationInfoStruct(mDesiredAnimationInfo)))
				{
					PlayIdleAnim();
				}

				if(!IsTimerActive( NameOf( StartRandomMovement ) ))
				{
					SetTimer(RandRange(1.0f, GGNpcSlice(mMyPawn).mIsTartine?2.f:10.0f), false, nameof( StartRandomMovement ) );
				}
			}
			else
			{
				if( !mMyPawn.isCurrentAnimationInfoStruct( mMyPawn.mRunAnimationInfo ) )
				{
					mMyPawn.SetAnimationInfoStruct( mMyPawn.mRunAnimationInfo );
				}
				mDesiredAnimationInfo=mMyPawn.mIdleAnimationInfo;
				mLastMovementRotation=mMyPawn.Rotation;
			}
		}
		FindBestState();
		// if waited too long to before reaching some place or some item, abandon
		totalTime = totalTime + (deltaTime * (mMyPawn.isCurrentAnimationInfoStruct( mMyPawn.mRunAnimationInfo )?2:1));
		if(totalTime > mAbandonTime)
		{
			totalTime=0.f;
			if(mActorToAttack != none)
			{
				mMyPawn.SetRagdoll(true);
				missCount++;//WorldInfo.Game.Broadcast(self, mMyPawn $ " missCount=" $ missCount);
			}
			else if(!isArrived)
			{
				mMyPawn.SetRagdoll(true);
			}
			EndAttack();//WorldInfo.Game.Broadcast(self, mMyPawn $ " EndAttack 2");
		}
	}
	else
	{
		//Fix NPC not standing up
		if(!IsTimerActive( NameOf( StandUp ) )
		&& mMyPawn.mTimesKnockedByGoat<mMyPawn.mTimesKnockedByGoatStayDownLimit)
		{
			StartStandUpTimer();
		}

		//Swim
		if(mMyPawn.mInWater)
		{
			totalTime = totalTime + deltaTime;
			if(totalTime > 1.f)
			{
				totalTime=0.f;
				DoRagdollJump();
			}
		}
	}
}

function FindBestState()
{
	if(mActorToAttack != none)
	{
		if(!IsValidTarget(mActorToAttack) || !ActInRange(mActorToAttack))
		{
			EndAttack();
		}
		else if(mCurrentState == '')
		{
			GotoState( 'ChasePawn' );
		}
	}
	else if(mCurrentState != 'RandomMovement')
	{
		GotoState( 'RandomMovement' );
	}
}

// Trigger random animations and voices
function PlayIdleAnim()
{
	if(IsTimerActive(NameOf(PlayIdleAnim)))
	{
		ClearTimer(NameOf(PlayIdleAnim));
	}

	if(mActorToAttack != none)
		return;

	switch(Rand(2))
	{
		case 0:
			mDesiredAnimationInfo=mMyPawn.mIdleAnimationInfo;
			break;
		case 1:
			mDesiredAnimationInfo=mMyPawn.mAngryAnimationInfo;
			break;
	}
	mMyPawn.SetAnimationInfoStruct(mDesiredAnimationInfo, true);
}

function bool FindRandomActorToAttack()
{
	local Actor target, tmp;
	local array<Actor> visibleActors;
	local int size;

	foreach VisibleCollidingActors(class'Actor', tmp, mMyPawn.SightRadius, mMyPawn.Location)
	{
		if(IsValidTarget(tmp))
		{
			visibleActors.AddItem(tmp);
		}
	}

	size=visibleActors.Length;
	if(size > 0)
	{
		target=visibleActors[Rand(size)];
	}
	else
	{
		return false;
	}

	EndAttack();//WorldInfo.Game.Broadcast(self, mMyPawn $ " EndAttack 3");
	StartAttackingItem(mMyPawn.mProtectItems[0], target);
	return true;
}

function StartRandomMovement()
{
	local vector dest;
	local int OffsetX;
	local int OffsetY;

	if(mActorToAttack != none || mMyPawn.mIsRagdoll)
	{
		return;
	}
	//mMyPawn.PlaySoundFromAnimationInfoStruct( mMyPawn.mAngryAnimationInfo );
	if(mIsHungry && (Rand(10) > 0 || GGNpcSlice(mMyPawn).mIsTartine) && FindRandomActorToAttack())// 90% chances to try to eat a food item / 100% for Tartines
	{
		return;
	}
	if(!mIsHungry)
	{
		missCount--;//WorldInfo.Game.Broadcast(self, mMyPawn $ " missCount=" $ missCount);
		if(missCount <= 0 || GGNpcSlice(mMyPawn).mIsTartine)
		{
			mIsHungry=true;//WorldInfo.Game.Broadcast(self, mMyPawn $ " mIsHungry");
			missCount=0;
		}
	}
	totalTime=-10.f;
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " start random movement");

	OffsetX = Rand(500)-250;
	OffsetY = Rand(500)-250;

	dest.X = mMyPawn.Location.X + OffsetX;
	dest.Y = mMyPawn.Location.Y + OffsetY;
	dest.Z = mMyPawn.Location.Z;

	destActor.SetLocation(dest);
	isArrived=false;
	//mMyPawn.SetDesiredRotation(rotator(Normal(dest -  mMyPawn.Location)));

}

function StartAttackingItem( ProtectInfo protectInformation, Actor threat )
{
	local float h;

	// Don't attack if pawn out of view or no enemy
	if(threat == none
	|| mMyPawn.IsInState( 'UnrenderedState' ))
		return;

	if(!mIsHungry)// if not hungry, forget enemy
	{
		mVisibleGoats.RemoveItem(GGGoat(threat));
		mVisibleEnemies.RemoveItem(Pawn(threat));
		return;
	}

	StopAllScheduledMovement();
	totalTime=0.f;

	mCurrentlyProtecting = protectInformation;

	mPawnToAttack = GGPawn(threat);
	mActorToAttack = threat;
	mActorToAttack.GetBoundingCylinder(targetRadius, h);

	StartLookAt( threat, 5.0f );

	GotoState( 'ChasePawn' );
}

/**
 * Do ragdoll jump, e.g. for jumping out of water.
 */
function DoRagdollJump()
{
	local vector newVelocity;

	newVelocity = Normal2D(mSpawnPos-mMyPawn.mesh.GetPosition());
	newVelocity.Z = 1.f;
	newVelocity = Normal(newVelocity) * mMyPawn.JumpZ;

	mMyPawn.mesh.SetRBLinearVelocity( newVelocity );
}

function EatActor(Actor newFood)
{
	GGNpcSlice(mMyPawn).EatActor(newFood);
}

//All work done in StartAttackingItem
function StartProtectingItem( ProtectInfo protectInformation, GGPawn threat );

//All work done in StartEating
function StartAttack( Pawn pawnToAttack );

//All work done in EatCurrentActor
function AttackPawn();

function StartEating( Actor actorToEat )
{
	local float animLength;

	Pawn.SetDesiredRotation( rotator( Normal2D( actorToEat.Location - Pawn.Location ) ) );

	mMyPawn.LockDesiredRotation( true );

	mActorToAttack = actorToEat;

	animLength = mMyPawn.SetAnimationInfoStruct( mMyPawn.mAttackAnimationInfo );

	ClearTimer( nameof( EatCurrentActor ) );

	mMyPawn.ZeroMovementVariables();

	SetTimer( animLength / 2, false, nameof( EatCurrentActor ) );

	if(animLength == 0)
	{
		EatCurrentActor();
	}
}

function EatCurrentActor()
{
	StartLookAt( mActorToAttack, 5.0f );

	EatActor(mActorToAttack);

	mAttackIntervalInfo.LastTimeStamp = WorldInfo.TimeSeconds;
	missCount=0;//WorldInfo.Game.Broadcast(self, mMyPawn $ " missCount=" $ missCount);

	EndAttack();
}

event PawnFalling();//do NOT go into wait for landing state

/**
 * We have to disable the notifications for changing states, since there are so many npcs which all have hundreds of calls.
 */
state MasterState
{
	function BeginState( name prevStateName )
	{
		mCurrentState = GetStateName();
	}
}

state RandomMovement extends MasterState
{
	/**
	 * Called by APawn::moveToward when the point is unreachable
	 * due to obstruction or height differences.
	 */
	event MoveUnreachable( vector AttemptedDest, Actor AttemptedTarget )
	{
		if( AttemptedDest == mOriginalPosition )
		{
			if( mMyPawn.IsDefaultAnimationRestingOnSomething() )
			{
			    mMyPawn.mDefaultAnimationInfo =	mMyPawn.mIdleAnimationInfo;
			}

			mOriginalPosition = mMyPawn.Location;
			mMyPawn.ZeroMovementVariables();

			StartRandomMovement();
		}
	}
Begin:
	mMyPawn.ZeroMovementVariables();
	while(mActorToAttack == none && !KillAIIfPawnDead())
	{
		//WorldInfo.Game.Broadcast(self, mMyPawn $ " STATE OK!!!");
		if(VSize2D(destActor.Location - mMyPawn.Location) > mDestinationOffset)
		{
			MoveToward (destActor);
		}
		else
		{
			if(!isArrived)
			{
				isArrived=true;
			}
			totalTime=0.f;
			MoveToward (mMyPawn,, mDestinationOffset);// Ugly hack to prevent "runnaway loop" error
		}
	}
	mMyPawn.ZeroMovementVariables();
}

state ChasePawn extends MasterState
{
	ignores SeePlayer;
 	ignores SeeMonster;
 	ignores HearNoise;
 	ignores OnManual;
 	ignores OnWallJump;
 	ignores OnWallRunning;

begin:
	mMyPawn.SetAnimationInfoStruct( mMyPawn.mRunAnimationInfo );

	while(mActorToAttack != none && !KillAIIfPawnDead() && VSize( mMyPawn.Location - mActorToAttack.Location ) - targetRadius > mMyPawn.mAttackRange || !ReadyToAttack() )
	{
		MoveToward( mActorToAttack,, mDestinationOffset );
	}

	if(!IsValidTarget(mActorToAttack))
	{
		ReturnToOriginalPosition();
	}
	else
	{
		FinishRotation();
		GotoState( 'Attack' );
	}
}

state Attack extends MasterState
{
	ignores SeePlayer;
 	ignores SeeMonster;
 	ignores HearNoise;
 	ignores OnManual;
 	ignores OnWallJump;
 	ignores OnWallRunning;

begin:
	Focus = mActorToAttack;

	StartEating(mActorToAttack);
	FinishRotation();
}

/**
 * Go back to where the position we spawned on
 */
function ReturnToOriginalPosition()
{
	FindBestState();
}

//All work done in FindRandomActorToAttack()
function CheckVisibilityOfGoats();
function CheckVisibilityOfEnemies();
event SeePlayer( Pawn Seen );
event SeeMonster( Pawn Seen );
function bool EnemyNearProtectItem( ProtectInfo protectInformation, out GGPawn enemyNear );

/**
 * Helper function to determine if our pawn is close to a protect item, called when we arrive at a pathnode
 * @param currentlyAtNode - The pathNode our pawn just arrived at
 * @param out_ProctectInformation - The info about the protect item we are near if any
 * @return true / false depending on if the pawn is near or not
 */
function bool NearProtectItem( PathNode currentlyAtNode, out ProtectInfo out_ProctectInformation )
{
	out_ProctectInformation=mMyPawn.mProtectItems[0];
	return true;
}

event HearNoise( float Loudness, Actor NoiseMaker, optional Name NoiseType );


function bool IsValidEnemy( Pawn newEnemy )
{
	local GGNpc npc;

	npc=GGNpc(newEnemy);
	if(npc != none && npc.mInWater)
	{
		return false;
	}

	return true;
}

function bool IsValidTarget( Actor newEnemy )
{
	return GGNpcSlice(mMyPawn).IsValidFood(newEnemy) && (GGPawn(newEnemy) == none || IsValidEnemy(GGPawn(newEnemy)));
}

/**
 * Helper functioner for determining if the goat is in range of uur sightradius
 * if other is not specified mLastSeenGoat is checked against
 */
function bool PawnInRange( optional Pawn other )
{
	local GGPawn gpawn;

	gpawn=GGPawn(other);

	if(gpawn == none)
	{
		return false;
	}
	else
	{
		return super.PawnInRange(gpawn);
	}

}

function bool ActInRange( optional Actor other )
{
	local float dist;
	local Pawn pwn;

	pwn=Pawn(other);
	if(pwn != none)
	{
		return PawnInRange(pwn);
	}

	dist = VSize( other.Location - mMyPawn.Location );
	return dist <= mMyPawn.SightRadius;
}

function ResumeDefaultAction()
{
	super.ResumeDefaultAction();
	FindBestState();
}

function bool GoatCarryingDangerItem();
function bool PawnUsesScriptedRoute();
function StartLookAt( Actor lookAtActor, float lookAtDuration );
function StopLookAt();
function StartInteractingWith( InteractionInfo intertactionInfo );

//--------------------------------------------------------------//
//			GGNotificationInterface								//
//--------------------------------------------------------------//

function OnTrickMade( GGTrickBase trickMade );
function OnTakeDamage( Actor damagedActor, Actor damageCauser, int damage, class< DamageType > dmgType, vector momentum );
function OnKismetActivated( SequenceAction activatedKismet );
/**
 * Called when an actor begins to ragdoll
 */
function OnRagdoll( Actor ragdolledActor, bool isRagdoll )
{
	local GGPawn gpawn;

	gpawn = GGPawn( ragdolledActor );

	if( ragdolledActor == mMyPawn && isRagdoll )
	{
		if( IsTimerActive( NameOf( StopPointing ) ) )
		{
			StopPointing();
		}

		if( IsTimerActive( NameOf( StopLookAt ) ) )
		{
			StopLookAt();
		}

		if( mCurrentState == 'ProtectItem' )
		{
			ClearTimer( nameof( AttackPawn ) );
			ClearTimer( nameof( EatCurrentActor ) );
			ClearTimer( nameof( DelayedGoToProtect ) );
		}
		StopAllScheduledMovement();
		StartStandUpTimer();
		UnlockDesiredRotation();
	}

	if( gpawn != none)
	{
		if( gpawn == mPawnToAttack )
		{
			EndAttack();//WorldInfo.Game.Broadcast(self, mMyPawn $ " EndAttack 7");
		}

		if( gpawn == mLookAtActor )
		{
			StopLookAt();
		}
	}
}

function DelayedGoToProtect()
{
	UnlockDesiredRotation();
	FindBestState();
}

/**
 * Try to figure out what we want to do after we have stand up
 */
function DeterminWhatToDoAfterStandup()
{
	FindBestState();
}

function EndAttack()
{
	mActorToAttack=none;
	mDesiredAnimationInfo=mMyPawn.mIdleAnimationInfo;
	if(mIsHungry && missCount >= maxMissAllowed)
	{
		if(GGNpcSlice(mMyPawn).mIsTartine)//Tartines are always hungry :p
		{
			missCount=0;
		}
		else
		{
			mIsHungry=false;//WorldInfo.Game.Broadcast(self, mMyPawn $ "not mIsHungry");
		}
	}
	super.EndAttack();
}

function bool CanPawnInteract();
function OnManual( Actor manualPerformer, bool isDoingManual, bool wasSuccessful );
function OnWallRun( Actor runner, bool isWallRunning );
function OnWallJump( Actor jumper );

//--------------------------------------------------------------//
//			End GGNotificationInterface							//
//--------------------------------------------------------------//

function ApplaudGoat();
function PointAtGoat();
function StopPointing();
function bool WantToPanicOverTrick( GGTrickBase trickMade );
function bool WantToApplaudTrick( GGTrickBase trickMade  );
function bool WantToPanicOverKismetTrick( GGSeqAct_GiveScore trickRelatedKismet );
function bool WantToApplaudKismetTrick( GGSeqAct_GiveScore trickRelatedKismet );
function bool NearInteractItem( PathNode currentlyAtNode, out InteractionInfo out_InteractionInfo );
function bool ShouldApplaud();
function bool ShouldNotice();
event GoatPickedUpDangerItem( GGGoat goat );
function Panic();
function Dance(optional bool forever);
function PawnDied(Pawn inPawn);

DefaultProperties
{
	mIsHungry=true
	maxMissAllowed=5
	mAbandonTime=30.f

	mDestinationOffset=100.0f
	bIsPlayer=true

	mAttackIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mCheckProtItemsThreatIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mVisibilityCheckIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
}
