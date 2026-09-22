# Feedback for the `dual-compiler-delphi-lazarus` skill

**Audience:** the agent maintaining [`pascal-skills-faa`](https://github.com/fabianoallex/pascal-skills-faa).
**Source:** one real session in which Claude Code (Opus 5.5) built this repository from a one-line prompt, using the skill as its only dual-compiler guide. See [`README.md`](README.md) for the prompt and the result.

Every item below comes from something that actually happened in that session, and each one cites a file in this repo you can inspect. Nothing is speculative. Items are ordered by how much improvisation they forced. Where a fix is proposed, treat it as a suggestion. The skill's own rule applies: *link to real code, state trade-offs, don't invent.*

## Toolchain and verification status

| | Version | How it was verified |
|---|---|---|
| Delphi | 12 (Studio 23.0), **Community Edition** | By the user, in the IDE: game builds and runs; DUnitX 20/20 passed, 0 leaked |
| Lazarus / FPC | 4.0 / 3.2.2, Win64 | By the agent: `lazbuild -B`, FPCUnit 20/20 passed, heaptrc 0 unfreed blocks |
| OS | Windows 11, display at 125% scaling | This scaling mattered; see item 5 |

Note that the skill's "versions tested" table lists **Lazarus 2.2.6**, but this session used **Lazarus 4.0**. Everything below held on 4.0.

---

## What worked well (keep as is)

- **The *MODE DELPHI vs objfpc* section** made the choice immediate. It gives a clear default and a clear reason to deviate.
- **The *Forms* section and `references/forms-dfm-lfm.md`** decided the UI architecture (`CreateNew`, no form files). The evidence-based tone (DPI drift, `Anchors` reordering) is what makes it convincing.
- **The *"No `Sleep` and no real wall-clock in tests"* rule** directly produced a testable design: pure rules advanced by `Step`, plus an injectable `TSnakeRandom`. See `src/Snake.Game.pas`.
- **The Delphi CE warning** predicted the `msbuild` failure exactly, so no time went into workarounds.
- **`scripts/verify_test_mirrors.py`** ran with no configuration against `tests/Unit` + `tests/Unit/fpc` and reported `clean`.
- **The BOM-per-file-type convention** was precise and directly applicable.
- **Scaffold output was accepted by Delphi 12 CE unchanged.** After the user opened the group and built both projects, `git status` showed no modification to `PascalSnake.dproj`, `tests/Unit/SnakeUnitTests.dproj` or `PascalSnake.groupproj`. That's new confirmation for the `add` path and for a GUI-converted `.dproj`.

---

## Improvements, by priority

### 1. No GUI path in the scaffold (highest impact)

**What happened:** `scaffold_dual_project.py new` produces a console app only. The SKILL.md says, for GUI apps, *"follow Anatomy… and skim how pascal-amqp-faa or pascal-dfe-broker are organized."* A GUI app (VCL/LCL) is probably the most common thing someone arriving at this skill wants to build. The agent converted the generated `.dproj` by hand:
- `FrameworkType` `None` → `VCL`; `AppType` `Console` → `Application`
- appended `Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell` to `DCC_Namespace`, which the short-name `uses Forms, Controls, ...` style needs
- added `Manifest_File`, `AppDPIAwarenessMode=PerMonitorV2` and `AppEnableRuntimeThemes`
- added `<DCCReference>` entries for the units. The scaffold emits none, even for the console case.

It also rewrote the `.lpi` by hand: `LCL` in `RequiredPackages`, `Scaled`, an `XPManifest` with `DpiAware`, and `GraphicApplication`. It wrote a separate `.lpr` (see item 4).

**Evidence:** `PascalSnake.dproj`, `PascalSnakeLCL.lpi`, `PascalSnakeLCL.lpr`.

**Proposed:** add `new --gui vcl-lcl` (at least), generating a `CreateNew`-based starter form that matches the skill's own recommendation. If that's too much for now, add a **"console → VCL/LCL conversion checklist"** to `references/project-scaffolding.md` with the fields listed above.

### 2. No test-runner templates, and the best pattern isn't mentioned

**What happened:** the SKILL.md describes the mirrored DUnitX + FPCUnit pattern well but ships no files for it. The agent had to clone `pascal-redis-faa` to copy:
- the DUnitX console runner `.dpr` (`tests/Unit/SnakeUnitTests.dpr`)
- the FPCUnit `.lpr` with the GUI/console switch (`tests/Unit/fpc/SnakeUnitTestsFpc.lpr`)
- the FPCUnit `.lpi` (`FPCUnitTestRunner` + `FCL` packages, `--all --format=plain` run params)
- **`Redis.DUnitXCompat.pas`**, an adapter that exposes FPCUnit's `TAssert.AssertEquals/AssertTrue/AssertFalse` on top of DUnitX. With it, **the test bodies are byte-identical in both suites**; only the fixture declarations differ (`[Test]` vs `published`). It made mirroring trivial here (`tests/Unit/Snake.DUnitXCompat.pas`), yet **the SKILL.md never mentions it**. It also fixes a trap: DUnitX's `Assert.AreEqual(string, string)` is case-*insensitive* by default.

Also: the skill says to enable heaptrc but not *how*. In the `.lpi` that's `<Linking><Debugging><UseHeaptrc Value="True"/>` (see `tests/Unit/fpc/SnakeUnitTestsFpc.lpi`).

**Proposed:**
- Ship under `assets/`: `DUnitXCompat.pas.example`, `DUnitXRunner.dpr.example`, `FPCUnitRunner.lpr.example` and `FPCUnitRunner.lpi.example` (with heaptrc on).
- Add a paragraph to *Mirrored tests* on the compat-adapter technique (identical bodies, case-sensitivity fix) as the recommended way to keep mirrors in sync, with `verify_test_mirrors.py` as the check.
- Optional: a scaffold subcommand `tests` that generates both runners and registers them in both groups.

### 3. `add` contradicts the skill's own guidance for test projects

**What happened:** `references/project-scaffolding.md` says a test runner *"genuinely needs a separate `.lpr`… copy the pattern from `tests/Unit/` … instead of using this script."* But `add` was the only way to get a `.dproj` generated **and** registered in the `.groupproj`, so the agent used it:

```
scaffold_dual_project.py add --name SnakeUnitTests --dir tests/Unit --groupproj ... --lpg ... --inc ...
```

Side effects that had to be undone:
- it wrote a console `SnakeUnitTests.dpr` and a starter `SnakeUnitTests.Core.pas`, both discarded
- it wrote `tests/Unit/SnakeUnitTests.lpi` **and registered that one in the `.lpg`**. In the mirrored layout the FPC project is `tests/Unit/fpc/SnakeUnitTestsFpc.lpi`, so the `.lpg` pointed at the wrong project and was rewritten by hand.
- the snippets it inserted into `.groupproj`/`.lpg` had broken indentation. That's cosmetic, but it's the kind of noise the skill warns about elsewhere.

**Proposed:** one or more of the following:
- `add --delphi-only` / `add --fpc-only`
- `add --no-starter`, which skips the `.dpr` and `Core.pas`
- a `register` subcommand that only inserts an existing `.dproj`/`.lpi` into the groups
- fix the indentation of inserted blocks

### 4. `.res` collision between a `.dpr` and a `.lpr` with the same name (new gotcha)

**What happened:** following *"a `.lpr` earns its keep when the two compilers genuinely need different entry-point logic"*, the agent created `PascalSnake.dpr` and `PascalSnake.lpr` side by side. Both contain `{$R *.res}`, so **both resolve to the same `PascalSnake.res`**:
- Lazarus regenerates that `.res` on every build from the `.lpi` (manifest, plus icon/version info when set)
- Delphi writes its own version (MAINICON, version info)

Each IDE would silently overwrite the other's resource. The opcb `no-dfm` example avoids this with different names (`DelphiProject.dpr` / `LazarusProject.lpr`), but the skill never says that's the reason.

**Fix used:** rename the Lazarus side to `PascalSnakeLCL.lpr/.lpi` and keep `<Target><Filename Value="PascalSnake"/>`, so the executable is still `PascalSnake.exe`. After the Delphi build, the root holds two separate files, `PascalSnake.res` (Delphi) and `PascalSnakeLCL.res` (Lazarus).

**Proposed:** one line in *Anatomy → Project files and groups*: *"If `.dpr` and `.lpr` live in the same folder, give them different program names; `{$R *.res}` resolves to `<program>.res` on both compilers and each IDE rewrites that file. Set the Lazarus target filename to keep the same exe name."* Also worth an entry in `references/rtl-gotchas.md` (symptom → root cause → fix).

The skill recommends a single shared `.dpr` for console apps, and that case doesn't hit this because there's only one program file. The collision is specific to the *two programs, one folder* case.

### 5. Double DPI scaling with `CreateNew` forms under LCL (new gotcha)

**What happened:** following the no-form-file strategy, `TSnakeForm` calls `inherited CreateNew(AOwner)` and sizes itself in real pixels (`MulDiv(26, Screen.PixelsPerInch, 96)` per cell), because the board is drawn pixel by pixel into a `TBitmap`. On a 125% display under Lazarus (`Application.Scaled := True` in the `.lpr`), **the LCL scaled the form again**. The window came out about 25% larger than the board, leaving an empty band on the right and bottom and an oversized status panel. It compiled fine and was only caught by taking a screenshot of the running app.

**Fix used:** `Scaled := False` in the form constructor, before any sizing. Delphi (PerMonitorV2) rendered correctly with the same code. See `src/Snake.MainForm.pas`, constructor.

**Proposed:** a short note in `references/forms-dfm-lfm.md`, under the *build the UI in `.pas`* strategy. Because that file *recommends* `CreateNew`, this is a direct consequence of following its advice: *"A code-built form has no designer DPI to scale from. Either size it in 96-dpi logical units and let `Scaled` do the work, or size it in real pixels (e.g. for custom drawing) and set `Scaled := False`. Mixing the two scales twice on the LCL."* Also suggest checking forms at a non-100% display scale.

### 6. Encoding: add a confirmed data point for GUI apps

**What happened:** the skill correctly says *decide and document*, but its evidence is all console (cp850 mojibake in `pascal-redis-faa`). For a GUI app with Portuguese UI strings the agent couldn't tell in advance whether accented literals in a UTF-8-with-BOM `.pas` under `{$MODE DELPHI}` would render correctly under the LCL.

**Confirmed:** they do, on both sides. Delphi reads the BOM file as UTF-8 into `UnicodeString`, and FPC/LCL shows `começar`, `Espaço`, `sólidas` and `Você` correctly (`images/game-start.png`, `images/game-over.png`). The project keeps accents **only** in UI strings (`src/Snake.MainForm.pas`); code, comments and tests are ASCII. See `CLAUDE.md`.

**Proposed:** add this as a data point in the *Encoding* section: *"GUI (VCL/LCL): UTF-8 with BOM + accented literals renders correctly on both, confirmed with Delphi 12 / Lazarus 4.0; the console cp850 problem does not apply."*

### 7. Cloning the opcb reference repo fails on Windows

**What happened:** the skill says *"prefer opening the real file in one of these repos."* `git clone https://github.com/fabianoallex/opcb-object-pascal-component-builder` on Windows failed with `Filename too long` (e.g. `examples/Builders/VCL/exemplo-classes-personalizadas/OPCB.Vcl.ExemploClassesPersonalizadas.dproj`), leaving a partial checkout. The agent got lucky: the `no-dfm` files it needed were checked out before the failure.

**Proposed:** in the reference-projects table or `forms-dfm-lfm.md`, suggest `git clone -c core.longpaths=true …`, or link directly to the specific files (`examples/Builders/VCL-Lazarus/no-dfm/UMainForm.pas`, `LazarusProject.lpr`, `LazarusProject.lpi`).

---

## Minor

- **Throwaway starter files.** `new` generates `src/<Name>.Core.pas` (a `Greeting` class) and a console `.dpr`. For any GUI project both get deleted. That's harmless, but with item 1 in place the starter could be a `CreateNew` form instead.
- **Mixed confidence signals.** The script prints *"Generated files are unverified against a real IDE"*, while `project-scaffolding.md` says *"Confirmed end-to-end."* Both are true in their own scope, but on a first read they look contradictory. Consider *"Verified for the plain console template; re-verify after changing templates or project type."*
- **`{$R *.res}` inside a `{ }` comment ends the comment early.** This is general Pascal, not dual-compiler. The agent hit it while documenting item 4 in a header comment (`PascalSnakeLCL.lpr`). If the skill's templates ever explain `{$R}` in a brace comment, use `//` or `(* *)`.

## Suggested acceptance check for the skill changes

Re-run the same prompt against the updated skill (*"create a Delphi/Lazarus project implementing a snake game, using this skill"*) and confirm that:

1. the agent doesn't need to clone any reference repo to get GUI project files or test runners (items 1 and 2)
2. no generated file is deleted or rewritten by hand after `add` (item 3)
3. the `.dpr` and `.lpr` don't share a `.res` (item 4)
4. the window fits the board at 125% scaling on both compilers (item 5)
