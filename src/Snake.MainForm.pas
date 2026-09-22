unit Snake.MainForm;

{ Janela principal, compilada sem alteracoes em Delphi (VCL) e Lazarus (LCL).

  Nao existe .dfm nem .lfm: o construtor chama CreateNew (que nao tenta carregar
  recurso de formulario) e monta os controles em codigo. Isso evita manter dois
  arquivos de formulario independentes que cada IDE reescreve por conta propria
  (DPI, ordem de Anchors, encoding) -- ver CLAUDE.md.

  Toda a regra do jogo esta em Snake.Game; aqui so' ha entrada, timer e desenho. }

{$I pascalsnake.inc}

interface

uses
  {$IFDEF FPC}
  LCLType,
  {$ELSE}
  Windows,
  {$ENDIF}
  SysUtils, Classes, Types, Graphics, Controls, Forms, ExtCtrls, StdCtrls,
  Snake.Game;

type
  TSnakeForm = class(TForm)
  private
    FGame: TSnakeGame;
    FBoard: TPaintBox;
    FStatusPanel: TPanel;
    FScoreLabel: TLabel;
    FHelpLabel: TLabel;
    FTimer: TTimer;
    FBuffer: TBitmap;
    FCellSize: Integer;
    FBestScore: Integer;
    procedure BoardPaint(Sender: TObject);
    procedure TimerTick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleDirection(ADirection: TSnakeDirection);
    procedure NewGame;
    procedure StartGame;
    procedure SyncTimer;
    procedure UpdateStatus;
    procedure RenderBoard;
    procedure DrawCell(X, Y: Integer; AColor: TColor; AInset: Integer);
    procedure DrawOverlay(const ATitle, ASubtitle: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  SnakeForm: TSnakeForm;

implementation

const
  BoardCols = 24;
  BoardRows = 18;
  BaseCellSize = 26;  // em 96 dpi

  ColorBackground = TColor($00221A14);
  ColorGridA = TColor($002A211A);
  ColorGridB = TColor($00261E17);
  ColorHead = TColor($0071E08A);
  ColorBody = TColor($0046B45A);
  ColorBodyTail = TColor($00307A3C);
  ColorFood = TColor($004A4AE8);
  ColorFoodShine = TColor($00A0A0FF);
  ColorOverlay = TColor($00F0F0F0);
  ColorAccent = TColor($0071E08A);
  ColorPanel = TColor($00302620);

{ TSnakeForm }

constructor TSnakeForm.Create(AOwner: TComponent);
begin
  // inherited Create procuraria um .dfm/.lfm, que nao existe neste projeto.
  inherited CreateNew(AOwner);

  Caption := 'Pascal Snake';
  BorderStyle := bsSingle;
  BorderIcons := [biSystemMenu, biMinimize];
  Position := poScreenCenter;
  Color := ColorBackground;
  KeyPreview := True;
  DoubleBuffered := True;
  OnKeyDown := FormKeyDown;

  // Os tamanhos abaixo ja' sao convertidos para o DPI real com MulDiv, porque
  // o tabuleiro e' desenhado pixel a pixel num TBitmap. Sem Scaled := False a
  // LCL (Application.Scaled) aplicaria a escala uma segunda vez no form.
  Scaled := False;
  FCellSize := MulDiv(BaseCellSize, Screen.PixelsPerInch, 96);

  FStatusPanel := TPanel.Create(Self);
  FStatusPanel.Parent := Self;
  FStatusPanel.Align := alBottom;
  FStatusPanel.Height := MulDiv(54, Screen.PixelsPerInch, 96);
  FStatusPanel.BevelOuter := bvNone;
  FStatusPanel.Color := ColorPanel;
  {$IFNDEF FPC}
  FStatusPanel.ParentBackground := False;
  {$ENDIF}

  FScoreLabel := TLabel.Create(Self);
  FScoreLabel.Parent := FStatusPanel;
  FScoreLabel.Left := MulDiv(12, Screen.PixelsPerInch, 96);
  FScoreLabel.Top := MulDiv(6, Screen.PixelsPerInch, 96);
  FScoreLabel.Font.Name := 'Segoe UI';
  FScoreLabel.Font.Size := 12;
  FScoreLabel.Font.Style := [fsBold];
  FScoreLabel.Font.Color := ColorAccent;

  FHelpLabel := TLabel.Create(Self);
  FHelpLabel.Parent := FStatusPanel;
  FHelpLabel.Left := FScoreLabel.Left;
  FHelpLabel.Top := MulDiv(30, Screen.PixelsPerInch, 96);
  FHelpLabel.Font.Name := 'Segoe UI';
  FHelpLabel.Font.Size := 9;
  FHelpLabel.Font.Color := clSilver;
  FHelpLabel.Caption :=
    'Setas/WASD: mover   Espaço/P: pausar   Enter: novo jogo   M: modo de paredes';

  FBoard := TPaintBox.Create(Self);
  FBoard.Parent := Self;
  FBoard.Align := alClient;
  FBoard.ControlStyle := FBoard.ControlStyle + [csOpaque];
  FBoard.OnPaint := BoardPaint;

  ClientWidth := BoardCols * FCellSize;
  ClientHeight := BoardRows * FCellSize + FStatusPanel.Height;

  FBuffer := TBitmap.Create;
  FBuffer.Width := BoardCols * FCellSize;
  FBuffer.Height := BoardRows * FCellSize;

  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.OnTimer := TimerTick;

  Randomize;
  FGame := TSnakeGame.Create(BoardCols, BoardRows);
  NewGame;
end;

destructor TSnakeForm.Destroy;
begin
  // O timer e' filho do form e so' seria liberado no inherited; desliga antes
  // para nao haver tick com FGame ja' liberado.
  FTimer.Enabled := False;
  FGame.Free;
  FBuffer.Free;
  inherited Destroy;
end;

procedure TSnakeForm.NewGame;
begin
  FGame.Reset;
  SyncTimer;
  UpdateStatus;
  RenderBoard;
end;

procedure TSnakeForm.StartGame;
begin
  FGame.Start;
  SyncTimer;
  UpdateStatus;
  RenderBoard;
end;

procedure TSnakeForm.SyncTimer;
begin
  FTimer.Interval := FGame.TickIntervalMs;
  FTimer.Enabled := FGame.State = gsRunning;
end;

procedure TSnakeForm.HandleDirection(ADirection: TSnakeDirection);
begin
  case FGame.State of
    gsReady:
      begin
        FGame.ChangeDirection(ADirection);
        StartGame;
      end;
    gsRunning:
      FGame.ChangeDirection(ADirection);
  end;
end;

procedure TSnakeForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_UP, Ord('W'): HandleDirection(sdUp);
    VK_DOWN, Ord('S'): HandleDirection(sdDown);
    VK_LEFT, Ord('A'): HandleDirection(sdLeft);
    VK_RIGHT, Ord('D'): HandleDirection(sdRight);
    VK_SPACE, Ord('P'):
      case FGame.State of
        gsReady: StartGame;
        gsRunning, gsPaused:
          begin
            FGame.TogglePause;
            SyncTimer;
            UpdateStatus;
            RenderBoard;
          end;
        gsGameOver, gsWon: NewGame;
      end;
    VK_RETURN:
      NewGame;
    Ord('M'):
      if FGame.State in [gsReady, gsGameOver, gsWon] then
      begin
        FGame.WrapWalls := not FGame.WrapWalls;
        UpdateStatus;
        RenderBoard;
      end;
  else
    Exit;
  end;
  Key := 0;
end;

procedure TSnakeForm.TimerTick(Sender: TObject);
begin
  case FGame.Step of
    srAte:
      FTimer.Interval := FGame.TickIntervalMs;
    srDied, srWon:
      begin
        FTimer.Enabled := False;
        if FGame.Score > FBestScore then
          FBestScore := FGame.Score;
      end;
  end;
  UpdateStatus;
  RenderBoard;
end;

procedure TSnakeForm.UpdateStatus;
const
  WallMode: array[Boolean] of string = ('paredes sólidas', 'paredes vazadas');
begin
  FScoreLabel.Caption := Format('Pontos: %d     Recorde: %d     Tamanho: %d     Modo: %s',
    [FGame.Score, FBestScore, FGame.Length, WallMode[FGame.WrapWalls]]);
end;

procedure TSnakeForm.DrawCell(X, Y: Integer; AColor: TColor; AInset: Integer);
var
  R: TRect;
begin
  R := Rect(X * FCellSize + AInset, Y * FCellSize + AInset,
    (X + 1) * FCellSize - AInset, (Y + 1) * FCellSize - AInset);
  FBuffer.Canvas.Brush.Color := AColor;
  FBuffer.Canvas.Pen.Color := AColor;
  FBuffer.Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom,
    FCellSize div 3, FCellSize div 3);
end;

procedure TSnakeForm.DrawOverlay(const ATitle, ASubtitle: string);
var
  C: TCanvas;
  W, H, Y: Integer;
begin
  C := FBuffer.Canvas;
  W := FBuffer.Width;
  H := FBuffer.Height;

  C.Brush.Style := bsClear;
  C.Font.Name := 'Segoe UI';
  C.Font.Color := ColorOverlay;
  C.Font.Style := [fsBold];
  C.Font.Size := 26;
  // Terco superior: a cobra nasce no meio do tabuleiro e ficaria coberta.
  Y := H div 3 - C.TextHeight(ATitle);
  C.TextOut((W - C.TextWidth(ATitle)) div 2, Y, ATitle);

  C.Font.Style := [];
  C.Font.Size := 11;
  Y := Y + MulDiv(52, Screen.PixelsPerInch, 96);
  C.TextOut((W - C.TextWidth(ASubtitle)) div 2, Y, ASubtitle);
  C.Brush.Style := bsSolid;
end;

procedure TSnakeForm.RenderBoard;
var
  C: TCanvas;
  X, Y, I, Inset, R: Integer;
  P: TGridPoint;
begin
  C := FBuffer.Canvas;

  for Y := 0 to BoardRows - 1 do
    for X := 0 to BoardCols - 1 do
    begin
      if (X + Y) mod 2 = 0 then
        C.Brush.Color := ColorGridA
      else
        C.Brush.Color := ColorGridB;
      C.FillRect(Rect(X * FCellSize, Y * FCellSize,
        (X + 1) * FCellSize, (Y + 1) * FCellSize));
    end;

  if not FGame.WrapWalls then
  begin
    C.Brush.Style := bsClear;
    C.Pen.Color := ColorBodyTail;
    C.Pen.Width := 2;
    C.Rectangle(1, 1, FBuffer.Width - 1, FBuffer.Height - 1);
    C.Pen.Width := 1;
    C.Brush.Style := bsSolid;
  end;

  if FGame.HasFood then
  begin
    P := FGame.Food;
    Inset := FCellSize div 6;
    C.Brush.Color := ColorFood;
    C.Pen.Color := ColorFood;
    C.Ellipse(P.X * FCellSize + Inset, P.Y * FCellSize + Inset,
      (P.X + 1) * FCellSize - Inset, (P.Y + 1) * FCellSize - Inset);
    R := FCellSize div 8;
    C.Brush.Color := ColorFoodShine;
    C.Pen.Color := ColorFoodShine;
    C.Ellipse(P.X * FCellSize + Inset + R, P.Y * FCellSize + Inset + R,
      P.X * FCellSize + Inset + 3 * R, P.Y * FCellSize + Inset + 3 * R);
  end;

  // Do rabo para a cabeca, para a cabeca ficar por cima.
  for I := FGame.Length - 1 downto 1 do
  begin
    P := FGame.Segments[I];
    if I > FGame.Length div 2 then
      DrawCell(P.X, P.Y, ColorBodyTail, 2)
    else
      DrawCell(P.X, P.Y, ColorBody, 2);
  end;
  P := FGame.Head;
  DrawCell(P.X, P.Y, ColorHead, 1);

  case FGame.State of
    gsReady:
      DrawOverlay('Pascal Snake', 'Pressione uma seta para começar');
    gsPaused:
      DrawOverlay('Pausado', 'Espaço para continuar');
    gsGameOver:
      DrawOverlay('Fim de jogo', Format('%d pontos  -  Enter para jogar de novo',
        [FGame.Score]));
    gsWon:
      DrawOverlay('Você venceu!', Format('%d pontos  -  Enter para jogar de novo',
        [FGame.Score]));
  end;

  FBoard.Invalidate;
end;

procedure TSnakeForm.BoardPaint(Sender: TObject);
begin
  FBoard.Canvas.Draw(0, 0, FBuffer);
end;

end.
