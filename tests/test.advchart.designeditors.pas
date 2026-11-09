unit test.advchart.designeditors;
{$mode objfpc}{$H+}

{ Guards for the chart's Object Inspector editors: the Option property editor
  tyControls.Design.AdvanceChart.Register hangs on TTyCustomAdvanceChart.

  TyControls' test.designeditors parses every RegisterPropertyEditor call in its designtime/ and
  resolves each against the runtime classes' RTTI; the chart's registration was one of them (its
  base class sat in that unit's RegisterClasses block) until it moved here. The same checks run
  here over this repository's designtime/:
    - a registration names a property its class, or a registered class derived from it,
      publishes, and a TypeInfo(string) registration a plain string property -- otherwise the
      IDE never matches it and shows a plain edit box, with no error anywhere;
    - every property editor declared in designtime/ is registered;
    - an editing registration sits on the custom class (TyControls' plan D2), so a third party
      that derives TTyCustomAdvanceChart and publishes Option gets the editor too.

  tests/ cannot LINK the design-time units (they pull in IDEIntf); it reads them, through
  test.designregistry, the parser TyControls' guards share. }

interface

uses
  Classes, SysUtils, StrUtils, TypInfo, fpcunit, testregistry,
  test.designregistry, test.advchart.customclasses,
  tyControls.AdvanceChart;

type
  TAdvChartDesignEditorsTest = class(TTestCase)
  published
    procedure TestEveryRegistrationTargetsARealProperty;
    procedure TestNoDeclaredPropertyEditorIsUnregistered;
    procedure TestEditorsSitOnTheCustomClass;
  end;

implementation

const
  { The type expression the string registrations use, whitespace already squeezed out. }
  CStringTypeExpr = 'TypeInfo(string)';

{ Whitespace carries no meaning inside an argument (the registrations wrap across lines). }
function Squeezed(const S: string): string;
var i: Integer;
begin
  Result := '';
  for i := 1 to Length(S) do
    if S[i] > ' ' then Result := Result + S[i];
end;

{ Is APropInfo a PLAIN `string` property? RegisterPropertyEditor matches on the type NAME, so
  `string`, `TCaption` and `TTranslateString` are different targets. }
function IsPlainString(APropInfo: PPropInfo): Boolean;
begin
  Result := (APropInfo <> nil)
        and (APropInfo^.PropType^.Name = PTypeInfo(TypeInfo(string))^.Name);
end;

{ Every RegisterPropertyEditor call in designtime/, as parsed records. Caller frees. }
function Registrations: TStringList;
begin
  Result := TStringList.Create;
  try
    CollectPropertyEditorRegistrations(Result);
  except
    Result.Free;
    raise;
  end;
end;

{ The editor class registered for ABase.AProp exactly, or '' when there is none. }
function EditorFor(const ABase, AProp: string): string;
var
  regs: TStringList;
  i: Integer;
  ty, base, prop, ed: string;
begin
  Result := '';
  regs := Registrations;
  try
    for i := 0 to regs.Count - 1 do
      if SplitEditorRegistration(regs[i], ty, base, prop, ed)
         and (Squeezed(base) = ABase) and SameText(Squeezed(prop), AProp) then
        Exit(Squeezed(ed));
  finally
    regs.Free;
  end;
end;

{ Follow AName up the ancestor chain declared in the design source and return the first
  ancestor not declared there -- the LCL base it specialises. '' when AName is not declared. }
function LclBaseOf(const AName: string): string;
var
  decls: TStringList;
  cur, nm, anc: string;
  i, hops: Integer;
  found: Boolean;
begin
  Result := '';
  decls := TStringList.Create;
  try
    CollectClassDeclarations(decls);
    cur := AName;
    for hops := 0 to decls.Count do
    begin
      found := False;
      for i := 0 to decls.Count - 1 do
        if SplitClassDeclaration(decls[i], nm, anc) and SameText(nm, cur) then
        begin
          cur := anc;
          found := True;
          Break;
        end;
      if not found then
      begin
        if hops = 0 then Exit('');
        Exit(cur);
      end;
    end;
  finally
    decls.Free;
  end;
end;

{ The registered class that inherits from AClass and publishes AProp; nil when there is none.
  The IDE matches a registration by InheritsFrom and shows only PUBLISHED properties, so an
  editor on a custom class fires for the final class that publishes the name. }
function PublishingDescendant(AClass: TClass; const AProp: string): PPropInfo;
var
  names: TStringList;
  i: Integer;
  c: TPersistentClass;
begin
  Result := nil;
  names := TStringList.Create;
  try
    CollectRegisteredClassNames(names);
    for i := 0 to names.Count - 1 do
    begin
      c := GetClass(names[i]);
      if (c = nil) or not c.InheritsFrom(AClass) then Continue;
      Result := GetPropInfo(c, AProp);
      if Result <> nil then Exit;
    end;
  finally
    names.Free;
  end;
end;

procedure TAdvChartDesignEditorsTest.TestEveryRegistrationTargetsARealProperty;
var
  regs, unresolved, missing, mistyped: TStringList;
  i, named: Integer;
  ty, base, prop, ed: string;
  cls: TPersistentClass;
  pi: PPropInfo;
begin
  regs := Registrations;
  unresolved := TStringList.Create;
  missing := TStringList.Create;
  mistyped := TStringList.Create;
  try
    AssertTrue('no RegisterPropertyEditor calls parsed out of designtime/ -- the parse has'
      + ' drifted', regs.Count > 0);
    named := 0;
    for i := 0 to regs.Count - 1 do
    begin
      AssertTrue('malformed registration record (expected four fields): ' + regs[i],
        SplitEditorRegistration(regs[i], ty, base, prop, ed));
      ty := Squeezed(ty); base := Squeezed(base); prop := Squeezed(prop);
      if prop = '' then Continue;          // blanket, type-only rule
      Inc(named);
      cls := GetClass(base);
      if cls = nil then
      begin
        unresolved.Add(base);
        Continue;
      end;
      pi := GetPropInfo(cls, prop);
      if pi = nil then
        pi := PublishingDescendant(cls, prop);
      if pi = nil then
      begin
        missing.Add(base + '.' + prop);
        Continue;
      end;
      if (ty = CStringTypeExpr) and not IsPlainString(pi) then
        mistyped.Add(base + '.' + prop + ' is ' + pi^.PropType^.Name);
    end;
    { Anti-vacuity: the chart's one named registration, Option, at least. }
    AssertTrue(Format('only %d NAMED property-editor registrations were checked -- the parse'
      + ' has shrunk', [named]), named >= 1);
    AssertEquals('property editors registered on classes this test cannot resolve -- add them to'
      + ' the RegisterClasses block in tests/test.advchart.designeditors.pas:' + LineEnding
      + unresolved.Text, 0, unresolved.Count);
    AssertEquals('property editor registered on a property that neither the class publishes'
      + ' nor any registered class derived from it does -- the Object Inspector will never'
      + ' consult that editor:' + LineEnding + missing.Text, 0, missing.Count);
    AssertEquals('registered with TypeInfo(string) but the property is a DIFFERENT string type'
      + ' -- RegisterPropertyEditor compares type names, so this editor never fires:' + LineEnding
      + mistyped.Text, 0, mistyped.Count);
  finally
    mistyped.Free;
    missing.Free;
    unresolved.Free;
    regs.Free;
  end;
end;

procedure TAdvChartDesignEditorsTest.TestNoDeclaredPropertyEditorIsUnregistered;
var
  decls, regs, used, dead: TStringList;
  i, editors: Integer;
  nm, anc, root, ty, base, prop, ed: string;
begin
  decls := TStringList.Create;
  regs := Registrations;
  used := TStringList.Create;
  dead := TStringList.Create;
  try
    CollectClassDeclarations(decls);
    AssertTrue('no class declarations parsed out of designtime/', decls.Count > 0);
    for i := 0 to regs.Count - 1 do
      if SplitEditorRegistration(regs[i], ty, base, prop, ed) then
        used.Add(Squeezed(ed));
    editors := 0;
    for i := 0 to decls.Count - 1 do
    begin
      if not SplitClassDeclaration(decls[i], nm, anc) then Continue;
      root := LclBaseOf(nm);
      if not (AnsiEndsText('PropertyEditor', root) or AnsiEndsText('Property', root)) then
        Continue;
      Inc(editors);
      if used.IndexOf(nm) < 0 then dead.Add(nm + ' (a ' + root + ')');
    end;
    AssertTrue(Format('only %d property-editor classes were recognised in the design source --'
      + ' the ancestry parse has drifted', [editors]), editors >= 1);
    AssertEquals('property editor declared but never registered -- it is dead code and the'
      + ' property it was written for still shows a plain edit box:' + LineEnding + dead.Text,
      0, dead.Count);
  finally
    dead.Free;
    used.Free;
    regs.Free;
    decls.Free;
  end;
end;

procedure TAdvChartDesignEditorsTest.TestEditorsSitOnTheCustomClass;
var
  regs, bad: TStringList;
  i, checked: Integer;
  ty, base, prop, ed: string;
  cls: TPersistentClass;
begin
  regs := Registrations;
  bad := TStringList.Create;
  try
    checked := 0;
    for i := 0 to regs.Count - 1 do
    begin
      if not SplitEditorRegistration(regs[i], ty, base, prop, ed) then Continue;
      base := Squeezed(base); prop := Squeezed(prop); ed := Squeezed(ed);
      if SameText(ed, 'THiddenPropertyEditor') then Continue;
      Inc(checked);
      if CustomClassesSplit.IndexOf(base) < 0 then Continue;   // not a split final class
      cls := GetClass(base);
      if (cls <> nil) and (cls.ClassParent <> nil) then
        bad.Add(Format('%s.%s (%s): register it on %s', [base, prop, ed, cls.ClassParent.ClassName]))
      else
        bad.Add(Format('%s.%s (%s): register it on the custom class', [base, prop, ed]));
    end;
    AssertTrue(Format('only %d editing registrations were checked -- the parse has shrunk',
      [checked]), checked >= 1);
    AssertEquals('property editor registered on a split FINAL class: a third party deriving the'
      + ' custom class and publishing the property gets a plain box:' + LineEnding
      + bad.Text, 0, bad.Count);
    { The one this repository has, by name. }
    AssertEquals('TTyCustomAdvanceChart.Option', 'TTyChartOptionProperty',
      EditorFor('TTyCustomAdvanceChart', 'Option'));
  finally
    bad.Free;
    regs.Free;
  end;
end;

initialization
  { Name -> class, so a base parsed out of the registrations can be resolved. The chart's Option
    property editor is registered on the custom class (TyControls registered it here too). }
  RegisterClasses([TTyCustomAdvanceChart]);
  RegisterTest(TAdvChartDesignEditorsTest);

end.
