$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter n’est pas disponible dans le PATH.'
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$flutterVersion = (flutter --version | Select-Object -First 1)
if ($flutterVersion -notmatch 'Flutter 3\.35\.4') {
  throw "Version Flutter non validée: $flutterVersion. Utilisez Flutter 3.35.4 (voir .flutter-version / .fvmrc)."
}

if (Get-Command python -ErrorAction SilentlyContinue) {
  python tools/validate_release.py .
  if ($LASTEXITCODE -ne 0) { throw 'Validation du corpus échouée.' }
} else {
  Write-Warning 'Python absent: validation indépendante du corpus non exécutée.'
}

if (-not (Test-Path 'android') -or -not (Test-Path 'windows')) {
  Write-Host 'Génération déterministe des plateformes Android et Windows avec Flutter 3.35.4...'
  flutter create --platforms=android,windows --org org.godfirst .
  if ($LASTEXITCODE -ne 0) { throw 'flutter create a échoué.' }
}

flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get a échoué.' }
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'flutter analyze a échoué.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'flutter test a échoué.' }

Write-Host 'Contrôles Flutter terminés avec Flutter 3.35.4.'
