# pascal-snake

Jogo Snake em Object Pascal, **dual-compiler**: o mesmo código compila em Delphi (VCL) e Lazarus/FPC (LCL).
Estrutura baseada na skill [`dual-compiler-delphi-lazarus`](https://github.com/fabianoallex/pascal-skills-faa).

## Layout

```
src/pascalsnake.inc          diretivas compartilhadas ({$MODE DELPHI}{$H+} no FPC, PASCALSNAKE_WINDOWS)
src/Snake.Game.pas           regras do jogo: pura, sem UI, sem relógio, aleatoriedade injetável
src/Snake.MainForm.pas       janela (VCL/LCL) construída em código, sem .dfm/.lfm
PascalSnake.dpr / .dproj     entrada Delphi
PascalSnakeLCL.lpr / .lpi    entrada Lazarus (Interfaces + Application.Scaled); nome diferente
                             do .dpr para nao disputar o mesmo PascalSnake.res; exe = PascalSnake.exe
PascalSnake.groupproj        grupo Delphi  (app + testes DUnitX)
PascalSnake.lpg              grupo Lazarus (app + testes FPCUnit)
tests/Unit/                  DUnitX: SnakeUnitTests.dpr, Snake.GameTests.pas, Snake.DUnitXCompat.pas
tests/Unit/Snake.TestDoubles.pas   dublês compartilhados pelas duas suítes (sem espelho)
tests/Unit/fpc/              FPCUnit: SnakeUnitTestsFpc.lpr, Snake.GameTests.pas (espelho)
```

## Regras do projeto

- **Uma árvore `src/` só.** Diferenças de compilador ficam em `{$IFDEF FPC}` dentro da própria unit.
  Toda unit nova em `src/` inclui `{$I pascalsnake.inc}` logo após `unit ...;`.
- **`{$MODE DELPHI}`, sem generics, sem métodos anônimos, sem inline var, `uses` sem namespace**
  (`SysUtils`, não `System.SysUtils` — o `.dproj` resolve via `DCC_Namespace`).
- **Sem `.dfm`/`.lfm`.** Formulários chamam `inherited CreateNew(AOwner)` e montam os controles em código.
  Os dois IDEs reescrevem arquivos de formulário por conta própria (DPI, ordem de `Anchors`, encoding);
  não reintroduzir sem necessidade real.
- **DPI:** o tabuleiro é desenhado pixel a pixel num `TBitmap`, então o form usa `Scaled := False` e
  converte os tamanhos com `MulDiv(x, Screen.PixelsPerInch, 96)`. Sem isso a LCL escala duas vezes.
- **Lógica fora da UI.** Tudo que é regra vai para `Snake.Game` e ganha teste; o form só lê estado,
  trata teclado, controla o `TTimer` e desenha.
- **Encoding:** UTF-8 **com BOM** em `.pas`/`.dpr`/`.lpr`/`.dproj`/`.groupproj`; sem BOM em `.inc`/`.lpi`/`.lpg`.
  Código, comentários e testes em **ASCII puro**; acentos só em textos visíveis da UI (`Snake.MainForm.pas`),
  que funcionam em VCL (UnicodeString) e LCL (UTF-8).
- **Fim de linha:** LF (ver `.gitattributes`).
- **Projeto novo:** todo `.dproj` entra no `.groupproj`; todo `.lpi` entra no `.lpg`.

## Testes (espelhados)

Cada teste existe nas duas suítes com o **mesmo nome e o mesmo corpo** (`TAssert.AssertEquals/AssertTrue/AssertFalse`;
do lado DUnitX isso é o adaptador `Snake.DUnitXCompat`). Mudou um lado, muda o outro na mesma sessão.
Critério de aceite: **compila e passa nos dois compiladores, com 0 vazamentos** (heaptrc no FPC,
`ReportMemoryLeaksOnShutdown` no Delphi). Nada de `Sleep`/relógio real em teste — o jogo avança por `Step`.

```
# FPC (linha de comando)
lazbuild -B tests/Unit/fpc/SnakeUnitTestsFpc.lpi
tests/Unit/fpc/SnakeUnitTestsFpc.exe --all --format=plain     # sem parâmetros abre o runner GUI

# Delphi: abrir PascalSnake.groupproj na IDE e rodar SnakeUnitTests
# (Delphi Community Edition não compila por linha de comando)

# Paridade estrutural das suítes (script da skill)
python <pascal-skills-faa>/dual-compiler-delphi-lazarus/scripts/verify_test_mirrors.py --root . --ignore-glob /lib/,/backup/,__recovery
```

## Build do jogo

- Lazarus: `lazbuild -B PascalSnakeLCL.lpi` (gera `PascalSnake.exe` na raiz).
- Delphi: abrir `PascalSnake.dproj` (ou o grupo) e compilar (saída em `Win32\Debug\`).
