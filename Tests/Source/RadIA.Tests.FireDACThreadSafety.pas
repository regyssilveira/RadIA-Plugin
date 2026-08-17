unit RadIA.Tests.FireDACThreadSafety;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAFireDACThreadSafetyTests = class
  private
    function AnalyzeJson(const ASource: string): string;
  public
    [Test]
    procedure ReportsSharedConnectionAndUnsafeUI;
    [Test]
    procedure AcceptsWorkerLocalConnectionAndMarshalledUI;
    [Test]
    procedure DetectsTaskParallelAndAnonymousThreadContexts;
    [Test]
    procedure IgnoresFireDACUseOutsideBackgroundWork;
    [Test]
    procedure IgnoresComponentsAndWorkersInsideStringsAndComments;
    [Test]
    procedure DoesNotReadBeyondBackgroundContext;
  end;

implementation

uses
  RadIA.Core.FireDAC.ThreadSafety;

function TRadIAFireDACThreadSafetyTests.AnalyzeJson(const ASource: string): string;
var
  LAnalysis: TRadIAFireDACThreadSafetyAnalysis;
  LAnalyzer: TRadIAFireDACThreadSafetyAnalyzer;
begin
  LAnalyzer := TRadIAFireDACThreadSafetyAnalyzer.Create;
  try
    LAnalysis := LAnalyzer.Analyze(ASource, 'Worker.pas');
    try
      Result := LAnalysis.ToJson;
    finally
      LAnalysis.Free;
    end;
  finally
    LAnalyzer.Free;
  end;
end;

procedure TRadIAFireDACThreadSafetyTests.ReportsSharedConnectionAndUnsafeUI;
var
  LJson: string;
begin
  LJson := AnalyzeJson(
    'type TDataModule = class' + sLineBreak +
    '  MainConnection: TFDConnection;' + sLineBreak +
    'end;' + sLineBreak +
    'TTask.Run(' + sLineBreak +
    '  procedure' + sLineBreak +
    '  begin' + sLineBreak +
    '    MainConnection.Open;' + sLineBreak +
    '    Form1.Caption := ''Loaded'';' + sLineBreak +
    '  end);'
  );
  Assert.Contains(LJson, 'firedac.thread.shared-component');
  Assert.Contains(LJson, 'firedac.thread.ui-without-marshalling');
  Assert.Contains(LJson, '"symbol":"MainConnection"');
  Assert.Contains(LJson, '"sharedComponentCount":1');
end;

procedure TRadIAFireDACThreadSafetyTests.AcceptsWorkerLocalConnectionAndMarshalledUI;
var
  LJson: string;
begin
  LJson := AnalyzeJson(
    'var LConnection: TFDConnection;' + sLineBreak +
    'TTask.Run(' + sLineBreak +
    '  procedure' + sLineBreak +
    '  begin' + sLineBreak +
    '    LConnection := TFDConnection.Create(nil);' + sLineBreak +
    '    LConnection.Open;' + sLineBreak +
    '    TThread.Queue(nil, procedure begin Form1.Caption := ''Loaded''; end);' + sLineBreak +
    '  end);'
  );
  Assert.DoesNotContain(LJson, 'firedac.thread.shared-component');
  Assert.DoesNotContain(LJson, 'firedac.thread.ui-without-marshalling');
  Assert.Contains(LJson, '"localComponentCount":1');
  Assert.Contains(LJson, '"marshalledUI":true');
end;

procedure TRadIAFireDACThreadSafetyTests.DetectsTaskParallelAndAnonymousThreadContexts;
var
  LJson: string;
begin
  LJson := AnalyzeJson(
    'TTask.Run(procedure begin end);' + sLineBreak +
    'TParallel.For(0, 1, procedure(I: Integer) begin end);' + sLineBreak +
    'TThread.CreateAnonymousThread(procedure begin end);'
  );
  Assert.Contains(LJson, '"kind":"TTask.Run"');
  Assert.Contains(LJson, '"kind":"TParallel.For"');
  Assert.Contains(LJson, '"kind":"TThread.CreateAnonymousThread"');
end;

procedure TRadIAFireDACThreadSafetyTests.IgnoresFireDACUseOutsideBackgroundWork;
var
  LJson: string;
begin
  LJson := AnalyzeJson(
    'type TDataModule = class' + sLineBreak +
    '  MainQuery: TFDQuery;' + sLineBreak +
    'end;' + sLineBreak +
    'MainQuery.Open;'
  );
  Assert.Contains(LJson, '"contexts":[]');
  Assert.Contains(LJson, '"findings":[]');
end;

procedure TRadIAFireDACThreadSafetyTests.IgnoresComponentsAndWorkersInsideStringsAndComments;
var
  LJson: string;
begin
  LJson := AnalyzeJson(
    '// FakeConnection: TFDConnection;' + sLineBreak +
    'Text := ''TTask.Run(procedure begin FakeConnection.Open; end);'';' + sLineBreak +
    '{ TThread.CreateAnonymousThread(procedure begin end); }'
  );
  Assert.Contains(LJson, '"contexts":[]');
  Assert.Contains(LJson, '"findings":[]');
end;

procedure TRadIAFireDACThreadSafetyTests.DoesNotReadBeyondBackgroundContext;
var
  LJson: string;
begin
  LJson := AnalyzeJson(
    'type TDataModule = class' + sLineBreak +
    '  MainConnection: TFDConnection;' + sLineBreak +
    'end;' + sLineBreak +
    'TTask.Run(procedure begin end);' + sLineBreak +
    'MainConnection.Open;'
  );
  Assert.DoesNotContain(LJson, 'firedac.thread.shared-component');
  Assert.Contains(LJson, '"sharedComponentCount":0');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAFireDACThreadSafetyTests);

end.
