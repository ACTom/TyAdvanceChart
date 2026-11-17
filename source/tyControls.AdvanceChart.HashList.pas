unit tyControls.AdvanceChart.HashList;
{$I tyControls.AdvanceChart.Compiler.inc}
{ The chart's name-to-pointer tables: the animation's proxy indexes, the
  axis proxies, the z allocation and the view ranks.

  UNDER FPC THE OLD CLASS. TTyHashList is FPC's TFPHashList itself and
  TTyHashKey a ShortString, so every table behaves bit for bit as before.

  UNDER DELPHI A CLASS OF ITS OWN, keyed by string: a ShortString there holds
  ANSI only, and a series name outside it would be lost. It does what the
  chart relies on TFPHashList for (tests/test.advchart.hashlist.pas pins it):
  entries are kept in the order they were added and Add returns the new
  index; a name added twice keeps both entries and lookups find the later;
  an entry whose item is nil is counted but never found; Delete moves the
  later entries down one and lookups follow; Remove deletes the first entry
  that holds the item. Names compare exactly, case included.

  PURE: contnrs under FPC; Generics.Collections under Delphi. }
interface
uses {$IFDEF FPC}contnrs{$ELSE}System.Generics.Collections{$ENDIF};

type
  { The name under which an item is kept. Under FPC a ShortString, as
    TFPHashList wants (255 bytes at most); under Delphi a string, because a
    ShortString there holds ANSI only. }
  TTyHashKey = {$IFDEF FPC}ShortString{$ELSE}string{$ENDIF};
  {$IFDEF FPC}TTyHashList = TFPHashList;{$ELSE}
  TTyHashList = class
  private
    { the entries, by index }
    FNames: TList<string>;
    FItems: TList<Pointer>;
    { each name to the highest index holding it with an item other than nil }
    FIndex: TDictionary<string, Integer>;
    function GetCount: Integer;
    procedure Reindex;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const AName: TTyHashKey; AItem: Pointer): Integer;
    function Find(const AName: TTyHashKey): Pointer;
    function FindIndexOf(const AName: TTyHashKey): Integer;
    procedure Delete(AIndex: Integer);
    function Remove(AItem: Pointer): Integer;
    procedure Clear;
    property Count: Integer read GetCount;
  end;
  {$ENDIF}

implementation

{$IFNDEF FPC}
uses System.Classes, System.RTLConsts;

constructor TTyHashList.Create;
begin
  inherited Create;
  FNames := TList<string>.Create;
  FItems := TList<Pointer>.Create;
  FIndex := TDictionary<string, Integer>.Create;
end;

destructor TTyHashList.Destroy;
begin
  FIndex.Free;
  FItems.Free;
  FNames.Free;
  inherited Destroy;
end;

function TTyHashList.GetCount: Integer;
begin
  Result := FItems.Count;
end;

{ Every entry in index order, a later one taking over its name, as
  TFPHashList's ReHash chains them. }
procedure TTyHashList.Reindex;
var
  i: Integer;
begin
  FIndex.Clear;
  for i := 0 to FItems.Count - 1 do
    if FItems[i] <> nil then
      FIndex.AddOrSetValue(FNames[i], i);
end;

function TTyHashList.Add(const AName: TTyHashKey; AItem: Pointer): Integer;
begin
  Result := FItems.Count;
  FNames.Add(AName);
  FItems.Add(AItem);
  if AItem <> nil then
    FIndex.AddOrSetValue(AName, Result);
end;

function TTyHashList.Find(const AName: TTyHashKey): Pointer;
var
  i: Integer;
begin
  if FIndex.TryGetValue(AName, i) then
    Result := FItems[i]
  else
    Result := nil;
end;

function TTyHashList.FindIndexOf(const AName: TTyHashKey): Integer;
begin
  if not FIndex.TryGetValue(AName, Result) then
    Result := -1;
end;

procedure TTyHashList.Delete(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FItems.Count) then
    raise EListError.CreateFmt(SListIndexError, [AIndex]);
  FNames.Delete(AIndex);
  FItems.Delete(AIndex);
  Reindex;
end;

function TTyHashList.Remove(AItem: Pointer): Integer;
begin
  Result := FItems.IndexOf(AItem);
  if Result <> -1 then
    Delete(Result);
end;

procedure TTyHashList.Clear;
begin
  FIndex.Clear;
  FItems.Clear;
  FNames.Clear;
end;
{$ENDIF}

end.
