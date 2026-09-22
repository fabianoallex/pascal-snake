unit Snake.GameTests;

{ Testes de Snake.Game (FPCUnit). Mesma cobertura de tests\Unit\Snake.GameTests.pas
  (DUnitX/Delphi), com corpos identicos: toda mudanca aqui vai para la' na mesma
  sessao. Conferir com python <skill>/scripts/verify_test_mirrors.py --root . }

{$MODE DELPHI}{$H+}

interface

uses
  fpcunit, testregistry, SysUtils,
  Snake.Game,
  Snake.TestDoubles;

type
  TSnakeGameTests = class(TTestCase)
  published
    procedure NewGame_IsReadyWithThreeSegments;
    procedure NewGame_HeadAtCenterFacingRight;
    procedure NewGame_FoodOnFirstFreeCellWithFixedRandom;
    procedure CellAt_ReportsHeadAndBody;
    procedure Create_TooSmallBoard_Raises;
    procedure Step_WhenReady_DoesNothing;
    procedure Step_MovesHeadOneCellAndKeepsLength;
    procedure ChangeDirection_RejectsReverseAndSame;
    procedure ChangeDirection_TwoQuickTurnsAreBothApplied;
    procedure ChangeDirection_QueueHoldsAtMostTwo;
    procedure ChangeDirection_WhilePaused_IsRejected;
    procedure TogglePause_StopsAndResumes;
    procedure Step_EatingFoodGrowsAndScores;
    procedure Step_AfterEating_FoodReappearsOffTheSnake;
    procedure Step_HittingWall_EndsGame;
    procedure Step_WrapWalls_ComesOutOnOppositeSide;
    procedure Step_BitingItself_EndsGame;
    procedure Step_IntoCellTheTailIsLeaving_IsAllowed;
    procedure TickInterval_SpeedsUpAndHasFloor;
    procedure Step_FillingTheBoard_WinsTheGame;
  end;

implementation

procedure TSnakeGameTests.NewGame_IsReadyWithThreeSegments;
var
  G: TSnakeGame;
  F: TFixedRandom;
begin
  G := CreateGame(10, 10, F);
  try
    TAssert.AssertTrue('estado', G.State = gsReady);
    TAssert.AssertEquals('tamanho', 3, G.Length);
    TAssert.AssertEquals('pontos', 0, G.Score);
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.NewGame_HeadAtCenterFacingRight;
var
  G: TSnakeGame;
  F: TFixedRandom;
begin
  G := CreateGame(10, 10, F);
  try
    TAssert.AssertEquals(5, G.Head.X);
    TAssert.AssertEquals(5, G.Head.Y);
    TAssert.AssertEquals(4, G.Segments[1].X);
    TAssert.AssertEquals(3, G.Segments[2].X);
    TAssert.AssertTrue(G.Direction = sdRight);
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.NewGame_FoodOnFirstFreeCellWithFixedRandom;
var
  G: TSnakeGame;
  F: TFixedRandom;
begin
  G := CreateGame(10, 10, F);
  try
    TAssert.AssertTrue(G.HasFood);
    TAssert.AssertTrue(G.CellAt(0, 0) = scFood);
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.CellAt_ReportsHeadAndBody;
var
  G: TSnakeGame;
  F: TFixedRandom;
begin
  G := CreateGame(10, 10, F);
  try
    TAssert.AssertTrue(G.CellAt(5, 5) = scHead);
    TAssert.AssertTrue(G.CellAt(4, 5) = scBody);
    TAssert.AssertTrue(G.CellAt(3, 5) = scBody);
    TAssert.AssertTrue(G.CellAt(9, 9) = scEmpty);
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.Create_TooSmallBoard_Raises;
var
  Raised: Boolean;
begin
  Raised := False;
  try
    // O TFixedRandom passa a pertencer ao jogo mesmo quando o construtor
    // levanta: nao pode vazar (heaptrc/FastMM acusariam).
    TSnakeGame.Create(4, 1, TFixedRandom.Create).Free;
  except
    on ESnakeError do
      Raised := True;
  end;
  TAssert.AssertTrue(Raised);
end;

procedure TSnakeGameTests.Step_WhenReady_DoesNothing;
var
  G: TSnakeGame;
  F: TFixedRandom;
begin
  G := CreateGame(10, 10, F);
  try
    TAssert.AssertTrue(G.Step = srNone);
    TAssert.AssertEquals(5, G.Head.X);
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.Step_MovesHeadOneCellAndKeepsLength;
var
  G: TSnakeGame;
  F: TFixedRandom;
begin
  G := CreateGame(10, 10, F);
  try
    G.Start;
    TAssert.AssertTrue(G.Step = srMoved);
    TAssert.AssertEquals(6, G.Head.X);
    TAssert.AssertEquals(5, G.Head.Y);
    TAssert.AssertEquals(3, G.Length);
    TAssert.AssertTrue('cauda liberada', G.CellAt(3, 5) = scEmpty);
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.ChangeDirection_RejectsReverseAndSame;
var
  G: TSnakeGame;
  F: TFixedRandom;
begin
  G := CreateGame(10, 10, F);
  try
    TAssert.AssertFalse('meia-volta', G.ChangeDirection(sdLeft));
    TAssert.AssertFalse('mesma direcao', G.ChangeDirection(sdRight));
    TAssert.AssertTrue('curva', G.ChangeDirection(sdUp));
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.ChangeDirection_TwoQuickTurnsAreBothApplied;
var
  G: TSnakeGame;
  F: TFixedRandom;
begin
  G := CreateGame(10, 10, F);
  try
    G.Start;
    TAssert.AssertTrue(G.ChangeDirection(sdUp));
    // Esquerda e' meia-volta da direcao ATUAL (direita), mas nao da
    // enfileirada (cima): deve ser aceita.
    TAssert.AssertTrue(G.ChangeDirection(sdLeft));
    G.Step;
    TAssert.AssertEquals(5, G.Head.X);
    TAssert.AssertEquals(4, G.Head.Y);
    G.Step;
    TAssert.AssertEquals(4, G.Head.X);
    TAssert.AssertEquals(4, G.Head.Y);
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.ChangeDirection_QueueHoldsAtMostTwo;
var
  G: TSnakeGame;
  F: TFixedRandom;
begin
  G := CreateGame(10, 10, F);
  try
    TAssert.AssertTrue(G.ChangeDirection(sdUp));
    TAssert.AssertTrue(G.ChangeDirection(sdLeft));
    TAssert.AssertFalse(G.ChangeDirection(sdDown));
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.ChangeDirection_WhilePaused_IsRejected;
var
  G: TSnakeGame;
  F: TFixedRandom;
begin
  G := CreateGame(10, 10, F);
  try
    G.Start;
    G.TogglePause;
    TAssert.AssertFalse(G.ChangeDirection(sdUp));
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.TogglePause_StopsAndResumes;
var
  G: TSnakeGame;
  F: TFixedRandom;
begin
  G := CreateGame(10, 10, F);
  try
    G.Start;
    G.TogglePause;
    TAssert.AssertTrue(G.State = gsPaused);
    TAssert.AssertTrue(G.Step = srNone);
    TAssert.AssertEquals(5, G.Head.X);
    G.TogglePause;
    TAssert.AssertTrue(G.State = gsRunning);
    TAssert.AssertTrue(G.Step = srMoved);
    TAssert.AssertEquals(6, G.Head.X);
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.Step_EatingFoodGrowsAndScores;
var
  G: TSnakeGame;
  F: TFixedRandom;
begin
  G := CreateGame(10, 10, F);
  try
    F.NextValue := FreeCellIndex(G, 6, 5);
    G.Reset;
    TAssert.AssertTrue(G.CellAt(6, 5) = scFood);
    G.Start;
    TAssert.AssertTrue(G.Step = srAte);
    TAssert.AssertEquals('tamanho', 4, G.Length);
    TAssert.AssertEquals('pontos', 10, G.Score);
    TAssert.AssertEquals('comidas', 1, G.FoodEaten);
    TAssert.AssertEquals('cauda fica', 3, G.Segments[3].X);
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.Step_AfterEating_FoodReappearsOffTheSnake;
var
  G: TSnakeGame;
  F: TFixedRandom;
  I: Integer;
begin
  G := CreateGame(10, 10, F);
  try
    F.NextValue := FreeCellIndex(G, 6, 5);
    G.Reset;
    G.Start;
    G.Step;
    TAssert.AssertTrue(G.HasFood);
    for I := 0 to G.Length - 1 do
      TAssert.AssertFalse(SameGridPoint(G.Segments[I], G.Food));
    TAssert.AssertTrue(G.CellAt(G.Food.X, G.Food.Y) = scFood);
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.Step_HittingWall_EndsGame;
var
  G: TSnakeGame;
  F: TFixedRandom;
  I: Integer;
begin
  G := CreateGame(10, 10, F);
  try
    G.Start;
    for I := 1 to 4 do
      TAssert.AssertTrue(G.Step = srMoved);
    TAssert.AssertEquals(9, G.Head.X);
    TAssert.AssertTrue(G.Step = srDied);
    TAssert.AssertTrue(G.State = gsGameOver);
    TAssert.AssertTrue('parado apos morrer', G.Step = srNone);
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.Step_WrapWalls_ComesOutOnOppositeSide;
var
  G: TSnakeGame;
  F: TFixedRandom;
  I: Integer;
begin
  G := CreateGame(10, 10, F);
  try
    G.WrapWalls := True;
    G.Start;
    for I := 1 to 5 do
      TAssert.AssertTrue(G.Step = srMoved);
    TAssert.AssertEquals(0, G.Head.X);
    TAssert.AssertEquals(5, G.Head.Y);
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.Step_BitingItself_EndsGame;
var
  G: TSnakeGame;
  F: TFixedRandom;
begin
  G := CreateGame(10, 10, F);
  try
    // Com NextValue fixo, a comida reaparece sempre logo a frente da cabeca:
    // come duas vezes e fica com 5 segmentos em (3..7, 5).
    F.NextValue := FreeCellIndex(G, 6, 5);
    G.Reset;
    G.Start;
    TAssert.AssertTrue(G.Step = srAte);
    TAssert.AssertEquals(7, G.Food.X);
    TAssert.AssertTrue(G.Step = srAte);
    TAssert.AssertEquals(5, G.Length);
    G.ChangeDirection(sdDown);
    G.Step;
    G.ChangeDirection(sdLeft);
    G.Step;
    G.ChangeDirection(sdUp);
    TAssert.AssertTrue(G.Step = srDied);
    TAssert.AssertTrue(G.State = gsGameOver);
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.Step_IntoCellTheTailIsLeaving_IsAllowed;
var
  G: TSnakeGame;
  F: TFixedRandom;
begin
  G := CreateGame(10, 10, F);
  try
    F.NextValue := FreeCellIndex(G, 6, 5);
    G.Reset;
    G.Start;
    TAssert.AssertTrue(G.Step = srAte);
    TAssert.AssertEquals(4, G.Length);
    // Quadrado 2x2: no terceiro passo a cabeca entra onde a cauda estava.
    G.ChangeDirection(sdDown);
    G.Step;
    G.ChangeDirection(sdLeft);
    G.Step;
    G.ChangeDirection(sdUp);
    TAssert.AssertTrue(G.Step = srMoved);
    TAssert.AssertEquals(5, G.Head.X);
    TAssert.AssertEquals(5, G.Head.Y);
    TAssert.AssertTrue(G.State = gsRunning);
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.TickInterval_SpeedsUpAndHasFloor;
var
  G: TSnakeGame;
  F: TFixedRandom;
  I: Integer;
begin
  G := CreateGame(60, 1, F);
  try
    TAssert.AssertEquals(150, G.TickIntervalMs);
    // Comida sempre logo a frente (ver Step_BitingItself_EndsGame).
    F.NextValue := FreeCellIndex(G, 31, 0);
    G.Reset;
    G.Start;
    TAssert.AssertTrue(G.Step = srAte);
    TAssert.AssertEquals(146, G.TickIntervalMs);
    for I := 2 to 25 do
      TAssert.AssertTrue(G.Step = srAte);
    TAssert.AssertEquals(25, G.FoodEaten);
    TAssert.AssertEquals(60, G.TickIntervalMs);
  finally
    G.Free;
  end;
end;

procedure TSnakeGameTests.Step_FillingTheBoard_WinsTheGame;
var
  G: TSnakeGame;
  F: TFixedRandom;
begin
  G := CreateGame(5, 1, F);
  try
    // Cobra em (0..2, 0); com NextValue = 0 a comida cai em (3, 0) e depois (4, 0).
    G.Start;
    TAssert.AssertTrue(G.Step = srAte);
    TAssert.AssertEquals(4, G.Food.X);
    TAssert.AssertTrue(G.Step = srWon);
    TAssert.AssertTrue(G.State = gsWon);
    TAssert.AssertFalse(G.HasFood);
    TAssert.AssertEquals(20, G.Score);
  finally
    G.Free;
  end;
end;

initialization
  RegisterTest(TSnakeGameTests);

end.
