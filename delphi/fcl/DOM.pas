{ A stand-in for Free Pascal's fcl-xml DOM unit, for Delphi: the part of it that the chart's map reader
  (tyControls.AdvanceChart.Geo and .GeoSvg) uses, under FPC's names. Compiled by Delphi only: Lazarus
  builds with FPC's own unit. New code of the TyAdvanceChart project, not a port of FPC's dom.pp; its
  results are checked node by node against FPC's by the 'xml' section of delphi/tests/tyadvchart_fcl.dpr.

  What it is:
  - a read-only tree: TXMLDocument owns every node (freeing it frees the tree); the nodes are built by
    the reader in XMLRead through the TXMLDocument.Create* functions, TDOMNode.AppendChild and
    TDOMElement.SetAttribute;
  - node types, NodeName and NodeValue as FPC gives them: '#document', '#text', '#comment',
    '#cdata-section'; a processing instruction is named by its target and its value is its data; the
    document type node is named by the root name and has an empty value; an element's value is empty;
  - TextContent as FPC computes it: an element's is the text of its text and CDATA descendants (comments
    and processing instructions left out), the document's is empty, any other node's is its value;
  - attributes are not children: GetAttributeNode finds one by its name as written (no namespaces), and
    returns nil when there is none; the node it returns has type ATTRIBUTE_NODE, the attribute's name
    and its value.
  What it is not: no editing after the reader is done (no RemoveChild, no NodeValue setter), no
  namespaces, no named node maps, no entity or notation nodes. }
unit DOM;

interface

uses
  SysUtils, Classes;

type
  DOMString = UnicodeString;

const
  ELEMENT_NODE = 1;
  ATTRIBUTE_NODE = 2;
  TEXT_NODE = 3;
  CDATA_SECTION_NODE = 4;
  PROCESSING_INSTRUCTION_NODE = 7;
  COMMENT_NODE = 8;
  DOCUMENT_NODE = 9;
  DOCUMENT_TYPE_NODE = 10;

type
  TXMLDocument = class;

  TDOMNode = class
  private
    FNodeType: Integer;
    FNodeName: DOMString;
    FNodeValue: DOMString;
    FParentNode: TDOMNode;
    FFirstChild: TDOMNode;
    FLastChild: TDOMNode;
    FNextSibling: TDOMNode;
  protected
    function GetTextContent: DOMString; virtual;
  public
    { A node of type ANodeType with that name and value, in no tree yet. }
    constructor Create(ANodeType: Integer; const ANodeName, ANodeValue: DOMString);
    { Frees the children too. }
    destructor Destroy; override;
    { Appends ANewChild, which must not be in a tree yet, as the last child; returns it. }
    function AppendChild(ANewChild: TDOMNode): TDOMNode;
    property NodeType: Integer read FNodeType;
    property NodeName: DOMString read FNodeName;
    property NodeValue: DOMString read FNodeValue;
    property FirstChild: TDOMNode read FFirstChild;
    property NextSibling: TDOMNode read FNextSibling;
    property ParentNode: TDOMNode read FParentNode;
    property TextContent: DOMString read GetTextContent;
  end;

  TDOMElement = class(TDOMNode)
  private
    FAttributes: array of TDOMNode;
  protected
    function GetTextContent: DOMString; override;
  public
    destructor Destroy; override;
    { The attribute named AName (as written), nil when the element has none. }
    function GetAttributeNode(const AName: DOMString): TDOMNode;
    { Sets the attribute AName to AValue, adding it when the element has none of that name. }
    procedure SetAttribute(const AName, AValue: DOMString);
  end;

  TXMLDocument = class(TDOMNode)
  private
    function GetDocumentElement: TDOMElement;
  protected
    function GetTextContent: DOMString; override;
  public
    constructor Create;
    function CreateElement(const ATagName: DOMString): TDOMElement;
    function CreateTextNode(const AData: DOMString): TDOMNode;
    function CreateComment(const AData: DOMString): TDOMNode;
    function CreateCDATASection(const AData: DOMString): TDOMNode;
    function CreateProcessingInstruction(const ATarget, AData: DOMString): TDOMNode;
    { The document type node of a DOCTYPE declaration whose root name is AName. }
    function CreateDocumentTypeNode(const AName: DOMString): TDOMNode;
    { The first child that is an element; nil when there is none. }
    property DocumentElement: TDOMElement read GetDocumentElement;
  end;

  EDOMError = class(Exception);

implementation

{ TDOMNode }

constructor TDOMNode.Create(ANodeType: Integer; const ANodeName, ANodeValue: DOMString);
begin
  inherited Create;
  FNodeType := ANodeType;
  FNodeName := ANodeName;
  FNodeValue := ANodeValue;
end;

destructor TDOMNode.Destroy;
var
  c, n: TDOMNode;
begin
  c := FFirstChild;
  while c <> nil do
  begin
    n := c.FNextSibling;
    c.Free;
    c := n;
  end;
  inherited Destroy;
end;

function TDOMNode.AppendChild(ANewChild: TDOMNode): TDOMNode;
begin
  if (ANewChild = nil) or (ANewChild.FParentNode <> nil) or (ANewChild = Self) then
    raise EDOMError.Create('AppendChild: the node is nil, already in a tree, or the parent itself');
  ANewChild.FParentNode := Self;
  if FLastChild = nil then
    FFirstChild := ANewChild
  else
    FLastChild.FNextSibling := ANewChild;
  FLastChild := ANewChild;
  Result := ANewChild;
end;

function TDOMNode.GetTextContent: DOMString;
begin
  Result := FNodeValue;
end;

{ TDOMElement }

destructor TDOMElement.Destroy;
var
  i: Integer;
begin
  for i := 0 to High(FAttributes) do
    FAttributes[i].Free;
  inherited Destroy;
end;

{ The text of the text and CDATA descendants, as FPC's TDOMNode_WithChildren.GetTextContent: a text
  child gives its value, a comment or a processing instruction nothing, any other child its own
  TextContent (an element's, recursively; a CDATA section's value). Collected in one buffer. }
procedure CollectText(ANode: TDOMNode; var ABuf: DOMString; var ALen: Integer);
var
  c: TDOMNode;
  v: DOMString;
begin
  c := ANode.FirstChild;
  while c <> nil do
  begin
    case c.NodeType of
      COMMENT_NODE, PROCESSING_INSTRUCTION_NODE: ;
      ELEMENT_NODE: CollectText(c, ABuf, ALen);
    else
      v := c.NodeValue;
      if Length(v) > 0 then
      begin
        if ALen + Length(v) > Length(ABuf) then
          SetLength(ABuf, 2 * (ALen + Length(v)));
        Move(v[1], ABuf[ALen + 1], Length(v) * SizeOf(WideChar));
        Inc(ALen, Length(v));
      end;
    end;
    c := c.NextSibling;
  end;
end;

function TDOMElement.GetTextContent: DOMString;
var
  n: Integer;
begin
  Result := '';
  n := 0;
  CollectText(Self, Result, n);
  SetLength(Result, n);
end;

function TDOMElement.GetAttributeNode(const AName: DOMString): TDOMNode;
var
  i: Integer;
begin
  for i := 0 to High(FAttributes) do
    if FAttributes[i].NodeName = AName then
    begin
      Result := FAttributes[i];
      Exit;
    end;
  Result := nil;
end;

procedure TDOMElement.SetAttribute(const AName, AValue: DOMString);
var
  a: TDOMNode;
  n: Integer;
begin
  a := GetAttributeNode(AName);
  if a <> nil then
  begin
    a.FNodeValue := AValue;
    Exit;
  end;
  n := Length(FAttributes);
  SetLength(FAttributes, n + 1);
  FAttributes[n] := TDOMNode.Create(ATTRIBUTE_NODE, AName, AValue); // no parent, as in the DOM
end;

{ TXMLDocument }

constructor TXMLDocument.Create;
begin
  inherited Create(DOCUMENT_NODE, '#document', '');
end;

function TXMLDocument.GetTextContent: DOMString;
begin
  Result := '';
end;

function TXMLDocument.GetDocumentElement: TDOMElement;
var
  c: TDOMNode;
begin
  c := FirstChild;
  while (c <> nil) and not (c is TDOMElement) do
    c := c.NextSibling;
  Result := TDOMElement(c);
end;

function TXMLDocument.CreateElement(const ATagName: DOMString): TDOMElement;
begin
  Result := TDOMElement.Create(ELEMENT_NODE, ATagName, '');
end;

function TXMLDocument.CreateTextNode(const AData: DOMString): TDOMNode;
begin
  Result := TDOMNode.Create(TEXT_NODE, '#text', AData);
end;

function TXMLDocument.CreateComment(const AData: DOMString): TDOMNode;
begin
  Result := TDOMNode.Create(COMMENT_NODE, '#comment', AData);
end;

function TXMLDocument.CreateCDATASection(const AData: DOMString): TDOMNode;
begin
  Result := TDOMNode.Create(CDATA_SECTION_NODE, '#cdata-section', AData);
end;

function TXMLDocument.CreateProcessingInstruction(const ATarget, AData: DOMString): TDOMNode;
begin
  Result := TDOMNode.Create(PROCESSING_INSTRUCTION_NODE, ATarget, AData);
end;

function TXMLDocument.CreateDocumentTypeNode(const AName: DOMString): TDOMNode;
begin
  Result := TDOMNode.Create(DOCUMENT_TYPE_NODE, AName, '');
end;

end.
