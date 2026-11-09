unit test.advchart.version;
{$mode objfpc}{$H+}

{ The library-version guard, for what this repository registers with the IDE.

  TyControls' test.version sweeps every class its designtime/ registers: each must publish a
  read-only `Version: string` that reports TyVersion, and descend from a class TyControls hangs
  its Version property editor (the About dialog) on. The chart sat in that sweep (its entry in
  the Reg() block) until it moved here, so the same sweep runs over this repository's own
  registrations -- the population parsed out of designtime/ by test.designregistry, the class
  names resolved through the Reg() block below.

  Where the Version editor is registered is TyControls' design-time code, not this
  repository's: that half reads the checkout TY_CORE_DIR names, and is ignored without one. }

interface

uses
  Classes, SysUtils, TypInfo, Controls, Forms, fpcunit, testregistry,
  test.designregistry, test.advchart.coredir,
  tyControls.Types, tyControls.AdvanceChart;

type
  TAdvChartVersionTest = class(TTestCase)
  published
    procedure TestEveryRegisteredNameResolves;
    procedure TestEveryRegisteredComponentReportsTyVersion;
    procedure TestTheCoresVersionEditorReachesEveryRegisteredComponent;
  end;

implementation

var
  { Names of the classes this unit teaches the class registry about, recorded by Reg(): the
    reverse half of the drift guard, as in TyControls' test.version. }
  GKnownNames: TStringList = nil;

procedure Reg(const AClasses: array of TPersistentClass);
var i: Integer;
begin
  RegisterClasses(AClasses);
  if GKnownNames = nil then GKnownNames := TStringList.Create;
  for i := Low(AClasses) to High(AClasses) do
    if GKnownNames.IndexOf(AClasses[i].ClassName) < 0 then
      GKnownNames.Add(AClasses[i].ClassName);
end;

{ The drift guard. Two directions: every name the registrations mention must be buildable here,
  and every name built here must still be registered. }
procedure TAdvChartVersionTest.TestEveryRegisteredNameResolves;
var
  names, bad: TStringList;
  i: Integer;
begin
  names := TStringList.Create;
  bad := TStringList.Create;
  try
    CollectRegisteredClassNames(names);
    AssertTrue('parser found the palette entry (RegisterComponents)',
      names.IndexOf('TTyAdvanceChart') >= 0);
    for i := 0 to names.Count - 1 do
      if GetClass(names[i]) = nil then bad.Add(names[i]);
    AssertEquals('registered in designtime/ but not reachable from this test -- add the class'
      + ' (and its unit) to the Reg() block at the bottom of tests/test.advchart.version.pas:'
      + LineEnding + bad.Text, 0, bad.Count);
    bad.Clear;
    for i := 0 to GKnownNames.Count - 1 do
      if names.IndexOf(GKnownNames[i]) < 0 then bad.Add(GKnownNames[i]);
    AssertEquals('known to be registered with the IDE, but the parse of designtime/ no longer'
      + ' finds them -- either the registration was removed (drop them from Reg() too) or the'
      + ' parser has stopped matching a call shape:' + LineEnding + bad.Text, 0, bad.Count);
  finally
    bad.Free;
    names.Free;
  end;
end;

{ The sweep: build one of everything registered and read the property back. }
procedure TAdvChartVersionTest.TestEveryRegisteredComponentReportsTyVersion;
var
  names, bad: TStringList;
  i: Integer;
  cls: TPersistentClass;
  C: TComponent;
  pi: PPropInfo;
begin
  names := TStringList.Create;
  bad := TStringList.Create;
  try
    CollectRegisteredClassNames(names);
    AssertTrue('the sweep has something to build', names.Count > 0);
    for i := 0 to names.Count - 1 do
    begin
      cls := GetClass(names[i]);
      if cls = nil then Continue;   // TestEveryRegisteredNameResolves reports it
      C := nil;
      try
        try
          C := TComponentClass(cls).Create(nil);
        except
          on E: Exception do
          begin
            bad.Add(names[i] + ': constructor raised ' + E.ClassName + ': ' + E.Message);
            C := nil;
          end;
        end;
        if C = nil then Continue;
        pi := GetPropInfo(cls, 'Version');
        if pi = nil then
          bad.Add(names[i] + ': no published Version property')
        else if not (pi^.PropType^.Kind in [tkSString, tkLString, tkAString, tkWString, tkUString]) then
          bad.Add(names[i] + ': Version is not a string property')
        else if pi^.SetProc <> nil then
          { a writable Version streams `Version = '...'` into every saved form }
          bad.Add(names[i] + ': Version must be read-only (it has a setter) -- a writable'
            + ' Version streams into .lfm files')
        else if GetStrProp(C, 'Version') <> TyVersion then
          bad.Add(names[i] + ': Version = ''' + GetStrProp(C, 'Version')
            + ''' (expected ''' + TyVersion + ''')');
      finally
        C.Free;
      end;
    end;
    AssertEquals('registered components that do not report TyVersion through a published'
      + ' read-only Version property:' + LineEnding + bad.Text, 0, bad.Count);
  finally
    bad.Free;
    names.Free;
  end;
end;

{ Having the property is half the contract: the '...' button that opens the About dialog comes
  from TyControls' RegisterPropertyEditor(..., 'Version', ...) calls on a few BASE classes, and a
  component off that inheritance tree shows a dead property in the Object Inspector. The bases
  are read from TyControls' designtime/ (TY_CORE_DIR); a chart class must have one of them, by
  name, on its ancestor chain. }
procedure TAdvChartVersionTest.TestTheCoresVersionEditorReachesEveryRegisteredComponent;
var
  core: string;
  bases, names, bad: TStringList;
  i: Integer;
  cls: TPersistentClass;
  c: TClass;
  reached: Boolean;
begin
  core := TyCoreDirFor(Self, 'whether TyControls'' Version editor reaches the chart');
  bases := TStringList.Create;
  names := TStringList.Create;
  bad := TStringList.Create;
  try
    CollectPropertyEditorBases('Version', bases, core);
    AssertTrue('no Version property-editor registrations found in ' + core + 'designtime/'
      + ' -- the parse has drifted', bases.Count > 0);
    CollectRegisteredClassNames(names);
    for i := 0 to names.Count - 1 do
    begin
      cls := GetClass(names[i]);
      if cls = nil then Continue;   // TestEveryRegisteredNameResolves reports it
      reached := False;
      c := cls;
      while (c <> nil) and not reached do
      begin
        reached := bases.IndexOf(c.ClassName) >= 0;
        c := c.ClassParent;
      end;
      if not reached then
        bad.Add(names[i] + ': Version is not reachable by the design-time editor -- it must'
          + ' descend from one of: ' + StringReplace(Trim(bases.Text), LineEnding, ', ',
          [rfReplaceAll]));
    end;
    AssertEquals('registered components the Version editor never reaches:' + LineEnding
      + bad.Text, 0, bad.Count);
  finally
    bad.Free;
    names.Free;
    bases.Free;
  end;
end;

initialization
  { Name -> class for the sweep. Not the list under test: TestEveryRegisteredNameResolves is what
    fails when it falls behind designtime/. }
  Reg([TTyAdvanceChart]);
  RegisterTest(TAdvChartVersionTest);

finalization
  GKnownNames.Free;

end.
