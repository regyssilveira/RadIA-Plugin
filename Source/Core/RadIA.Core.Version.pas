unit RadIA.Core.Version;

interface

const
  CRadIAVersion = '2.17.0';

function RadIAVersionedCaption(const ACaption: string): string;

implementation

uses
  System.SysUtils;

function RadIAVersionedCaption(const ACaption: string): string;
begin
  Result := Format('%s v%s', [ACaption, CRadIAVersion]);
end;

end.
