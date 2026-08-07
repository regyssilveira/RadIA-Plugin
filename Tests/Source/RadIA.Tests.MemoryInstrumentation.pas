unit RadIA.Tests.MemoryInstrumentation;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIAMemoryInstrumentation = class
  public
    [Test]
    procedure AddsDefinesAndFastMMAsFirstUnit;
    [Test]
    procedure PreservesWindowsLineBreaks;
    [Test]
    procedure RejectsAlreadyInstrumentedSource;
    [Test]
    procedure RejectsSourceWithoutUsesClause;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.MemoryInstrumentation;

procedure TTestRadIAMemoryInstrumentation.AddsDefinesAndFastMMAsFirstUnit;
var
  LInstrumented: string;
  LOriginal: string;
begin
  LOriginal :=
    'program Demo;' + sLineBreak + sLineBreak +
    'uses' + sLineBreak +
    '  Vcl.Forms,' + sLineBreak +
    '  Main in ''Main.pas'';' + sLineBreak + sLineBreak +
    'begin' + sLineBreak +
    'end.';
  Assert.IsTrue(
    TRadIAMemoryInstrumentationTransformer.Instrument(
      LOriginal,
      'D:\Delphi\FastMM5\FastMM5.pas',
      'D:\Delphi\FastMM5\FastMM_FullDebugMode.dll',
      'D:\Demo\.radia\memory\latest-fastmm5.log',
      LInstrumented
    )
  );
  Assert.Contains(
    LInstrumented,
    'FastMM_DebugSupportLibraryName'
  );
  Assert.Contains(
    LInstrumented,
    'FastMM_SetEventLogFilename'
  );
  Assert.IsTrue(
    Pos('begin' + sLineBreak + '  FastMM_DebugSupportLibraryName', LInstrumented) > 0
  );
  Assert.Contains(
    LInstrumented,
    '{$DEFINE FastMM_EnableMemoryLeakReporting}'
  );
  Assert.IsTrue(
    Pos('FastMM5 in', LInstrumented) <
    Pos('Vcl.Forms', LInstrumented)
  );
end;

procedure TTestRadIAMemoryInstrumentation.PreservesWindowsLineBreaks;
var
  I: Integer;
  LInstrumented: string;
  LOriginal: string;
begin
  LOriginal := 'program Demo;' + #13#10 + 'uses' + #13#10 +
    '  System.SysUtils;' + #13#10 + 'begin' + #13#10 + 'end.';
  Assert.IsTrue(
    TRadIAMemoryInstrumentationTransformer.Instrument(
      LOriginal,
      'D:\FastMM5\FastMM5.pas',
      'D:\FastMM5\FastMM_FullDebugMode.dll',
      'D:\Demo\.radia\memory\latest-fastmm5.log',
      LInstrumented
    )
  );
  for I := Low(LInstrumented) to High(LInstrumented) do
    if LInstrumented[I] = #10 then
      Assert.IsTrue(
        (I > Low(LInstrumented)) and (LInstrumented[I - 1] = #13),
        'Lone LF at character ' + I.ToString +
        ', previous=' + Ord(LInstrumented[I - 1]).ToString
      );
end;

procedure TTestRadIAMemoryInstrumentation.RejectsAlreadyInstrumentedSource;
var
  LInstrumented: string;
begin
  Assert.IsFalse(
    TRadIAMemoryInstrumentationTransformer.Instrument(
      'program Demo; uses FastMM5 in ''FastMM5.pas''; begin end.',
      'D:\FastMM5\FastMM5.pas',
      'D:\FastMM5\FastMM_FullDebugMode.dll',
      'D:\Demo\.radia\memory\latest-fastmm5.log',
      LInstrumented
    )
  );
end;

procedure TTestRadIAMemoryInstrumentation.RejectsSourceWithoutUsesClause;
var
  LInstrumented: string;
begin
  Assert.IsFalse(
    TRadIAMemoryInstrumentationTransformer.Instrument(
      'program Demo; begin end.',
      'D:\FastMM5\FastMM5.pas',
      'D:\FastMM5\FastMM_FullDebugMode.dll',
      'D:\Demo\.radia\memory\latest-fastmm5.log',
      LInstrumented
    )
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAMemoryInstrumentation);

end.
