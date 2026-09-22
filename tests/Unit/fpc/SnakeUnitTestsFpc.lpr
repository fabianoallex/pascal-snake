program SnakeUnitTestsFpc;

{ Runner FPCUnit (mesma cobertura de tests\Unit\SnakeUnitTests.dpr, DUnitX).

  Console, quando chamado com qualquer parametro (CI / agentes):
    .\SnakeUnitTestsFpc.exe --all --format=plain
  GUI (arvore de testes + barra verde/vermelha), sem parametros:
    .\SnakeUnitTestsFpc.exe
  Fora do Windows roda sempre em modo console (sem LCL/widgetset).

  Compilado com heaptrc (-gh): o criterio e' 0 blocos nao liberados. }

{$MODE DELPHI}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  Interfaces, Forms, GuiTestRunner,
  {$ENDIF}
  Classes, consoletestrunner, testregistry,
  Snake.GameTests;

var
  ConsoleApp: TTestRunner;
begin
  {$IFDEF MSWINDOWS}
  if ParamCount = 0 then
  begin
    Application.Initialize;
    Application.CreateForm(TGUITestRunner, TestRunner);
    Application.Run;
  end
  else
  {$ENDIF}
  begin
    DefaultFormat := fPlain;
    DefaultRunAllTests := True;
    ConsoleApp := TTestRunner.Create(nil);
    try
      ConsoleApp.Initialize;
      ConsoleApp.Title := 'pascal-snake - testes unitarios (FPCUnit)';
      ConsoleApp.Run;
    finally
      ConsoleApp.Free;
    end;
  end;
end.
