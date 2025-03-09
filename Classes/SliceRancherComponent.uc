class SliceRancherComponent extends GGMutatorComponent;

var GGGoat gMe;
var GGMutator myMut;

var bool mIsBaaPressed;

var SoundCue mParkPlacementSound;
var SoundCue mParkDestructionSound;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;
		GGGameInfo( gMe.WorldInfo.Game ).SpawnMutator( gMe, class'GGMutatorInventory' );
	}
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if(localInput.IsKeyIsPressed("GBA_Baa", string( newKey )))
		{
			mIsBaaPressed=true;
		}

		if(localInput.IsKeyIsPressed("LeftMouseButton", string( newKey )) || newKey == 'XboxTypeS_RightTrigger')
		{
			if(mIsBaaPressed)
			{
				PlaceSlicePark();
			}
		}

		if(localInput.IsKeyIsPressed("GBA_ToggleRagdoll", string( newKey )))
		{
			if(mIsBaaPressed)
			{
				DestroySlicePark();
			}
		}
	}
	else if( keyState == KS_Up )
	{
		if(localInput.IsKeyIsPressed("GBA_Baa", string( newKey )))
		{
			mIsBaaPressed=false;
		}
	}
}

function PlaceSlicePark()
{
	local SlicePark tmpPark;
	local GGNpcSlice tmpSlice;
	local int moneyAvailable;

	if(gMe.mIsRagdoll || !IsZero(gMe.Velocity) || gMe.mIsInAir)
		return;

	//Test if not too close to another park
	foreach gMe.AllActors(class'SlicePark', tmpPark)
	{
		if(tmpPark.IsTooClose(gMe))
		{
			myMut.WorldInfo.Game.Broadcast(myMut, "Can't create a park here: Too close to another park.");
			return;
		}
	}

	//Test if slices nearby
	foreach gMe.AllActors(class'GGNpcSlice', tmpSlice)
	{
		if(class'SlicePark'.static.IsInRadius(gMe, tmpSlice))
		{
			myMut.WorldInfo.Game.Broadcast(myMut, "Can't create a park here: There is Slices nearby.");
			return;
		}
	}

	//Test price
	if(!BuyWithBlortsFromInventory(15, moneyAvailable))
	{
		myMut.WorldInfo.Game.Broadcast(myMut, "Can't create a park here: A park cost 15 Blorts (you only have" @ moneyAvailable @ "in your inventory).");
		return;
	}

	tmpPark=gMe.Spawn(class'SlicePark', gMe,, gMe.Location + (vect(0, 0, -1) * gMe.GetCollisionHeight()), gMe.Rotation,, true);
	tmpPark.InitPark(gMe.mCachedSlotNr);
	gMe.PlaySound(mParkPlacementSound);
}

function DestroySlicePark()
{
	local SlicePark oldPark;

	if(gMe.mIsInAir)
		return;

	oldPark=class'SlicePark'.static.GetParkContaining(gMe);
	if(oldPark != none && oldPark.mRancher == gMe.mCachedSlotNr)
	{
		oldPark.Destroy();
		gMe.PlaySound(mParkDestructionSound);
	}
}

function bool BuyWithBlortsFromInventory(int price, out int blortCount)
{
	local int i;
	local GGInventory inv;

	inv=gMe.mInventory;
	if(price <= 0) return true;
	if(inv == none) return false;

	blortCount=0;
	for(i=0 ; i<inv.mInventorySlots.Length ; i++)
	{
		if(Blort(inv.mInventorySlots[i].mItem) != none)
		{
			blortCount++;
			if(blortCount == price) break;
		}
	}

	if(blortCount == price)
	{
		for(i=0 ; i<inv.mInventorySlots.Length ; i=i)
		{
			if(Blort(inv.mInventorySlots[i].mItem) != none)
			{
				inv.RemoveFromInventory(i);
				Actor(inv.mLastItemRemoved).ShutDown();
				Actor(inv.mLastItemRemoved).Destroy();
				blortCount--;
				if(blortCount == 0) return true;
			}
			else
			{
				i++;
			}
		}
	}

	return false;
}

function TickMutatorComponent(float deltaTime)
{
	super.TickMutatorComponent(deltaTime);
}

defaultproperties
{
	mParkPlacementSound=SoundCue'Goat_Sounds.Cue.Effect_BuilderGoat_box_cue'
	mParkDestructionSound=SoundCue'Goat_Sounds.Cue.Effect_builderGoat_removal'
}