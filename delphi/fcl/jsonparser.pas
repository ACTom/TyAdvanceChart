{
    This file is part of the Free Component Library

    JSON source parser
    Copyright (c) 2007 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{ Ported for Delphi by the TyAdvanceChart project from Free Pascal 3.2.2,
  packages/fcl-json/src/jsonparser.pp. Compiled by Delphi only: Lazarus builds with FPC's own unit.
  Changed, by kind:
  - range and overflow checks are off (the directives $R- and $Q- before the unit clause), as
    FPC builds its fcl-json, so that a project compiled with them gets FPC's results
    (TJSONInt64Number of 2^40 gives AsInteger 0, not ERangeError);
  - strings are Delphi's UTF-16 string (TJSONStringType = string, TJSONCharType = Char), and QWord
    is written UInt64;
  - procedure variables are compared through local variables and Assigned;
  - the switch to mode objfpc is gone (FPC's only).
  The original's licence applies, see the notice above (THIRD-PARTY-NOTICES.md says more). }
{$h+}
{ Compiled as FPC compiles its own units: without range and overflow checks, whatever the
  project sets. }
{$R-}{$Q-}
unit jsonparser;

interface

uses
  Classes, SysUtils, fpJSON, jsonscanner, jsonreader;
  
Type

  { TJSONParser }

  TJSONParser = Class(TBaseJSONReader)
  private
    FStack : Array of TJSONData;
    FStackPos : integer;
    FStruct : TJSONData;
    FValue : TJSONData;
    FKey: TJSONStringType;
    procedure Pop(aType: TJSONType);
    Procedure Push(AValue : TJSONData);
    Function NewValue(AValue : TJSONData) : TJSONData;
  Protected
    Procedure KeyValue(Const AKey : TJSONStringType); override;
    Procedure StringValue(Const AValue : TJSONStringType);override;
    Procedure NullValue; override;
    Procedure FloatValue(Const AValue : Double); override;
    Procedure BooleanValue(Const AValue : Boolean); override;
    Procedure NumberValue(Const AValue : TJSONStringType); override;
    Procedure IntegerValue(Const AValue : integer); override;
    Procedure Int64Value(Const AValue : int64); override;
    Procedure QWordValue(Const AValue : UInt64); override;
    Procedure StartArray; override;
    Procedure StartObject; override;
    Procedure EndArray; override;
    Procedure EndObject; override;
  Public
    function Parse: TJSONData;
  end;
  
  EJSONParser = jsonReader.EJSONParser;
  
implementation

Resourcestring
  SErrStructure = 'Structural error';

{ TJSONParser }

procedure DefJSONParserHandler(AStream: TStream; const AUseUTF8: Boolean; out
  Data: TJSONData);

Var
  P : TJSONParser;
  AOptions: TJSONOptions;

begin
  Data:=Nil;
  AOptions:=[];
  if AUseUTF8 then
    Include(AOptions,joUTF8);
  P:=TJSONParser.Create(AStream,AOptions);
  try
    Data:=P.Parse;
  finally
    P.Free;
  end;
end;

procedure DefJSONStringParserHandler(Const S : TJSONStringType; const AUseUTF8: Boolean; out
  Data: TJSONData);

Var
  P : TJSONParser;
  AOptions: TJSONOptions;

begin
  Data:=Nil;
  AOptions:=[];
  if AUseUTF8 then
    Include(AOptions,joUTF8);
  P:=TJSONParser.Create(S,AOptions);
  try
    Data:=P.Parse;
  finally
    P.Free;
  end;
end;

procedure TJSONParser.Pop(aType: TJSONType);

begin
  if (FStackPos=0) then
    DoError(SErrStructure);
  If (FStruct.JSONType<>aType) then
    DoError(SErrStructure);
  Dec(FStackPos);
  FStruct:=FStack[FStackPos];
end;

procedure TJSONParser.Push(AValue: TJSONData);

begin
  if (FStackPos=Length(FStack)) then
    SetLength(FStack,FStackPos+10);
  FStack[FStackPos]:=FStruct;
  Inc(FStackPos);
  FStruct:=AValue;
end;

function TJSONParser.NewValue(AValue: TJSONData): TJSONData;
begin
  Result:=AValue;
  // Add to existing structural type
  if (FStruct is TJSONObject) then
    begin
    if (Not (joIgnoreDuplicates in options)) then
      try
        TJSONObject(FStruct).Add(FKey,AValue);
      except
        AValue.Free;
        Raise;
      end
    else if (TJSONObject(FStruct).IndexOfName(FKey)=-1) then
      TJSONObject(FStruct).Add(FKey,AValue)
    else
      AValue.Free;
    FKey:='';
    end
  else if (FStruct is TJSONArray) then
    TJSONArray(FStruct).Add(AValue);
  // The first actual value is our result
  if (FValue=Nil) then
    FValue:=AValue;
end;

procedure TJSONParser.KeyValue(const AKey: TJSONStringType);
begin
  if (FStruct is TJSONObject) and (FKey='') then
    FKey:=Akey
  else
    DoError('Duplicatekey or no object');
end;

procedure TJSONParser.StringValue(const AValue: TJSONStringType);
begin
  NewValue(CreateJSON(AValue));
end;

procedure TJSONParser.NullValue;
begin
  NewValue(CreateJSON);
end;

procedure TJSONParser.FloatValue(const AValue: Double);
begin
  NewValue(CreateJSON(AValue));
end;

procedure TJSONParser.BooleanValue(const AValue: Boolean);
begin
  NewValue(CreateJSON(AValue));
end;

procedure TJSONParser.NumberValue(const AValue: TJSONStringType);
begin
  // Do nothing
  if AValue='' then ;
end;

procedure TJSONParser.IntegerValue(const AValue: integer);
begin
  NewValue(CreateJSON(AValue));
end;

procedure TJSONParser.Int64Value(const AValue: int64);
begin
  NewValue(CreateJSON(AValue));
end;

procedure TJSONParser.QWordValue(const AValue: UInt64);
begin
  NewValue(CreateJSON(AValue));
end;

procedure TJSONParser.StartArray;
begin
  Push(NewValue(CreateJSONArray([])))
end;


procedure TJSONParser.StartObject;
begin
  Push(NewValue(CreateJSONObject([])));
end;

procedure TJSONParser.EndArray;
begin
  Pop(jtArray);
end;

procedure TJSONParser.EndObject;
begin
  Pop(jtObject);
end;


function TJSONParser.Parse: TJSONData;

begin
  SetLength(FStack,0);
  FStackPos:=0;
  FValue:=Nil;
  FStruct:=Nil;
  try
    DoExecute;
    Result:=FValue;
  except
    On E : exception do
      begin
      FreeAndNil(FValue);
      FStackPos:=0;
      SetLength(FStack,0);
      Raise;
      end;
  end;
end;

{
  Consume next token and convert to JSON data structure.
  If AtCurrent is true, the current token is used. If false,
  a token is gotten from the scanner.
  If AllowEOF is false, encountering a tkEOF will result in an exception.
}


Procedure InitJSONHandler;
var H: TJSONParserHandler; HS: TJSONStringParserHandler;
begin
  H:=GetJSONParserHandler(); HS:=GetJSONStringParserHandler();
  if not Assigned(H) then
    SetJSONParserHandler(@DefJSONParserHandler);
  if not Assigned(HS) then
    SetJSONStringParserHandler(@DefJSONStringParserHandler);
end;

Procedure DoneJSONHandler;
var H: TJSONParserHandler; HS: TJSONStringParserHandler;
begin
  H:=GetJSONParserHandler(); HS:=GetJSONStringParserHandler();
  if @H=@DefJSONParserHandler then
    SetJSONParserHandler(Nil);
  if @HS=@DefJSONStringParserHandler then
    SetJSONStringParserHandler(Nil);
end;

initialization
  InitJSONHandler;
finalization
  DoneJSONHandler;
end.

