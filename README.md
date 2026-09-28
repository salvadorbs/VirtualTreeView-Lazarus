# VirtualTreeView-Lazarus

Lazarus / Free Pascal port of the [Virtual Treeview](https://github.com/JAM-Software/Virtual-TreeView) control.

Virtual Treeview is an advanced, highly customizable tree view control written in Object Pascal: a huge number of nodes, multi-column layout, themes, drag & drop, in-place editing, clipboard, export and more, with full control over painting and data storage.

This is the Lazarus port. Please note that this is an experimental fork of VTV for Lazarus and is not yet ready for production use.

This port is based on work done by Luiz Américo Pereira Câmara (https://github.com/blikblum/VirtualTreeView-Lazarus). It is an attempt to try to keep this port aligned with the official repo. If you need something stable, keep using the https://github.com/blikblum/VirtualTreeView-Lazarus version.

## Authors

- Mike Lischke — author of the original Virtual Treeview control.
- Luiz Américo Pereira Câmara — author of the original Lazarus port.
- Matteo Salvi (aka "El Salvador", https://github.com/salvadorbs) — author of this port.

## Features

- Unlimited number of nodes, in flat or hierarchical form.
- Multi-column trees with headers, sorting and header popup menus.
- Highly customizable nodes: images, checkboxes, radio buttons, buttons and expanders, with per-node and per-column data.
- Full owner-draw control (`OnPaint`, `OnBeforePaint`, `OnAfterPaint`, colors, fonts, hints and line styles).
- In-place cell editing and custom editors.
- Drag & drop, including OLE drag & drop on Windows.
- Clipboard copy/paste, incremental search and keyboard navigation.
- Export (text, HTML, RTF, CSV) and printing.
- Accessibility support.
- `TVirtualDrawTree` for fully custom-drawn trees and `TVirtualStringTree` for string-based data.

## Requirements

- Lazarus 3.0 or newer
- FPC 3.2.2 or newer
- [LCL Extensions](https://github.com/blikblum/luipack) 0.6 or newer (`lclextensions_package`)

## Installation

1. Make sure `lclextensions_package` (LCL Extensions) is installed in the IDE.
2. Open `Packages/Lazarus/virtualtreeview_package.lpk`.
3. Click **Use → Install** and let the IDE rebuild itself.

The same can be done from the command line:

```bash
# Point the IDE to LCL Extensions first, if it is not installed yet
lazbuild --add-package-link /path/to/luipack/lclextensions/lclextensions_package.lpk

# Add and build the VirtualTreeView package, then rebuild the IDE
lazbuild --add-package Packages/Lazarus/virtualtreeview_package.lpk
lazbuild --build-ide=
```

After installation the components appear on the **Virtual Controls** palette page:

| Component | Unit |
|---|---|
| `TVirtualStringTree` | `VirtualTrees.pas` |
| `TVirtualDrawTree` | `VirtualTrees.pas` |
| `TVTHeaderPopupMenu` | `VirtualTrees.HeaderPopup.pas` |

## Package layout

The main visual package is `Packages/Lazarus/virtualtreeview_package.lpk`. Its core units live in `Source/`:

| Unit | Description |
|---|---|
| `VirtualTrees.pas` | Main units: `TBaseVirtualTree`, `TVirtualStringTree`, `TVirtualDrawTree` |
| `VirtualTrees.BaseTree.pas` | Abstract tree implementation (node management, painting loop) |
| `VirtualTrees.AncestorLcl.pas` / `VirtualTrees.BaseAncestorLcl.pas` | LCL integration of the base tree |
| `VirtualTrees.Types.pas` | Public types, enums, records and options |
| `VirtualTrees.Classes.pas` | Helper classes |
| `VirtualTrees.Utils.pas` | Internal utilities |
| `VirtualTrees.Colors.pas` | Color helpers |
| `VirtualTrees.Header.pas` / `VirtualTrees.HeaderPopup.pas` | Header and header popup menu |
| `VirtualTrees.DrawTree.pas` | Fully owner-drawn tree |
| `VirtualTrees.EditLink.pas` | In-place editing support |
| `VirtualTrees.ClipBoard.pas` | Clipboard handling |
| `VirtualTrees.Export.pas` | Export to text/HTML/RTF/CSV |
| `VirtualTrees.DragnDrop.pas` / `VirtualTrees.DragImage.pas` / `VirtualTrees.DataObject.pas` | Drag & drop support |
| `VirtualTrees.WorkerThread.pas` | Background worker thread used for incremental work |
| `VirtualTrees.Accessibility.pas` / `VirtualTrees.AccessibilityFactory.pas` | Accessibility support |
| `VirtualTrees.IDEEditors.pas` / `registervirtualtreeview.pas` | IDE editors and component registration |

Widgetset-specific helpers are kept under `Source/units/<widgetset>/` and `Source/include/intf/` (Win32, GTK2, GTK3, Qt/Qt5/Qt6, Cocoa, Carbon). `Contributions/GenericWrapper/` contains an optional generic wrapper (`VirtualTreeWrapper.pas`) for non-VCL-friendly integration scenarios.

## Demos

Runnable examples are in `Demos/`:

- `Minimal/` — smallest possible tree (`minimal_lcl.lpi`)
- `Advanced/` — large feature tour
- `vtbasic/` — basic tree operations
- `dataarray/` — virtual data stored in arrays
- `images/` — image lists and per-node images
- `Multiselect/` — multi-selection and cell selection
- `Objects/` — MVC-style usage
- `Interfaces/` — custom interfaces in nodes
- `dragdrop/` — drag & drop
- `unicode/` — Unicode captions
- `OLE/` — OLE drag & drop (Windows only)

## Tests

`Tests/` holds an FPCUnit suite covering the core tree behavior, mouse utilities, cell selection, `OnDrawText`, `OnEditCancelled` and a worker-thread regression test. Build and run it from the command line:

```bash
lazbuild Tests/Tests.lpi
Tests/Tests --all --progress --format=plain
```

## Contributing

Issues and pull requests are welcome. When reporting a bug, please attach a minimal example (or a modified demo) that reproduces it, and state the widgetset and the versions of Lazarus/FPC you are using.

## License

Virtual Treeview is published under a double license: **MPL 1.1** and **LGPL 2.1** with static linking exception, as described here: http://wiki.freepascal.org/modified_LGPL
