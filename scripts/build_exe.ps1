Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-IsccPath {
  $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }

  $paths = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
  )
  foreach ($p in $paths) {
    if ($p -and (Test-Path -LiteralPath $p)) {
      return $p
    }
  }
  return $null
}

function Get-PubspecValue {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Pattern
  )
  $m = Select-String -Path $Path -Pattern $Pattern | Select-Object -First 1
  if ($m) {
    return $m.Matches[0].Groups[1].Value.Trim()
  }
  return $null
}

function To-CamelCase {
  param([Parameter(Mandatory = $true)][string]$Value)
  $parts = $Value -split '[-_\s]+'
  $result = ''
  foreach ($part in $parts) {
    if ([string]::IsNullOrWhiteSpace($part)) {
      continue
    }
    $first = $part.Substring(0, 1).ToUpperInvariant()
    $rest = ''
    if ($part.Length -gt 1) {
      $rest = $part.Substring(1)
    }
    $result += "$first$rest"
  }
  return $result
}

function Add-FileAssociationSection {
  param(
    [Parameter(Mandatory = $true)][string]$IssPath,
    [Parameter(Mandatory = $true)][string]$ExeName
  )

  $content = Get-Content -LiteralPath $IssPath -Raw -Encoding utf8
  if ($content -match 'Software\\Classes\\\.gmh') {
    return
  }

  $registrySection = @'

[Registry]
Root: HKCU; Subkey: "Software\Classes\.gmh"; ValueType: string; ValueName: ""; ValueData: "gm_hub.gmh"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\gm_hub.gmh"; ValueType: string; ValueName: ""; ValueData: "GM Hub Project File"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\gm_hub.gmh\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyExeName},0"
Root: HKCU; Subkey: "Software\Classes\gm_hub.gmh\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyExeName}"" ""%1"""
'@

  $withDefine = "#define MyExeName ""$ExeName""" + "`r`n" + $content.TrimEnd() + $registrySection + "`r`n"
  Set-Content -LiteralPath $IssPath -Value $withDefine -Encoding utf8
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

flutter pub get
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$flutterBat = (Get-Command flutter -ErrorAction Stop).Source
$flutterBin = Split-Path -Parent $flutterBat
$flutterDart = Join-Path $flutterBin 'cache\dart-sdk\bin\dart.exe'

if (-not (Test-Path -LiteralPath $flutterDart)) {
  throw "Flutter bundled dart.exe not found: $flutterDart"
}

$dartAppData = Join-Path $repoRoot '.dart_appdata'
if (-not (Test-Path -LiteralPath $dartAppData)) {
  New-Item -ItemType Directory -Path $dartAppData | Out-Null
}

$env:APPDATA = $dartAppData

$isccPath = Resolve-IsccPath
if (-not $isccPath) {
  throw "Inno Setup not found. Install it first, e.g. `winget install JRSoftware.InnoSetup` or download from https://jrsoftware.org/isdl.php"
}

$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
if (-not (Test-Path -LiteralPath $pubspecPath)) {
  throw "pubspec.yaml not found: $pubspecPath"
}

$appName = Get-PubspecValue -Path $pubspecPath -Pattern '^\s*name:\s*([^\s#]+)\s*$'
$configuredName = Get-PubspecValue -Path $pubspecPath -Pattern '^\s{2}name:\s*(.+?)\s*$'
if ($configuredName) {
  $installerName = $configuredName
} elseif ($appName) {
  $installerName = $appName
} else {
  $installerName = 'gm_hub'
}

$buildType = 'release'
if ($args -contains '--debug') {
  $buildType = 'debug'
} elseif ($args -contains '--profile') {
  $buildType = 'profile'
}

$camel = To-CamelCase -Value $installerName
$scriptPath = Join-Path ([IO.Path]::GetTempPath()) "$camel`Installer\$buildType\inno-script.iss"

& $flutterDart run inno_bundle --no-install-inno --no-gen-app-id --no-gen-publisher --no-installer @args
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

if (-not (Test-Path -LiteralPath $scriptPath)) {
  throw "Generated ISS file not found: $scriptPath"
}

Add-FileAssociationSection -IssPath $scriptPath -ExeName "$appName.exe"

& $isccPath $scriptPath
exit $LASTEXITCODE
