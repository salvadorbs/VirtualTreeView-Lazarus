unit VirtualTrees.Utils;

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  Classes, Controls, Graphics,
  {$ifdef Windows}
  Windows,
  ActiveX,
  CommCtrl,
  UxTheme,
  {$else}
  FakeActiveX,
  {$endif}
  DelphiCompat;

type

implementation

uses
  VirtualTrees;

end.
