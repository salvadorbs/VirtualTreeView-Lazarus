# AI Coding Assistant Guide for VirtualTreeView-Lazarus

This document provides essential information for AI coding assistants working with the
Virtual TreeView codebase of this repository. It follows the upstream `Agents.md` and
replaces only the parts that are Delphi/RAD Studio specific with their Free Pascal /
Lazarus equivalent.

## Quick Reference

- **Project Type**: Open source Lazarus component library, LCL port of Virtual TreeView
- **Primary Language**: Object Pascal (Free Pascal in `{$mode delphi}`)
- **Main Documentation**: See [`README.md`](README.md) for the package layout, supported
  widgetsets and project overview

## Language

Everything you write to this repository or its GitHub project must be in English: code,
identifiers, comments, commit messages, pull requests, issue comments and documentation.
This also applies when you talk to the user in another language.

Important Directories

### Source Code

- [`Source/`](Source/) - **ALL runtime LCL source code** (.pas files)
  - Pure runtime code only - no designtime dependencies
  - Compiled units (.ppu, .o) are generated in the project output directories
  - Widgetset-specific helpers live in [`Source/units/<widgetset>/`](Source/units/)
    (`win32`, `gtk2`, `gtk3`, `qt`, `qt5`, `qt6`, `cocoa`, `carbon`) and in
    [`Source/include/intf/`](Source/include/intf/)
- [`Packages/`](Packages/) - **Lazarus packages**
  - [`Packages/Lazarus/virtualtreeview_package.lpk`](Packages/Lazarus/virtualtreeview_package.lpk) -
    the visual package, including component registration and the IDE property editors
  - There is no `Design/` directory in this fork: design-time units
    (`registervirtualtreeview.pas`, `VirtualTrees.IDEEditors.pas`) live in
    `Packages/Lazarus` and must not be used from runtime units

### Testing

- [`Tests/`](Tests/) - **Unit-test code** for the FPCUnit framework, built with the LCL
  console test runner (`consoletestrunner`)
  - Do not add code to the production code under [`Source/`](Source/) only to make it
    testable (e.g. test hooks, extra public or protected members, visibility changes)
    without asking the user first. Write tests against the existing public interface or
    use helper classes in the test project
  - Windows-only behaviour (OLE clipboard, real window handles) cannot be tested on
    Linux: skip it with a `NOTE:` and document why instead of faking the platform

### Sample Projects

- [`Demos/`](Demos/) - **sample projects** showing how to use the components
  - Compiled binaries and other build output are not tracked. Do not commit them and do
    not delete untracked demo artifacts that are already present

## How to build

### Unit Tests

See [`README.md#tests`](README.md#tests).

Use the console build of the tests (`Tests/lib/$(TargetCPU)-$(TargetOS)/Tests`). Build it
with `lazbuild`; no Delphi toolchain or `MsBuild` is involved:

```bash
lazbuild Tests/Tests.lpi
```

The LCL runner has no `--exitbehavior` option and does not wait for Enter. It also has no
`--run:` option (that is DUnitX): select a suite with `--suite=`, list the tests with
`--list` and filter the output with `--sparse`. Run everything with:

```bash
Tests/lib/x86_64-linux/Tests --all --format=plain
```

Tests create real forms, so on Unix they need an X display:

```bash
DISPLAY=:0 Tests/lib/x86_64-linux/Tests --all --format=plain
```

To add a test unit, register it in all three places - a missing entry makes the test
disappear silently:

1. `RegisterTest(TMyTests)` in the `initialization` section of the new unit.
2. The unit in the `uses ... in '...pas'` list of `Tests/Tests.lpr`.
3. A `<Unit>` entry in `Tests/Tests.lpi`.

### All relevant code

Always build all relevant code after making changes to see if everything compiles:

```bash
lazbuild Packages/Lazarus/virtualtreeview_package.lpk
lazbuild Tests/Tests.lpi
lazbuild Demos/Minimal/minimal_lcl.lpi
```

Pass `--ws=<widgetset>` (for example `--ws=qt5`) to build against another backend. At
least the Linux GTK2 build must compile and pass the tests.

The compiler sometimes reports `Fatal: Internal error 200611031` after switching
defines, widgetsets or FPC versions. That is a stale-unit problem, not a source problem:

```bash
rm -rf Source/lib Tests/lib
lazbuild Tests/Tests.lpi
```

## Cross-platform notes

The same source must compile and behave correctly on every supported widgetset. Assume
nothing about the platform unless it is guarded.

- Use `LCLIntf`, `LCLType` and `LMessages`; do not call Win32 units (`Windows`,
  `Messages`) from shared units
- LCL message handling uses `TLMessage` / `LM_*`, not `TMessage` / `WM_*`
- Never narrow a handle, atom or clipboard format id to `Word`/`Integer`; use `PtrInt`,
  `THandle`, `TClipboardFormat` and friends (see issue #42713)
- Resource ownership differs: `SetWindowRgn`, for example, takes ownership of the region
  only on Windows and it must be freed explicitly elsewhere
- Guard newer LCL APIs with `{$IF LCL_FullVersion >= x}` and keep an `{$ELSE}` fallback
  (for example `ThemeServices.DrawElementForPPI`, available from LCL 5.99 only)
- LCL scales forms, fonts and controls automatically; the tree must follow without double
  scaling. Convert 96 DPI values with `Scale96ToFont`, `ScaleX`/`ScaleY` or `MulDiv`.
  `Scale96ToFont` exists from LCL 1.8, hence the `{$IF LCL_FullVersion >= 1080000}`
  guards
- When assigning a `TFont` to a canvas with a different `PixelsPerInch` (offscreen
  bitmaps, buffer canvases), set `PixelsPerInch` explicitly after `Assign`:
  `TFont.Assign` converts to the canvas resolution otherwise
- Per-monitor DPI changes reach forms through `LM_DPI_CHANGED`; controls follow through
  the protected `DoAutoAdjustLayout` override. Scale header metrics, column widths and
  node heights together, and wrap bulk column changes in `Columns.BeginUpdate` /
  `EndUpdate`
- DPI regression tests run with the default 96 DPI screen: assert what the code computes,
  do not depend on the physical monitor

## Bug fixing

When fixing an issue from the issue tracker, always add a comment that explains the change
and include the issue number in the comment.

This fork also tracks upstream JAM Software fixes and the Lazarus issue tracker. Upstream
commits are ported, not merged wholesale: Delphi/FMX sources, RAD Studio packages and
DUnitX tests do not apply to this port. Port the behaviour, adapt the regression test to
FPCUnit/LCL, and keep the upstream attribution in the commit body ("Ported from Lazarus
<hash> ..." or the upstream issue number).

Keep one logical change per commit, keep documentation and test updates with the code they
describe, and do not push unless the user asks.
