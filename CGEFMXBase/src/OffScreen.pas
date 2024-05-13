unit OffScreen;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  CastleUIControls, CastleVectors,
  CastleGLUtils, CastleColors,
  CastleViewport,
  CastleTransform,
  CastleDebugTransform,
  CastleScene,
  X3DNodes,
  CastleImages,
  CastleRectangles,
  CastleHelpers;

type
  TOffScreenViewport = class(TCastleUserInterface)
  private
    fWidth: Integer;
    fHeight: Integer;
    fViewport: TCastleViewport;
    fStage: TCastleScene;
    fCamera: TCastleCamera;
    fCameraLight: TCastleDirectionalLight;
    fTransparent: Boolean;
    function CloneModel(const AModel: TCastleScene; const AniIndex: Integer = -1; const AniTime: Single = 0; const UseCenterOfGeometry: Boolean = False): TCastleScene;
    procedure Clear;
    procedure CreateViewport;
    function Duplicate(const AModel: TCastleTransform; const UseCenterOfGeometry: Boolean = False): TCastleTransform;
    function GetEnvelope: TFloatRectangle;
    procedure DebugLogNodeName(Node: TX3DNode);
  public
    constructor Create(AOwner: TComponent); overload; override;
    constructor Create(AOwner: TComponent; const AWidth: Integer; const AHeight: Integer); reintroduce; overload;
    destructor Destroy; override;
    property Transparent: Boolean read fTransparent write fTransparent;
    property Width: Integer read fWidth write fWidth;
    property Height: Integer read fHeight write fHeight;
  end;

  TFrameExport = class(TOffScreenViewport)
  private
    fImageBuffer: TCastleImage;
  public
    destructor Destroy; override;
    function Analyse(const AContainer: TCastleContainer; const AModel: TCastleTransform; const NewWidth: Single = 1; const NewHeight: Single = 1): TFloatRectangle;
    function Grab(const AContainer: TCastleContainer; const AModel: TCastleTransform; const NewWidth: Single = 1; const NewHeight: Single = 1): Boolean;
    procedure Save(const AFilename: String);
  end;

implementation

uses CastleProjection, CastleGLImages, CastleLog, Math, X3DLoad, CastleFilesUtils;

{ TOffScreenViewport }

constructor TOffScreenViewport.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fTransparent := True;
  EnableUIScaling := False;
end;

{ Recursively clone model and add to stage }
procedure TOffScreenViewport.Clear;
begin
  if Assigned(fStage) then
    fStage.ClearAndFreeItems;
end;

procedure TOffScreenViewport.DebugLogNodeName(Node: TX3DNode);
var
  ParentNode: TX3DNode;
  ParentNodeStr: String;
  Img: TCastleImage;
begin
  ParentNode := Nil;
  case Node.ParentFieldsCount of
    0: ParentNodeStr := ''; // possible for root node
    1: begin
         ParentNode := Node.ParentFields[0].ParentNode as TX3DNode;
         ParentNodeStr := ParentNode.X3DName;
       end;
    else
       ParentNodeStr := '(multiple parents)';
  end;

  if Node is TImageTextureNode then
    begin
    WritelnLog('Found node: %s, parent: %s, BaseURL: %s', [
      Node.X3DName,
      ParentNodeStr,
      TImageTextureNode(Node).FdUrl.Items[0]
    ]);
    if TImageTextureNode(Node).FdUrl.Items[0] = 'dungeon_texture.png' then
      begin
      Img := LoadImage('castle-data:/alt_texture_1_Golden.png');
      TImageTextureNode(Node).LoadFromImage(Img, True, '');
//      if ParentNode is TPhysicalMaterialNode then
//        TPhysicalMaterialNode(ParentNode).BaseTexture := TImageTextureNode(Node);
      TImageTextureNode(Node).IsTextureLoaded :=  True;
      end;

    end
  else if Node is TTransformNode then
    begin
      if (ParentNodeStr <> '') and (Node.X3DName = 'wall_doorway_door') then
        begin
//          TTransformNode(Node).Rotation := Vector4(0,1,0,DegToRad(180));
          WritelnLog('Tried opening door');
        end;

    end
  else
    WritelnLog('Found node: %s, parent: %s', [
      Node.X3DName,
      ParentNodeStr
    ]);
end;

{ Recursively clone model and add to stage }
function TOffScreenViewport.Duplicate(const AModel: TCastleTransform; const UseCenterOfGeometry: Boolean = False): TCastleTransform;
var
  I: Integer;
  Clone, Kid: TCastleTransform;
  NN: TX3DNode;
begin
  Clone := Nil;
  if AModel is TCastleScene then
    begin
      Clone := CloneModel(AModel as TCastleScene, -1, 0, UseCenterOfGeometry);
{
      NN := TCastleScene(Clone).RootNode;
      NN.EnumerateNodes(TImageTextureNode, DebugLogNodeName, false);  // TTransformNode
//      NN.EnumerateNodes(TTransformNode, DebugLogNodeName, false);
      Clone.VisibleChangeHere([vcVisibleGeometry, vcVisibleNonGeometry]);
      SaveNode(NN, '../../data/test.x3d');
}
    end
  else if AModel is TCastleTransform then
    begin
      Clone := TCastleTransform.Create(Self);
      Clone.Name := '';
    end
  else
    WriteLnLog('*** Unhandled Class *** = ' + AModel.ClassName);

  for I := 0 to AModel.Count - 1 do
    begin
      if AModel.Items[I] is TCastleScene then
        begin
          Kid := Duplicate(AModel.Items[I], UseCenterOfGeometry);
          if (Clone <> Nil) and (Kid <> Nil) then
            Clone.Add(Kid);
        end
      else
        WriteLnLog('Skipping ' + AModel.ClassName + ' ' + AModel.Name);
    end;
  Result := Clone;
end;

function TOffScreenViewport.CloneModel(const AModel: TCastleScene; const AniIndex: Integer = -1; const AniTime: Single = 0; const UseCenterOfGeometry: Boolean = False): TCastleScene;
var
  ClonedModel: TCastleScene;
  AniName: String;
begin
  Result := Nil;
  if AModel.Pickable then
    begin
      ClonedModel := AModel.Clone(AModel);
      if not UseCenterOfGeometry then
        ClonedModel.AdjustOriginOffset
      else
        ClonedModel.Translation := -ClonedModel.CenterOfGeometry;
      if AniIndex >= 0 then
        begin
          AniName := ClonedModel.AnimationsList[AniIndex];
          if AniTime < 0 then
            ClonedModel.ForceAnimationPose(AniName, ClonedModel.AnimationDuration(AniName) * -AniTime, True)
          else
            ClonedModel.ForceAnimationPose(AniName, AniTime, True);
        end;
      ClonedModel.Scale := AModel.Scale;
      ClonedModel.Name := '';
      Result := ClonedModel;
    end;
end;

constructor TOffScreenViewport.Create(AOwner: TComponent; const AWidth,
  AHeight: Integer);
begin
  Create(AOwner);
  fWidth := AWidth;
  fHeight := AHeight;
  Width := fWidth;
  Height := fHeight;
  CreateViewport;
end;

procedure TOffScreenViewport.CreateViewport;
begin
  fViewport := TCastleViewport.Create(Self);
  fViewport.FullSize := False;
  fViewport.Width := fWidth;
  fViewport.Height := fHeight;
  fViewport.Transparent := fTransparent;

  fStage := TCastleScene.Create(fViewport);

  fCamera := TCastleCamera.Create(fViewport);
  fCamera.ProjectionType := ptOrthographic;
  fCamera.Translation := Vector3(1,1,1);
  fCamera.Direction := -fCamera.Translation;
  fCamera.Orthographic.Origin := Vector2(0.5, 0.5);
  fCamera.Orthographic.Width := 1;
  fCamera.Orthographic.Height := 1;

  fCameraLight := CreateDirectionalLight(fCamera, Vector3(0,0,1));
  fCamera.Add(fCameraLight);

  fViewport.Items.Add(fCamera);
  fViewport.Items.Add(fStage);

  fViewport.Camera := fCamera;

  InsertFront(fViewport);
end;

destructor TOffScreenViewport.Destroy;
begin
  if Assigned(fStage) then
    begin
      Clear;
      FreeAndNil(fStage);
    end;
  if Assigned(fCameraLight) then
    FreeAndNil(fCameraLight);
  if Assigned(fCamera) then
    FreeAndNil(fCamera);
  if Assigned(fViewport) then
    FreeAndNil(fViewport);
  inherited;
end;

function TOffScreenViewport.GetEnvelope: TFloatRectangle;
begin
  Result := fViewport.GetEnvelope(fStage);
end;

{ TFrameExport }

destructor TFrameExport.Destroy;
begin
  if Assigned(fImageBuffer) then
    FreeAndNil(fImageBuffer);
  inherited;
end;

function TFrameExport.Grab(const AContainer: TCastleContainer; const AModel: TCastleTransform;
  const NewWidth: Single = 1; const NewHeight: Single = 1): Boolean;
var
  Image: TDrawableImage;
  RGBA: TRGBAlphaImage;
  ViewportRect: TRectangle;
begin
  Result := False;
  try
    RGBA := TRGBAlphaImage.Create(fWidth, fHeight);
    RGBA.ClearAlpha(0);
    Image := TDrawableImage.Create(RGBA, true, true);

    try
      fViewport.Transparent := fTransparent;
      fCamera.Orthographic.Width := NewWidth;
      fCamera.Orthographic.Height := NewHeight;
      fStage.Add(Duplicate(AModel, True));

      Image.RenderToImageBegin;
      ViewportRect := Rectangle(0, 0, fWidth, fHeight);
      AContainer.RenderControl(fViewport,ViewportRect);
      Image.RenderToImageEnd;

      try
        if Assigned(fImageBuffer) then
          FreeAndNil(fImageBuffer);

        if fTransparent then
          fImageBuffer := Image.GetContents(TRGBAlphaImage)
        else
          fImageBuffer := Image.GetContents(TRGBImage);
        Result := True;
      except
        on E : Exception do
          raise Exception.Create('Exception extracting framebuffer : ' + E.ClassName + ' - ' + E.Message);
      end;
    except
      on E : Exception do
        raise Exception.Create('Exception creating and rendering scene : ' + E.ClassName + ' - ' + E.Message);
    end;
  finally
    FreeAndNil(Image);
  end;
end;

function TFrameExport.Analyse(const AContainer: TCastleContainer; const AModel: TCastleTransform;
  const NewWidth: Single = 1; const NewHeight: Single = 1): TFloatRectangle;
var
  Image: TDrawableImage;
  RGBA: TRGBAlphaImage;
  ViewportRect: TRectangle;
begin
  Result := TFloatRectangle.Empty;
  try
    RGBA := TRGBAlphaImage.Create(fWidth, fHeight);
    RGBA.ClearAlpha(0);
    Image := TDrawableImage.Create(RGBA, true, true);

    fViewport.Transparent := fTransparent;
    fViewport.Width := fWidth;
    fViewport.Height := fHeight;

    fStage.ClearAndFreeItems;
    fCamera.Orthographic.Width := NewWidth;
    fCamera.Orthographic.Height := NewHeight;

    fStage.Add(Duplicate(AModel));
//    fStage.Center := Vector3(0,0,0);
    try
      Image.RenderToImageBegin;
      ViewportRect := Rectangle(0, 0, fWidth, fHeight);
      AContainer.RenderControl(fViewport,ViewportRect);
      Image.RenderToImageEnd;
      Result := GetEnvelope;
      WriteLnLog('Envelope = ' + Result.ToString);
    except
      on E : Exception do
        raise Exception.Create('Exception creating and rendering scene : ' + E.ClassName + ' - ' + E.Message);
    end;
  finally
    FreeAndNil(Image);
  end;
end;

procedure TFrameExport.Save(const AFilename: String);
begin
  if Assigned(fImageBuffer) then
    SaveImage(fImageBuffer, AFilename);
end;

end.
