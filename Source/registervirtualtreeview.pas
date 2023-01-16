unit registervirtualtreeview; 

{$Mode ObjFpc}
{$H+}

interface
  
procedure Register;

implementation

{$R ideicons.res}

uses
  Classes, SysUtils, LResources, LazarusPackageIntf,
  VirtualTrees, VirtualTrees.HeaderPopup, VirtualTrees.IDEEditors, ComponentEditors, VirtualTrees.DrawTree;


procedure RegisterUnitVirtualTrees;
begin
  RegisterComponents('Virtual Controls', [TVirtualDrawTree, TVirtualStringTree]);
end;  

procedure RegisterUnitVTHeaderPopup;
begin
  RegisterComponents('Virtual Controls', [TVTHeaderPopupMenu]);
end;

procedure Register;

begin
  RegisterComponentEditor([TCustomVirtualDrawTree, TCustomVirtualStringTree], TVirtualTreeEditor);
  RegisterUnit('VirtualTrees', @RegisterUnitVirtualTrees);
  RegisterUnit('VirtualTrees.HeaderPopup', @RegisterUnitVTHeaderPopup);
end;

end.
