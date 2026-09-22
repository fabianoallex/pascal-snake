program PascalSnake;

{ Entrada do Delphi (VCL). A entrada do Lazarus e' PascalSnakeLCL.lpr: as duas
  diferem de verdade (a LCL precisa da unit Interfaces e de Application.Scaled),
  entao cada compilador tem o seu programa; o codigo em src\ e' um so'. }

uses
  Forms,
  Snake.Game in 'src\Snake.Game.pas',
  Snake.MainForm in 'src\Snake.MainForm.pas';

{$R *.res}

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Pascal Snake';
  // TSnakeForm nao tem .dfm: o construtor usa CreateNew.
  Application.CreateForm(TSnakeForm, SnakeForm);
  Application.Run;
end.
