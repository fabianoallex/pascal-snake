# pascal-snake

Snake game in Object Pascal, **dual-compiler**: the same code compiles with Delphi (VCL) and Lazarus/FPC (LCL).
The structure follows the [`dual-compiler-delphi-lazarus`](https://github.com/fabianoallex/pascal-skills-faa) skill.
See `README.md` for the layout and `SKILL_FEEDBACK.md` for what this project taught about the skill.

## Project rules

- **One `src/` tree.** Compiler differences go in `{$IFDEF FPC}` inside the unit itself.
  Every new unit in `src/` includes `{$I pascalsnake.inc}` right after `unit ...;`.
- **`{$MODE DELPHI}`**: no generics, no anonymous methods, no inline `var`, and `uses` without namespaces
  (`SysUtils`, not `System.SysUtils`; the `.dproj` resolves them through `DCC_Namespace`).
- **No `.dfm`/`.lfm`.** Forms call `inherited CreateNew(AOwner)` and build their controls in code.
  Both IDEs rewrite form files on their own (DPI, `Anchors` order, encoding), so don't add form files back
  without a real need.
- **DPI:** the board is drawn pixel by pixel into a `TBitmap`, so the form sets `Scaled := False` and converts
  sizes with `MulDiv(x, Screen.PixelsPerInch, 96)`. Without it the LCL scales the form twice.
- **Logic stays out of the UI.** Every rule goes in `Snake.Game` and gets a test. The form only reads state,
  handles the keyboard, drives the `TTimer` and draws.
- **Encoding:** UTF-8 **with BOM** for `.pas`/`.dpr`/`.lpr`/`.dproj`/`.groupproj`, no BOM for `.inc`/`.lpi`/`.lpg`.
  Code, comments and tests are **plain ASCII**. Accents are allowed only in user-visible UI strings
  (`Snake.MainForm.pas`); they render correctly on VCL (UnicodeString) and LCL (UTF-8).
- **Line endings:** LF (see `.gitattributes`).
- **Program names:** `PascalSnake.dpr` and `PascalSnakeLCL.lpr` have different names on purpose, because `{$R *.res}`
  would otherwise point both IDEs at the same `.res`. The Lazarus target filename keeps the exe named `PascalSnake`.
- **New projects:** every `.dproj` goes into `PascalSnake.groupproj`; every `.lpi` goes into `PascalSnake.lpg`.

## Tests (mirrored)

Each test exists in both suites with the **same name and the same body**
(`TAssert.AssertEquals/AssertTrue/AssertFalse`; on the DUnitX side that's the `Snake.DUnitXCompat` adapter).
When you change one side, change the other in the same session.
Acceptance means it **builds and passes on both compilers with 0 leaks** (heaptrc on FPC,
`ReportMemoryLeaksOnShutdown` on Delphi). No `Sleep` or real clock in tests: the game advances through `Step`.

```
# FPC (command line)
lazbuild -B tests/Unit/fpc/SnakeUnitTestsFpc.lpi
tests/Unit/fpc/SnakeUnitTestsFpc.exe --all --format=plain     # run it without arguments for the GUI runner

# Delphi: open PascalSnake.groupproj in the IDE and run SnakeUnitTests
# (Delphi Community Edition can't build from the command line)

# Structural parity of the two suites (script shipped with the skill)
python <pascal-skills-faa>/dual-compiler-delphi-lazarus/scripts/verify_test_mirrors.py --root . --ignore-glob /lib/,/backup/,__recovery
```

## Building the game

- Lazarus: `lazbuild -B PascalSnakeLCL.lpi` (writes `PascalSnake.exe` in the root).
- Delphi: open `PascalSnake.dproj` (or the group) and build (output in `Win32\Debug\`).
