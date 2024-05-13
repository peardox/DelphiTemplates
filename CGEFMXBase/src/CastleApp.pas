unit CastleApp;

interface
uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation,
  fmx.castlecontrol,
  CastleViewport,
  CastleUIControls,
  CastleVectors,
  CastleTransform,
  CastleRectangles,
  CastleScene,
  OffScreen,
  CastleHelpers;

type
  { TCastleApp }
  TCastleApp = class(TCastleView)
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override; // TCastleUserInterface
    procedure Start; override; // TCastleView
    procedure Stop; override; // TCastleView
    procedure Resize; override; // TCastleUserInterface
    procedure RenderOverChildren; override; // TCastleUserInterface
    procedure Render; override;
    procedure BeforeRender; override;
    { Override everything we might want to actually use }
  private
    { Private declarations }
    fStage: TCastleTransform; // A Holding Scene
    fCamera: TCastleCamera; // The camera
    fCameraLight: TCastleDirectionalLight; // A light
    fViewport: TCastleViewport; // The VP
    fEnvelope: TFloatRectangle;
    fUpdateCamera: Boolean;
    procedure MakeViewport;
    procedure AddModel(const AFilename: String);
    procedure DrawEnvelope;
    procedure ResetCamera(const AnEnvelope: TFloatRectangle);
    procedure SetCameraView(const AModel: TCastleTransform);
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Stage: TCastleTransform read fStage write fStage;
    property Camera: TCastleCamera read fCamera write fCamera;
  end;

implementation

uses
  Math,
  X3DLoad,
  CastleUtils,
  CastleUriUtils,
  CastleBoxes,
  CastleGLUtils,
  CastleColors,
  CastleLog,
  CastleProjection;

constructor TCastleApp.Create(AOwner: TComponent);
{ Simplified creation from FormCreate that sets up parent params
  Note that it defaults to Client layout so if you don't want
  it being full app then create the parent TCastleControl with
  an owning component e.g. a TLayout
}
var
  OwningCC: TCastleControl;
begin
  inherited;
  if AOwner is TCastleControl then
    begin
      OwningCC := AOwner as TCastleControl;
      OwningCC.Align := TAlignLayout.Client;
      OwningCC.Container.View := Self;
      if OwningCC.Owner is TFmxObject then
        begin
          OwningCC.Parent := OwningCC.Owner as TFmxObject;
        end
      else
        Raise Exception.Create('CastleControl must be owned by a TFmxObject');
    end
  else
    Raise Exception.Create('Owner must be a TCastleControl');
  fEnvelope := TFloatRectangle.Empty;
  fUpdateCamera := True;
end;

procedure TCastleApp.Start;
begin
  inherited;
  MakeViewport; // Make the VP
  AddModel('castle-data:/wall_doorway.gltf'); // Add a test model to the holding scene
                                   // created by MakeViewport
end;

procedure TCastleApp.AddModel(const AFilename: String);
{ Adds a model to the holding scene }
var
  model: TCastleScene;
begin
  if Assigned(fStage) and UriFileExists(AFilename) then
    begin
      model := TCastleScene.Create(Self);
      model.Load(AFilename);
      model.AdjustOriginOffset;
      fStage.Add(model);
    end
  else
    Raise Exception.Create('File not found');
end;

procedure TCastleApp.Stop;
begin
  inherited;
end;

procedure TCastleApp.Update(const SecondsPassed: Single;
  var HandleInput: Boolean);
begin
  inherited;
end;

procedure TCastleApp.MakeViewport;
begin
  fViewport := TCastleViewport.Create(Self);
  fViewport.FullSize := True;
  fViewport.Width := Container.UnscaledWidth;
  fViewport.Height := Container.UnscaledHeight;
  fViewport.Transparent := True;
  { Setup basic VP }

  fStage := TCastleTransform.Create(fViewport);
  fStage.Name := 'fStage';
  { Create a holding scene }

  fCamera := TCastleCamera.Create(fViewport);
  fCamera.ProjectionType := ptOrthographic;
  fCamera.Translation := Vector3(1,1,1);
  fCamera.Direction := -fCamera.Translation;
  fCamera.Orthographic.Origin := Vector2(0.5, 0.5);
  fCamera.Orthographic.Width := 1;
  fCamera.Orthographic.Height := 1;
  { Setup Camera }

  fCameraLight := CreateDirectionalLight(fCamera, Vector3(0,0,1));
  fCamera.Add(fCameraLight);
  { Create light and add it to Camera }

  fViewport.Items.Add(fCamera);
  fViewport.Items.Add(fStage);
  { Add to VP }

  fViewport.Camera := fCamera;
  { Set VP camera }

  InsertFront(fViewport);
  { Make it active }
end;

procedure TCastleApp.ResetCamera(const AnEnvelope: TFloatRectangle);
begin
  if (EffectiveHeight > 0) and (AnEnvelope.Height > 0) then
    begin
      if((AnEnvelope.Width / AnEnvelope.Height)<(EffectiveWidth / EffectiveHeight)) then
        begin
          fCamera.Orthographic.Width := AnEnvelope.Height;
          fCamera.Orthographic.Height := AnEnvelope.AspectRatio/AnEnvelope.Height;
        end
      else
        begin
          fCamera.Orthographic.Width := AnEnvelope.Width;
          fCamera.Orthographic.Height := AnEnvelope.AspectRatio / AnEnvelope.Width;
        end;
    end;
end;

procedure TCastleApp.SetCameraView(const AModel: TCastleTransform);
var
  osv: TFrameExport;
  NewEnvelope: TFloatRectangle;
begin
  if fUpdateCamera then
    begin
      osv := TFrameExport.Create(Self, 1, 1);
      fEnvelope := osv.Analyse(Container, AModel);

      if not fEnvelope.IsEmpty then
        begin
          if (fCamera.Orthographic.Width > 0) and (fCamera.Orthographic.Height > 0) then
            begin
              ResetCamera(fEnvelope);
              Resize;
              fUpdateCamera := False;
            end;
        end;
      FreeAndNil(osv);
    end;
end;

procedure TCastleApp.BeforeRender;
begin
  inherited;
  SetCameraView(fStage);
end;

procedure TCastleApp.Render;
begin
  inherited;
end;

procedure TCastleApp.RenderOverChildren;
begin
  inherited;
  DrawEnvelope;
  { Try drawing the envelope }
end;

procedure TCastleApp.Resize;
{ Handle resiz3wee }
begin
  inherited;
  fViewport.Width := Container.UnscaledWidth;
  fViewport.Height := Container.UnscaledHeight;
  if (fCamera.Orthographic.Width > 0) and (fViewport.Width > 0) then
    fCamera.Orthographic.Height := fCamera.Orthographic.Width * (fViewport.Height/fViewport.Width);
end;

destructor TCastleApp.Destroy;
begin
  inherited;
end;

procedure TCastleApp.DrawEnvelope;
var
  cr: TFloatRectangle;
begin
  if Assigned(fStage) then
    begin
      cr := fViewport.GetEnvelope(fStage);
      if not cr.IsEmpty then
        begin
          DrawRectangleOutline(cr, Gray);
        end;
    end;
end;


end.
