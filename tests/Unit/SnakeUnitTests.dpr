program SnakeUnitTests;

{ Runner DUnitX (console) dos testes unitarios. A suite irma em FPCUnit fica em
  tests\Unit\fpc -- mesma cobertura, corpos de teste identicos.

  ReportMemoryLeaksOnShutdown ligado: o criterio e' 0 vazamentos, como o
  heaptrc do lado FPC (cada lado pega classes de bug diferentes). }

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  Snake.Game in '..\..\src\Snake.Game.pas',
  Snake.TestDoubles in 'Snake.TestDoubles.pas',
  Snake.DUnitXCompat in 'Snake.DUnitXCompat.pas',
  Snake.GameTests in 'Snake.GameTests.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;
begin
  ReportMemoryLeaksOnShutdown := True;
  try
    TDUnitX.CheckCommandLine;

    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.FailsOnNoAsserts := False;

    if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
    begin
      Logger := TDUnitXConsoleLogger.Create(
        TDUnitX.Options.ConsoleMode = TDunitXConsoleMode.Quiet);
      Runner.AddLogger(Logger);
    end;

    NUnitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    Runner.AddLogger(NUnitLogger);

    Results := Runner.Execute;

    if not Results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    if (TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause) and IsConsole then
    begin
      System.Write('Fim. Pressione <Enter> para sair.');
      System.Readln;
    end;
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
end.
