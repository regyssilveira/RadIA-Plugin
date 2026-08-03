unit RadIA.Tests.AwsSigner;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestAwsSigner = class
  public
    [Test]
    procedure TestGetAmzDateTimeStrings;
    [Test]
    procedure TestComputeSignatureHeaders;
    [Test]
    procedure TestComputeSignatureHeadersWithSessionToken;
  end;

implementation

uses
  System.Classes, System.SysUtils, RadIA.Core.AwsSigner;

{ TTestAwsSigner }

procedure TTestAwsSigner.TestGetAmzDateTimeStrings;
var
  LAmzDate: string;
  LDateStamp: string;
begin
  TAwsSigV4Signer.GetAmzDateTimeStrings(LAmzDate, LDateStamp);
  Assert.AreEqual(8, Integer(Length(LDateStamp)), 'DateStamp format should be YYYYMMDD');
  Assert.AreEqual(16, Integer(Length(LAmzDate)), 'AmzDate format should be YYYYMMDDTHHMMSSZ');
  Assert.IsTrue(LAmzDate.EndsWith('Z'), 'AmzDate must end with Z');
end;

procedure TTestAwsSigner.TestComputeSignatureHeaders;
var
  LHeaders: TStringList;
  LReq: TAwsSignRequest;
const
  AMZ_DATE = '20260608T170000Z';
begin
  LReq.AccessKeyId := 'TEST_ACCESS_KEY';
  LReq.SecretAccessKey := 'TEST_SECRET';
  LReq.Region := 'us-east-1';
  LReq.Service := 'bedrock';
  LReq.Method := 'POST';
  LReq.Uri := '/invoke';
  LReq.Payload := '{}';
  LReq.AmzDate := AMZ_DATE;
  LReq.DateStamp := '20260608';
  LReq.SessionToken := '';

  LHeaders := TAwsSigV4Signer.ComputeSignatureHeaders(LReq);
  try
    Assert.IsNotNull(LHeaders);
    Assert.AreEqual('application/json', LHeaders.Values['content-type']);
    Assert.AreEqual(AMZ_DATE, LHeaders.Values['x-amz-date']);
    Assert.IsNotEmpty(LHeaders.Values['x-amz-content-sha256']);
    Assert.IsNotEmpty(LHeaders.Values['Authorization']);
    Assert.IsTrue(LHeaders.Values['Authorization'].Contains(
      'Credential=TEST_ACCESS_KEY/20260608/us-east-1/bedrock/aws4_request'));
    Assert.IsTrue(LHeaders.Values['Authorization'].Contains(
      'SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date'));
  finally
    LHeaders.Free;
  end;
end;

procedure TTestAwsSigner.TestComputeSignatureHeadersWithSessionToken;
var
  LHeaders: TStringList;
  LReq: TAwsSignRequest;
const
  SESSION_TOKEN = 'session_token_xyz_123';
  AMZ_DATE = '20260608T170000Z';
begin
  LReq.AccessKeyId := 'TEST_ACCESS_KEY';
  LReq.SecretAccessKey := 'TEST_SECRET';
  LReq.Region := 'us-east-1';
  LReq.Service := 'bedrock';
  LReq.Method := 'POST';
  LReq.Uri := '/invoke';
  LReq.Payload := '{}';
  LReq.AmzDate := AMZ_DATE;
  LReq.DateStamp := '20260608';
  LReq.SessionToken := SESSION_TOKEN;

  LHeaders := TAwsSigV4Signer.ComputeSignatureHeaders(LReq);
  try
    Assert.IsNotNull(LHeaders);
    Assert.AreEqual(SESSION_TOKEN, LHeaders.Values['x-amz-security-token']);
    Assert.IsTrue(LHeaders.Values['Authorization'].Contains(
      'SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date;x-amz-security-token'));
  finally
    LHeaders.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestAwsSigner);

end.
