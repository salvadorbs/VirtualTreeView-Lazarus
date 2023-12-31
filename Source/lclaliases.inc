
  TMessage = TLMessage;

  TWMEraseBkgnd       = TLMEraseBkgnd;
  TWMKillFocus        = TLMKillFocus;
  TWMMouse            = TLMMouse;
  TWMNCHITTEST        = TLMNCHITTEST;
  TWMSCROLL           = TLMSCROLL;
  TWMSetFocus         = TLMSetFocus;
  TWMSIZE             = TLMSIZE;
  TWMHScroll          = TLMHScroll;
  TWMVScroll          = TLMVScroll;
  TWMKeyDown          = TLMKeyDown;
  TWMKeyUp            = TLMKeyUp;
  TWMWindowPosChanged = TLMWindowPosChanged;
  TWMPaint            = TLMPaint;
  TWMLButtonDown      = TLMLButtonDown;
  TWMLButtonUp        = TLMLButtonUp;
  TWMLButtonDblClk    = TLMLButtonDblClk;
  TWMMButtonUp        = TLMMButtonUp;
  TWMMButtonDown      = TLMMButtonDown;
  TWMMButtonDblClk    = TLMMButtonDblClk;
  TWMRButtonUp        = TLMRButtonUp;
  TWMRButtonDown      = TLMRButtonDown;
  TWMRButtonDblClk    = TLMRButtonDblClk;
  TWMKey              = TLMKey;
  TWMCommand          = TLMCommand;
  TWMChar             = TLMChar;
  TWMNotify           = TLMNotify;
  TWMCut              = TLMCut;
  TWMCopy             = TLMCopy;
  TWMPaste            = TLMPaste;
  TWMSetCursor        = TLMSetCursor;
  TWMNoParams         = TLMNoParams;
  TWMGetDlgCode       = TLMNoParams;
  TWMMouseMove        = TLMMouseMove;
  TWMActivate         = TLMActivate;
  TWMNCMButtonUp      = TLMMButtonUp;
  TWMNCMButtonDown    = TLMMButtonDown;
  TWMNCRButtonDown    = TLMRButtonDown;
  TWMNCRButtonUp      = TLMRButtonUp;
  TWMNCMouseMove      = TLMMouseMove;

  TCMMouseWheel = TLMMouseEvent;
  
  TWMContextMenu = TLMContextMenu;
  TWMEnable = TLMNoParams;
  TWMTimer = TLMTimer;
  TWMDestroy = TLMDestroy;
  TWMMeasureItem = TLMMeasureItem;
  TWMDrawItem = TLMDrawItems;

const
  WM_DROPFILES        = LM_DROPFILES;
  WM_ERASEBKGND       = LM_ERASEBKGND;
  WM_GETDLGCODE       = LM_GETDLGCODE;
  WM_HSCROLL          = LM_HSCROLL;
  WM_KILLFOCUS        = LM_KILLFOCUS;
  WM_LBUTTONUP        = LM_LBUTTONUP;
  WM_LBUTTONDOWN      = LM_LBUTTONDOWN;
  WM_LBUTTONDBLCLK    = LM_LBUTTONDBLCLK;
  WM_MBUTTONUP        = LM_MBUTTONUP;
  WM_MBUTTONDOWN      = LM_MBUTTONDOWN;
  WM_MBUTTONDBLCLK    = LM_MBUTTONDBLCLK;
  WM_RBUTTONUP        = LM_RBUTTONUP;
  WM_RBUTTONDOWN      = LM_RBUTTONDOWN;
  WM_RBUTTONDBLCLK    = LM_RBUTTONDBLCLK;
  WM_MOUSEMOVE        = LM_MOUSEMOVE;
  WM_MOUSEENTER       = LM_MOUSEENTER;
  WM_MOUSELEAVE       = LM_MOUSELEAVE;
  WM_NCHITTEST        = LM_NCHITTEST;
  WM_QUIT             = LM_QUIT;
  WM_SETFOCUS         = LM_SETFOCUS;
  WM_SIZE             = LM_SIZE;
  WM_SYSCHAR          = LM_SYSCHAR;
  WM_SYSKEYDOWN       = LM_SYSKEYDOWN;
  WM_SYSKEYUP         = LM_SYSKEYUP;
  WM_VSCROLL          = LM_VSCROLL;
  WM_NCPAINT          = LM_NCPAINT;
  WM_CAPTURECHANGED   = LM_CAPTURECHANGED;
  WM_KEYDOWN          = LM_KEYDOWN;
  WM_KEYUP            = LM_KEYUP;
  WM_WINDOWPOSCHANGED = LM_WINDOWPOSCHANGED;
  WM_CUT              = LM_CUT;
  WM_COPY             = LM_COPY;
  WM_PASTE            = LM_PASTE;
  WM_SETCURSOR        = LM_SETCURSOR;
  WM_PAINT            = LM_PAINT;
  WM_CHAR             = LM_CHAR;
  WM_COMMAND          = LM_COMMAND;
  WM_CANCELMODE       = LM_CANCELMODE;
  WM_NOTIFY           = LM_NOTIFY;
  WM_CREATE           = LM_CREATE;
  WM_ACTIVATE         = LM_ACTIVATE;
  WM_NCMBUTTONUP      = LM_MBUTTONUP;
  WM_NCMBUTTONDOWN    = LM_MBUTTONDOWN;
  WM_NCLBUTTONDBLCLK  = LM_LBUTTONDBLCLK;
  WM_NCMBUTTONDBLCLK  = LM_MBUTTONDBLCLK;
  WM_NCRBUTTONDBLCLK  = LM_RBUTTONDBLCLK;
  WM_NCLBUTTONDOWN    = LM_LBUTTONDOWN;
  WM_NCRBUTTONDOWN    = LM_RBUTTONDOWN;
  WM_NCRBUTTONUP      = LM_RBUTTONUP;
  WM_NCLBUTTONUP      = LM_LBUTTONUP;
  WM_NCMOUSEMOVE      = LM_MOUSEMOVE;

  WM_CONTEXTMENU = LM_CONTEXTMENU;
  WM_ENABLE = LM_ENABLE;
  WM_TIMER = LM_TIMER;
  CM_MOUSEWHEEL = LM_MOUSEWHEEL;
  WM_DESTROY = LM_DESTROY;

  {$if defined(LCLCarbon) or defined(LCLCocoa)}
    ssCtrl = ssMeta;     // Mac OS X fix
  {$endif}

type

