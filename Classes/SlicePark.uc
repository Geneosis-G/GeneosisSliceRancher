class SlicePark extends StaticMeshActor;

var int mRancher;//Player ID of the park owner
var float mRadius;

var vector A, B, C, D, AB, CD, AC, BD;

//Must call this right after spawn (because PostBeginPlay is never called)
function InitPark(int ownerID)
{
	local rotator tmpRot;
	//WorldInfo.Game.Broadcast(self, self @ "InitPark");

	SetPhysics(PHYS_None);
	mRancher=ownerID;

	tmpRot.Yaw=8192;
	A=Location + ((Normal(vector(Rotation)) * (mRadius - 10.f)) << tmpRot);
	B=Location + ((Normal(vector(Rotation)) * (mRadius - 10.f)) << (tmpRot * 3.f));
	D=Location + ((Normal(vector(Rotation)) * (mRadius - 10.f)) << (tmpRot * 5.f));//D before C, to match the pattern
	C=Location + ((Normal(vector(Rotation)) * (mRadius - 10.f)) << (tmpRot * 7.f));

	AB=B-A;
	CD=D-C;
	AC=C-A;
	BD=D-B;
}

/*simulated event Tick( float delta )
{
	super.Tick( delta );

	//DrawDebugCylinder(Location, Location + vect(0, 0, 1000), mRadius, 64, 255, 255, 255);
	DrawDebugCylinder(A, A + vect(0, 0, 1000), 10, 16, 255, 255, 255);
	DrawDebugCylinder(B, B + vect(0, 0, 1000), 10, 16, 255, 255, 255);
	DrawDebugCylinder(C, C + vect(0, 0, 1000), 10, 16, 255, 255, 255);
	DrawDebugCylinder(D, D + vect(0, 0, 1000), 10, 16, 255, 255, 255);
	WorldInfo.Game.Broadcast(self, "Location=" $ Location $ " mRancher=" $ mRancher);
	WorldInfo.Game.Broadcast(self, "A=" $ A);
	WorldInfo.Game.Broadcast(self, "B=" $ B);
	WorldInfo.Game.Broadcast(self, "C=" $ C);
	WorldInfo.Game.Broadcast(self, "D=" $ D);
}*/

static function SlicePark GetParkContaining(Actor act)
{
	local SlicePark hitPark;
	//act.WorldInfo.Game.Broadcast(act, "GetParkContaining " $ act);
	foreach act.CollidingActors(class'SlicePark', hitPark, class'SlicePark'.default.mRadius, act.Location)
	{
		//act.WorldInfo.Game.Broadcast(act, "hitPark=" $ hitPark);
		if(hitPark.IsInPark(act))
		{
			return hitPark;
		}
	}

	return none;
}

static function SlicePark GetParkContainingPos(vector pos)
{
	local SlicePark hitPark;
	//act.WorldInfo.Game.Broadcast(act, "GetParkContaining " $ act);
	foreach class'WorldInfo'.static.GetWorldInfo().CollidingActors(class'SlicePark', hitPark, class'SlicePark'.default.mRadius, pos)
	{
		//act.WorldInfo.Game.Broadcast(act, "hitPark=" $ hitPark);
		if(hitPark.IsPosInPark(pos))
		{
			return hitPark;
		}
	}

	return none;
}

function bool IsInPark(Actor act)
{
	return IsPosInPark((GGPawn(act)!=none&&GGPawn(act).mIsRagdoll)?GGPawn(act).mesh.GetPosition():act.Location);
}

//Old method to detect any rotation
function bool IsPosInPark(vector P)
{
	local vector QAB, QCD, QAC, QBD;
	//Test if P between AB and CD and if P between AC and BD
	//A_____B
	//|     |
	//| .P  |
	//|_____|
	//C     D
	//
	P.Z=Location.Z;

	QAB = A + Normal( AB ) * ((( AB ) dot ( P - A )) / VSize( AB ));
	QCD = C + Normal( CD ) * ((( CD ) dot ( P - C )) / VSize( CD ));
	QAC = A + Normal( AC ) * ((( AC ) dot ( P - A )) / VSize( AC ));
	QBD = B + Normal( BD ) * ((( BD ) dot ( P - B )) / VSize( BD ));

	return ((P-QAB) dot (P-QCD) < 0) && ((P-QAC) dot (P-QBD) < 0);
	//VSize2D(Location-act.Location) <= mRadius;
}
/*
//Simplified version, only work if axis aligned
function bool IsPosInPark(vector P)
{
	//Test if P between AB and CD and if P between AC and BD
	//A_____B
	//|     |
	//| .P  |
	//|_____|
	//C     D
	//
	if(Sgn(A.X - P.X) != -Sgn(B.X - P.X)) return false;
	if(Sgn(A.Y - P.Y) != -Sgn(C.Y - P.Y)) return false;

	return true;
}*/

function float Sgn( float theValue )
{
  if( theValue == 0 )
    return 0;
  return theValue / Abs(theValue);
}

function bool IsTooClose(Actor act)
{
	return VSize2D(Location-act.Location) <= mRadius * 2.f;
}

static function bool IsInRadius(GGPawn pwn1, GGPawn pwn2)
{
	return VSize2D(pwn1.Mesh.GetPosition()-pwn2.Mesh.GetPosition()) <= default.mRadius;
}

DefaultProperties
{
	mRadius=350//This depends on the scale and the translation of the box

	Begin Object class=StaticMeshComponent Name=StaticMeshComp1
		StaticMesh=StaticMesh'Container.mesh.Container_03'
		Materials(0)=Material'Zombie_Particles.Materials.Mind_Control_Bubble_3_MAT'
		//Materials(0)=Material'MMO_Effects.Materials.Effects_Shockwave_Mat_01'
		//Materials(0)=Material'MMO_Effects.Materials.FogVolumeMaterial_Elves'
		//Materials(0)=MaterialInstanceConstant'MMO_Environment_01.Materials.ocean.Water_Elven_Mat_01'
		//Materials(0)=Material'Zombie_Craftable_Items.Materials.Crystal_Ball_MAT'//ice
		//Materials(0)=Material'Zombie_Particles.Materials.Crystal_Glow_Mat'//ice
		//Materials(0)=Material'Zombie_Particles.Materials.Mind_Control_Bubble_MAT'//+2
		//Materials(0)=Material'Zombie_Particles.Materials.Mind_Control_Bubble_2_MAT'//ice
		//Materials(0)=Material'Zombie_Environment.ZombieGoatGarageFog_Mat_01'
		bNotifyRigidBodyCollision = true
		ScriptRigidBodyCollisionThreshold = 1
        CollideActors = true
        BlockActors = true
        Rotation=(Pitch=16384, Yaw=0, Roll=0)//-16384
        Translation=(X=250, Y=0, Z=0)
		Scale3D=(X=0.5f, Y=2.f, Z=2.f)
	End Object
	Components.Add(StaticMeshComp1)

	CollisionComponent=StaticMeshComp1
	bCollideActors=true
	bBlockActors=true

	mBlockCamera=false

	bNoDelete=false
	bStatic=false
}