unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Layouts,
  FMX.StdCtrls, Fmx.CastleControl, FMX.Controls.Presentation,
  CastleApp
  ;

type
  TForm1 = class(TForm)
    Layout1: TLayout;
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    CastleControl: TCastleControl;
    CastleApp: TCastleApp;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

uses CastleLog;

procedure TForm1.FormCreate(Sender: TObject);
begin
  LogFileName := 'Test.log';
  InitializeLog;

  CastleControl := TCastleControl.Create(Layout1);
  CastleApp := TCastleApp.Create(CastleControl);
end;

end.
