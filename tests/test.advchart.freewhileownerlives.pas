{ Copied from TyControls tests/test.freewhileownerlives.pas at 77860b40. }
unit test.advchart.freewhileownerlives;
{$mode objfpc}{$H+}

{ Every registered component can be freed on its own while its form stays open.

  That is the path `Chart1.Free` takes at run time, and it differs from the one a closing form
  takes. Freeing a component removes it from its owner, and the owner notifies every component it
  owns of the removal -- the dying one included, after its own destructor has already run. A
  Notification override that reads a field the destructor freed crashes there. A closing form
  never gets there, so a test suite that only ever frees whole forms never sees it (TyControls
  #15, TTyCoolBar). TyControls' TFreeWhileOwnerLivesTest sweeps its palette; TTyAdvanceChart was
  on it until it moved here, and the same sweep runs over this repository's registrations: build
  each class on a live form (parented, when it is a control), free it, keep the form. }

interface

uses
  Classes, SysUtils, Forms, Controls, fpcunit, testregistry, test.designregistry,
  test.advchart.version;

type
  TAdvChartFreeWhileOwnerLivesTest = class(TTestCase)
  published
    procedure TestEveryRegisteredComponentCanBeFreedWhileItsFormLives;
  end;

implementation

procedure TAdvChartFreeWhileOwnerLivesTest.TestEveryRegisteredComponentCanBeFreedWhileItsFormLives;
var
  names, crashed: TStringList;
  i, swept, n: Integer;
  cls: TPersistentClass;
  form: TForm;
  c: TComponent;
begin
  names := TStringList.Create;
  crashed := TStringList.Create;
  try
    CollectRegisteredClassNames(names);
    AssertTrue('the design-registry parser found the palette entry',
      names.IndexOf('TTyAdvanceChart') >= 0);
    swept := 0;
    for i := 0 to names.Count - 1 do
    begin
      cls := GetClass(names[i]);
      { An unresolvable name is test.advchart.version's to report. A form is not dropped on a
        form. }
      if (cls = nil) or (not cls.InheritsFrom(TComponent)) then Continue;
      if cls.InheritsFrom(TCustomForm) then Continue;
      form := TForm.CreateNew(nil);
      try
        form.SetBounds(0, 0, 400, 300);
        c := nil;
        try
          c := TComponentClass(cls).Create(form);
          if c is TControl then TControl(c).Parent := form;
          n := form.ComponentCount;
          Inc(swept);
          c.Free;
          if form.ComponentCount <> n - 1 then
            crashed.Add(Format('%s: the form went from %d to %d components',
              [names[i], n, form.ComponentCount]));
        except
          on E: Exception do
            crashed.Add(names[i] + ': ' + E.ClassName + ': ' + E.Message);
        end;
      finally
        form.Free;
      end;
    end;
    AssertTrue(Format('the sweep must cover the registrations, and it covered %d classes',
      [swept]), swept >= 1);
    AssertEquals('components that cannot be freed on their own while their form stays open:' +
      LineEnding + crashed.Text, 0, crashed.Count);
  finally
    crashed.Free;
    names.Free;
  end;
end;

initialization
  RegisterTest(TAdvChartFreeWhileOwnerLivesTest);
end.
