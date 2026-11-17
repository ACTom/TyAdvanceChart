{ What the chart uses of FPC's dynlibs, for Delphi on Windows: Data reaches kernel32's time zone routines
  through it. The names and their meaning are FPC's; underneath are Winapi.Windows' LoadLibrary,
  GetProcAddress and FreeLibrary. Delphi only (Lazarus builds with FPC's own dynlibs). }
unit dynlibs;

interface

{$IFNDEF MSWINDOWS}{$MESSAGE FATAL 'dynlibs: Windows only'}{$ENDIF}

uses
  Winapi.Windows;

type
  TLibHandle = HMODULE;

const
  NilHandle = TLibHandle(0);

{ the module AName, loaded; NilHandle when it cannot be }
function LoadLibrary(const AName: string): TLibHandle;
{ the address of the routine AProcName exports; nil when it exports none of that name }
function GetProcedureAddress(ALib: TLibHandle; const AProcName: string): Pointer;
{ True when the module is released }
function UnloadLibrary(ALib: TLibHandle): Boolean;

implementation

function LoadLibrary(const AName: string): TLibHandle;
begin
  Result := Winapi.Windows.LoadLibrary(PChar(AName));
end;

function GetProcedureAddress(ALib: TLibHandle; const AProcName: string): Pointer;
var
  name: AnsiString;
begin
  { exported names are ANSI }
  name := AnsiString(AProcName);
  Result := Winapi.Windows.GetProcAddress(ALib, PAnsiChar(name));
end;

function UnloadLibrary(ALib: TLibHandle): Boolean;
begin
  Result := Winapi.Windows.FreeLibrary(ALib);
end;

end.
