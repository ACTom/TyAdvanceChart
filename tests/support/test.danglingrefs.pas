{ Copied from TyControls tests/test.danglingrefs.pas at 77860b40. }
unit test.danglingrefs;
{$mode objfpc}{$H+}

{ Only the poisoned-free helpers came over. The unit's own suite, TDanglingRefsTest, sweeps
  TyControls' palette and stays in TyControls. }

interface

uses
  Classes, SysUtils;

{ Poisoned frees, for any suite that has to prove nothing reads a freed object (see the
  implementation). Pair every BeginPoison with an EndPoison in a finally. }
procedure BeginPoison;
procedure EndPoison;

implementation

{ Freed memory, poisoned and held back. Between BeginPoison and EndPoison a freed block is filled
  with $7F and kept off the heap, so a read through a dangling pointer meets $7F7F... and faults
  every time -- instead of meeting whatever the heap put there next, which is often a live object
  and a silent pass. $7F and not the usual $CC: as a pointer either is outside the address space,
  but as a count $CC... is negative, so a freed list walked from Count - 1 down to 0 never reads
  anything and the test passes over the very use it is there to catch. EndPoison hands the blocks
  back. }
const
  CQuarantineMax = 16384;
var
  GOldMM: TMemoryManager;
  GQuarantine: array[0..CQuarantineMax - 1] of Pointer;
  GQuarantined: Integer;

function PoisonFreemem(p: Pointer): PtrUInt;
begin
  if p = nil then Exit(0);
  if GQuarantined >= CQuarantineMax then Exit(GOldMM.Freemem(p));
  Result := GOldMM.MemSize(p);
  FillChar(p^, Result, $7F);
  GQuarantine[GQuarantined] := p;
  Inc(GQuarantined);
end;

function PoisonFreememSize(p: Pointer; ASize: PtrUInt): PtrUInt;
begin
  Result := PoisonFreemem(p);
end;

procedure BeginPoison;
var
  mm: TMemoryManager;
begin
  GetMemoryManager(GOldMM);
  mm := GOldMM;
  mm.Freemem := @PoisonFreemem;
  mm.FreememSize := @PoisonFreememSize;
  GQuarantined := 0;
  SetMemoryManager(mm);
end;

procedure EndPoison;
var
  i: Integer;
begin
  SetMemoryManager(GOldMM);
  for i := 0 to GQuarantined - 1 do
    GOldMM.Freemem(GQuarantine[i]);
  GQuarantined := 0;
end;

end.
