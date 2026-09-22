unit Snake.Game;

{ Regras do jogo, sem nenhuma dependencia de UI (VCL/LCL) nem de relogio.

  O tabuleiro avanca um passo por chamada de Step; quem decide QUANDO chamar
  (TTimer no formulario, laco manual nos testes) e' o chamador. A fonte de
  numeros aleatorios e' injetavel (TSnakeRandom) para que os testes consigam
  posicionar a comida de forma deterministica. }

{$I pascalsnake.inc}

interface

uses
  SysUtils;

type
  ESnakeError = class(Exception);

  TSnakeDirection = (sdUp, sdRight, sdDown, sdLeft);
  TSnakeGameState = (gsReady, gsRunning, gsPaused, gsGameOver, gsWon);
  TSnakeStepResult = (srNone, srMoved, srAte, srDied, srWon);
  TSnakeCell = (scEmpty, scBody, scHead, scFood);

  TGridPoint = record
    X: Integer;
    Y: Integer;
  end;

  { Fonte de aleatoriedade. A implementacao padrao usa System.Random; os
    testes herdam desta classe para devolver valores fixos. }
  TSnakeRandom = class
  public
    { Devolve um inteiro em [0, ARange). ARange sempre > 0. }
    function Next(ARange: Integer): Integer; virtual;
  end;

  TSnakeGame = class
  private
    FWidth: Integer;
    FHeight: Integer;
    FRandom: TSnakeRandom;
    FBody: array of TGridPoint;   // indice 0 = cabeca
    FLength: Integer;
    FOccupied: array of Boolean;  // FWidth * FHeight, celulas com corpo
    FFood: TGridPoint;
    FHasFood: Boolean;
    FDirection: TSnakeDirection;
    FQueue: array[0..1] of TSnakeDirection;
    FQueueCount: Integer;
    FState: TSnakeGameState;
    FFoodEaten: Integer;
    FWrapWalls: Boolean;
    function IndexOf(X, Y: Integer): Integer;
    function GetSegment(AIndex: Integer): TGridPoint;
    function GetHead: TGridPoint;
    function GetScore: Integer;
    procedure PlaceFood;
  public
    const
      InitialLength = 3;
      PointsPerFood = 10;
      BaseIntervalMs = 150;
      IntervalStepMs = 4;
      MinIntervalMs = 60;

    { A instancia assume a posse de ARandom (libera no Destroy). nil = padrao. }
    constructor Create(AWidth, AHeight: Integer; ARandom: TSnakeRandom = nil);
    destructor Destroy; override;

    { Volta ao estado inicial (gsReady): cobra de 3 segmentos no centro,
      virada para a direita, pontuacao zerada e comida posicionada. }
    procedure Reset;
    { gsReady -> gsRunning. Ignorado em outros estados. }
    procedure Start;
    { gsRunning <-> gsPaused. Ignorado em outros estados. }
    procedure TogglePause;
    { Enfileira uma mudanca de direcao (ate 2 pendentes, para curvas rapidas
      entre dois ticks). Recusa meia-volta e repeticao da ultima direcao. }
    function ChangeDirection(ADirection: TSnakeDirection): Boolean;
    { Avanca um passo. So tem efeito em gsRunning. }
    function Step: TSnakeStepResult;
    { Intervalo sugerido entre passos: acelera conforme a cobra come. }
    function TickIntervalMs: Integer;
    function CellAt(X, Y: Integer): TSnakeCell;

    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
    property State: TSnakeGameState read FState;
    property Direction: TSnakeDirection read FDirection;
    property Length: Integer read FLength;
    property Segments[AIndex: Integer]: TGridPoint read GetSegment;
    property Head: TGridPoint read GetHead;
    property Food: TGridPoint read FFood;
    property HasFood: Boolean read FHasFood;
    property FoodEaten: Integer read FFoodEaten;
    property Score: Integer read GetScore;
    { Quando True, sair por uma borda entra pela oposta em vez de morrer.
      Pode ser trocado a qualquer momento; vale a partir do proximo passo. }
    property WrapWalls: Boolean read FWrapWalls write FWrapWalls;
  end;

function GridPoint(X, Y: Integer): TGridPoint;
function SameGridPoint(const A, B: TGridPoint): Boolean;
function OppositeDirection(ADirection: TSnakeDirection): TSnakeDirection;

implementation

const
  DeltaX: array[TSnakeDirection] of Integer = (0, 1, 0, -1);
  DeltaY: array[TSnakeDirection] of Integer = (-1, 0, 1, 0);

function GridPoint(X, Y: Integer): TGridPoint;
begin
  Result.X := X;
  Result.Y := Y;
end;

function SameGridPoint(const A, B: TGridPoint): Boolean;
begin
  Result := (A.X = B.X) and (A.Y = B.Y);
end;

function OppositeDirection(ADirection: TSnakeDirection): TSnakeDirection;
begin
  case ADirection of
    sdUp: Result := sdDown;
    sdRight: Result := sdLeft;
    sdDown: Result := sdUp;
  else
    Result := sdRight;
  end;
end;

{ TSnakeRandom }

function TSnakeRandom.Next(ARange: Integer): Integer;
begin
  Result := Random(ARange);
end;

{ TSnakeGame }

constructor TSnakeGame.Create(AWidth, AHeight: Integer; ARandom: TSnakeRandom);
begin
  inherited Create;
  // Assume a posse de ARandom ANTES de validar: se o raise abaixo acontecer,
  // o Destroy (chamado automaticamente) libera o objeto recebido.
  if ARandom <> nil then
    FRandom := ARandom
  else
    FRandom := TSnakeRandom.Create;
  if (AWidth < InitialLength + 2) or (AHeight < 1) then
    raise ESnakeError.CreateFmt('Tabuleiro invalido: %dx%d', [AWidth, AHeight]);
  FWidth := AWidth;
  FHeight := AHeight;
  SetLength(FBody, FWidth * FHeight);
  SetLength(FOccupied, FWidth * FHeight);
  Reset;
end;

destructor TSnakeGame.Destroy;
begin
  FRandom.Free;
  inherited Destroy;
end;

function TSnakeGame.IndexOf(X, Y: Integer): Integer;
begin
  Result := Y * FWidth + X;
end;

function TSnakeGame.GetSegment(AIndex: Integer): TGridPoint;
begin
  if (AIndex < 0) or (AIndex >= FLength) then
    raise ESnakeError.CreateFmt('Segmento fora do intervalo: %d', [AIndex]);
  Result := FBody[AIndex];
end;

function TSnakeGame.GetHead: TGridPoint;
begin
  Result := FBody[0];
end;

function TSnakeGame.GetScore: Integer;
begin
  Result := FFoodEaten * PointsPerFood;
end;

procedure TSnakeGame.Reset;
var
  I, CenterX, CenterY: Integer;
begin
  for I := 0 to High(FOccupied) do
    FOccupied[I] := False;

  CenterX := FWidth div 2;
  CenterY := FHeight div 2;
  FLength := InitialLength;
  for I := 0 to FLength - 1 do
  begin
    FBody[I] := GridPoint(CenterX - I, CenterY);
    FOccupied[IndexOf(CenterX - I, CenterY)] := True;
  end;

  FDirection := sdRight;
  FQueueCount := 0;
  FFoodEaten := 0;
  FState := gsReady;
  PlaceFood;
end;

procedure TSnakeGame.PlaceFood;
var
  FreeCount, Target, I: Integer;
begin
  FreeCount := FWidth * FHeight - FLength;
  FHasFood := FreeCount > 0;
  if not FHasFood then
    Exit;

  // Sorteia o N-esimo espaco livre (varredura linha a linha): um unico
  // sorteio, sem tentativa-e-erro, mesmo com o tabuleiro quase cheio.
  Target := FRandom.Next(FreeCount);
  for I := 0 to High(FOccupied) do
    if not FOccupied[I] then
    begin
      if Target = 0 then
      begin
        FFood := GridPoint(I mod FWidth, I div FWidth);
        Exit;
      end;
      Dec(Target);
    end;
end;

procedure TSnakeGame.Start;
begin
  if FState = gsReady then
    FState := gsRunning;
end;

procedure TSnakeGame.TogglePause;
begin
  case FState of
    gsRunning: FState := gsPaused;
    gsPaused: FState := gsRunning;
  end;
end;

function TSnakeGame.ChangeDirection(ADirection: TSnakeDirection): Boolean;
var
  Last: TSnakeDirection;
begin
  Result := False;
  if not (FState in [gsReady, gsRunning]) then
    Exit;
  if FQueueCount >= System.Length(FQueue) then
    Exit;

  // Compara com a ultima direcao ENFILEIRADA, nao com a atual: assim
  // "cima, esquerda" dentro do mesmo tick vira duas curvas validas em vez
  // de uma meia-volta que mataria a cobra.
  if FQueueCount > 0 then
    Last := FQueue[FQueueCount - 1]
  else
    Last := FDirection;
  if (ADirection = Last) or (ADirection = OppositeDirection(Last)) then
    Exit;

  FQueue[FQueueCount] := ADirection;
  Inc(FQueueCount);
  Result := True;
end;

function TSnakeGame.Step: TSnakeStepResult;
var
  NewHead, Tail: TGridPoint;
  WillEat: Boolean;
  I: Integer;
begin
  Result := srNone;
  if FState <> gsRunning then
    Exit;

  if FQueueCount > 0 then
  begin
    FDirection := FQueue[0];
    FQueue[0] := FQueue[1];
    Dec(FQueueCount);
  end;

  NewHead := GridPoint(FBody[0].X + DeltaX[FDirection],
    FBody[0].Y + DeltaY[FDirection]);

  if (NewHead.X < 0) or (NewHead.X >= FWidth) or
     (NewHead.Y < 0) or (NewHead.Y >= FHeight) then
  begin
    if not FWrapWalls then
    begin
      FState := gsGameOver;
      Result := srDied;
      Exit;
    end;
    NewHead.X := (NewHead.X + FWidth) mod FWidth;
    NewHead.Y := (NewHead.Y + FHeight) mod FHeight;
  end;

  WillEat := FHasFood and SameGridPoint(NewHead, FFood);
  Tail := FBody[FLength - 1];

  // Entrar na celula da cauda e' permitido quando a cobra nao cresce: a cauda
  // sai dali neste mesmo passo.
  if FOccupied[IndexOf(NewHead.X, NewHead.Y)] and
     (WillEat or not SameGridPoint(NewHead, Tail)) then
  begin
    FState := gsGameOver;
    Result := srDied;
    Exit;
  end;

  if WillEat then
    Inc(FLength)
  else
    FOccupied[IndexOf(Tail.X, Tail.Y)] := False;

  for I := FLength - 1 downto 1 do
    FBody[I] := FBody[I - 1];
  FBody[0] := NewHead;
  FOccupied[IndexOf(NewHead.X, NewHead.Y)] := True;

  if not WillEat then
  begin
    Result := srMoved;
    Exit;
  end;

  Inc(FFoodEaten);
  PlaceFood;
  if FHasFood then
    Result := srAte
  else
  begin
    FState := gsWon;
    Result := srWon;
  end;
end;

function TSnakeGame.TickIntervalMs: Integer;
begin
  Result := BaseIntervalMs - FFoodEaten * IntervalStepMs;
  if Result < MinIntervalMs then
    Result := MinIntervalMs;
end;

function TSnakeGame.CellAt(X, Y: Integer): TSnakeCell;
begin
  if (X < 0) or (X >= FWidth) or (Y < 0) or (Y >= FHeight) then
    raise ESnakeError.CreateFmt('Celula fora do tabuleiro: (%d, %d)', [X, Y]);
  if SameGridPoint(FBody[0], GridPoint(X, Y)) then
    Result := scHead
  else if FOccupied[IndexOf(X, Y)] then
    Result := scBody
  else if FHasFood and SameGridPoint(FFood, GridPoint(X, Y)) then
    Result := scFood
  else
    Result := scEmpty;
end;

end.
