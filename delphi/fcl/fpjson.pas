{
    This file is part of the Free Component Library

    JSON Data structures
    Copyright (c) 2007 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{ Ported for Delphi by the TyAdvanceChart project from Free Pascal 3.2.2,
  packages/fcl-json/src/fpjson.pp. Compiled by Delphi only: Lazarus builds with FPC's own unit.
  Changed, by kind:
  - strings are Delphi's UTF-16 string (TJSONStringType = string, TJSONCharType = Char), and QWord
    is written UInt64;
  - an object's members are kept by TJSONMemberList (in the implementation): in order, by names
    of any length, in place of contnrs' TFPHashObjectList (names of at most 255 bytes); an
    array's elements by System.Contnrs' TObjectList, sorted with FPC's QuickSort; the field
    that holds the member table is declared TObject and cast in one place, MemberList;
  - the overload directives FPC's objfpc mode does without are added; a property's index
    parameter repeats its accessors' const; the UnicodeString overloads that would duplicate the
    string ones are left out; procedure variables are tested with Assigned; HexStr is IntToHex,
    StrToQWord is StrToUInt64, and a UInt64 is printed with UIntToStr (Delphi's IntToStr takes
    it for an Int64); array of const takes Delphi's kinds of string and character as well;
    AsUnicodeString converts nothing;
  - JSONStringToString walks the string with PChar, not PAnsiChar; \u escapes: each escape is
    one code unit, appended as it is (an unpaired surrogate is kept; \u0000 is a #0, where FPC's
    drops it); FPC 3.2.2 keeps an escape pending, encodes it to UTF-8 together with the next
    escape, and appends the pending one a second time, so it damages valid text and drops
    unpaired surrogates (a deliberate difference: the port does not copy that defect; its
    MaybeAppendUnicode and U1 are kept only to stay line-comparable with FPC's);
  - bytes become text through tyfclutf8's TyFclUtf8Decode only: GetJSON(TStream) without a
    stream parser handler reads the stream with it (and returns nil, as FPC's does); FPC keeps
    the raw bytes in its byte string, the port has UTF-16 strings and replaces an invalid
    sequence by U+FFFD (a deliberate difference: it never raises on invalid bytes);
    GetJSON(string) without a string parser handler hands the stream handler the text's UTF-8
    bytes (TStringStream with TEncoding.UTF8; FPC's string already holds them);
  - DumpJSON writes UTF-8, as FPC's does, not the bytes of the UTF-16 string; an unpaired
    surrogate the port keeps is written as the encoder's replacement character (EF BF BD),
    whereas AsJSON keeps the unit;
  - floating-point numbers and text are converted by tyfclnum (TyFclTextToFloat for Val,
    TyFclLocaleTextToFloat for TryStrToFloat, TyFclFloatToText for Str, TyFclFloatToStr for
    FloatToStr);
  - the branches for PAS2JS and for other FPC versions are removed, and so is the include of
    fcl-json.inc (its mode switch, a define these units do not test and a warning switch are
    FPC's only).
  The original's licence applies, see the notice above (THIRD-PARTY-NOTICES.md says more). }
unit fpjson;

interface

uses
  variants,
  SysUtils,
  classes,
  System.Contnrs;

type
  TJSONtype = (jtUnknown, jtNumber, jtString, jtBoolean, jtNull, jtArray, jtObject);
  TJSONInstanceType = (
    jitUnknown,
    jitNumberInteger,
    jitNumberInt64,
    jitNumberQWord,
    jitNumberFloat,
    jitString,
    jitBoolean,
    jitNull,
    jitArray,
    jitObject);
  TJSONFloat = Double;
  TJSONStringType = string;
  TJSONUnicodeStringType = Unicodestring;
  TJSONCharType = Char;
  PJSONCharType = ^TJSONCharType;
  TJSONVariant = variant;
  TFPJSStream = TMemoryStream;
  TJSONLargeInt = Int64;
  TFormatOption = (foSingleLineArray,   // Array without CR/LF : all on one line
                   foSingleLineObject,  // Object without CR/LF : all on one line
                   foDoNotQuoteMembers, // Do not quote object member names.
                   foUseTabchar,        // Use tab characters instead of spaces.
                   foSkipWhiteSpace,    // Do not use whitespace at all
                   foSkipWhiteSpaceOnlyLeading   //  When foSkipWhiteSpace is active, skip whitespace for object members only before :
                   );
  TFormatOptions = set of TFormatOption;

Const
  DefaultIndentSize = 2;
  DefaultFormat     = [];
  AsJSONFormat      = [foSingleLineArray,foSingleLineObject]; // These options make FormatJSON behave as AsJSON
  AsCompressedJSON  = [foSingleLineArray,foSingleLineObject,foskipWhiteSpace]; // These options make FormatJSON behave as AsJSON with TJSONData.CompressedJSON=True
  AsCompactJSON     = [foSingleLineArray,foSingleLineObject,foskipWhiteSpace,foDoNotQuoteMembers]; // These options make FormatJSON behave as AsJSON with TJSONData.CompressedJSON=True and TJSONObject.UnquotedMemberNames=True
  ValueJSONTypes    = [jtNumber, jtString, jtBoolean, jtNull];
  ActualValueJSONTypes = ValueJSONTypes - [jtNull];
  StructuredJSONTypes  = [jtArray,jtObject];
  jitNumberLargeInt = jitNumberInt64;

Type
  TJSONData = Class;

  { TBaseJSONEnumerator }

  TJSONEnum = Record
    Key : TJSONStringType;
    KeyNum : Integer;
    Value : TJSONData;
  end;

  TBaseJSONEnumerator = class
  public
    function GetCurrent: TJSONEnum; virtual; abstract;
    function MoveNext : Boolean; virtual; abstract;
    property Current: TJSONEnum read GetCurrent;
  end;

  { TJSONData }
  
  TJSONData = class(TObject)
  private
    Const
      ElementSeps  : Array[Boolean] of TJSONStringType = (', ',',');
    Class Var FCompressedJSON : Boolean;
    Class Var FElementSep : TJSONStringType;
    class procedure DetermineElementSeparators;
    class function GetCompressedJSON: Boolean; static;
    class procedure SetCompressedJSON(AValue: Boolean); static;
  protected
    Class Procedure DoError(Const Msg : String); overload;
    Class Procedure DoError(Const Fmt : String; const Args : Array of Const); overload;
    Function DoFindPath(Const APath : TJSONStringType; Out NotFound : TJSONStringType) : TJSONdata; virtual;
    function GetAsBoolean: Boolean; virtual; abstract;
    function GetAsFloat: TJSONFloat; virtual; abstract;
    function GetAsInteger: Integer; virtual; abstract;
    function GetIsNull: Boolean; virtual;
    function GetAsInt64: Int64; virtual; abstract;
    function GetAsQWord: UInt64; virtual; abstract;
    function GetAsUnicodeString: TJSONUnicodeStringType; virtual;
    procedure SetAsInt64(const AValue: Int64); virtual; abstract;
    procedure SetAsQword(const AValue: UInt64); virtual; abstract;
    procedure SetAsUnicodeString(const AValue: TJSONUnicodeStringType); virtual;
    procedure SetAsBoolean(const AValue: Boolean); virtual; abstract;
    procedure SetAsFloat(const AValue: TJSONFloat); virtual; abstract;
    procedure SetAsInteger(const AValue: Integer); virtual; abstract;
    function GetAsJSON: TJSONStringType; virtual; abstract;
    function GetAsString: TJSONStringType; virtual; abstract;
    procedure SetAsString(const AValue: TJSONStringType); virtual; abstract;
    function GetValue: TJSONVariant; virtual; abstract;
    procedure SetValue(const AValue: TJSONVariant); virtual; abstract;
    function GetItem(Index : Integer): TJSONData; virtual;
    procedure SetItem(Index : Integer; const AValue: TJSONData); virtual;
    Function DoFormatJSON(Options : TFormatOptions; CurrentIndent, Indent : Integer) : TJSONStringType; virtual;
    function GetCount: Integer; virtual;
  Public
    Class function JSONType: TJSONType; virtual;
    Class Property CompressedJSON : Boolean Read GetCompressedJSON Write SetCompressedJSON;
  public
    Constructor Create; virtual;
    Procedure Clear;  virtual; Abstract;
    Procedure DumpJSON(S : TFPJSStream);
    // Get enumerator
    function GetEnumerator: TBaseJSONEnumerator; virtual;
    Function FindPath(Const APath : TJSONStringType) : TJSONdata;
    Function GetPath(Const APath : TJSONStringType) : TJSONdata;
    Function Clone : TJSONData; virtual; abstract;
    Function FormatJSON(Options : TFormatOptions = DefaultFormat; Indentsize : Integer = DefaultIndentSize) : TJSONStringType; 
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TJSONData read GetItem write SetItem;
    property Value: TJSONVariant read GetValue write SetValue;
    Property AsString : TJSONStringType Read GetAsString Write SetAsString;
    Property AsUnicodeString : TJSONUnicodeStringType Read GetAsUnicodeString Write SetAsUnicodeString;
    Property AsInt64 : Int64 Read GetAsInt64 Write SetAsInt64;
    Property AsQWord : UInt64 Read GetAsQWord Write SetAsQword;
    Property AsLargeInt : TJSONLargeInt Read GetAsInt64 Write SetAsInt64;
    Property AsFloat : TJSONFloat Read GetAsFloat Write SetAsFloat;
    Property AsInteger : Integer Read GetAsInteger Write SetAsInteger;
    Property AsBoolean : Boolean Read GetAsBoolean Write SetAsBoolean;
    Property IsNull : Boolean Read GetIsNull;
    Property AsJSON : TJSONStringType Read GetAsJSON;
  end;

  TJSONDataClass = Class of TJSONData;
  TJSONNumberType = (
    ntFloat,
    ntInteger
    ,ntInt64
    ,ntQWord
    );

  TJSONNumber = class(TJSONData)
  protected
  public
    class function JSONType: TJSONType; override;
    class function NumberType : TJSONNumberType; virtual; abstract;
  end;

  { TJSONFloatNumber }

  TJSONFloatNumber = class(TJSONNumber)
  Private
    FValue : TJSONFloat;
  protected
    function GetAsBoolean: Boolean; override;
    function GetAsFloat: TJSONFloat; override;
    function GetAsInteger: Integer; override;
    function GetAsJSON: TJSONStringType; override;
    function GetAsString: TJSONStringType; override;
    function GetValue: TJSONVariant; override;
    function GetAsInt64: Int64; override;
    function GetAsQWord: UInt64; override;
    procedure SetAsInt64(const AValue: Int64); override;
    procedure SetAsQword(const AValue: UInt64); override;
    procedure SetAsBoolean(const AValue: Boolean); override;
    procedure SetAsFloat(const AValue: TJSONFloat); override;
    procedure SetAsInteger(const AValue: Integer); override;
    procedure SetAsString(const AValue: TJSONStringType); override;
    procedure SetValue(const AValue: TJSONVariant); override;
  public
    Constructor Create(AValue : TJSONFloat); reintroduce;
    class function NumberType : TJSONNumberType; override;
    Procedure Clear;  override;
    Function Clone : TJSONData; override;
  end;
  TJSONFloatNumberClass = Class of TJSONFloatNumber;

  { TJSONIntegerNumber }

  TJSONIntegerNumber = class(TJSONNumber)
  Private
    FValue : Integer;
  protected
    function GetAsBoolean: Boolean; override;
    function GetAsFloat: TJSONFloat; override;
    function GetAsInteger: Integer; override;
    function GetAsInt64: Int64; override;
    function GetAsQWord: UInt64; override;
    procedure SetAsInt64(const AValue: Int64); override;
    procedure SetAsQword(const AValue: UInt64); override;
    procedure SetAsBoolean(const AValue: Boolean); override;
    procedure SetAsFloat(const AValue: TJSONFloat); override;
    procedure SetAsInteger(const AValue: Integer); override;
    function GetAsJSON: TJSONStringType; override;
    function GetAsString: TJSONStringType; override;
    procedure SetAsString(const AValue: TJSONStringType); override;
    function GetValue: TJSONVariant; override;
    procedure SetValue(const AValue: TJSONVariant); override;
  public
    Constructor Create(AValue : Integer); reintroduce;
    class function NumberType : TJSONNumberType; override;
    Procedure Clear;  override;
    Function Clone : TJSONData; override;
  end;
  TJSONIntegerNumberClass = Class of TJSONIntegerNumber;

  { TJSONInt64Number }

  TJSONInt64Number = class(TJSONNumber)
  Private
    FValue : Int64;
  protected
    function GetAsBoolean: Boolean; override;
    function GetAsFloat: TJSONFloat; override;
    function GetAsInteger: Integer; override;
    function GetAsInt64: Int64; override;
    function GetAsQWord: UInt64; override;
    procedure SetAsBoolean(const AValue: Boolean); override;
    procedure SetAsFloat(const AValue: TJSONFloat); override;
    procedure SetAsInteger(const AValue: Integer); override;
    procedure SetAsInt64(const AValue: Int64); override;
    procedure SetAsQword(const AValue: UInt64); override;
    function GetAsJSON: TJSONStringType; override;
    function GetAsString: TJSONStringType; override;
    procedure SetAsString(const AValue: TJSONStringType); override;
    function GetValue: TJSONVariant; override;
    procedure SetValue(const AValue: TJSONVariant); override;
  public
    Constructor Create(AValue : Int64); reintroduce;
    class function NumberType : TJSONNumberType; override;
    Procedure Clear;  override;
    Function Clone : TJSONData; override;
  end;
  TJSONInt64NumberClass = Class of TJSONInt64Number;

  TJSONLargeIntNumber = TJSONInt64Number;
  TJSONLargeIntNumberClass = TJSONInt64NumberClass;

  { TJSONQWordNumber }

  TJSONQWordNumber = class(TJSONNumber)
  Private
    FValue : UInt64;
  protected
    function GetAsBoolean: Boolean; override;
    function GetAsFloat: TJSONFloat; override;
    function GetAsInteger: Integer; override;
    function GetAsInt64: Int64; override;
    function GetAsQWord: UInt64; override;
    procedure SetAsBoolean(const AValue: Boolean); override;
    procedure SetAsFloat(const AValue: TJSONFloat); override;
    procedure SetAsInteger(const AValue: Integer); override;
    procedure SetAsInt64(const AValue: Int64); override;
    procedure SetAsQword(const AValue: UInt64); override;
    function GetAsJSON: TJSONStringType; override;
    function GetAsString: TJSONStringType; override;
    procedure SetAsString(const AValue: TJSONStringType); override;
    function GetValue: TJSONVariant; override;
    procedure SetValue(const AValue: TJSONVariant); override;
  public
    Constructor Create(AValue : UInt64); reintroduce;
    class function NumberType : TJSONNumberType; override;
    Procedure Clear;  override;
    Function Clone : TJSONData; override;
  end;
  TJSONQWordNumberClass = Class of TJSONQWordNumber;

  { TJSONString }

  TJSONString = class(TJSONData)
  Private
    FValue: TJSONStringType;
  protected
    function GetValue: TJSONVariant; override;
    procedure SetValue(const AValue: TJSONVariant); override;
    function GetAsBoolean: Boolean; override;
    function GetAsFloat: TJSONFloat; override;
    function GetAsInteger: Integer; override;
    function GetAsInt64: Int64; override;
    function GetAsQWord: UInt64; override;
    procedure SetAsInt64(const AValue: Int64); override;
    procedure SetAsQword(const AValue: UInt64); override;
    procedure SetAsBoolean(const AValue: Boolean); override;
    procedure SetAsFloat(const AValue: TJSONFloat); override;
    procedure SetAsInteger(const AValue: Integer); override;
    function GetAsJSON: TJSONStringType; override;
    function GetAsString: TJSONStringType; override;
    procedure SetAsString(const AValue: TJSONStringType); override;
  Public
    Class var StrictEscaping : Boolean;
  public
    Constructor Create(const AValue : TJSONStringType); reintroduce;
    class function JSONType: TJSONType; override;
    Procedure Clear;  override;
    Function Clone : TJSONData; override;
  end;
  TJSONStringClass = Class of TJSONString;

  { TJSONBoolean }

  TJSONBoolean = class(TJSONData)
  Private
    FValue: Boolean;
  protected
    function GetValue: TJSONVariant; override;
    procedure SetValue(const AValue: TJSONVariant); override;
    function GetAsBoolean: Boolean; override;
    function GetAsFloat: TJSONFloat; override;
    function GetAsInteger: Integer; override;
    function GetAsInt64: Int64; override;
    function GetAsQWord: UInt64; override;
    procedure SetAsInt64(const AValue: Int64); override;
    procedure SetAsQword(const AValue: UInt64); override;
    procedure SetAsBoolean(const AValue: Boolean); override;
    procedure SetAsFloat(const AValue: TJSONFloat); override;
    procedure SetAsInteger(const AValue: Integer); override;
    function GetAsJSON: TJSONStringType; override;
    function GetAsString: TJSONStringType; override;
    procedure SetAsString(const AValue: TJSONStringType); override;
  public
    Constructor Create(AValue : Boolean); reintroduce;
    class function JSONType: TJSONType; override;
    Procedure Clear;  override;
    Function  Clone : TJSONData; override;
  end;
  TJSONBooleanClass = Class of TJSONBoolean;

  { TJSONnull }

  TJSONNull = class(TJSONData)
  protected
    Procedure Converterror(From : Boolean);
    function GetAsBoolean: Boolean; override;
    function GetAsFloat: TJSONFloat; override;
    function GetAsInteger: Integer; override;
    function GetIsNull: Boolean; override;
    function GetAsJSON: TJSONStringType; override;
    function GetAsString: TJSONStringType; override;
    function GetValue: TJSONVariant; override;
    function GetAsInt64: Int64; override;
    function GetAsQWord: UInt64; override;
    procedure SetAsInt64(const AValue: Int64); override;
    procedure SetAsQword(const AValue: UInt64); override;
    procedure SetAsBoolean(const AValue: Boolean); override;
    procedure SetAsFloat(const AValue: TJSONFloat); override;
    procedure SetAsInteger(const AValue: Integer); override;
    procedure SetAsString(const AValue: TJSONStringType); override;
    procedure SetValue(const AValue: TJSONVariant); override;
  public
    class function JSONType: TJSONType; override;
    Procedure Clear;  override;
    Function Clone : TJSONData; override;
  end;
  TJSONNullClass = Class of TJSONNull;

  TJSONArrayIterator = procedure(Item: TJSONData; Data: TObject; var Continue: Boolean) of object;

  { TJSONArray }
  TJSONObject = Class;

  TJSONArray = class(TJSONData)
  Private
    FList : TObjectList;
    function GetArrays(Index : Integer): TJSONArray;
    function GetBooleans(Index : Integer): Boolean;
    function GetFloats(Index : Integer): TJSONFloat;
    function GetIntegers(Index : Integer): Integer;
    function GetNulls(Index : Integer): Boolean;
    function GetObjects(Index : Integer): TJSONObject;
    function GetStrings(Index : Integer): TJSONStringType;
    function GetTypes(Index : Integer): TJSONType;
    function GetInt64s(Index : Integer): Int64;
    function GetQWords(Index : Integer): UInt64;
    function GetUnicodeStrings(Index : Integer): TJSONUnicodeStringType;
    procedure SetInt64s(Index : Integer; const AValue: Int64);
    procedure SetQWords(Index : Integer; AValue: UInt64);
    procedure SetUnicodeStrings(Index : Integer; const AValue: TJSONUnicodeStringType);
    procedure SetArrays(Index : Integer; const AValue: TJSONArray);
    procedure SetBooleans(Index : Integer; const AValue: Boolean);
    procedure SetFloats(Index : Integer; const AValue: TJSONFloat);
    procedure SetIntegers(Index : Integer; const AValue: Integer);
    procedure SetObjects(Index : Integer; const AValue: TJSONObject);
    procedure SetStrings(Index : Integer; const AValue: TJSONStringType);
  protected
    Function DoFindPath(Const APath : TJSONStringType; Out NotFound : TJSONStringType) : TJSONdata; override;
    Procedure Converterror(From : Boolean);
    function GetAsBoolean: Boolean; override;
    function GetAsFloat: TJSONFloat; override;
    function GetAsInteger: Integer; override;
    function GetAsInt64: Int64; override;
    function GetAsQWord: UInt64; override;
    procedure SetAsInt64(const AValue: Int64); override;
    procedure SetAsQword(const AValue: UInt64); override;
    procedure SetAsBoolean(const AValue: Boolean); override;
    procedure SetAsFloat(const AValue: TJSONFloat); override;
    procedure SetAsInteger(const AValue: Integer); override;
    function GetAsJSON: TJSONStringType; override;
    function GetAsString: TJSONStringType; override;
    procedure SetAsString(const AValue: TJSONStringType); override;
    function GetValue: TJSONVariant; override;
    procedure SetValue(const AValue: TJSONVariant); override;
    function GetCount: Integer; override;
    function GetItem(Index : Integer): TJSONData; override;
    procedure SetItem(Index : Integer; const AValue: TJSONData); override;
    Function DoFormatJSON(Options : TFormatOptions; CurrentIndent, Indent : Integer) : TJSONStringType; override;
  public
    Constructor Create; reintroduce; overload;
    Constructor Create(const Elements : Array of Const); overload;
    Destructor Destroy; override;
    class function JSONType: TJSONType; override;
    Function Clone : TJSONData; override;
    // Examine
    procedure Iterate(Iterator : TJSONArrayIterator; Data: TObject);
    function IndexOf(obj: TJSONData): Integer;
    function GetEnumerator: TBaseJSONEnumerator; override;
    // Manipulate
    Procedure Clear;  override;
    function Add(Item : TJSONData): Integer; overload;
    function Add(I : Integer): Integer; overload;
    function Add(I : Int64): Int64; overload;
    function Add(I : UInt64): UInt64; overload;
    function Add(const S : String): Integer; overload;
    function Add: Integer; overload;
    function Add(F : TJSONFloat): Integer; overload;
    function Add(B : Boolean): Integer; overload;
    function Add(AnArray : TJSONArray): Integer; overload;
    function Add(AnObject: TJSONObject): Integer; overload;
    Procedure Delete(Index : Integer);
    procedure Exchange(Index1, Index2: Integer);
    function Extract(Item: TJSONData): TJSONData; overload;
    function Extract(Index : Integer): TJSONData; overload;
    procedure Insert(Index: Integer); overload;
    procedure Insert(Index: Integer; Item : TJSONData); overload;
    procedure Insert(Index: Integer; I : Integer); overload;
    procedure Insert(Index: Integer; I : Int64); overload;
    procedure Insert(Index: Integer; I : UInt64); overload;
    procedure Insert(Index: Integer; const S : String); overload;
    procedure Insert(Index: Integer; F : TJSONFloat); overload;
    procedure Insert(Index: Integer; B : Boolean); overload;
    procedure Insert(Index: Integer; AnArray : TJSONArray); overload;
    procedure Insert(Index: Integer; AnObject: TJSONObject); overload;
    procedure Move(CurIndex, NewIndex: Integer);
    Procedure Remove(Item : TJSONData);
    Procedure Sort(Compare: TListSortCompare);
    // Easy Access Properties.
    property Items;default;
    Property Types[Index : Integer] : TJSONType Read GetTypes;
    Property Nulls[Index : Integer] : Boolean Read GetNulls;
    Property Integers[Index : Integer] : Integer Read GetIntegers Write SetIntegers;
    Property Int64s[Index : Integer] : Int64 Read GetInt64s Write SetInt64s;
    Property LargeInts[Index : Integer] : TJSONLargeInt Read GetInt64s Write SetInt64s;
    Property QWords[Index : Integer] : UInt64 Read GetQWords Write SetQWords;
    Property UnicodeStrings[Index : Integer] : TJSONUnicodeStringType Read GetUnicodeStrings Write SetUnicodeStrings;
    Property Strings[Index : Integer] : TJSONStringType Read GetStrings Write SetStrings;
    Property Floats[Index : Integer] : TJSONFloat Read GetFloats Write SetFloats;
    Property Booleans[Index : Integer] : Boolean Read GetBooleans Write SetBooleans;
    Property Arrays[Index : Integer] : TJSONArray Read GetArrays Write SetArrays;
    Property Objects[Index : Integer] : TJSONObject Read GetObjects Write SetObjects;
  end;
  TJSONArrayClass = Class of TJSONArray;

  TJSONObjectIterator = procedure(Const AName : TJSONStringType; Item: TJSONData; Data: TObject; var Continue: Boolean) of object;

  { TJSONObject }

  TJSONObject = class(TJSONData)
  private
    Const
      ElementStart   : Array[Boolean] of TJSONStringType = ('"','');
      SpacedQuoted   : Array[Boolean] of TJSONStringType = ('" : ',' : ');
      UnSpacedQuoted : Array[Boolean] of TJSONStringType = ('":',':');
      ObjStartSeps   : Array[Boolean] of TJSONStringType = ('{ ','{');
      ObjEndSeps     : Array[Boolean] of TJSONStringType = (' }','}');
    Class var FUnquotedMemberNames: Boolean;
    Class var FObjStartSep,FObjEndSep,FElementEnd,FElementStart : TJSONStringType;
    function DoAdd(const AName: TJSONStringType; AValue: TJSONData; FreeOnError: Boolean=True): Integer;
    Class procedure DetermineElementQuotes;
  Private
    FHash : TObject; // A TJSONMemberList, see the implementation
    function GetArrays(const AName : String): TJSONArray;
    function GetBooleans(const AName : String): Boolean;
    function GetElements(const AName: string): TJSONData;
    function GetFloats(const AName : String): TJSONFloat;
    function GetIntegers(const AName : String): Integer;
    function GetIsNull(const AName : String): Boolean; reintroduce;
    function GetNameOf(Index : Integer): TJSONStringType;
    function GetObjects(const AName : String): TJSONObject;
    function GetStrings(const AName : String): TJSONStringType;
    function GetTypes(const AName : String): TJSONType;
    procedure SetArrays(const AName : String; const AValue: TJSONArray);
    procedure SetBooleans(const AName : String; const AValue: Boolean);
    procedure SetElements(const AName: string; const AValue: TJSONData);
    procedure SetFloats(const AName : String; const AValue: TJSONFloat);
    procedure SetIntegers(const AName : String; const AValue: Integer);
    function GetInt64s(const AName : String): Int64;
    function GetUnicodeStrings(const AName : String): TJSONUnicodeStringType;
    function GetQWords(AName : String): UInt64;
    procedure SetInt64s(const AName : String; const AValue: Int64);
    procedure SetQWords(AName : String; AValue: UInt64);
    procedure SetUnicodeStrings(const AName : String; const AValue: TJSONUnicodeStringType);
    procedure SetIsNull(const AName : String; const AValue: Boolean);
    procedure SetObjects(const AName : String; const AValue: TJSONObject);
    procedure SetStrings(const AName : String; const AValue: TJSONStringType);
    class function GetUnquotedMemberNames: Boolean; static;
    class procedure SetUnquotedMemberNames(AValue: Boolean); static;
  protected
    Function DoFindPath(Const APath : TJSONStringType; Out NotFound : TJSONStringType) : TJSONdata; override;
    Procedure Converterror(From : Boolean);
    function GetAsBoolean: Boolean; override;
    function GetAsFloat: TJSONFloat; override;
    function GetAsInteger: Integer; override;
    function GetAsInt64: Int64; override;
    function GetAsQWord: UInt64; override;
    procedure SetAsInt64(const AValue: Int64); override;
    procedure SetAsQword(const AValue: UInt64); override;
    procedure SetAsBoolean(const AValue: Boolean); override;
    procedure SetAsFloat(const AValue: TJSONFloat); override;
    procedure SetAsInteger(const AValue: Integer); override;
    function GetAsJSON: TJSONStringType; override;
    function GetAsString: TJSONStringType; override;
    procedure SetAsString(const AValue: TJSONStringType); override;
    function GetValue: TJSONVariant; override;
    procedure SetValue(const AValue: TJSONVariant); override;
    function GetCount: Integer; override;
    function GetItem(Index : Integer): TJSONData; override;
    procedure SetItem(Index : Integer; const AValue: TJSONData); override;
    Function DoFormatJSON(Options : TFormatOptions; CurrentIndent, Indent : Integer) : TJSONStringType; override;
  public
    constructor Create; reintroduce; overload;
    Constructor Create(const Elements : Array of Const); overload;
    destructor Destroy; override;
    class function JSONType: TJSONType; override;
    Class Property UnquotedMemberNames : Boolean Read GetUnquotedMemberNames Write SetUnquotedMemberNames;
    Function Clone : TJSONData; override;
    function GetEnumerator: TBaseJSONEnumerator; override;
    // Examine
    procedure Iterate(Iterator : TJSONObjectIterator; Data: TObject);
    function IndexOf(Item: TJSONData): Integer;
    Function IndexOfName(const AName: TJSONStringType; CaseInsensitive : Boolean = False): Integer;
    Function Find(Const AName : String) : TJSONData; overload;
    Function Find(Const AName : String; AType : TJSONType) : TJSONData; overload;
    function Find(const key: TJSONStringType; out AValue: TJSONData): boolean; overload;
    function Find(const key: TJSONStringType; out AValue: TJSONObject): boolean; overload;
    function Find(const key: TJSONStringType; out AValue: TJSONArray): boolean; overload;
    function Find(const key: TJSONStringType; out AValue: TJSONString): boolean; overload;
    function Find(const key: TJSONStringType; out AValue: TJSONBoolean): boolean; overload;
    function Find(const key: TJSONStringType; out AValue: TJSONNumber): boolean; overload;
    Function Get(Const AName : String) : TJSONVariant; overload;
    Function Get(Const AName : String; ADefault : TJSONFloat) : TJSONFloat; overload;
    Function Get(Const AName : String; ADefault : Integer) : Integer; overload;
    Function Get(Const AName : String; ADefault : Int64) : Int64; overload;
    Function Get(Const AName : String; ADefault : UInt64) : UInt64; overload;
    Function Get(Const AName : String; ADefault : Boolean) : Boolean; overload;
    Function Get(Const AName : String; ADefault : TJSONStringType) : TJSONStringType; overload;
    Function Get(Const AName : String; ADefault : TJSONArray) : TJSONArray; overload;
    Function Get(Const AName : String; ADefault : TJSONObject) : TJSONObject; overload;
    // Manipulate
    Procedure Clear;  override;
    function Add(const AName: TJSONStringType; AValue: TJSONData): Integer; overload;
    function Add(const AName: TJSONStringType; AValue: Boolean): Integer; overload;
    function Add(const AName: TJSONStringType; AValue: TJSONFloat): Integer; overload;
    function Add(const AName, AValue: TJSONStringType): Integer; overload;
    function Add(const AName: TJSONStringType; Avalue: Int64): Integer; overload;
    function Add(const AName: TJSONStringType; Avalue: UInt64): Integer; overload;
    function Add(const AName: TJSONStringType; Avalue: Integer): Integer; overload;
    function Add(const AName: TJSONStringType): Integer; overload;
    function Add(const AName: TJSONStringType; AValue : TJSONArray): Integer; overload;
    procedure Delete(Index : Integer); overload;
    procedure Delete(Const AName : string); overload;
    procedure Remove(Item : TJSONData);
    Function Extract(Index : Integer) : TJSONData; overload;
    Function Extract(Const AName : string) : TJSONData; overload;
    // Easy access properties.
    property Names[Index : Integer] : TJSONStringType read GetNameOf;
    property Elements[const AName: string] : TJSONData read GetElements write SetElements; default;

    Property Types[const AName : String] : TJSONType Read GetTypes;
    Property Nulls[const AName : String] : Boolean Read GetIsNull Write SetIsNull;
    Property Floats[const AName : String] : TJSONFloat Read GetFloats Write SetFloats;
    Property Integers[const AName : String] : Integer Read GetIntegers Write SetIntegers;
    Property Int64s[const AName : String] : Int64 Read GetInt64s Write SetInt64s;
    Property QWords[AName : String] : UInt64 Read GetQWords Write SetQWords;
    Property LargeInts[const AName : String] : TJSONLargeInt Read GetInt64s Write SetInt64s;
    Property UnicodeStrings[const AName : String] : TJSONUnicodeStringType Read GetUnicodeStrings Write SetUnicodeStrings;
    Property Strings[const AName : String] : TJSONStringType Read GetStrings Write SetStrings;
    Property Booleans[const AName : String] : Boolean Read GetBooleans Write SetBooleans;
    Property Arrays[const AName : String] : TJSONArray Read GetArrays Write SetArrays;
    Property Objects[const AName : String] : TJSONObject Read GetObjects Write SetObjects;
  end;
  TJSONObjectClass = Class of TJSONObject;

  EJSON = Class(Exception);

  TJSONParserHandler = Procedure(AStream : TStream; Const AUseUTF8 : Boolean; Out Data : TJSONData);
  TJSONStringParserHandler = Procedure(Const aJSON : TJSONStringType; Const AUseUTF8 : Boolean; Out Data : TJSONData);

Function SetJSONInstanceType(AType : TJSONInstanceType; AClass : TJSONDataClass) : TJSONDataClass;
Function GetJSONInstanceType(AType : TJSONInstanceType) : TJSONDataClass;

Function StringToJSONString(const S : TJSONStringType; Strict : Boolean = False) : TJSONStringType;
Function JSONStringToString(const S : TJSONStringType) : TJSONStringType;
Function JSONTypeName(JSONType : TJSONType) : String;

// These functions create JSONData structures, taking into account the instance types
Function CreateJSON : TJSONNull; overload;
Function CreateJSON(Data : Boolean) : TJSONBoolean; overload;
Function CreateJSON(Data : Integer) : TJSONIntegerNumber; overload;
Function CreateJSON(Data : Int64) : TJSONInt64Number; overload;
Function CreateJSON(Data : UInt64) : TJSONQWordNumber; overload;
Function CreateJSON(Data : TJSONFloat) : TJSONFloatNumber; overload;
Function CreateJSON(const Data : TJSONStringType) : TJSONString; overload;
Function CreateJSONArray(const Data : Array of Const) : TJSONArray;
Function CreateJSONObject(const Data : Array of Const) : TJSONObject;

// These functions rely on a callback. If the callback is not set, they will raise an error.
// When the jsonparser unit is included in the project, the callback is automatically set.
Function GetJSON(Const JSON : TJSONStringType; Const UseUTF8 : Boolean = True) : TJSONData; overload;
Function GetJSON(Const JSON : TStream; Const UseUTF8 : Boolean = True) : TJSONData; overload;
Function SetJSONParserHandler(AHandler : TJSONParserHandler) : TJSONParserHandler;
Function SetJSONStringParserHandler(AHandler : TJSONStringParserHandler) : TJSONStringParserHandler;
Function GetJSONParserHandler : TJSONParserHandler;
Function GetJSONStringParserHandler: TJSONStringParserHandler;

implementation

Uses typinfo, tyfclnum, tyfclutf8;

Resourcestring
  SErrCannotConvertFromNull = 'Cannot convert data from Null value';
  SErrCannotConvertToNull = 'Cannot convert data to Null value';
  SErrCannotConvertFromArray = 'Cannot convert data from array value';
  SErrCannotConvertToArray = 'Cannot convert data to array value';
  SErrCannotConvertFromObject = 'Cannot convert data from object value';
  SErrCannotConvertToObject = 'Cannot convert data to object value';
  SErrInvalidFloat = 'Invalid float value : %s';
  SErrCannotSetNotIsNull = 'IsNull cannot be set to False';
  SErrCannotAddArrayTwice = 'Adding an array object to an array twice is not allowed';
  SErrCannotAddObjectTwice = 'Adding an object to an array twice is not allowed';
  SErrUnknownTypeInConstructor = 'Unknown type in JSON%s constructor: %d';
  SErrNotJSONData = 'Cannot add object of type %s to TJSON%s';
  SErrOddNumber = 'TJSONObject must be constructed with name,value pairs';
  SErrNameMustBeString = 'TJSONObject constructor element name at pos %d is not a string';
  SErrNonexistentElement = 'Unknown object member: "%s"';
  SErrDuplicateValue = 'Duplicate object member: "%s"';
  SErrPathElementNotFound = 'Path "%s" invalid: element "%s" not found.';
  SErrWrongInstanceClass = 'Cannot set instance class: %s does not descend from %s.';
  SErrPointerNotNil = 'Cannot add non-nil pointer to JSON%s';
  SErrNoParserHandler = 'No JSON parser handler installed. Recompile your project with the jsonparser unit included';

Var
  DefaultJSONInstanceTypes :
    Array [TJSONInstanceType] of TJSONDataClass = (
      TJSONData,
      TJSONIntegerNumber,
      TJSONInt64Number,
      TJSONQWordNumber,
      TJSONFloatNumber,
      TJSONString,
      TJSONBoolean,
      TJSONNull,
      TJSONArray,
      TJSONObject);
Const
  MinJSONInstanceTypes :
    Array [TJSONInstanceType] of TJSONDataClass = (
      TJSONData,
      TJSONIntegerNumber,
      TJSONInt64Number,
      TJSONQWordNumber,
      TJSONFloatNumber,
      TJSONString,
      TJSONBoolean,
      TJSONNull,
      TJSONArray,
      TJSONObject
      );

function SetJSONInstanceType(AType: TJSONInstanceType; AClass: TJSONDataClass): TJSONDataClass;
begin
  if AClass=Nil then
    TJSONData.DoError(SErrWrongInstanceClass,['Nil',MinJSONInstanceTypes[AType].ClassName]);
  if Not AClass.InheritsFrom(MinJSONINstanceTypes[AType]) then
    TJSONData.DoError(SErrWrongInstanceClass,[AClass.ClassName,MinJSONInstanceTypes[AType].ClassName]);
  Result:=DefaultJSONInstanceTypes[AType];
  DefaultJSONINstanceTypes[AType]:=AClass;
end;

function GetJSONInstanceType(AType: TJSONInstanceType): TJSONDataClass;
begin
  Result:=DefaultJSONInstanceTypes[AType]
end;

function StringToJSONString(const S: TJSONStringType; Strict : Boolean = False): TJSONStringType;

Var
  I,J,L : Integer;
  C : Char;

begin
  I:=1;
  J:=1;
  Result:='';
  L:=Length(S);
  While I<=L do
    begin
    C:=S[I];
    if (C in ['"','/','\',#0..#31]) then
      begin
      Result:=Result+Copy(S,J,I-J);
      Case C of
        '\' : Result:=Result+'\\';
        '/' : if Strict then
                Result:=Result+'\/'
              else
                Result:=Result+'/';
        '"' : Result:=Result+'\"';
        #8  : Result:=Result+'\b';
        #9  : Result:=Result+'\t';
        #10 : Result:=Result+'\n';
        #12 : Result:=Result+'\f';
        #13 : Result:=Result+'\r';
      else
        Result:=Result+'\u'+IntToHex(Ord(C),4);
      end;
      J:=I+1;
      end;
    Inc(I);
    end;
  Result:=Result+Copy(S,J,I-1);
end;

function JSONStringToString(const S: TJSONStringType): TJSONStringType;


    function BufferHexToInt(P : PChar): integer;
    var
      N, i: integer;
      ch: Char;
    begin
      Result:= 0;
      for i:= 1 to 4 do
      begin
        ch:= p^;
        case ch of
          '0'..'9':
            N:= Ord(ch)-Ord('0');
          'a'..'f':
            N:= Ord(ch)-(Ord('a')-10);
          'A'..'F':
            N:= Ord(ch)-(Ord('A')-10);
          else
            exit(-1);
        end;
        Inc(P);
        Result:= Result*16+N;
      end;
    end;

Var

  I,J,L,U1,U2 : Integer;
  App : String;

  // Kept to stay line-comparable with FPC; U1 is never non-zero here.
  Procedure MaybeAppendUnicode;

  Var
    U : String;

  begin
    if (U1<>0) then
      begin
      U:=widechar(U1);
      Result:=Result+U;
      U1:=0;
      end;
  end;

begin
  I:=1;
  J:=1;
  L:=Length(S);
  Result:='';
  U1:=0;
  While (I<=L) do
    begin
    if (S[I]='\') then
      begin
      Result:=Result+Copy(S,J,I-J);
      If I<L then
        begin
        Inc(I);
        App:='';
        Case S[I] of
          '\','"','/'
              : App:=S[I];
          'b' : App:=#8;
          't' : App:=#9;
          'n' : App:=#10;
          'f' : App:=#12;
          'r' : App:=#13;
          'u' : begin
                U2:=BufferHexToInt(PChar(S)+I);
                if U2=-1 then
                   Raise EJSON.Create('Invalid unicode hex code: '+Copy(S,I+1,4));
                Inc(I,4);
                // Each escape is one code unit (U1 stays 0): FPC's pairs a pending escape
                // with the next one and appends the pending one twice.
                App:=WideChar(U2);
                end;
        end;
        if App<>'' then
          begin
          MaybeAppendUnicode;
          Result:=Result+App;
          end;
        end;
      J:=I+1;
      end
    else
      MaybeAppendUnicode;
    Inc(I);
    end;
  MaybeAppendUnicode;
  Result:=Result+Copy(S,J,I-J+1);
end;

function JSONTypeName(JSONType: TJSONType): String;
begin
  Result:=GetEnumName(TypeInfo(TJSONType),Ord(JSONType));
end;

function CreateJSON: TJSONNull;
begin
  Result:=TJSONNullClass(DefaultJSONInstanceTypes[jitNull]).Create
end;

function CreateJSON(Data: Boolean): TJSONBoolean;
begin
  Result:=TJSONBooleanClass(DefaultJSONInstanceTypes[jitBoolean]).Create(Data);
end;

function CreateJSON(Data: Integer): TJSONIntegerNumber;
begin
  Result:=TJSONIntegerNumberCLass(DefaultJSONInstanceTypes[jitNumberInteger]).Create(Data);
end;

function CreateJSON(Data: Int64): TJSONInt64Number;
begin
  Result:=TJSONInt64NumberCLass(DefaultJSONInstanceTypes[jitNumberInt64]).Create(Data);
end;

function CreateJSON(Data: UInt64): TJSONQWordNumber;
begin
  Result:=TJSONQWordNumberClass(DefaultJSONInstanceTypes[jitNumberQWord]).Create(Data);
end;

function CreateJSON(Data: TJSONFloat): TJSONFloatNumber;
begin
  Result:=TJSONFloatNumberCLass(DefaultJSONInstanceTypes[jitNumberFloat]).Create(Data);
end;

function CreateJSON(const Data: TJSONStringType): TJSONString;
begin
  Result:=TJSONStringCLass(DefaultJSONInstanceTypes[jitString]).Create(Data);
end;


function CreateJSONArray(const Data: array of Const): TJSONArray;
begin
  Result:=TJSONArrayCLass(DefaultJSONInstanceTypes[jitArray]).Create(Data);
end;

function CreateJSONObject(const Data: array of Const): TJSONObject;
begin
  Result:=TJSONObjectClass(DefaultJSONInstanceTypes[jitObject]).Create(Data);
end;

Var
  JPH : TJSONParserHandler;
  JPSH : TJSONStringParserHandler;

function GetJSON(const JSON: TJSONStringType; const UseUTF8: Boolean): TJSONData;

Var
  SS : TStringStream;
begin
  if Assigned(JPSH) then
    JPSH(JSON,UseUTF8,Result)
  else
    begin
      SS:=TStringStream.Create(JSON,TEncoding.UTF8);
    try
      Result:=GetJSON(SS,UseUTF8);
    finally
      SS.Free;
    end;
    end;
end;

function GetJSON(const JSON: TStream; const UseUTF8: Boolean): TJSONData;

Var
  S : TJSONStringType;
  B : TBytes;

begin
  Result:=Nil;
  If Assigned(JPH) then
    JPH(JSON,UseUTF8,Result)
  else if not Assigned(JPSH) then
    TJSONData.DoError(SErrNoParserHandler)
  else
    begin
    B:=nil;
    Setlength(B,JSON.Size);
    if Length(B)>0 then
      JSON.ReadBuffer(B[0],Length(B));
    S:=TyFclUtf8Decode(B);
    end;
end;


Function SetJSONStringParserHandler(AHandler : TJSONStringParserHandler) : TJSONStringParserHandler;
begin
  Result:=JPSH;
  JPSH:=AHandler;
end;

function SetJSONParserHandler(AHandler: TJSONParserHandler): TJSONParserHandler;
begin
  Result:=JPH;
  JPH:=AHandler;
end;

function GetJSONParserHandler: TJSONParserHandler;
begin
  Result:=JPH;
end;

function GetJSONStringParserHandler: TJSONStringParserHandler;
begin
  Result:=JPSH;
end;

Type
  { TJSONEnumerator }

  TJSONEnumerator = class(TBaseJSONEnumerator)
  Private
    FData : TJSONData;
  public
    Constructor Create(AData : TJSONData);
    function GetCurrent: TJSONEnum; override;
    function MoveNext : Boolean; override;
  end;

  { TJSONArrayEnumerator }

  TJSONArrayEnumerator = class(TBaseJSONEnumerator)
  Private
    FData : TJSONArray;
    FCurrent : Integer;
  public
    Constructor Create(AData : TJSONArray);
    function GetCurrent: TJSONEnum; override;
    function MoveNext : Boolean; override;
  end;

  { TJSONObjectEnumerator }

  TJSONObjectEnumerator = class(TBaseJSONEnumerator)
  Private
    FData : TJSONObject;
    FCurrent : Integer;
  public
    Constructor Create(AData : TJSONObject);
    function GetCurrent: TJSONEnum; override;
    function MoveNext : Boolean; override;
  end;

{ TJSONQWordNumber }

function TJSONQWordNumber.GetAsBoolean: Boolean;
begin
  Result:=FValue<>0;
end;

function TJSONQWordNumber.GetAsFloat: TJSONFloat;
begin
  Result:= FValue;
end;

function TJSONQWordNumber.GetAsInteger: Integer;
begin
  Result := FValue;
end;

function TJSONQWordNumber.GetAsInt64: Int64;
begin
  Result := FValue;
end;

function TJSONQWordNumber.GetAsQWord: UInt64;
begin
  Result := FValue;
end;

procedure TJSONQWordNumber.SetAsBoolean(const AValue: Boolean);
begin
  FValue:=Ord(AValue);
end;

procedure TJSONQWordNumber.SetAsFloat(const AValue: TJSONFloat);
begin
  FValue:=Round(AValue);
end;

procedure TJSONQWordNumber.SetAsInteger(const AValue: Integer);
begin
  FValue:=AValue;
end;

procedure TJSONQWordNumber.SetAsInt64(const AValue: Int64);
begin
  FValue := AValue;
end;

procedure TJSONQWordNumber.SetAsQword(const AValue: UInt64);
begin
  FValue:=AValue;
end;

function TJSONQWordNumber.GetAsJSON: TJSONStringType;
begin
  Result:=AsString;
end;

function TJSONQWordNumber.GetAsString: TJSONStringType;
begin
  Result:=UIntToStr(FValue);
end;

procedure TJSONQWordNumber.SetAsString(const AValue: TJSONStringType);
begin
  FValue:=StrToUInt64(AValue);
end;

function TJSONQWordNumber.GetValue: TJSONVariant;
begin
  Result:=FValue;
end;

procedure TJSONQWordNumber.SetValue(const AValue: TJSONVariant);
begin
  FValue:=AValue;
end;

constructor TJSONQWordNumber.Create(AValue: UInt64);
begin
  FValue := AValue;
end;

class function TJSONQWordNumber.NumberType: TJSONNumberType;
begin
  Result:=ntQWord;
end;

procedure TJSONQWordNumber.Clear;
begin
  FValue:=0;
end;

function TJSONQWordNumber.Clone: TJSONData;
begin
  Result:=TJSONQWordNumberClass(ClassType).Create(Self.FValue);
end;

{ TJSONObjectEnumerator }

constructor TJSONObjectEnumerator.Create(AData: TJSONObject);
begin
  FData:=AData;
  FCurrent:=-1;
end;

function TJSONObjectEnumerator.GetCurrent: TJSONEnum;
begin
  Result.KeyNum:=FCurrent;
  Result.Key:=FData.Names[FCurrent];
  Result.Value:=FData.Items[FCurrent];
end;

function TJSONObjectEnumerator.MoveNext: Boolean;
begin
  Inc(FCurrent);
  Result:=FCurrent<FData.Count;
end;

{ TJSONArrayEnumerator }

constructor TJSONArrayEnumerator.Create(AData: TJSONArray);
begin
  FData:=AData;
  FCurrent:=-1;
end;

function TJSONArrayEnumerator.GetCurrent: TJSONEnum;
begin
  Result.KeyNum:=FCurrent;
  Result.Key:=IntToStr(FCurrent);
  Result.Value:=FData.Items[FCurrent];
end;

function TJSONArrayEnumerator.MoveNext: Boolean;
begin
  Inc(FCurrent);
  Result:=FCurrent<FData.Count;
end;

  { TJSONEnumerator }

constructor TJSONEnumerator.Create(AData: TJSONData);
begin
  FData:=AData;
end;

function TJSONEnumerator.GetCurrent: TJSONEnum;
begin
  Result.Key:='';
  Result.KeyNum:=0;
  Result.Value:=FData;
  FData:=Nil;
end;

function TJSONEnumerator.MoveNext: Boolean;
begin
  Result:=FData<>Nil;
end;



{ TJSONData }

function TJSONData.GetAsUnicodeString: TJSONUnicodeStringType; 
begin
  Result:=AsString;
end;

procedure TJSONData.SetAsUnicodeString(const AValue: TJSONUnicodeStringType); 
begin
  AsString:=AValue;
end;

function TJSONData.GetItem(Index : Integer): TJSONData;
begin
  Result:=nil;
  if Index>0 then ;
end;

function TJSONData.GetCount: Integer;
begin
  Result:=0;
end;

constructor TJSONData.Create;
begin
  Clear;
end;

procedure TJSONData.DumpJSON(S: TFPJSStream);

  Procedure W(T : String);
  Var
    B : TBytes;
  begin
    if T='' then exit;
    B:=TEncoding.UTF8.GetBytes(T);
    S.WriteBuffer(B[0],Length(B));
  end;

Var
  I: Integer;
  O : TJSONObject;

begin
  Case JSONType of
    jtObject :
      begin
      O:=TJSONObject(Self);
      W('{');
      For I:=0 to O.Count-1 do
        begin
        if (I>0) then
          W(',');
        W('"');
        W(StringToJSONString(O.Names[i],False));
        W('":');
        O.Items[I].DumpJSON(S);
        end;
      W('}');
      end;
    jtArray :
      begin
      W('[');
      For I:=0 to Count-1 do
        begin
        if (I>0) then
          W(',');
        Items[I].DumpJSON(S);
        end;
      W(']');
      end
  else
    W(AsJSON)
  end;
end;

class function TJSONData.GetCompressedJSON: Boolean;
begin
  Result:=FCompressedJSON;
end;

class procedure TJSONData.DetermineElementSeparators;


begin
  FElementSep:=ElementSeps[FCompressedJSON];
end;

class procedure TJSONData.SetCompressedJSON(AValue: Boolean);


begin
  if AValue=FCompressedJSON then exit;
  FCompressedJSON:=AValue;
  DetermineElementSeparators;
  TJSONObject.DetermineElementQuotes;
end;

class procedure TJSONData.DoError(const Msg: String);
begin
  Raise EJSON.Create(Msg);
end;

class procedure TJSONData.DoError(const Fmt: String;
  const Args: array of Const);
begin
  Raise EJSON.CreateFmt(Fmt,Args);
end;

function TJSONData.DoFindPath(const APath: TJSONStringType; out
  NotFound: TJSONStringType): TJSONdata;
begin
  If APath<>'' then
    begin
    NotFound:=APath;
    Result:=Nil;
    end
  else
    Result:=Self;
end;

function TJSONData.GetIsNull: Boolean;
begin
  Result:=False;
end;

class function TJSONData.JSONType: TJSONType;
begin
  JSONType:=jtUnknown;
end;

function TJSONData.GetEnumerator: TBaseJSONEnumerator;
begin
  Result:=TJSONEnumerator.Create(Self);
end;

function TJSONData.FindPath(const APath: TJSONStringType): TJSONdata;

Var
  M : TJSONStringType;

begin
  Result:=DoFindPath(APath,M);
end;

function TJSONData.GetPath(const APath: TJSONStringType): TJSONdata;

Var
  M : TJSONStringType;
begin
  Result:=DoFindPath(APath,M);
  If Result=Nil then
    DoError(SErrPathElementNotFound,[APath,M]);
end;

procedure TJSONData.SetItem(Index : Integer; const AValue:
  TJSONData);
begin
  // Do Nothing
  if Index>0 then ;
  if AValue<>nil then ;
end;

function TJSONData.FormatJSON(Options: TFormatOptions; Indentsize: Integer
  ): TJSONStringType;

begin
  Result:=DoFormatJSON(Options,0,IndentSize);
end;

function TJSONData.DoFormatJSON(Options: TFormatOptions; CurrentIndent,
  Indent: Integer): TJSONStringType;

begin
  Result:=AsJSON;
  if Options=[] then ;
  if CurrentIndent=0 then ;
  if Indent>0 then ;
end;

{ TJSONnumber }

class function TJSONnumber.JSONType: TJSONType;
begin
  Result:=jtNumber;
end;


{ TJSONstring }

class function TJSONString.JSONType: TJSONType;
begin
  Result:=jtString;
end;

procedure TJSONString.Clear;
begin
  FValue:='';
end;

function TJSONString.Clone: TJSONData;

begin
  Result:=TJSONStringClass(ClassType).Create(Self.FValue);
end;

function TJSONString.GetValue: TJSONVariant;
begin
  Result:=FValue;
end;

procedure TJSONString.SetValue(const AValue: TJSONVariant);
begin
  FValue:=AValue;
end;


function TJSONString.GetAsBoolean: Boolean;
begin
  Result:=StrToBool(FValue);
end;

function TJSONString.GetAsFloat: TJSONFloat;

begin
  If Not TyFclTextToFloat(FValue,Result) then
    If Not TyFclLocaleTextToFloat(FValue,Result) then
      Raise EConvertError.CreateFmt(SErrInvalidFloat,[FValue]);
end;

function TJSONString.GetAsInteger: Integer;
begin
  Result:=StrToInt(FValue);
end;

function TJSONString.GetAsInt64: Int64;
begin
  Result:=StrToInt64(FValue);
end;

function TJSONString.GetAsQWord: UInt64;
begin
  Result:=StrToUInt64(FValue);
end;

procedure TJSONString.SetAsInt64(const AValue: Int64);
begin
  FValue:=IntToStr(AValue);
end;

procedure TJSONString.SetAsQword(const AValue: UInt64);
begin
  FValue:=UIntToStr(AValue);
end;


procedure TJSONString.SetAsBoolean(const AValue: Boolean);
begin
  FValue:=BoolToStr(AValue);
end;

procedure TJSONString.SetAsFloat(const AValue: TJSONFloat);
begin
  FValue:=TyFclFloatToStr(AValue);
end;

procedure TJSONString.SetAsInteger(const AValue: Integer);
begin
  FValue:=IntToStr(AValue);
end;

function TJSONString.GetAsJSON: TJSONStringType;
begin
  Result:='"'+StringToJSONString(FValue,StrictEscaping)+'"';
end;

function TJSONString.GetAsString: TJSONStringType;
begin
  Result:=FValue;
end;

procedure TJSONString.SetAsString(const AValue: TJSONStringType);
begin
  FValue:=AValue;
end;

constructor TJSONString.Create(const AValue: TJSONStringType);
begin
  FValue:=AValue;
end;


{ TJSONboolean }


function TJSONBoolean.GetValue: TJSONVariant;
begin
  Result:=FValue;
end;

class function TJSONBoolean.JSONType: TJSONType;
begin
  Result:=jtBoolean;
end;

procedure TJSONBoolean.Clear;
begin
  FValue:=False;
end;

function TJSONBoolean.Clone: TJSONData;
begin
  Result:=TJSONBooleanClass(Self.ClassType).Create(Self.Fvalue);
end;


procedure TJSONBoolean.SetValue(const AValue: TJSONVariant);
begin
  FValue:=boolean(AValue);
end;

function TJSONBoolean.GetAsBoolean: Boolean;
begin
  Result:=FValue;
end;

function TJSONBoolean.GetAsFloat: TJSONFloat;
begin
  Result:=Ord(FValue);
end;

function TJSONBoolean.GetAsInteger: Integer;
begin
  Result:=Ord(FValue);
end;

function TJSONBoolean.GetAsInt64: Int64;
begin
  Result:=Ord(FValue);
end;

function TJSONBoolean.GetAsQWord: UInt64;
begin
  Result:=Ord(FValue);
end;

procedure TJSONBoolean.SetAsInt64(const AValue: Int64);
begin
  FValue:=(AValue<>0)
end;

procedure TJSONBoolean.SetAsQword(const AValue: UInt64);
begin
  FValue:=(AValue<>0)
end;


procedure TJSONBoolean.SetAsBoolean(const AValue: Boolean);
begin
  FValue:=AValue;
end;

procedure TJSONBoolean.SetAsFloat(const AValue: TJSONFloat);
begin
  FValue:=(AValue<>0)
end;

procedure TJSONBoolean.SetAsInteger(const AValue: Integer);
begin
  FValue:=(AValue<>0)
end;

function TJSONBoolean.GetAsJSON: TJSONStringType;
begin
  If FValue then
    Result:='true'
  else
    Result:='false';
end;

function TJSONBoolean.GetAsString: TJSONStringType;
begin
  Result:=BoolToStr(FValue, True);
end;

procedure TJSONBoolean.SetAsString(const AValue: TJSONStringType);
begin
  FValue:=StrToBool(AValue);
end;


constructor TJSONBoolean.Create(AValue: Boolean);
begin
  FValue:=AValue;
end;

{ TJSONnull }

procedure TJSONNull.Converterror(From: Boolean);
begin
  If From then
    DoError(SErrCannotConvertFromNull)
  else
    DoError(SErrCannotConvertToNull);
end;

{$warnings off}
function TJSONNull.GetAsBoolean: Boolean;
begin
  ConvertError(True);
  Result:=false;
end;

function TJSONNull.GetAsFloat: TJSONFloat;
begin
  ConvertError(True);
  Result:=0.0;
end;

function TJSONNull.GetAsInteger: Integer;
begin
  ConvertError(True);
  Result:=0;
end;


function TJSONNull.GetAsInt64: Int64;
begin
  ConvertError(True);
end;

function TJSONNull.GetAsQWord: UInt64;
begin
  ConvertError(True);
end;

procedure TJSONNull.SetAsInt64(const AValue: Int64);
begin
  ConvertError(False);
  if AValue>0 then ;
end;

procedure TJSONNull.SetAsQword(const AValue: UInt64);
begin
  ConvertError(False);
  if AValue>0 then ;
end;


function TJSONNull.GetIsNull: Boolean;
begin
  Result:=True;
end;

procedure TJSONNull.SetAsBoolean(const AValue: Boolean);
begin
  ConvertError(False);
  if AValue then ;
end;

procedure TJSONNull.SetAsFloat(const AValue: TJSONFloat);
begin
  ConvertError(False);
  if AValue>0 then ;
end;

procedure TJSONNull.SetAsInteger(const AValue: Integer);
begin
  ConvertError(False);
  if AValue>0 then ;
end;

function TJSONNull.GetAsJSON: TJSONStringType;
begin
  Result:='null';
end;

function TJSONNull.GetAsString: TJSONStringType;
begin
  ConvertError(True);
  Result:='';
end;

procedure TJSONNull.SetAsString(const AValue: TJSONStringType);
begin
  ConvertError(True);
  if AValue='' then ;
end;


function TJSONNull.GetValue: TJSONVariant;
begin
  Result:=variants.Null;
end;

procedure TJSONNull.SetValue(const AValue: TJSONVariant);
begin
  ConvertError(False);
  if VarType(AValue)=0 then ;
end;

class function TJSONNull.JSONType: TJSONType;
begin
  Result:=jtNull;
end;

procedure TJSONNull.Clear;
begin
  // Do nothing
end;

function TJSONNull.Clone: TJSONData;
begin
  Result:=TJSONNullClass(Self.ClassType).Create;
end;

{$warnings on}



{ TJSONFloatNumber }

function TJSONFloatNumber.GetAsBoolean: Boolean;
begin
  Result:=(FValue<>0);
end;

function TJSONFloatNumber.GetAsFloat: TJSONFloat;
begin
  Result:=FValue;
end;

function TJSONFloatNumber.GetAsInteger: Integer;
begin
  Result:=Round(FValue);
end;

function TJSONFloatNumber.GetAsInt64: Int64;
begin
  Result:=Round(FValue);
end;

function TJSONFloatNumber.GetAsQWord: UInt64;
begin
  Result:=Round(FValue);
end;

procedure TJSONFloatNumber.SetAsInt64(const AValue: Int64);
begin
  FValue:=AValue;
end;

procedure TJSONFloatNumber.SetAsQword(const AValue: UInt64);
begin
  FValue:=AValue;
end;


procedure TJSONFloatNumber.SetAsBoolean(const AValue: Boolean);
begin
  FValue:=Ord(AValue);
end;

procedure TJSONFloatNumber.SetAsFloat(const AValue: TJSONFloat);
begin
  FValue:=AValue;
end;

procedure TJSONFloatNumber.SetAsInteger(const AValue: Integer);
begin
  FValue:=AValue;
end;



function TJSONFloatNumber.GetAsJSON: TJSONStringType;
begin
  Result:=AsString;
end;

function TJSONFloatNumber.GetAsString: TJSONStringType;
begin
  // What Str gives, without the ' ' it produces in front where the - can go.
  Result:=TyFclFloatToText(FValue);
end;

procedure TJSONFloatNumber.SetAsString(const AValue: TJSONStringType);
begin
  If Not TyFclTextToFloat(AValue,FValue) then
    Raise EConvertError.CreateFmt(SErrInvalidFloat,[AValue]);
end;


function TJSONFloatNumber.GetValue: TJSONVariant;
begin
  Result:=FValue;
end;

procedure TJSONFloatNumber.SetValue(const AValue: TJSONVariant);
begin
  FValue:=AValue;
end;

constructor TJSONFloatNumber.Create(AValue: TJSONFloat);
begin
  FValue:=AValue;
end;

class function TJSONFloatNumber.NumberType: TJSONNumberType;
begin
  Result:=ntFloat;
end;

procedure TJSONFloatNumber.Clear;
begin
  FValue:=0;
end;

function TJSONFloatNumber.Clone: TJSONData;

begin
  Result:=TJSONFloatNumberClass(ClassType).Create(Self.FValue);
end;

{ TJSONIntegerNumber }

function TJSONIntegerNumber.GetAsBoolean: Boolean;
begin
  Result:=FValue<>0;
end;

function TJSONIntegerNumber.GetAsFloat: TJSONFloat;
begin
  Result:=FValue;
end;

function TJSONIntegerNumber.GetAsInteger: Integer;
begin
  Result:=FValue;
end;

function TJSONIntegerNumber.GetAsInt64: Int64;
begin
  Result:=FValue;
end;

function TJSONIntegerNumber.GetAsQWord: UInt64;
begin
  result:=FValue;
end;

procedure TJSONIntegerNumber.SetAsInt64(const AValue: Int64);
begin
  FValue:=AValue;
end;

procedure TJSONIntegerNumber.SetAsQword(const AValue: UInt64);
begin
  FValue:=AValue;
end;


procedure TJSONIntegerNumber.SetAsBoolean(const AValue: Boolean);
begin
  FValue:=Ord(AValue);
end;

procedure TJSONIntegerNumber.SetAsFloat(const AValue: TJSONFloat);
begin
  FValue:=Round(AValue);
end;

procedure TJSONIntegerNumber.SetAsInteger(const AValue: Integer);
begin
  FValue:=AValue;
end;


function TJSONIntegerNumber.GetAsJSON: TJSONStringType;
begin
  Result:=AsString;
end;

function TJSONIntegerNumber.GetAsString: TJSONStringType;
begin
  Result:=IntToStr(FValue)
end;

procedure TJSONIntegerNumber.SetAsString(const AValue: TJSONStringType);
begin
  FValue:=StrToInt(AValue);
end;


function TJSONIntegerNumber.GetValue: TJSONVariant;
begin
  Result:=FValue;
end;

procedure TJSONIntegerNumber.SetValue(const AValue: TJSONVariant);
begin
  FValue:=AValue;
end;

constructor TJSONIntegerNumber.Create(AValue: Integer);
begin
  FValue:=AValue;
end;

class function TJSONIntegerNumber.NumberType: TJSONNumberType;
begin
  Result:=ntInteger;
end;

procedure TJSONIntegerNumber.Clear;
begin
  FValue:=0;
end;

function TJSONIntegerNumber.Clone: TJSONData;

begin
  Result:=TJSONIntegerNumberClass(ClassType).Create(Self.FValue);
end;

{ TJSONInt64Number }

function TJSONInt64Number.GetAsInt64: Int64;
begin
  Result := FValue;
end;

function TJSONInt64Number.GetAsQWord: UInt64;
begin
  Result := FValue;
end;

procedure TJSONInt64Number.SetAsInt64(const AValue: Int64);
begin
  FValue := AValue;
end;

procedure TJSONInt64Number.SetAsQword(const AValue: UInt64);
begin
  FValue := AValue;
end;

function TJSONInt64Number.GetAsBoolean: Boolean;
begin
  Result:=FValue<>0;
end;

function TJSONInt64Number.GetAsFloat: TJSONFloat;
begin
  Result:= FValue;
end;

function TJSONInt64Number.GetAsInteger: Integer;
begin
  Result := FValue;
end;

procedure TJSONInt64Number.SetAsBoolean(const AValue: Boolean);
begin
  FValue:=Ord(AValue);
end;

procedure TJSONInt64Number.SetAsFloat(const AValue: TJSONFloat);
begin
  FValue:=Round(AValue);
end;

procedure TJSONInt64Number.SetAsInteger(const AValue: Integer);
begin
  FValue:=AValue;
end;

function TJSONInt64Number.GetAsJSON: TJSONStringType;
begin
  Result:=AsString;
end;

function TJSONInt64Number.GetAsString: TJSONStringType;
begin
  Result:=IntToStr(FValue)
end;

procedure TJSONInt64Number.SetAsString(const AValue: TJSONStringType);
begin
  FValue:=StrToInt64(AValue);
end;

function TJSONInt64Number.GetValue: TJSONVariant;
begin
  Result:=FValue;
end;

procedure TJSONInt64Number.SetValue(const AValue: TJSONVariant);
begin
  FValue:=AValue;
end;

constructor TJSONInt64Number.Create(AValue: Int64);
begin
  FValue := AValue;
end;

class function TJSONInt64Number.NumberType: TJSONNumberType;
begin
  Result:=ntInt64;
end;

procedure TJSONInt64Number.Clear;
begin
  FValue:=0;
end;

function TJSONInt64Number.Clone: TJSONData;

begin
  Result:=TJSONInt64NumberClass(ClassType).Create(Self.FValue);
end;

{ FPC's QuickSort (rtl/objpas/classes/lists.inc), which TFPObjectList.Sort runs: equal elements end up
  in the order it leaves them in, not in that of Delphi's TList.Sort. }
Procedure JSONListQuickSort(AList: TList; L, R : Longint;
                     Compare: TListSortCompare);
var
  I, J : Longint;
  P : Pointer;
begin
 repeat
   I := L;
   J := R;
   P := AList.List[ (L + R) div 2 ];
   repeat
     while Compare(P, AList.List[i]) > 0 do
       I := I + 1;
     while Compare(P, AList.List[J]) < 0 do
       J := J - 1;
     If I <= J then
     begin
       AList.Exchange(I, J);
       I := I + 1;
       J := J - 1;
     end;
   until I > J;
   // sort the smaller range recursively
   // sort the bigger range via the loop
   // Reasons: memory usage is O(log(n)) instead of O(n) and loop is faster than recursion
   if J - L < R - I then
   begin
     if L < J then
       JSONListQuickSort(AList, L, J, Compare);
     L := I;
   end
   else
   begin
     if I < R then
       JSONListQuickSort(AList, I, R, Compare);
     R := J;
   end;
 until L >= R;
end;

{ TJSONArray }

function TJSONArray.GetBooleans(Index : Integer): Boolean;
begin
  Result:=Items[Index].AsBoolean;
end;

function TJSONArray.GetArrays(Index : Integer): TJSONArray;
begin
  Result:=Items[Index] as TJSONArray;
end;

function TJSONArray.GetFloats(Index : Integer): TJSONFloat;
begin
  Result:=Items[Index].AsFloat;
end;

function TJSONArray.GetIntegers(Index : Integer): Integer;
begin
  Result:=Items[Index].AsInteger;
end;


function TJSONArray.GetInt64s(Index : Integer): Int64;
begin
  Result:=Items[Index].AsInt64;
end;

function TJSONArray.GetNulls(Index : Integer): Boolean;
begin
  Result:=Items[Index].IsNull;
end;

function TJSONArray.GetObjects(Index : Integer): TJSONObject;
begin
  Result:=Items[Index] as TJSONObject;
end;

function TJSONArray.GetQWords(Index : Integer): UInt64;
begin
  Result:=Items[Index].AsQWord;
end;

function TJSONArray.GetStrings(Index : Integer): TJSONStringType;
begin
  Result:=Items[Index].AsString;
end;

function TJSONArray.GetUnicodeStrings(Index : Integer): TJSONUnicodeStringType;
begin
  Result:=Items[Index].AsUnicodeString;
end;

function TJSONArray.GetTypes(Index : Integer): TJSONType;
begin
  Result:=Items[Index].JSONType;
end;

procedure TJSONArray.SetArrays(Index : Integer; const AValue: TJSONArray);
begin
  Items[Index]:=AValue;
end;

procedure TJSONArray.SetBooleans(Index : Integer; const AValue: Boolean);

begin
  Items[Index]:=CreateJSON(AValue);
end;

procedure TJSONArray.SetFloats(Index : Integer; const AValue: TJSONFloat);
begin
  Items[Index]:=CreateJSON(AValue);
end;

procedure TJSONArray.SetIntegers(Index : Integer; const AValue: Integer);
begin
  Items[Index]:=CreateJSON(AValue);
end;



procedure TJSONArray.SetInt64s(Index : Integer; const AValue: Int64);
begin
  Items[Index]:=CreateJSON(AValue);
end;

procedure TJSONArray.SetObjects(Index : Integer; const AValue: TJSONObject);
begin
  Items[Index]:=AValue;
end;

procedure TJSONArray.SetQWords(Index : Integer; AValue: UInt64);
begin
  Items[Index]:=CreateJSON(AValue);
end;

procedure TJSONArray.SetStrings(Index : Integer; const AValue: TJSONStringType);
begin
  Items[Index]:=CreateJSON(AValue);
end;

procedure TJSONArray.SetUnicodeStrings(Index: Integer;
  const AValue: TJSONUnicodeStringType);
begin
  Items[Index]:=CreateJSON(AValue);
end;

function TJSONArray.DoFindPath(const APath: TJSONStringType; out
  NotFound: TJSONStringType): TJSONdata;

Var
  P,I : integer;
  E : String;

begin
  if (APath<>'') and (APath[1]='[') then
    begin
    P:=Pos(']',APath);
    I:=-1;
    If (P>2) then
      I:=StrToIntDef(Copy(APath,2,P-2),-1);
    If (I>=0) and (I<Count) then
       begin
       E:=APath;
       System.Delete(E,1,P);
       Result:=Items[i].DoFindPath(E,NotFound);
       end
    else
       begin
       Result:=Nil;
       If (P>0) then
         NotFound:=Copy(APath,1,P)
       else
         NotFound:=APath;
       end;
    end
  else
    Result:=inherited DoFindPath(APath, NotFound);
end;

procedure TJSONArray.Converterror(From: Boolean);
begin
  If From then
    DoError(SErrCannotConvertFromArray)
  else
    DoError(SErrCannotConvertToArray);
end;

{$warnings off}
function TJSONArray.GetAsBoolean: Boolean;
begin
  ConvertError(True);
  Result:=false;
end;

function TJSONArray.GetAsFloat: TJSONFloat;
begin
  ConvertError(True);
  Result:=0.0;
end;

function TJSONArray.GetAsInteger: Integer;
begin
  ConvertError(True);
  Result:=0;
end;



procedure TJSONArray.SetAsBoolean(const AValue: Boolean);
begin
  ConvertError(False);
  if AValue then ;
end;

procedure TJSONArray.SetAsFloat(const AValue: TJSONFloat);
begin
  ConvertError(False);
  if AValue>0 then ;
end;

procedure TJSONArray.SetAsInteger(const AValue: Integer);
begin
  ConvertError(False);
  if AValue>0 then ;
end;


{$warnings on}

function TJSONArray.GetAsJSON: TJSONStringType;

Var
  I : Integer;
  Sep : String;
  D : TJSONData;
  V : TJSONStringType;

begin
  Sep:=TJSONData.FElementSep;
  Result:='[';
  For I:=0 to Count-1 do
    begin
    D:=Items[i];
    if D<>Nil then
      V:=D.AsJSON
    else
      V:='null';
    Result:=Result+V;
    If (I<Count-1) then
      Result:=Result+Sep;
    end;
  Result:=Result+']';
end;

Function IndentString(Options : TFormatOptions; Indent : Integer) : TJSONStringType;

begin
  If (foUseTabChar in Options) then
    Result:=StringofChar(#9,Indent)
  else
    Result:=StringOfChar(' ',Indent);  
end;

function TJSONArray.DoFormatJSON(Options: TFormatOptions; CurrentIndent,
  Indent: Integer): TJSONStringType;

Var
  I : Integer;
  MultiLine : Boolean;
  SkipWhiteSpace : Boolean;
  Ind : String;
  
begin
  Result:='[';
  MultiLine:=Not (foSingleLineArray in Options);
  SkipWhiteSpace:=foSkipWhiteSpace in Options;
  Ind:=IndentString(Options, CurrentIndent+Indent);
  if MultiLine then
    Result:=Result+sLineBreak;
  For I:=0 to Count-1 do
    begin
    if MultiLine then
      Result:=Result+Ind;
    if Items[i]=Nil then
      Result:=Result+'null'
    else
      Result:=Result+Items[i].DoFormatJSON(Options,CurrentIndent+Indent,Indent);
    If (I<Count-1) then
      if MultiLine then
        Result:=Result+','
      else
        Result:=Result+ElementSeps[SkipWhiteSpace];
    if MultiLine then
      Result:=Result+sLineBreak
    end;
  if MultiLine then
    Result:=Result+IndentString(Options, CurrentIndent);
  Result:=Result+']';
end;


{$warnings off}
function TJSONArray.GetAsString: TJSONStringType;
begin
  ConvertError(True);
  Result:='';
end;

procedure TJSONArray.SetAsString(const AValue: TJSONStringType);
begin
  ConvertError(False);
  if AValue='' then ;
end;

function TJSONArray.GetValue: TJSONVariant;
begin
  ConvertError(True);
  Result:=0;
end;

procedure TJSONArray.SetValue(const AValue: TJSONVariant);
begin
  ConvertError(False);
  if VarType(AValue)=0 then ;
end;
{$warnings on}

function TJSONArray.GetCount: Integer;
begin
  Result:=FList.Count;
end;

function TJSONArray.GetItem(Index: Integer): TJSONData;
begin
  Result:=FList[Index] as TJSONData;
end;

procedure TJSONArray.SetItem(Index: Integer; const AValue: TJSONData);
begin
  If (Index=FList.Count) then
    FList.Add(AValue)
  else
    FList[Index]:=AValue;
end;

constructor TJSONArray.Create;
begin
  Flist:=TObjectList.Create(True);
end;

Function VarRecToJSON(Const Element : TVarRec; const SourceType : String) : TJSONData; overload;

begin
  Result:=Nil;
  With Element do
    case VType of
      vtInteger    : Result:=CreateJSON(VInteger);
      vtBoolean    : Result:=CreateJSON(VBoolean);
      vtChar       : Result:=CreateJSON(TJSONStringType(VChar));
      vtWideChar   : Result:=CreateJSON(TJSONStringType(VWideChar));
      vtExtended   : Result:=CreateJSON(VExtended^);
      vtString     : Result:=CreateJSON(TJSONStringType(vString^));
      vtAnsiString : Result:=CreateJSON(TJSONStringType(RawByteString(VAnsiString)));
      vtUnicodeString: Result:=CreateJSON(UnicodeString(VUnicodeString));
      vtWideString: Result:=CreateJSON(WideString(VWideString));
      vtPChar      : Result:=CreateJSON(StrPas(VPChar));
      vtPointer    : If (VPointer<>Nil) then
                       TJSONData.DoError(SErrPointerNotNil,[SourceType])
                     else
                       Result:=CreateJSON();
      vtCurrency   : Result:=CreateJSON(vCurrency^);
      vtInt64      : Result:=CreateJSON(vInt64^);
      vtObject     : if (VObject is TJSONData) then
                       Result:=TJSONData(VObject)
                     else
                       TJSONData.DoError(SErrNotJSONData,[VObject.ClassName,SourceType]);
      //vtVariant    :
    else
      TJSONData.DoError(SErrUnknownTypeInConstructor,[SourceType,VType])
    end;
end;

constructor TJSONArray.Create(const Elements: array of Const);

Var
  I : integer;
  J : TJSONData;

begin
  Create;
  For I:=Low(Elements) to High(Elements) do
    begin
    J:=VarRecToJSON(Elements[i],'Array');
    Add(J);
    end;
end;

destructor TJSONArray.Destroy;
begin
  FreeAndNil(FList);
  inherited Destroy;
end;

class function TJSONArray.JSONType: TJSONType;
begin
  Result:=jtArray;
end;

function TJSONArray.Clone: TJSONData;

Var
  A : TJSONArray;
  I : Integer;

begin
  A:=TJSONArrayClass(ClassType).Create;
  try
    For I:=0 to Count-1 do
      A.Add(Self.Items[I].Clone);
    Result:=A;
  except
    A.Free;
    Raise;
  end;
end;

procedure TJSONArray.Iterate(Iterator: TJSONArrayIterator; Data: TObject);

Var
  I : Integer;
  Cont : Boolean;
  
begin
  I:=0;
  Cont:=True;
  While (I<FList.Count) and cont do
    begin
    Iterator(Items[i],Data,Cont);
    Inc(I);
    end;
end;

function TJSONArray.IndexOf(obj: TJSONData): Integer;
begin
  Result:=FList.IndexOf(Obj);
end;

function TJSONArray.GetEnumerator: TBaseJSONEnumerator;
begin
  Result:=TJSONArrayEnumerator.Create(Self);
end;

procedure TJSONArray.Clear;
begin
  FList.Clear;
end;

function TJSONArray.Add(Item: TJSONData): Integer;
begin
  Result:=FList.Add(Item);
end;

function TJSONArray.Add(I: Integer): Integer;
begin
  Result:=Add(CreateJSON(I));
end;


function TJSONArray.GetAsInt64: Int64;
begin
  ConvertError(True);
  Result:=0;
end;

function TJSONArray.GetAsQWord: UInt64;
begin
  ConvertError(True);
  Result:=0;
end;

procedure TJSONArray.SetAsInt64(const AValue: Int64);
begin
  ConvertError(False);
  if AValue>0 then ;
end;

procedure TJSONArray.SetAsQword(const AValue: UInt64);
begin
  ConvertError(False);
  if AValue>0 then ;
end;

function TJSONArray.Add(I: Int64): Int64;
begin
  Result:=Add(CreateJSON(I));
end;

function TJSONArray.Add(I: UInt64): UInt64;
begin
  Result:=Add(CreateJSON(I));
end;


procedure TJSONArray.Insert(Index: Integer; I: Int64);
begin
  FList.Insert(Index, CreateJSON(I));
end;

procedure TJSONArray.Insert(Index: Integer; I: UInt64);
begin
  FList.Insert(Index, CreateJSON(I));
end;



function TJSONArray.Add(const S: String): Integer;
begin
  Result:=Add(CreateJSON(S));
end;

function TJSONArray.Add: Integer;
begin
  Result:=Add(CreateJSON);
end;

function TJSONArray.Add(F: TJSONFloat): Integer;
begin
  Result:=Add(CreateJSON(F));
end;

function TJSONArray.Add(B: Boolean): Integer;
begin
  Result:=Add(CreateJSON(B));
end;

function TJSONArray.Add(AnArray: TJSONArray): Integer;
begin
  If (IndexOf(AnArray)<>-1) then
    DoError(SErrCannotAddArrayTwice);
  Result:=Add(TJSONData(AnArray));
end;

function TJSONArray.Add(AnObject: TJSONObject): Integer;
begin
  If (IndexOf(AnObject)<>-1) then
    DoError(SErrCannotAddObjectTwice);
  Result:=Add(TJSONData(AnObject));
end;

procedure TJSONArray.Delete(Index: Integer);
begin
  FList.Delete(Index);
end;

procedure TJSONArray.Exchange(Index1, Index2: Integer);
begin
  FList.Exchange(Index1, Index2);
end;

function TJSONArray.Extract(Item: TJSONData): TJSONData;
begin
  Result := TJSONData(FList.Extract(Item));
end;

function TJSONArray.Extract(Index: Integer): TJSONData;
begin
  Result := TJSONData(FList.Extract(FList.Items[Index]));
end;

procedure TJSONArray.Insert(Index: Integer);
begin
  Insert(Index,CreateJSON);
end;

procedure TJSONArray.Insert(Index: Integer; Item: TJSONData);
begin
  FList.Insert(Index, Item);
end;

procedure TJSONArray.Insert(Index: Integer; I: Integer);
begin
  FList.Insert(Index, CreateJSON(I));
end;


procedure TJSONArray.Insert(Index: Integer; const S: String);
begin
  FList.Insert(Index, CreateJSON(S));
end;

procedure TJSONArray.Insert(Index: Integer; F: TJSONFloat);
begin
  FList.Insert(Index, CreateJSON(F));
end;

procedure TJSONArray.Insert(Index: Integer; B: Boolean);
begin
  FList.Insert(Index, CreateJSON(B));
end;

procedure TJSONArray.Insert(Index: Integer; AnArray: TJSONArray);
begin
  if (IndexOf(AnArray)<>-1) then
    DoError(SErrCannotAddArrayTwice);
  FList.Insert(Index, AnArray);
end;

procedure TJSONArray.Insert(Index: Integer; AnObject: TJSONObject);
begin
  if (IndexOf(AnObject)<>-1) then
    DoError(SErrCannotAddObjectTwice);
  FList.Insert(Index, AnObject);
end;

procedure TJSONArray.Move(CurIndex, NewIndex: Integer);
begin
  FList.Move(CurIndex, NewIndex);
end;

procedure TJSONArray.Remove(Item: TJSONData);
begin
  FList.Remove(Item);
end;

procedure TJSONArray.Sort(Compare: TListSortCompare);
begin
  // TFPList.Sort
  if FList.Count>=2 then
    JSONListQuickSort(FList,0,FList.Count-1,Compare);
end;

Resourcestring
  SErrMemberIndex = 'List index (%d) out of bounds';

Type
  { TJSONMemberList: the members of a TJSONObject, in the order they were added, found by name through
    a hash. It takes the place of contnrs' TFPHashObjectList, without its limit on the length of a name,
    and does what TJSONObject asks of that list the way it does: Items[] (when set), Delete, Remove and
    Clear free the value when OwnsObjects, Extract does not; an index out of range raises EListError;
    of two members of the same name Find gives the one added last. }
  TJSONMemberList = class
  private
    FNames : Array of TJSONStringType;
    FItems : Array of TObject;
    FHashes : Array of Cardinal;
    FNext : Array of Integer;
    FBuckets : Array of Integer;
    FCount : Integer;
    FOwnsObjects : Boolean;
    class function HashOf(const AName: TJSONStringType): Cardinal; static;
    procedure CheckIndex(Index: Integer);
    procedure ReHash;
    procedure RemoveAt(Index: Integer);
    function GetItem(Index: Integer): TObject;
    procedure SetItem(Index: Integer; AObject: TObject);
  public
    constructor Create(AOwnsObjects: Boolean);
    destructor Destroy; override;
    function Add(const AName: TJSONStringType; AObject: TObject): Integer;
    procedure Clear;
    procedure Delete(Index: Integer);
    function Extract(Item: TObject): TObject;
    function Remove(AObject: TObject): Integer;
    function IndexOf(AObject: TObject): Integer;
    function Find(const AName: TJSONStringType): TObject;
    function FindIndexOf(const AName: TJSONStringType): Integer;
    function NameOfIndex(Index: Integer): TJSONStringType;
    property Count: Integer read FCount;
    property Items[Index: Integer]: TObject read GetItem write SetItem;
    property OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

{ The member table of AObject. TJSONObject.FHash is declared TObject in the interface, where
  TJSONMemberList is not known; this is the one place that casts it. }
function MemberList(AObject: TJSONObject): TJSONMemberList; inline;
begin
  Result:=TJSONMemberList(AObject.FHash);
end;

{ TJSONMemberList }

constructor TJSONMemberList.Create(AOwnsObjects: Boolean);
begin
  inherited Create;
  FOwnsObjects:=AOwnsObjects;
end;

destructor TJSONMemberList.Destroy;
begin
  Clear;
  inherited Destroy;
end;

// FNV-1a over the UTF-16 code units; the products stay below 2^56, so no overflow check can fire.
class function TJSONMemberList.HashOf(const AName: TJSONStringType): Cardinal;
var
  I : Integer;
begin
  Result:=2166136261;
  for I:=1 to Length(AName) do
    Result:=Cardinal((UInt64(Result xor Ord(AName[I]))*16777619) and $FFFFFFFF);
end;

procedure TJSONMemberList.CheckIndex(Index: Integer);
begin
  if (Index<0) or (Index>=FCount) then
    raise EListError.CreateFmt(SErrMemberIndex,[Index]);
end;

// Every name into its bucket, in index order: the last of equal names heads the chain.
procedure TJSONMemberList.ReHash;
var
  I, B, N : Integer;
begin
  N:=16;
  while N<FCount do
    N:=N*2;
  SetLength(FBuckets,N);
  for I:=0 to N-1 do
    FBuckets[I]:=-1;
  for I:=0 to FCount-1 do
    begin
    B:=FHashes[I] and Cardinal(N-1);
    FNext[I]:=FBuckets[B];
    FBuckets[B]:=I;
    end;
end;

function TJSONMemberList.Add(const AName: TJSONStringType; AObject: TObject): Integer;
var
  B : Integer;
begin
  if FCount=Length(FItems) then
    begin
    SetLength(FNames,FCount*2+8);
    SetLength(FItems,FCount*2+8);
    SetLength(FHashes,FCount*2+8);
    SetLength(FNext,FCount*2+8);
    end;
  Result:=FCount;
  FNames[Result]:=AName;
  FItems[Result]:=AObject;
  FHashes[Result]:=HashOf(AName);
  Inc(FCount);
  if FCount>Length(FBuckets) then
    ReHash
  else
    begin
    B:=FHashes[Result] and Cardinal(Length(FBuckets)-1);
    FNext[Result]:=FBuckets[B];
    FBuckets[B]:=Result;
    end;
end;

procedure TJSONMemberList.Clear;
var
  I : Integer;
begin
  if FOwnsObjects then
    for I:=0 to FCount-1 do
      FItems[I].Free;
  FCount:=0;
  SetLength(FNames,0);
  SetLength(FItems,0);
  SetLength(FHashes,0);
  SetLength(FNext,0);
  SetLength(FBuckets,0);
end;

// Takes the member out without freeing its value; the indexes after it move down by one.
procedure TJSONMemberList.RemoveAt(Index: Integer);
var
  I : Integer;
begin
  for I:=Index to FCount-2 do
    begin
    FNames[I]:=FNames[I+1];
    FItems[I]:=FItems[I+1];
    FHashes[I]:=FHashes[I+1];
    end;
  Dec(FCount);
  FNames[FCount]:='';
  FItems[FCount]:=Nil;
  ReHash;
end;

procedure TJSONMemberList.Delete(Index: Integer);
begin
  CheckIndex(Index);
  if FOwnsObjects then
    FItems[Index].Free;
  RemoveAt(Index);
end;

function TJSONMemberList.Extract(Item: TObject): TObject;
var
  I : Integer;
begin
  Result:=Nil;
  I:=IndexOf(Item);
  if I>=0 then
    begin
    Result:=Item;
    RemoveAt(I);
    end;
end;

function TJSONMemberList.Remove(AObject: TObject): Integer;
begin
  Result:=IndexOf(AObject);
  if (Result<>-1) then
    begin
    if FOwnsObjects then
      FItems[Result].Free;
    RemoveAt(Result);
    end;
end;

function TJSONMemberList.IndexOf(AObject: TObject): Integer;
begin
  Result:=0;
  while (Result<FCount) and (FItems[Result]<>AObject) do
    Inc(Result);
  if Result=FCount then
    Result:=-1;
end;

function TJSONMemberList.Find(const AName: TJSONStringType): TObject;
var
  I : Integer;
begin
  I:=FindIndexOf(AName);
  if I>=0 then
    Result:=FItems[I]
  else
    Result:=Nil;
end;

function TJSONMemberList.FindIndexOf(const AName: TJSONStringType): Integer;
var
  H : Cardinal;
begin
  Result:=-1;
  if Length(FBuckets)=0 then
    Exit;
  H:=HashOf(AName);
  Result:=FBuckets[H and Cardinal(Length(FBuckets)-1)];
  while (Result<>-1) and not ((FHashes[Result]=H) and (FNames[Result]=AName)) do
    Result:=FNext[Result];
end;

function TJSONMemberList.NameOfIndex(Index: Integer): TJSONStringType;
begin
  CheckIndex(Index);
  Result:=FNames[Index];
end;

function TJSONMemberList.GetItem(Index: Integer): TObject;
begin
  CheckIndex(Index);
  Result:=FItems[Index];
end;

// As TFPHashObjectList.SetItem: the previous value is freed when OwnsObjects.
procedure TJSONMemberList.SetItem(Index: Integer; AObject: TObject);
begin
  CheckIndex(Index);
  if FOwnsObjects then
    FItems[Index].Free;
  FItems[Index]:=AObject;
end;

{ TJSONObject }

function TJSONObject.GetArrays(const AName: String): TJSONArray;
begin
  Result:=GetElements(AName) as TJSONArray;
end;

function TJSONObject.GetBooleans(const AName: String): Boolean;
begin
  Result:=GetElements(AName).AsBoolean;
end;

function TJSONObject.GetElements(const AName: string): TJSONData;
begin
  Result:=TJSONData(MemberList(Self).Find(AName));
  If (Result=Nil) then
    DoError(SErrNonexistentElement,[AName]);
end;

function TJSONObject.GetFloats(const AName: String): TJSONFloat;
begin
  Result:=GetElements(AName).AsFloat;
end;

function TJSONObject.GetIntegers(const AName: String): Integer;
begin
  Result:=GetElements(AName).AsInteger;
end;

function TJSONObject.GetInt64s(const AName: String): Int64;
begin
  Result:=GetElements(AName).AsInt64;
end;

function TJSONObject.GetQWords(AName : String): UInt64;
begin
  Result:=GetElements(AName).AsQWord;
end;

function TJSONObject.GetUnicodeStrings(const AName: String
  ): TJSONUnicodeStringType;
begin
  Result:=GetElements(AName).AsUnicodeString;
end;

procedure TJSONObject.SetInt64s(const AName : String; const AValue: Int64);
begin
  SetElements(AName,CreateJSON(AVAlue));
end;

procedure TJSONObject.SetQWords(AName : String; AValue: UInt64);
begin
  SetElements(AName,CreateJSON(AVAlue));
end;

procedure TJSONObject.SetUnicodeStrings(const AName: String;
  const AValue: TJSONUnicodeStringType);
begin
  SetElements(AName,CreateJSON(AValue));
end;

function TJSONObject.GetIsNull(const AName: String): Boolean;
begin
  Result:=GetElements(AName).IsNull;
end;

function TJSONObject.GetNameOf(Index: Integer): TJSONStringType;
begin
  Result:=MemberList(Self).NameOfIndex(Index);
end;

function TJSONObject.GetObjects(const AName : String): TJSONObject;
begin
  Result:=GetElements(AName) as TJSONObject;
end;


function TJSONObject.GetStrings(const AName : String): TJSONStringType;
begin
  Result:=GetElements(AName).AsString;
end;

function TJSONObject.GetTypes(const AName : String): TJSONType;
begin
  Result:=Getelements(Aname).JSONType;
end;

class function TJSONObject.GetUnquotedMemberNames: Boolean;
begin
  Result:=FUnquotedMemberNames;
end;

procedure TJSONObject.SetArrays(const AName : String; const AValue: TJSONArray);

begin
  SetElements(AName,AVAlue);
end;

procedure TJSONObject.SetBooleans(const AName : String; const AValue: Boolean);
begin
  SetElements(AName,CreateJSON(AVAlue));
end;

procedure TJSONObject.SetElements(const AName: string; const AValue: TJSONData);
Var
  Index : Integer;

begin
  Index:=MemberList(Self).FindIndexOf(AName);
  If (Index=-1) then
    MemberList(Self).Add(AName,AValue)
  else
    MemberList(Self).Items[Index]:=AValue; // Will free the previous value.
end;

procedure TJSONObject.SetFloats(const AName : String; const AValue: TJSONFloat);
begin
  SetElements(AName,CreateJSON(AVAlue));
end;

procedure TJSONObject.SetIntegers(const AName : String; const AValue: Integer);
begin
  SetElements(AName,CreateJSON(AVAlue));
end;


procedure TJSONObject.SetIsNull(const AName : String; const AValue: Boolean);
begin
  If Not AValue then
    DoError(SErrCannotSetNotIsNull);
  SetElements(AName,CreateJSON);
end;

procedure TJSONObject.SetObjects(const AName : String; const AValue: TJSONObject);
begin
  SetElements(AName,AValue);
end;


procedure TJSONObject.SetStrings(const AName : String; const AValue: TJSONStringType);
begin
  SetElements(AName,CreateJSON(AValue));
end;


class procedure TJSONObject.DetermineElementQuotes;

begin
  FObjStartSep:=ObjStartSeps[TJSONData.FCompressedJSON];
  FObjEndSep:=ObjEndSeps[TJSONData.FCompressedJSON];
  if TJSONData.FCompressedJSON then
    FElementEnd:=UnSpacedQuoted[FUnquotedMemberNames]
  else
    FElementEnd:=SpacedQuoted[FUnquotedMemberNames];
  FElementStart:=ElementStart[FUnquotedMemberNames]
end;

class procedure TJSONObject.SetUnquotedMemberNames(AValue: Boolean);

begin
  if FUnquotedMemberNames=AValue then exit;
  FUnquotedMemberNames:=AValue;
  DetermineElementQuotes;
end;

function TJSONObject.DoFindPath(const APath: TJSONStringType; out
  NotFound: TJSONStringType): TJSONdata;

Var
  N: TJSONStringType;
  L,P,P2 : Integer;

begin
  If (APath='') then
    Exit(Self);
  N:=APath;
  L:=Length(N);
  P:=1;
  While (P<L) and (N[P]='.') do
    inc(P);
  P2:=P;
  While (P2<=L) and (Not (N[P2] in ['.','['])) do
    inc(P2);
   N:=Copy(APath,P,P2-P);
   If (N='') then
     Result:=Self
   else
     begin
     Result:=Find(N);
     If Result=Nil then
       NotFound:=N+Copy(APath,P2,L-P2)
     else
       begin
       N:=Copy(APath,P2,L-P2+1);
       Result:=Result.DoFindPath(N,NotFound);
       end;
     end;
end;

procedure TJSONObject.Converterror(From: Boolean);
begin
  If From then
    DoError(SErrCannotConvertFromObject)
  else
    DoError(SErrCannotConvertToObject);
end;

{$warnings off}
function TJSONObject.GetAsBoolean: Boolean;
begin
  ConvertError(True);
  Result:=false;
end;

function TJSONObject.GetAsFloat: TJSONFloat;
begin
  ConvertError(True);
  Result:=0.0;
end;

function TJSONObject.GetAsInteger: Integer;
begin
  ConvertError(True);
  Result:=0;
end;

procedure TJSONObject.SetAsBoolean(const AValue: Boolean);
begin
  ConvertError(False);
  if AValue then ;
end;

procedure TJSONObject.SetAsFloat(const AValue: TJSONFloat);
begin
  ConvertError(False);
  if AValue>0 then ;
end;

procedure TJSONObject.SetAsInteger(const AValue: Integer);
begin
  ConvertError(False);
  if AValue>0 then ;
end;


function TJSONObject.Add(const AName: TJSONStringType; Avalue: Int64): Integer;
begin
  Result:=DoAdd(AName,CreateJSON(AValue));
end;

function TJSONObject.Add(const AName: TJSONStringType; Avalue: UInt64): Integer;
begin
  Result:=DoAdd(AName,CreateJSON(AValue));
end;

function TJSONObject.GetAsInt64: Int64;
begin
  ConvertError(True);
end;

function TJSONObject.GetAsQWord: UInt64;
begin
  ConvertError(True);
end;

procedure TJSONObject.SetAsInt64(const AValue: Int64);
begin
  ConvertError(False);
  if AValue>0 then ;
end;

procedure TJSONObject.SetAsQword(const AValue: UInt64);
begin
  ConvertError(False);
  if AValue>0 then ;
end;


{$warnings on}

function TJSONObject.GetAsJSON: TJSONStringType;

Var
  I : Integer;
  Sep : String;
  V : TJSONStringType;
  D : TJSONData;

begin
  Sep:=TJSONData.FElementSep;
  Result:='';
  For I:=0 to Count-1 do
    begin
    If (Result<>'') then
      Result:=Result+Sep;
    D:=Items[i];
    if Assigned(D) then
      V:=Items[I].AsJSON
    else
      V:='null';
    Result:=Result+FElementStart+StringToJSONString(Names[i])+FElementEnd+V;
    end;
  If (Result<>'') then
    Result:=FObjStartSep+Result+FObjEndSep
  else
    Result:='{}';
end;

{$warnings off}
function TJSONObject.GetAsString: TJSONStringType;
begin
  ConvertError(True);
  Result:='';
end;

procedure TJSONObject.SetAsString(const AValue: TJSONStringType);
begin
  ConvertError(False);
  if AValue='' then ;
end;

function TJSONObject.GetValue: TJSONVariant;
begin
  ConvertError(True);
  Result:=0;
end;

procedure TJSONObject.SetValue(const AValue: TJSONVariant);
begin
  ConvertError(False);
  if VarType(AValue)=0 then ;
end;
{$warnings on}

function TJSONObject.GetCount: Integer;
begin
  Result:=MemberList(Self).Count;
end;

function TJSONObject.GetItem(Index: Integer): TJSONData;
begin
  Result:=TJSONData(MemberList(Self).Items[Index]);
end;

procedure TJSONObject.SetItem(Index: Integer; const AValue: TJSONData);
begin
  MemberList(Self).Items[Index]:=AValue;
end;

constructor TJSONObject.Create;
begin
  FHash:=TJSONMemberList.Create(True);
end;

constructor TJSONObject.Create(const Elements: array of Const);

Var
  I : integer;
  AName : TJSONUnicodeStringType;
  J : TJSONData;

begin
  Create;
  If ((High(Elements)-Low(Elements)) mod 2)=0 then
    DoError(SErrOddNumber);
  I:=Low(Elements);
  While I<=High(Elements) do
    begin
    With Elements[i] do
      Case VType of
        vtChar       : AName:=TJSONUnicodeStringType(VChar);
        vtWideChar   : AName:=TJSONUnicodeStringType(VWideChar);
        vtString     : AName:=TJSONUnicodeStringType(vString^);
        vtAnsiString : AName:=TJSONUnicodeStringType(RawByteString(VAnsiString));
        vtUnicodeString : AName:=TJSONUnicodeStringType(VUnicodeString);
        vtWideString : AName:=TJSONUnicodeStringType(WideString(VWideString));
        vtPChar      : AName:=TJSONUnicodeStringType(StrPas(VPChar));
      else
        DoError(SErrNameMustBeString,[I+1]);
      end;
    If (AName='') then
      DoError(SErrNameMustBeString,[I+1]);
    Inc(I);
    J:=VarRecToJSON(Elements[i],'Object');
    Add(AName,J);
    Inc(I);
    end;
end;

destructor TJSONObject.Destroy;
begin
  FreeAndNil(FHash);
  inherited Destroy;
end;

class function TJSONObject.JSONType: TJSONType;
begin
  Result:=jtObject;
end;

function TJSONObject.Clone: TJSONData;

Var
  O : TJSONObject;
  I: Integer;

begin
  O:=TJSONObjectClass(ClassType).Create;
  try
    For I:=0 to Count-1 do
      O.Add(Self.Names[I],Self.Items[I].Clone);
    Result:=O;
  except
    FreeAndNil(O);
    Raise;
  end;
end;

function TJSONObject.GetEnumerator: TBaseJSONEnumerator;
begin
  Result:=TJSONObjectEnumerator.Create(Self);
end;


function TJSONObject.DoFormatJSON(Options: TFormatOptions; CurrentIndent,
  Indent: Integer): TJSONStringType;

Var
  i : Integer;
  S : TJSONStringType;
  MultiLine,UseQuotes, SkipWhiteSpace,SkipWhiteSpaceOnlyLeading : Boolean;
  NSep,Sep,Ind : String;
  V : TJSONStringType;
  D : TJSONData;

begin
  Result:='';
  UseQuotes:=Not (foDoNotQuoteMembers in options);
  MultiLine:=Not (foSingleLineObject in Options);
  SkipWhiteSpace:=foSkipWhiteSpace in Options;
  SkipWhiteSpaceOnlyLeading:=foSkipWhiteSpaceOnlyLeading in Options;
  CurrentIndent:=CurrentIndent+Indent;
  Ind:=IndentString(Options, CurrentIndent);
  If SkipWhiteSpace then
    begin
    if SkipWhiteSpaceOnlyLeading then
      NSep:=': '
    else
      NSep:=':'
    end
  else
    NSep:=' : ';
  If MultiLine then
    Sep:=','+SLineBreak+Ind
  else if SkipWhiteSpace then
    Sep:=','
  else
    Sep:=', ';
  For I:=0 to Count-1 do
    begin
    If (I>0) then
      Result:=Result+Sep
    else If MultiLine then
      Result:=Result+Ind;
    S:=StringToJSONString(Names[i]);
    If UseQuotes then
      S:='"'+S+'"';
    D:=Items[i];
    if D=Nil then
      V:='null'
    else
      v:=Items[I].DoFormatJSON(Options,CurrentIndent,Indent);
    Result:=Result+S+NSep+V;
    end;
  If (Result<>'') then
    begin
    if MultiLine then
      Result:='{'+sLineBreak+Result+sLineBreak+indentString(options,CurrentIndent-Indent)+'}'
    else
      Result:=ObjStartSeps[SkipWhiteSpace]+Result+ObjEndSeps[SkipWhiteSpace]
    end
  else
    Result:='{}';
end;

procedure TJSONObject.Iterate(Iterator: TJSONObjectIterator; Data: TObject);
Var
  I : Integer;
  Cont : Boolean;

begin
  I:=0;
  Cont:=True;
  While (I<MemberList(Self).Count) and Cont do
    begin
    Iterator(Names[I],Items[i],Data,Cont);
    Inc(I);
    end;
end;

function TJSONObject.IndexOf(Item: TJSONData): Integer;
begin
  Result:=MemberList(Self).IndexOf(Item);
end;

function TJSONObject.IndexOfName(const AName: TJSONStringType; CaseInsensitive : Boolean = False): Integer;
begin
  Result:=MemberList(Self).FindIndexOf(AName);
  if (Result<0) and CaseInsensitive then
    begin
    Result:=Count-1;
    While (Result>=0) and (CompareText(Names[Result],AName)<>0) do
      Dec(Result);
    end;
end;

procedure TJSONObject.Clear;
begin
  MemberList(Self).Clear;
end;

function TJSONObject.DoAdd(const AName: TJSONStringType; AValue: TJSONData; FreeOnError : Boolean = True): Integer;
begin
  if (IndexOfName(aName)<>-1) then
    begin
    if FreeOnError then
      FreeAndNil(AValue);
    DoError(SErrDuplicateValue,[aName]);
    end;
  Result:=MemberList(Self).Add(AName,AValue);
end;

function TJSONObject.Add(const AName: TJSONStringType; AValue: TJSONData
  ): Integer;
begin
  Result:=DoAdd(aName,AValue,False);
end;

function TJSONObject.Add(const AName: TJSONStringType; AValue: Boolean
  ): Integer;
begin
  Result:=DoAdd(AName,CreateJSON(AValue));
end;

function TJSONObject.Add(const AName: TJSONStringType; AValue: TJSONFloat): Integer;
begin
  Result:=DoAdd(AName,CreateJSON(AValue));
end;

function TJSONObject.Add(const AName, AValue: TJSONStringType): Integer;
begin
  Result:=DoAdd(AName,CreateJSON(AValue));
end;

function TJSONObject.Add(const AName: TJSONStringType; Avalue: Integer): Integer;
begin
  Result:=DoAdd(AName,CreateJSON(AValue));
end;


function TJSONObject.Add(const AName: TJSONStringType): Integer;
begin
  Result:=DoAdd(AName,CreateJSON);
end;

function TJSONObject.Add(const AName: TJSONStringType; AValue: TJSONArray
  ): Integer;
begin
  Result:=DoAdd(AName,TJSONData(AValue),False);
end;

procedure TJSONObject.Delete(Index: Integer);
begin
  MemberList(Self).Delete(Index);
end;

procedure TJSONObject.Delete(const AName: string);
Var
  I : Integer;

begin
  I:=IndexOfName(AName);
  if (I<>-1) then
    Delete(I);
end;

procedure TJSONObject.Remove(Item: TJSONData);
begin
  MemberList(Self).Remove(Item);
end;


function TJSONObject.Extract(Index: Integer): TJSONData;
begin
  Result:=Items[Index];
  MemberList(Self).Extract(Result);
end;

function TJSONObject.Extract(const AName: string): TJSONData;


Var
  I : Integer;

begin
  I:=IndexOfName(AName);
  if (I<>-1) then
    Result:=Extract(I)
  else
    Result:=Nil
end;

function TJSONObject.Get(const AName: String): TJSONVariant;
Var
  I : Integer;

begin
  I:=IndexOfName(AName);
  If (I<>-1) then
    Result:=Items[i].Value
  else
    Result:=Null;
end;

function TJSONObject.Get(const AName: String; ADefault: TJSONFloat
  ): TJSONFloat;

Var
  D : TJSONData;

begin
  D:=Find(AName,jtNumber);
  If D<>Nil then
    Result:=D.AsFloat
  else
    Result:=ADefault;
end;

function TJSONObject.Get(const AName: String; ADefault: Integer
  ): Integer;

Var
  D : TJSONData;

begin
  D:=Find(AName,jtNumber);
  If D<>Nil then
    Result:=D.AsInteger
  else
    Result:=ADefault;
end;

function TJSONObject.Get(const AName: String; ADefault: Int64): Int64;
Var
  D : TJSONData;

begin
  D:=Find(AName,jtNumber);
  If D<>Nil then
    Result:=D.AsInt64
  else
    Result:=ADefault;
end;

function TJSONObject.Get(const AName: String; ADefault: UInt64): UInt64;
Var
  D : TJSONData;

begin
  D:=Find(AName,jtNumber);
  If D<>Nil then
    Result:=D.AsQWord
  else
    Result:=ADefault;
end;

function TJSONObject.Get(const AName: String; ADefault: Boolean
  ): Boolean;
Var
  D : TJSONData;

begin
  D:=Find(AName,jtBoolean);
  If D<>Nil then
    Result:=D.AsBoolean
  else
    Result:=ADefault;
end;

function TJSONObject.Get(const AName: String; ADefault: TJSONStringType
  ): TJSONStringType;
Var
  D : TJSONData;

begin
  D:=Find(AName,jtString);
  If (D<>Nil) then
    Result:=D.AsString
  else
    Result:=ADefault;
end;


function TJSONObject.Get(const AName: String; ADefault: TJSONArray
  ): TJSONArray;
Var
  D : TJSONData;

begin
  D:=Find(AName,jtArray);
  If (D<>Nil) then
    Result:=TJSONArray(D)
  else
    Result:=ADefault;
end;

function TJSONObject.Get(const AName: String; ADefault: TJSONObject
  ): TJSONObject;
Var
  D : TJSONData;

begin
  D:=Find(AName,jtObject);
  If (D<>Nil) then
    Result:=TJSONObject(D)
  else
    Result:=ADefault;
end;

function TJSONObject.Find(const AName: String): TJSONData;
Var
  I : Integer;

begin
  I:=IndexOfName(AName);
  If (I<>-1) then
    Result:=Items[i]
  else
    Result:=Nil;
end;

function TJSONObject.Find(const AName: String; AType: TJSONType): TJSONData;
begin
  Result:=Find(AName);
  If Assigned(Result) and (Result.JSONType<>AType) then
    Result:=Nil;
end;

function TJSONObject.Find(const key: TJSONStringType; out AValue: TJSONData): boolean;
begin
  AValue := Find(key);
  Result := assigned(AValue);
end;

function TJSONObject.Find(const key: TJSONStringType; out AValue: TJSONObject): boolean;
var
  v: TJSONData;
begin
  v := Find(key);
  Result := assigned(v) and (v.JSONType = jtObject);
  if Result then
    AValue := TJSONObject(v);
end;

function TJSONObject.Find(const key: TJSONStringType; out AValue: TJSONArray): boolean;
var
  v: TJSONData;
begin
  v := Find(key);
  Result := assigned(v) and (v.JSONType = jtArray);
  if Result then
    AValue := TJSONArray(v);
end;

function TJSONObject.Find(const key: TJSONStringType; out AValue: TJSONString): boolean;
var
  v: TJSONData;
begin
  v := Find(key);
  Result := assigned(v) and (v.JSONType = jtString);
  if Result then
    AValue := TJSONString(v);
end;

function TJSONObject.Find(const key: TJSONStringType; out AValue: TJSONBoolean): boolean;
var
  v: TJSONData;
begin
  v := Find(key);
  Result := assigned(v) and (v.JSONType = jtBoolean);
  if Result then
    AValue := TJSONBoolean(v);
end;

function TJSONObject.Find(const key: TJSONStringType; out AValue: TJSONNumber): boolean;
var
  v: TJSONData;
begin
  v := Find(key);
  Result := assigned(v) and (v.JSONType = jtNumber);
  if Result then
    AValue := TJSONNumber(v);
end;

initialization
  // Need to force initialization;
  TJSONData.DetermineElementSeparators;
  TJSONObject.DetermineElementQuotes;
end.

