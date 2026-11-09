{ Copied from TyControls tests/test.danglingrefs.pas at 77860b40. }
unit test.advchart.danglingrefs;
{$mode objfpc}{$H+}

{ A component that points at another one must let go of it when that one is freed, whoever owns it.

  A published reference to another component (Controller, PopupMenu, Action, ...) is safe only if
  the holder asks the target for a free notification. Without one, the holder hears of the
  target's death only through its owner's broadcast, and that reaches it only when the two share
  an owner. Put the target on another form, free it, and the holder keeps a pointer to freed
  memory.

  TyControls' TDanglingRefsTest.TestEveryReferenceLetsGoOfAComponentFreedElsewhere sweeps every
  class its designtime/ registers; TTyAdvanceChart was swept with them until it moved here. The
  same sweep runs here over this repository's registrations (test.designregistry). The floor is
  the chart's three: Controller, PopupMenu and Action. The suite's other tests are about the
  core's icon fonts, image lists and forms, and stay there. }

interface

uses
  Classes, SysUtils, TypInfo, Forms, Controls, fpcunit, testregistry,
  test.designregistry, test.advchart.version;

type
  TAdvChartDanglingRefsTest = class(TTestCase)
  published
    procedure TestEveryReferenceLetsGoOfAComponentFreedElsewhere;
  end;

implementation

{ A sub-component the holder made for itself is part of the holder, not a reference to set. }
function IsOwnPart(AHolder: TComponent; AValue: TObject): Boolean;
begin
  Result := (AValue is TComponent) and ((TComponent(AValue).Owner = AHolder)
    or (csSubComponent in TComponent(AValue).ComponentStyle));
end;

function PlaceOn(AClass: TComponentClass; AForm: TForm): TComponent;
begin
  Result := AClass.Create(AForm);
  if Result is TControl then TControl(Result).Parent := AForm;
end;

procedure TAdvChartDanglingRefsTest.TestEveryReferenceLetsGoOfAComponentFreedElsewhere;
var
  names, kept, seen: TStringList;
  i, j, n, checked: Integer;
  cls: TPersistentClass;
  props: PPropList;
  pi: PPropInfo;
  tcls: TClass;
  home, elsewhere: TForm;
  c, tgt: TComponent;
begin
  names := TStringList.Create;
  kept := TStringList.Create;
  seen := TStringList.Create;
  try
    CollectRegisteredClassNames(names);
    AssertTrue('the design-registry parser found the palette entry',
      names.IndexOf('TTyAdvanceChart') >= 0);
    checked := 0;
    for i := 0 to names.Count - 1 do
    begin
      cls := GetClass(names[i]);
      if (cls = nil) or (not cls.InheritsFrom(TComponent)) then Continue;
      if cls.InheritsFrom(TCustomForm) then Continue;
      n := GetPropList(cls, props);
      try
        for j := 0 to n - 1 do
        begin
          pi := props^[j];
          if (pi^.PropType^.Kind <> tkClass) or (pi^.SetProc = nil) then Continue;
          tcls := GetTypeData(pi^.PropType)^.ClassType;
          if (not tcls.InheritsFrom(TComponent)) or tcls.InheritsFrom(TCustomForm) then Continue;
          { The target lives on ANOTHER form, so the owner's broadcast cannot reach the holder:
            only a free notification can. }
          home := TForm.CreateNew(nil);
          elsewhere := TForm.CreateNew(nil);
          try
            try
              c := PlaceOn(TComponentClass(cls), home);
              if IsOwnPart(c, GetObjectProp(c, pi)) then Continue;
              tgt := nil;
              try
                tgt := PlaceOn(TComponentClass(tcls), elsewhere);
                SetObjectProp(c, pi, tgt);
              except
                tgt := nil;   // a target this property refuses is not a reference it holds
              end;
              if (tgt = nil) or (GetObjectProp(c, pi) <> tgt) then Continue;
              Inc(checked);
              seen.Add(cls.ClassName + '.' + pi^.Name);
              tgt.Free;
              if GetObjectProp(c, pi) <> nil then
                kept.Add(Format('%s.%s still points at the freed %s',
                  [cls.ClassName, pi^.Name, tcls.ClassName]));
            except
              on E: Exception do
                kept.Add(Format('%s.%s: %s: %s', [cls.ClassName, pi^.Name, E.ClassName, E.Message]));
            end;
          finally
            try
              home.Free;
            except
              on E: Exception do
                kept.Add(Format('%s.%s, freeing the holder''s form: %s: %s',
                  [cls.ClassName, pi^.Name, E.ClassName, E.Message]));
            end;
            try
              elsewhere.Free;
            except
              on E: Exception do
                kept.Add(Format('%s.%s, freeing the target''s form: %s: %s',
                  [cls.ClassName, pi^.Name, E.ClassName, E.Message]));
            end;
          end;
        end;
      finally
        FreeMem(props);
      end;
    end;
    AssertTrue(Format('the sweep must reach the chart''s references, and it reached %d: %s',
      [checked, seen.CommaText]), checked >= 3);
    AssertTrue('...Controller among them', seen.IndexOf('TTyAdvanceChart.Controller') >= 0);
    AssertTrue('...PopupMenu among them', seen.IndexOf('TTyAdvanceChart.PopupMenu') >= 0);
    AssertTrue('...Action among them', seen.IndexOf('TTyAdvanceChart.Action') >= 0);
    AssertEquals('references that keep pointing at a component freed on another form:' +
      LineEnding + kept.Text, 0, kept.Count);
  finally
    seen.Free;
    kept.Free;
    names.Free;
  end;
end;

initialization
  RegisterTest(TAdvChartDanglingRefsTest);
end.
