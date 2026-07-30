$ErrorActionPreference = 'Stop'
$envFile = Join-Path $PSScriptRoot '.env'

if (-not (Test-Path $envFile)) {
  Write-Error "Missing .env file"
}

$envVars = @{}
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  if ($line -and -not $line.StartsWith('#') -and $line.Contains('=')) {
    $k, $v = $line.Split('=', 2)
    $envVars[$k.Trim()] = $v.Trim()
  }
}

$flutter = "E:\LoveLink\FlutterDevEnv\FlutterSDK\bin\flutter.bat"
$defs = @(
  "--dart-define=SUPABASE_URL=$($envVars['SUPABASE_URL'])",
  "--dart-define=SUPABASE_ANON_KEY=$($envVars['SUPABASE_ANON_KEY'])",
  "--dart-define=FUNCTIONS_BASE_URL=$($envVars['FUNCTIONS_BASE_URL'])",
  "--dart-define=RAZORPAY_KEY=$($envVars['RAZORPAY_KEY'])"
) -join ' '

Set-Location $PSScriptRoot
cmd /c "$flutter pub get"
Write-Host "Running: flutter run $defs"
cmd /c "$flutter run $defs"
