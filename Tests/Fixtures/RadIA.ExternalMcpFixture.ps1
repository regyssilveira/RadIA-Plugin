param(
    [Parameter(Mandatory = $true)]
    [string]$StateFile
)

$ErrorActionPreference = "Stop"
[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$traceFile = [Environment]::GetEnvironmentVariable("RADIA_MCP_FIXTURE_LOG")

function Write-Trace {
    param([string]$Text)

    if (-not [string]::IsNullOrWhiteSpace($traceFile)) {
        Add-Content -LiteralPath $traceFile -Value $Text -Encoding UTF8
    }
}

function Write-ProtocolMessage {
    param([hashtable]$Message)

    [Console]::WriteLine(($Message | ConvertTo-Json -Depth 20 -Compress))
    [Console]::Out.Flush()
    Write-Trace ("send id=" + [string]$Message.id)
}

function Write-Result {
    param(
        [object]$Id,
        [object]$Result
    )

    Write-ProtocolMessage ([ordered]@{
        jsonrpc = "2.0"
        id = $Id
        result = $Result
    })
}

function Tool-List {
    return @(
        [ordered]@{
            name = "read_state"
            description = "Reads the isolated fixture state."
            inputSchema = [ordered]@{ type = "object" }
        },
        [ordered]@{
            name = "write_state"
            description = "Writes the isolated fixture state."
            inputSchema = [ordered]@{
                type = "object"
                properties = [ordered]@{
                    value = [ordered]@{ type = "string" }
                }
                required = @("value")
            }
        },
        [ordered]@{
            name = "slow_read"
            description = "Returns state after a cancellable delay."
            inputSchema = [ordered]@{ type = "object" }
        }
    )
}

function Read-State {
    if (Test-Path -LiteralPath $StateFile) {
        return [IO.File]::ReadAllText($StateFile, [Text.Encoding]::UTF8)
    }
    return "initial"
}

function Invoke-Tool {
    param([object]$Request)

    $name = [string]$Request.params.name
    if ($name -eq "write_state") {
        $value = [string]$Request.params.arguments.value
        [IO.File]::WriteAllText($StateFile, $value, [Text.UTF8Encoding]::new($false))
        return "written"
    }
    if ($name -eq "slow_read") {
        Start-Sleep -Milliseconds 1200
        return Read-State
    }
    return Read-State
}

while (($line = [Console]::ReadLine()) -ne $null) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }
    $request = $line | ConvertFrom-Json
    $method = [string]$request.method
    Write-Trace ("receive method=" + $method + " id=" + [string]$request.id)
    if ($method -eq "initialize") {
        Write-Result $request.id ([ordered]@{
            protocolVersion = "2025-06-18"
            capabilities = [ordered]@{
                tools = [ordered]@{}
                resources = [ordered]@{}
                prompts = [ordered]@{}
            }
            serverInfo = [ordered]@{
                name = "radia-external-mcp-fixture"
                version = "1.0.0"
            }
        })
    } elseif ($method -eq "tools/list") {
        Write-Result $request.id ([ordered]@{ tools = Tool-List })
    } elseif ($method -eq "resources/list") {
        Write-Result $request.id ([ordered]@{
            resources = @([ordered]@{
                uri = "fixture://state"
                name = "Fixture state"
                description = "Current isolated fixture state."
                mimeType = "text/plain"
            })
        })
    } elseif ($method -eq "prompts/list") {
        Write-Result $request.id ([ordered]@{
            prompts = @([ordered]@{
                name = "inspect_state"
                description = "Inspect the current fixture state."
                arguments = @()
            })
        })
    } elseif ($method -eq "tools/call") {
        try {
            $value = Invoke-Tool $request
            Write-Result $request.id ([ordered]@{
                content = @([ordered]@{ type = "text"; text = $value })
            })
        } catch {
            Write-Trace ("tool error=" + $_.Exception.Message)
            Write-ProtocolMessage ([ordered]@{
                jsonrpc = "2.0"
                id = $request.id
                error = [ordered]@{
                    code = -32603
                    message = "Fixture tool failed."
                }
            })
        }
    }
}
