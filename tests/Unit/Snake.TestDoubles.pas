unit Snake.TestDoubles;

{ Dubles compartilhados pelas duas suites (DUnitX em tests\Unit e FPCUnit em
  tests\Unit\fpc). So' depende de Snake.Game, entao compila igual nos dois
  compiladores e nao precisa de espelho. }

{$I pascalsnake.inc}

interface

uses
  Snake.Game;

type
  { Devolve sempre NextValue (limitado a ARange - 1). Com 0, a comida cai na
    primeira celula livre em varredura linha a linha. }
  TFixedRandom = class(TSnakeRandom)
  public
    NextValue: Integer;
    function Next(ARange: Integer): Integer; override;
  end;

{ Indice de (X, Y) entre as celulas livres (sem corpo) do tabuleiro, na mesma
  ordem que TSnakeGame usa para sortear a comida. Serve para mandar a comida
  para uma celula especifica: Fake.NextValue := FreeCellIndex(...); Reset. }
function FreeCellIndex(AGame: TSnakeGame; X, Y: Integer): Integer;

{ Cria um jogo com TFixedRandom (NextValue = 0). AFake continua pertencendo
  ao jogo -- a referencia so' serve para ajustar NextValue. }
function CreateGame(AWidth, AHeight: Integer; out AFake: TFixedRandom): TSnakeGame;

implementation

function TFixedRandom.Next(ARange: Integer): Integer;
begin
  Result := NextValue;
  if Result >= ARange then
    Result := ARange - 1;
end;

function FreeCellIndex(AGame: TSnakeGame; X, Y: Integer): Integer;
var
  CX, CY: Integer;
begin
  Result := 0;
  for CY := 0 to AGame.Height - 1 do
    for CX := 0 to AGame.Width - 1 do
    begin
      if (CX = X) and (CY = Y) then
        Exit;
      if AGame.CellAt(CX, CY) in [scEmpty, scFood] then
        Inc(Result);
    end;
  Result := -1;
end;

function CreateGame(AWidth, AHeight: Integer; out AFake: TFixedRandom): TSnakeGame;
begin
  AFake := TFixedRandom.Create;
  Result := TSnakeGame.Create(AWidth, AHeight, AFake);
end;

end.
