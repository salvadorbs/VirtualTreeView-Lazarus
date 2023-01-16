// Configuration file for VirtualTrees.pas (see www.soft-gems.net).
//
// The content of this file is public domain. You may do with it whatever you like, provided the header stays fully intact
// in all version and derivative work.
//
// The original code is VTConfig.inc, released October 5, 2004.
//
// The initial developer of the original code is Mike Lischke (public@soft-gems.net, www.soft-gems.net).
//----------------------------------------------------------------------------------------------------------------------

{.$define UseFlatScrollbars}
{.$define ReverseFullExpandHotKey} // Used to define Ctrl+'+' instead of Ctrl+Shift+'+' for full expand (and similar for collapsing).

// Enable this switch for Windows XP theme support. If you compile with Delphi 6 or lower you must download and install
// the Soft Gems Theme Manager package.
{$define ThemeSupport}

// Virtual Treeview can use a tiny but very effective local memory manager for node allocation.
// The local memory manager was implemented by David Clark from Caelo Software Inc.
// See below for more info about it.
{.$define UseLocalMemoryManager}


//Lazarus port options
{$define EnableOLE}

{.$define EnableNativeTVM}

{.$define EnablePrint}

{.$define EnableNCFunctions}

{$define EnableAdvancedGraphics}

{$define EnableAlphaBlend}

{$ifdef Windows}
  {$define EnableWinDataObject}
{$endif}

//Don't enable this because oleacc is not available for FreePascal
{.$define EnableAccessible}

{.$define DelphiStyleServices}

{$if defined(LCLWin32) or defined(LCLWinCE)}
  {$define LCLWin}
{$endif}

//Logging on console
{.$define DEBUG_VTV}

{$define USE_DELPHICOMPAT}

//since
{$if not defined(USE_DELPHICOMPAT) and not defined(LCLWin)}
  {$define INCOMPLETE_WINAPI}
{$endif}

//under linux the performance is poor with threading enabled
{$ifdef Windows}
  {$define EnableThreadSupport}
{$endif}
{$if defined(CPU64) or defined(LCLCarbon)}
  {$define PACKARRAYPASCAL}
{$endif}

{$define CompilerVersion := 19}  

{$if defined(LCLQt) or defined(LCLQt5) or defined(LCLQt6)}
     {$undef windows}
{$endif}                

{$if defined(LCLGtk) or defined(LCLGtk2) or defined(LCLGtk3)}
     {$undef windows}
{$endif}

{$if defined(LCLGtk) or defined(LCLGtk2)}
	{$define Gtk}
{$endif}

{$if defined(Gtk) or defined(LCLCocoa)}
	{$define ManualClipNeeded}
{$endif}

{$if defined(LCLGtk2) or defined(LCLCarbon) or defined(LCLQt)}
	{$define ContextMenuBeforeMouseUp}
{$endif}

{$define AtomicIncrement:=interlockedIncrement}
{$define AtomicDecrement:=interlockedDecrement}
{$define AtomicExchange:=interlockedExchange}
{$define AtomicCompareExchange:=InterlockedCompareExchange}

