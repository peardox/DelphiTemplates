unit CastleHelpers;

interface

uses System.SysUtils, System.Classes, System.Types,
  CastleScene,
  CastleVectors,
  CastleRectangles,
  CastleTransform,
  CastleViewport
  ;

type
  { TCastleSceneHelper }
  TCastleSceneHelper = class helper for TCastleScene
  public
    procedure ClearAndFreeItems;
    procedure AdjustOriginOffset;
    function CenterOfGeometry: TVector3;
  end;

  { TFloatRectangleHelper }
  TFloatRectangleHelper = record helper for TFloatRectangle
  public
    function AspectRatio: Single;
  end;

  { TCastleViewportHelper }
  TCastleViewportHelper = class helper for TCastleViewport
  public
    function GetEnvelope(const AScene: TCastleTransform): TFloatRectangle;
  end;


   { Standalone Functions }
function CreateDirectionalLight(const AOwner: TComponent; const LightPos: TVector3): TCastleDirectionalLight;

implementation

uses Math, CastleBoxes;

function TFloatRectangleHelper.AspectRatio: Single;
begin
  if Height = 0 then
    Raise Exception.Create('Attempting to calculate Aspect Ratio where height is zero');

  Result := Width / Height;
end;

function CreateDirectionalLight(const AOwner: TComponent; const LightPos: TVector3): TCastleDirectionalLight;
var
  Light: TCastleDirectionalLight;
begin
  Light := TCastleDirectionalLight.Create(AOwner);

  Light.Direction := LightPos;
  Light.Color := Vector3(1, 1, 1);
  Light.Intensity := 1;

  Result := Light;
end;

{ TCastleSceneHelper }

procedure TCastleSceneHelper.AdjustOriginOffset;
var
  CX, CY, CZ: Single;
  bb: TBox3D;
  normal: TBox3D;
  NewOrigin: TVector3;
begin
  if not(RootNode = nil) then
    begin
      bb := BoundingBox;
      if not bb.IsEmptyOrZero then
        begin
          if bb.MaxSize > 0 then
            begin
              CY := Min(bb.Data[0].Y, bb.Data[1].Y) + (bb.SizeY / 2);
              NewOrigin := Vector3(Center.X, CY, Center.Z);
              normal := bb.Translate(-NewOrigin);
              if not normal.Contains(Vector3(0,0,0)) then
                begin
                  CX := Min(bb.Data[0].X, bb.Data[1].X) + (bb.SizeX / 2);
                  CZ := Min(bb.Data[0].Z, bb.Data[1].Z) + (bb.SizeZ / 2);
                  NewOrigin := Vector3(CX, CY, CZ);
                end;
              Translation := -NewOrigin;
            end;
        end;
    end;
end;

function TCastleSceneHelper.CenterOfGeometry: TVector3;
var
  CX, CY, CZ: Single;
  bb: TBox3D;
  normal: TBox3D;
  NewOrigin: TVector3;
begin
  if not(RootNode = nil) then
    begin
      bb := BoundingBox;
      if not bb.IsEmptyOrZero then
        begin
          if bb.MaxSize > 0 then
            begin
              CX := Min(bb.Data[0].X, bb.Data[1].X) + (bb.SizeX / 2);
              CY := Min(bb.Data[0].Y, bb.Data[1].Y) + (bb.SizeY / 2);
              CZ := Min(bb.Data[0].Z, bb.Data[1].Z) + (bb.SizeZ / 2);
              Result := Vector3(CX, CY, CZ);
            end;
        end;
    end;
end;

procedure TCastleSceneHelper.ClearAndFreeItems;
var
  I: Integer;
begin
  for I := Count - 1 downto 0 do
    begin
      if (Items[I] is TCastleScene) then
        begin
          FreeAndNil(Items[I])
        end;
    end;
  Clear;
end;

{ TCastleViewportHelper }

function TCastleViewportHelper.GetEnvelope(
  const AScene: TCastleTransform): TFloatRectangle;
var
  i: Integer;
  OutputPoint: TVector2;
  rMin, rMax: TVector2;
  Corners: TBoxCorners;
begin
  Result := TFloatRectangle.Empty;
  rMin := Vector2(Infinity, Infinity);
  rMax := Vector2(-Infinity, -Infinity);
  { Initialise Extent min+max with max values }

  if ((EffectiveWidth > 0) and (EffectiveHeight > 0) and Assigned(AScene) and not AScene.BoundingBox.IsEmptyOrZero) then
	begin
	  AScene.BoundingBox.Corners(Corners);
    { Get BB Corners }
	  for i := Low(Corners) to High(Corners) do
      begin
        OutputPoint := PositionFromWorld(Corners[i]);
        { Convert 3D vertex to 2D }
        if OutputPoint.X < rMin.X then
          rMin.X := OutputPoint.X;
        if OutputPoint.Y < rMin.Y then
          rMin.Y := OutputPoint.Y;
        if OutputPoint.X > rMax.X then
          rMax.X := OutputPoint.X;
        if OutputPoint.Y > rMax.Y then
          rMax.Y := OutputPoint.Y;
        { Extract Min + Max }
      end;

    Result.Left := rMin.X;
    result.Bottom := rMin.Y;
	  Result.Width := (rMax.X - rMin.X);
	  Result.Height := (rMax.Y - rMin.Y);
    { Fill in result }
	end;
end;

end.
