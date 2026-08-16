unit RadIA.Core.IndyLoopback;

interface

uses
  RadIA.Core.Interfaces,
  IdHTTPServer, IdCustomHTTPServer, IdContext;

type
  { Indy-based implementation of the local loopback server }
  TRadIAIndyLoopbackServer = class(TInterfacedObject, IRadIALoopbackServer)
  private
    FServer: TIdHTTPServer;
    FCallback: TLoopbackCallback;
    FPort: Word;
    procedure OnCommandGetHandler(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    function ExtractQueryParam(const AQuery, AParam: string): string;
    procedure ParseCallbackRequest(ARequestInfo: TIdHTTPRequestInfo;
      out ACode: string; out AError: string);
    procedure HandleCallbackRoute(ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
    function GetSuccessHtml: string;
    function GetFailureHtml(const AError: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    { IRadIALoopbackServer }
    procedure Start(const APort: Word; const ACallback: TLoopbackCallback);
    procedure Stop;
    function GetActivePort: Word;
    function IsRunning: Boolean;
  end;

implementation

uses
  System.SysUtils, IdGlobal, IdSocketHandle, System.NetEncoding,
  RadIA.Core.Logger;

{ TRadIAIndyLoopbackServer }

constructor TRadIAIndyLoopbackServer.Create;
begin
  inherited Create;
  FServer := TIdHTTPServer.Create(nil);
  FServer.OnCommandGet := OnCommandGetHandler;
end;

destructor TRadIAIndyLoopbackServer.Destroy;
begin
  Stop;
  FServer.Free;
  inherited Destroy;
end;

function TRadIAIndyLoopbackServer.ExtractQueryParam(const AQuery, AParam: string): string;
var
  LParts: TArray<string>;
  LPart: string;
  LEqualPos: Integer;
begin
  Result := '';
  LParts := AQuery.Split(['&']);
  for LPart in LParts do
  begin
    if LPart.StartsWith(AParam + '=', True) then
    begin
      LEqualPos := LPart.IndexOf('=');
      if LEqualPos >= 0 then
      begin
        Result := LPart.Substring(LEqualPos + 1);
        Result := TNetEncoding.URL.Decode(Result);
        Exit;
      end;
    end;
  end;
end;

function TRadIAIndyLoopbackServer.GetActivePort: Word;
begin
  Result := FPort;
end;

function TRadIAIndyLoopbackServer.IsRunning: Boolean;
begin
  Result := FServer.Active;
end;

procedure TRadIAIndyLoopbackServer.Start(const APort: Word; const ACallback: TLoopbackCallback);
var
  LBinding: TIdSocketHandle;
begin
  Stop;
  FPort := APort;
  FCallback := ACallback;

  FServer.Bindings.Clear;
  LBinding := FServer.Bindings.Add;
  LBinding.IP := '127.0.0.1';
  LBinding.Port := FPort;
  LBinding.ReuseSocket := rsTrue;

  TLogger.Log('Starting Indy loopback server on 127.0.0.1:' + FPort.ToString, 'IndyLoopback');
  FServer.Active := True;
end;

procedure TRadIAIndyLoopbackServer.Stop;
begin
  if FServer.Active then
  begin
    TLogger.Log('Stopping Indy loopback server', 'IndyLoopback');
    FServer.Active := False;
    FServer.Bindings.Clear;
  end;
  FCallback := nil;
end;

procedure TRadIAIndyLoopbackServer.ParseCallbackRequest(
  ARequestInfo: TIdHTTPRequestInfo; out ACode: string; out AError: string);
begin
  ACode := ARequestInfo.Params.Values['code'];
  AError := ARequestInfo.Params.Values['error'];

  if ACode.IsEmpty then
  begin
    ACode := ExtractQueryParam(ARequestInfo.QueryParams, 'code');
    if AError.IsEmpty then
      AError := ExtractQueryParam(ARequestInfo.QueryParams, 'error');
  end;
end;

function TRadIAIndyLoopbackServer.GetSuccessHtml: string;
begin
  Result := '<!DOCTYPE html>' + #13#10 +
           '<html>' + #13#10 +
           '<head>' + #13#10 +
           '  <meta charset="utf-8">' + #13#10 +
           '  <title>Rad IA Authentication</title>' + #13#10 +
           '  <style>' + #13#10 +
           '    body { background: linear-gradient(135deg, #121214 0%, #1a1a1e 100%); color: #e1e1e6; ' +
           'font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, ' +
           'Arial, sans-serif; display: flex; align-items: center; justify-content: center; ' +
           'height: 100vh; margin: 0; }' + #13#10 +
           '    .card { background: rgba(255, 255, 255, 0.03); backdrop-filter: blur(8px); ' +
           'border: 1px solid rgba(255, 255, 255, 0.08); padding: 40px; border-radius: 12px; ' +
           'text-align: center; max-width: 450px; box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5); }' + #13#10 +
           '    h1 { color: #00e676; margin-top: 0; font-size: 26px; font-weight: 600; ' +
           'letter-spacing: -0.5px; }' + #13#10 +
           '    p { color: #a8a8b3; font-size: 16px; line-height: 1.6; margin: 16px 0; }' + #13#10 +
           '    .accent { color: #00b0ff; font-weight: 500; }' + #13#10 +
           '  </style>' + #13#10 +
           '</head>' + #13#10 +
           '<body>' + #13#10 +
           '  <div class="card">' + #13#10 +
           '    <h1>Authentication Successful!</h1>' + #13#10 +
           '    <p>You have successfully authorized <span class="accent">Rad IA</span>.</p>' + #13#10 +
           '    <p>You may now close this browser tab and return to your Delphi IDE.</p>' + #13#10 +
           '  </div>' + #13#10 +
           '</body>' + #13#10 +
           '</html>';
end;

function TRadIAIndyLoopbackServer.GetFailureHtml(const AError: string): string;
begin
  Result := '<!DOCTYPE html>' + #13#10 +
           '<html>' + #13#10 +
           '<head>' + #13#10 +
           '  <meta charset="utf-8">' + #13#10 +
           '  <title>Rad IA Authentication Error</title>' + #13#10 +
           '  <style>' + #13#10 +
           '    body { background: linear-gradient(135deg, #121214 0%, #1a1a1e 100%); color: #e1e1e6; ' +
           'font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, ' +
           'Arial, sans-serif; display: flex; align-items: center; justify-content: center; ' +
           'height: 100vh; margin: 0; }' + #13#10 +
           '    .card { background: rgba(255, 255, 255, 0.03); backdrop-filter: blur(8px); ' +
           'border: 1px solid rgba(255, 255, 255, 0.08); padding: 40px; border-radius: 12px; ' +
           'text-align: center; max-width: 450px; box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5); }' + #13#10 +
           '    h1 { color: #ff5252; margin-top: 0; font-size: 26px; font-weight: 600; ' +
           'letter-spacing: -0.5px; }' + #13#10 +
           '    p { color: #a8a8b3; font-size: 16px; line-height: 1.6; margin: 16px 0; }' + #13#10 +
           '    .error-msg { background: rgba(255, 82, 82, 0.1); border: 1px solid rgba(255, 82, 82, 0.2); ' +
           'padding: 12px; border-radius: 6px; font-family: monospace; color: #ff8a80; font-size: 14px; ' +
           'margin-top: 20px; word-break: break-all; }' + #13#10 +
           '  </style>' + #13#10 +
           '</head>' + #13#10 +
           '<body>' + #13#10 +
           '  <div class="card">' + #13#10 +
           '    <h1>Authentication Failed</h1>' + #13#10 +
           '    <p>An error occurred during authentication with Rad IA.</p>' + #13#10 +
           '    <div class="error-msg">' + AError + '</div>' + #13#10 +
           '  </div>' + #13#10 +
           '</body>' + #13#10 +
           '</html>';
end;

procedure TRadIAIndyLoopbackServer.HandleCallbackRoute(
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  LCode, LError: string;
begin
  ParseCallbackRequest(ARequestInfo, LCode, LError);

  AResponseInfo.CharSet := 'utf-8';
  AResponseInfo.ContentType := 'text/html';

  if LError.IsEmpty and not LCode.IsEmpty then
  begin
    AResponseInfo.ResponseNo := 200;
    AResponseInfo.ContentText := GetSuccessHtml;

    TLogger.Log('Successful callback received. Dispatching authorization code.', 'IndyLoopback');
    if Assigned(FCallback) then
      FCallback(LCode, '');
  end
  else
  begin
    if LError.IsEmpty then
      LError := 'No authorization code or parameters received.';

    AResponseInfo.ResponseNo := 400;
    AResponseInfo.ContentText := GetFailureHtml(LError);

    TLogger.Log('Failed callback received: ' + LError, 'IndyLoopback');
    if Assigned(FCallback) then
      FCallback('', LError);
  end;
end;

procedure TRadIAIndyLoopbackServer.OnCommandGetHandler(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  LURI: string;
begin
  LURI := ARequestInfo.URI;
  TLogger.Log('Loopback received HTTP request: ' + LURI, 'IndyLoopback');

  if LURI.StartsWith('/callback', True) or
     LURI.StartsWith('/auth/callback', True) or
     LURI.Equals('/') then
  begin
    HandleCallbackRoute(ARequestInfo, AResponseInfo);
  end
  else
  begin
    AResponseInfo.ResponseNo := 404;
    AResponseInfo.ContentText := 'Not Found';
  end;
end;

end.
