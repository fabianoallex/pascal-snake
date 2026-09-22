# Pascal Snake

Jogo da cobrinha em Object Pascal que compila, a partir do mesmo código, em **Delphi (VCL)** e **Lazarus/FPC (LCL)**.

## Como jogar

| Tecla | Ação |
|---|---|
| Setas / WASD | mover (a primeira seta inicia o jogo) |
| Espaço / P | pausar / continuar |
| Enter | novo jogo |
| M | alternar paredes sólidas / vazadas (antes de começar ou após o fim) |

A cobra acelera a cada comida (150 ms → mínimo 60 ms por passo). Cada comida vale 10 pontos; preencher o tabuleiro inteiro vence o jogo.

## Compilar

- **Lazarus**: abra `PascalSnakeLCL.lpi` (ou `PascalSnake.lpg`) e compile, ou `lazbuild -B PascalSnakeLCL.lpi`.
- **Delphi**: abra `PascalSnake.dproj` (ou `PascalSnake.groupproj`) e compile.

## Testes

Testes da lógica do jogo em duas suítes espelhadas: DUnitX (`tests/Unit/SnakeUnitTests.dproj`) e FPCUnit (`tests/Unit/fpc/SnakeUnitTestsFpc.lpi`). Veja `CLAUDE.md` para as convenções do projeto.
