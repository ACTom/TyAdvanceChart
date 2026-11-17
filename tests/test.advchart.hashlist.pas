unit test.advchart.hashlist;
{$mode objfpc}{$H+}
{ Tests for tyControls.AdvanceChart.HashList. The expected values are what
  FPC's TFPHashList does (measured on it before the Delphi class existed);
  delphi/tests/tyadvchart_values.dpr checks the same values on the Delphi
  class. }
interface
uses Classes, SysUtils, fpcunit, testregistry, tyControls.AdvanceChart.HashList;
type
  TAdvChartHashListTest = class(TTestCase)
  private
    FList: TTyHashList;
    procedure AddABC;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestFindMissingIsNil;
    procedure TestAddThenFind;
    procedure TestSameNameAddedTwice;
    procedure TestDeleteByIndex;
    procedure TestRemoveByItem;
    procedure TestClear;
  end;
implementation

const
  pA = Pointer(PtrInt(10));
  pB = Pointer(PtrInt(20));
  pC = Pointer(PtrInt(30));
  pD = Pointer(PtrInt(40));
  pZ = Pointer(PtrInt(99));

procedure TAdvChartHashListTest.SetUp;
begin
  FList := TTyHashList.Create;
end;

procedure TAdvChartHashListTest.TearDown;
begin
  FreeAndNil(FList);
end;

procedure TAdvChartHashListTest.AddABC;
begin
  FList.Add('a', pA);
  FList.Add('b', pB);
  FList.Add('c', pC);
end;

procedure TAdvChartHashListTest.TestFindMissingIsNil;
begin
  AssertTrue('empty: Find', FList.Find('x') = nil);
  AssertEquals('empty: FindIndexOf', -1, FList.FindIndexOf('x'));
  AssertEquals('empty: Count', 0, FList.Count);
  AddABC;
  AssertTrue('other names: Find', FList.Find('x') = nil);
  AssertEquals('other names: FindIndexOf', -1, FList.FindIndexOf('x'));
end;

procedure TAdvChartHashListTest.TestAddThenFind;
begin
  AssertEquals('Add a', 0, FList.Add('a', pA));
  AssertEquals('Add b', 1, FList.Add('b', pB));
  AssertEquals('Add c', 2, FList.Add('c', pC));
  AssertEquals('Count', 3, FList.Count);
  AssertTrue('Find a', FList.Find('a') = pA);
  AssertTrue('Find b', FList.Find('b') = pB);
  AssertTrue('Find c', FList.Find('c') = pC);
  AssertEquals('FindIndexOf a', 0, FList.FindIndexOf('a'));
  AssertEquals('FindIndexOf b', 1, FList.FindIndexOf('b'));
  AssertEquals('FindIndexOf c', 2, FList.FindIndexOf('c'));
end;

procedure TAdvChartHashListTest.TestSameNameAddedTwice;
begin
  AddABC;
  { the second entry is kept beside the first, and lookups find the later one }
  AssertEquals('Add b again', 3, FList.Add('b', pD));
  AssertTrue('Find b: the later', FList.Find('b') = pD);
  AssertEquals('Count', 4, FList.Count);
  AssertEquals('FindIndexOf b: the later', 3, FList.FindIndexOf('b'));
  { deleting the later uncovers the earlier }
  FList.Delete(FList.FindIndexOf('b'));
  AssertTrue('after Delete: Find b', FList.Find('b') = pB);
  AssertEquals('after Delete: Count', 3, FList.Count);
  AssertEquals('after Delete: FindIndexOf b', 1, FList.FindIndexOf('b'));
end;

procedure TAdvChartHashListTest.TestDeleteByIndex;
begin
  AddABC;
  FList.Delete(FList.FindIndexOf('b'));
  AssertTrue('Find b', FList.Find('b') = nil);
  AssertEquals('FindIndexOf b', -1, FList.FindIndexOf('b'));
  AssertEquals('Count', 2, FList.Count);
  AssertEquals('FindIndexOf a', 0, FList.FindIndexOf('a'));
  AssertEquals('FindIndexOf c: moved down', 1, FList.FindIndexOf('c'));
  AssertTrue('Find a', FList.Find('a') = pA);
  AssertTrue('Find c', FList.Find('c') = pC);
end;

procedure TAdvChartHashListTest.TestRemoveByItem;
begin
  AddABC;
  AssertEquals('Remove b: its index', 1, FList.Remove(pB));
  AssertTrue('Find b', FList.Find('b') = nil);
  AssertEquals('Count', 2, FList.Count);
  AssertTrue('Find c', FList.Find('c') = pC);
  AssertEquals('FindIndexOf c: moved down', 1, FList.FindIndexOf('c'));
  AssertEquals('Remove a pointer not held', -1, FList.Remove(pZ));
  AssertEquals('Count unchanged', 2, FList.Count);
  { an item held under two names: Remove takes the first entry only }
  AssertEquals('Add x', 2, FList.Add('x', pA));
  AssertEquals('Remove a: the first entry', 0, FList.Remove(pA));
  AssertEquals('Count after', 2, FList.Count);
  AssertTrue('Find a', FList.Find('a') = nil);
  AssertTrue('Find x', FList.Find('x') = pA);
  AssertEquals('FindIndexOf x', 1, FList.FindIndexOf('x'));
end;

procedure TAdvChartHashListTest.TestClear;
begin
  AddABC;
  FList.Clear;
  AssertEquals('Count', 0, FList.Count);
  AssertTrue('Find a', FList.Find('a') = nil);
  AssertEquals('FindIndexOf a', -1, FList.FindIndexOf('a'));
  AssertEquals('Add after Clear', 0, FList.Add('b', pD));
  AssertTrue('Find b', FList.Find('b') = pD);
  AssertEquals('Count after Add', 1, FList.Count);
end;

initialization
  RegisterTest(TAdvChartHashListTest);
end.
