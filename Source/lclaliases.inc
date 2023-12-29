
  TMessage = TLMessage;
  TCMMouseWheel = TLMMouseEvent;
  
  TWMContextMenu = TLMContextMenu;
  TWMEnable = TLMNoParams;
  TWMSize = TLMSize;
  TWMTimer = TLMTimer;

  WM_CONTEXTMENU = LM_CONTEXTMENU;
  WM_ENABLE = LM_ENABLE;
  WM_SIZE = LM_SIZE;
  WM_TIMER = LM_TIMER;
  CM_MOUSEWHEEL = LM_MOUSEWHEEL;

  {$if defined(LCLCarbon) or defined(LCLCocoa)}
    ssCtrl = ssMeta;     // Mac OS X fix
  {$else}
    ssCtrl = ssCtrl;
  {$endif}