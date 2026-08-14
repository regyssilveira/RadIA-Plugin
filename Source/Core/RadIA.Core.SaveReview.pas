unit RadIA.Core.SaveReview;

interface

type
  TRadIASaveReviewFinding = record
  private
    FLine: Integer;
    FMessage: string;
    FText: string;
  public
    constructor Create(
      const ALine: Integer;
      const AMessage: string;
      const AText: string
    );
    property Line: Integer read FLine;
    property Message: string read FMessage;
    property Text: string read FText;
  end;

  TRadIASaveReviewAnalyzer = class
  public
    class function Analyze(
      const AContent: string;
      const AMaxFindings: Integer = 20
    ): TArray<TRadIASaveReviewFinding>; static;
  end;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.Math,
  System.SysUtils;

constructor TRadIASaveReviewFinding.Create(
  const ALine: Integer;
  const AMessage: string;
  const AText: string
);
begin
  FLine := ALine;
  FMessage := AMessage;
  FText := AText;
end;

class function TRadIASaveReviewAnalyzer.Analyze(
  const AContent: string;
  const AMaxFindings: Integer
): TArray<TRadIASaveReviewFinding>;
var
  LFindings: TList<TRadIASaveReviewFinding>;
  LIndex: Integer;
  LLimit: Integer;
  LLine: string;
  LLines: TStringList;
begin
  LLimit := EnsureRange(AMaxFindings, 1, 100);
  LFindings := TList<TRadIASaveReviewFinding>.Create;
  LLines := TStringList.Create;
  try
    LLines.Text := AContent;
    for LIndex := 0 to LLines.Count - 1 do
    begin
      LLine := LLines[LIndex];
      if Length(LLine) > 120 then
        LFindings.Add(TRadIASaveReviewFinding.Create(
          LIndex + 1,
          'Line exceeds the project limit of 120 characters.',
          LLine
        ))
      else if LLine.EndsWith(' ') or LLine.EndsWith(#9) then
        LFindings.Add(TRadIASaveReviewFinding.Create(
          LIndex + 1,
          'Line contains trailing whitespace.',
          LLine
        ))
      else if LLine.Contains('TODO') or LLine.Contains('FIXME') then
        LFindings.Add(TRadIASaveReviewFinding.Create(
          LIndex + 1,
          'Saved code contains an unresolved TODO or FIXME marker.',
          LLine
        ));
      if LFindings.Count >= LLimit then
        Break;
    end;
    Result := LFindings.ToArray;
  finally
    LLines.Free;
    LFindings.Free;
  end;
end;

end.
