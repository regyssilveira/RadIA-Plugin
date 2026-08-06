unit RadIA.Core.Coverage;

interface

type
  TRadIACoverageSummary = record
  private
    FPackages: Integer;
    FClasses: Integer;
    FMethods: Integer;
    FSourceFiles: Integer;
    FSourceLines: Integer;
    FCoveredLines: Integer;
    FCoveredPercent: Integer;
  public
    constructor Create(
      const APackages: Integer;
      const AClasses: Integer;
      const AMethods: Integer;
      const ASourceFiles: Integer;
      const ASourceLines: Integer;
      const ACoveredLines: Integer;
      const ACoveredPercent: Integer
    );
    function ToJson: string;
    property SourceFiles: Integer read FSourceFiles;
    property SourceLines: Integer read FSourceLines;
    property CoveredLines: Integer read FCoveredLines;
    property CoveredPercent: Integer read FCoveredPercent;
  end;

  TRadIACoverageSummaryParser = class
  private
    function ReadIntegerAttribute(
      const ANode: IInterface;
      const AName: string
    ): Integer;
  public
    function Parse(const AXml: string): TRadIACoverageSummary;
  end;

implementation

uses
  System.JSON,
  System.SysUtils,
  System.Variants,
  Xml.XMLDoc,
  Xml.XMLIntf;

{ TRadIACoverageSummary }

constructor TRadIACoverageSummary.Create(
  const APackages: Integer;
  const AClasses: Integer;
  const AMethods: Integer;
  const ASourceFiles: Integer;
  const ASourceLines: Integer;
  const ACoveredLines: Integer;
  const ACoveredPercent: Integer
);
begin
  FPackages := APackages;
  FClasses := AClasses;
  FMethods := AMethods;
  FSourceFiles := ASourceFiles;
  FSourceLines := ASourceLines;
  FCoveredLines := ACoveredLines;
  FCoveredPercent := ACoveredPercent;
end;

function TRadIACoverageSummary.ToJson: string;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('packages', TJSONNumber.Create(FPackages));
    LJson.AddPair('classes', TJSONNumber.Create(FClasses));
    LJson.AddPair('methods', TJSONNumber.Create(FMethods));
    LJson.AddPair('sourceFiles', TJSONNumber.Create(FSourceFiles));
    LJson.AddPair('sourceLines', TJSONNumber.Create(FSourceLines));
    LJson.AddPair('coveredLines', TJSONNumber.Create(FCoveredLines));
    LJson.AddPair('coveredPercent', TJSONNumber.Create(FCoveredPercent));
    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

{ TRadIACoverageSummaryParser }

function TRadIACoverageSummaryParser.Parse(
  const AXml: string
): TRadIACoverageSummary;
var
  LClasses: Integer;
  LCoveredLines: Integer;
  LCoveredPercent: Integer;
  LDocument: IXMLDocument;
  LMethods: Integer;
  LPackages: Integer;
  LSourceFiles: Integer;
  LSourceLines: Integer;
  LStats: IXMLNode;
begin
  if Trim(AXml) = '' then
    raise EArgumentException.Create('Coverage XML report cannot be empty.');
  LDocument := LoadXMLData(AXml);
  if not Assigned(LDocument.DocumentElement) or
    not SameText(LDocument.DocumentElement.NodeName, 'report') then
    raise EArgumentException.Create(
      'Expected a Delphi Code Coverage report document.'
    );
  LStats := LDocument.DocumentElement.ChildNodes.FindNode('stats');
  if not Assigned(LStats) then
    raise EArgumentException.Create('Coverage report does not contain stats.');
  LPackages := ReadIntegerAttribute(
    LStats.ChildNodes.FindNode('packages'),
    'packages'
  );
  LClasses := ReadIntegerAttribute(
    LStats.ChildNodes.FindNode('classes'),
    'classes'
  );
  LMethods := ReadIntegerAttribute(
    LStats.ChildNodes.FindNode('methods'),
    'methods'
  );
  LSourceFiles := ReadIntegerAttribute(
    LStats.ChildNodes.FindNode('srcfiles'),
    'srcfiles'
  );
  LSourceLines := ReadIntegerAttribute(
    LStats.ChildNodes.FindNode('srclines'),
    'srclines'
  );
  LCoveredLines := ReadIntegerAttribute(
    LStats.ChildNodes.FindNode('coveredlines'),
    'coveredlines'
  );
  LCoveredPercent := ReadIntegerAttribute(
    LStats.ChildNodes.FindNode('coveredpercent'),
    'coveredpercent'
  );
  if LCoveredLines > LSourceLines then
    raise EArgumentException.Create(
      'Covered lines cannot exceed source lines.'
    );
  if LCoveredPercent > 100 then
    raise EArgumentException.Create(
      'Covered percent must be between 0 and 100.'
    );
  Result := TRadIACoverageSummary.Create(
    LPackages,
    LClasses,
    LMethods,
    LSourceFiles,
    LSourceLines,
    LCoveredLines,
    LCoveredPercent
  );
end;

function TRadIACoverageSummaryParser.ReadIntegerAttribute(
  const ANode: IInterface;
  const AName: string
): Integer;
var
  LNode: IXMLNode;
  LValue: string;
begin
  if not Supports(ANode, IXMLNode, LNode) or
    not LNode.HasAttribute('value') then
    raise EArgumentException.Create(
      'Coverage report is missing the ' + AName + ' value.'
    );
  LValue := VarToStr(LNode.Attributes['value']);
  if not TryStrToInt(LValue, Result) or (Result < 0) then
    raise EArgumentException.Create(
      'Coverage report contains an invalid ' + AName + ' value.'
    );
end;

end.
