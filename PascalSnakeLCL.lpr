program PascalSnakeLCL;

{ Entrada do Lazarus (LCL). A entrada do Delphi e' PascalSnake.dpr; o codigo
  em src\ e' compartilhado pelas duas.

  O nome difere do .dpr de proposito: cada programa gera o seu <nome>.res pelo
  $R *.res, e com o mesmo nome Delphi e Lazarus sobrescreveriam o recurso um
  do outro (icone/versao x manifesto). O executavel continua PascalSnake.exe
  (Target/Filename no .lpi). }

{$MODE DELPHI}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // widgetset da LCL
  Forms,
  Snake.Game,
  Snake.MainForm;

{$R *.res}

begin
  // Sem RequireDerivedFormResource: TSnakeForm nao tem .lfm (usa CreateNew).
  Application.Scaled := True;
  Application.Title := 'Pascal Snake';
  Application.Initialize;
  Application.CreateForm(TSnakeForm, SnakeForm);
  Application.Run;
end.
