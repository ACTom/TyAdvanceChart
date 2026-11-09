unit test.advchart.defaults;
{ TyControls #108, for the chart: a published ordinal property's declared default must be the
  value the constructor sets. When the two disagree, the designer loses a value: one equal to
  the declared default is not written to the .lfm, and the constructor puts its own back when
  the form is read. TyControls' test.defaults.guard checks every class on its palette;
  TTyAdvanceChart was in that palette list until it moved here, and is checked here the same way. }
{$mode objfpc}{$H+}
interface

uses
  Classes, SysUtils, TypInfo, Controls, Forms, fpcunit, testregistry;

type
  TAdvChartDeclaredDefaultsTest = class(TTestCase)
  published
    procedure TestEveryDeclaredDefaultIsTheConstructedValue;
  end;

implementation

uses
  tyControls.AdvanceChart;

const
  Palette: array[0..0] of TComponentClass = (TTyAdvanceChart);

procedure TAdvChartDeclaredDefaultsTest.TestEveryDeclaredDefaultIsTheConstructedValue;
var
  i, j, n, checked: Integer;
  c: TComponent;
  props: PPropList;
  p: PPropInfo;
  cur: Int64;
  found: TStringList;
begin
  found := TStringList.Create;
  try
    checked := 0;
    for i := 0 to High(Palette) do
    begin
      c := Palette[i].Create(nil);
      try
        n := GetPropList(PTypeInfo(c.ClassInfo), props);
        try
          for j := 0 to n - 1 do
          begin
            p := props^[j];
            if not (p^.PropType^.Kind in [tkInteger, tkChar, tkWChar, tkEnumeration, tkBool, tkSet]) then
              Continue;
            if (p^.GetProc = nil) or (p^.SetProc = nil) then Continue;
            if p^.Default = LongInt($80000000) then Continue;   // nodefault: always written
            if not IsStoredProp(c, p) then Continue;
            Inc(checked);
            cur := GetOrdProp(c, p);
            if LongInt(cur) <> p^.Default then
              found.Add(Format('%s.%s: declared %d, constructed %d',
                [c.ClassName, p^.Name, p^.Default, cur]));
          end;
        finally
          FreeMem(props);
        end;
      finally
        c.Free;
      end;
    end;
    AssertTrue('anti-vacuity: no property with a declared default was checked', checked > 0);
    AssertEquals('a declared default that is not the constructed value:' + LineEnding
      + found.Text, 0, found.Count);
  finally
    found.Free;
  end;
end;

initialization
  RegisterTest(TAdvChartDeclaredDefaultsTest);
end.
