<#
apigw_diagnostics.ps1

Usage examples:
PowerShell:
  pwsh -ExecutionPolicy Bypass -File .\apigw_diagnostics.ps1 
  # or with parameters:
  pwsh -ExecutionPolicy Bypass -File .\apigw_diagnostics.ps1 -ApiUrl "https://83mbqvr4j7.execute-api.us-east-1.amazonaws.com/prod/claims/claim-123/generate" -ElbUrl "http://a163a9...elb.amazonaws.com/api/v1/claims/claim-123/generate" -StartMinutesAgo 30 -AwsProfile default

This script performs three things:
  1. Calls the API Gateway endpoint and captures status, headers, and body.
  2. Calls the backend ELB (direct) to compare status/body.
  3. Uses AWS CLI to fetch recent CloudWatch API Gateway execution logs (optionally filtered by RequestId).

Requirements:
  - PowerShell (Windows PowerShell or pwsh)
  - AWS CLI configured in the environment if you want to fetch CloudWatch logs

#>

param(
  [string]$ApiUrl = "https://83mbqvr4j7.execute-api.us-east-1.amazonaws.com/prod/claims/claim-123/generate",
  [string]$ElbUrl = "http://a163a96921dd24d8984b2f7dc356f3ff-1178733739.us-east-1.elb.amazonaws.com/api/v1/claims/claim-123/generate",
  [int]$StartMinutesAgo = 30,
  [string]$AwsProfile = $null,
  [string]$FilterRequestId = $null
)

function Invoke-ApiGateway {
  param([string]$Url)
  Write-Output "`n--- Invoking API Gateway: $Url ---`n"
  try {
    $resp = Invoke-WebRequest -Uri $Url -Method POST -ContentType "application/json" -Body '{"test":"data"}' -UseBasicParsing -ErrorAction Stop
    Write-Output "=== API GATEWAY RESPONSE ==="
    Write-Output "StatusCode: $($resp.StatusCode)"
    Write-Output "Headers:"
    $resp.Headers.GetEnumerator() | ForEach-Object { Write-Output "{0}: {1}" -f $_.Name, ($_.Value -join ',') }
    Write-Output "Body:`n$($resp.Content)"

    # extract request ids from headers if present
    $rid = $null
    $possible = @('x-amzn-RequestId','x-amz-apigw-id','X-Amzn-Trace-Id')
    foreach ($h in $possible) {
      if ($resp.Headers[$h]) { $rid = $resp.Headers[$h]; break }
    }
    return @{Success=$true; Response=$resp; RequestId=$rid}
  } catch {
    Write-Output "=== API GATEWAY ERROR RESPONSE ==="
    $err = $_.Exception.Response
    if ($err -ne $null) {
      try { $status = $err.StatusCode.value__ } catch { $status = "Unknown" }
      Write-Output "StatusCode: $status"
      Write-Output "Headers:"
      foreach ($k in $err.Headers.AllKeys) { Write-Output "$k: $($err.Headers[$k] -join ',')" }
      $sr = New-Object System.IO.StreamReader($err.GetResponseStream())
      $body = $sr.ReadToEnd()
      $sr.Close()
      Write-Output "Body:`n$body"

      $rid = $err.Headers['x-amzn-RequestId'] -or $err.Headers['x-amz-apigw-id'] -or $err.Headers['X-Amzn-Trace-Id']
      return @{Success=$false; StatusCode=$status; Body=$body; RequestId=$rid}
    } else {
      Write-Output "Error: $($_.Exception.Message)"
      return @{Success=$false}
    }
  }
}

function Invoke-ELB {
  param([string]$Url)
  Write-Output "`n--- Invoking ELB directly: $Url ---`n"
  try {
    $resp = Invoke-WebRequest -Uri $Url -Method POST -ContentType "application/json" -Body '{"test":"data"}' -UseBasicParsing -ErrorAction Stop
    Write-Output "=== ELB DIRECT RESPONSE ==="
    Write-Output "StatusCode: $($resp.StatusCode)"
    Write-Output "Headers:"
    $resp.Headers.GetEnumerator() | ForEach-Object { Write-Output "{0}: {1}" -f $_.Name, ($_.Value -join ',') }
    Write-Output "Body:`n$($resp.Content)"
    return @{Success=$true; Response=$resp}
  } catch {
    Write-Output "=== ELB ERROR RESPONSE ==="
    $err = $_.Exception.Response
    if ($err -ne $null) {
      try { $status = $err.StatusCode.value__ } catch { $status = "Unknown" }
      Write-Output "StatusCode: $status"
      Write-Output "Headers:"
      foreach ($k in $err.Headers.AllKeys) { Write-Output "$k: $($err.Headers[$k] -join ',')" }
      $sr = New-Object System.IO.StreamReader($err.GetResponseStream())
      $body = $sr.ReadToEnd()
      $sr.Close()
      Write-Output "Body:`n$body"
      return @{Success=$false; StatusCode=$status; Body=$body}
    } else {
      Write-Output "Error: $($_.Exception.Message)"
      return @{Success=$false}
    }
  }
}

function Fetch-ApiGatewayLogs {
  param(
    [string]$ApiUrl,
    [int]$MinutesAgo = 30,
    [string]$AwsProfile = $null,
    [string]$RequestId = $null
  )

  # require aws cli
  $awsCmd = Get-Command aws -ErrorAction SilentlyContinue
  if (-not $awsCmd) {
    Write-Output "AWS CLI not found in PATH — skipping CloudWatch log fetch. Install/configure AWS CLI to fetch logs."
    return
  }

  # extract API id and stage from the URL if possible
  $apiId = $null; $stage = $null
  if ($ApiUrl -match "^https?://([^.]+)\.execute-api\.[^/]+/([^/]+)/") {
    $apiId = $matches[1]
    $stage = $matches[2]
  } else {
    Write-Output "Could not extract API id/stage from ApiUrl. Please pass a URL in the form https://{api-id}.execute-api.region.amazonaws.com/{stage}/..."
    return
  }

  $logGroup = "API-Gateway-Execution-Logs_${apiId}/${stage}"
  Write-Output "`nFetching logs from CloudWatch log group: $logGroup (last $MinutesAgo minutes)"

  $start = [int64]((Get-Date).AddMinutes(-$MinutesAgo).ToUniversalTime() - (Get-Date "1970-01-01")).TotalMilliseconds

  $baseArgs = @('logs','filter-log-events','--log-group-name',$logGroup,'--start-time',$start,'--limit','200')
  if ($RequestId) { $baseArgs += @('--filter-pattern',$RequestId) }
  if ($AwsProfile) { $baseArgs += @('--profile',$AwsProfile) }

  Write-Output "Running: aws $($baseArgs -join ' ')`n"
  try {
    $out = & aws @baseArgs
    if ($LASTEXITCODE -ne 0) { Write-Output "aws CLI returned exit code $LASTEXITCODE"; return }
    Write-Output "=== CloudWatch filter-log-events output (JSON) ==="
    Write-Output $out
    return $out
  } catch {
    Write-Output "Failed to run aws CLI: $($_.Exception.Message)"
  }
}

# Main
Write-Output "Running API Gateway diagnostics script..."

# $ApiUrl and $ElbUrl are from parameters
$apiResult = Invoke-ApiGateway -Url $ApiUrl

# determine request id (if any)
$reqId = $null
if ($apiResult.RequestId) { $reqId = $apiResult.RequestId }
elseif ($FilterRequestId) { $reqId = $FilterRequestId }

if ($reqId) { Write-Output "Captured RequestId: $reqId" }

# Call ELB
$elbResult = Invoke-ELB -Url $ElbUrl

# Fetch logs (optionally using request id)
Fetch-ApiGatewayLogs -ApiUrl $ApiUrl -MinutesAgo $StartMinutesAgo -AwsProfile $AwsProfile -RequestId $reqId

Write-Output "`nDone. If you want, rerun with -StartMinutesAgo 10 or -FilterRequestId '<requestId>' to narrow logs." 
