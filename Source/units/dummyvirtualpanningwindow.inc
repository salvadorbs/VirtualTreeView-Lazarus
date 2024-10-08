{$warnings off}
{$hints off}

{$mode objfpc}{$H+}

interface

{$I VTConfig.inc}

uses
  LCLType, Graphics, Classes, SysUtils, WSReferences;
  
type

  { TVirtualPanningWindow }

  TVirtualPanningWindow = class
  private
    FHandle: TLCLHandle;
    FOwnerHandle: TLCLHandle;
    FImage: TBitmap;
    procedure HandlePaintMessage;
  public
    procedure Start(OwnerHandle: TLCLHandle; const Position: TPoint);
    procedure Stop;
    procedure Show(ClipRegion: HRGN);
    property Image: TBitmap read FImage;
    property Handle: TLCLHandle read FHandle;
  end;

implementation

{$ifdef DEBUG_VTV}
uses
  VirtualTrees.Logger;
{$endif}

{ TVirtualPanningWindow }

procedure TVirtualPanningWindow.HandlePaintMessage;
begin
end;

procedure TVirtualPanningWindow.Start(OwnerHandle: TLCLHandle; const Position: TPoint);
begin  
  FImage := TBitmap.Create;
end;

procedure TVirtualPanningWindow.Stop;
begin
  FImage.Free;
  FImage := nil;
end;

procedure TVirtualPanningWindow.Show(ClipRegion: HRGN);
begin
  {$ifdef DEBUG_VTV}Logger.SendBitmap([lcPanning],'Panning Image',FImage);{$endif}
end;

end.

