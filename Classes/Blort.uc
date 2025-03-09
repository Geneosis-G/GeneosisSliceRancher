class Blort extends GGKactor
	placeable;

var bool mIsBlue;
var bool mIsYellow;
var bool mIsRed;

//Must call this right after spawn, color must be set before this call
event InitBlort()
{
	if(MaterialInstanceConstant(StaticMeshComponent.GetMaterial(0)) == none)
	{
		StaticMeshComponent.CreateAndSetMaterialInstanceConstant( 0 );
	}

	UpdateColor();

	SetMassScale( 1000000.f );
	StaticMeshComponent.WakeRigidBody();
}

function UpdateColor()
{
	local MaterialInstanceConstant mic;
	local color blue, yellow, red;
	local LinearColor newColor;

	mic=MaterialInstanceConstant(StaticMeshComponent.GetMaterial(0));

	blue = MakeColor( 0, 0, 255, 255 );
	yellow = MakeColor( 255, 255, 0, 255 );
	red = MakeColor( 255, 0, 0, 255 );

	if(mIsBlue)
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

function int GetScore()
{
	return 1;
}

/**
 * Access to the in game name of this actor
 */
function string GetActorName()
{
	if(mIsBlue) return "Blue Blort";
	if(mIsYellow) return "Yellow Blort";
	if(mIsRed) return "Red Blort";

	return "Blort";
}

DefaultProperties
{
	Begin Object name=StaticMeshComponent0
		StaticMesh=StaticMesh'Space_Props.Meshes.Crate_General_01'
		Materials(0)=Material'Slice_Rancher.Slice_Material'
		//Rotation=(Pitch=0, Yaw=0, Roll=-16384)
		Scale3D=(X=0.2f,Y=0.2f,Z=0.2f)
	End Object

	bNoDelete=false
	bStatic=false
}