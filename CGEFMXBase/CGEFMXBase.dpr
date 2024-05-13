program CGEFMXBase;

{$R *.dres}

uses
  System.StartUpCopy,
  FMX.Forms,
  Unit1 in 'src\Unit1.pas' {Form1},
  CastleApp in 'src\CastleApp.pas',
  CastleHelpers in 'src\CastleHelpers.pas',
  OffScreen in 'src\OffScreen.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
