@echo off
setlocal
cd /d "%~dp0\.."
where flutter >nul 2>nul
if errorlevel 1 (
  echo ERREUR: Flutter n'est pas disponible dans le PATH.
  exit /b 1
)
flutter --version | findstr /C:"Flutter 3.35.4" >nul
if errorlevel 1 (
  echo ERREUR: ce projet est valide avec Flutter 3.35.4. Consultez .flutter-version ou .fvmrc.
  flutter --version
  exit /b 1
)
where python >nul 2>nul
if not errorlevel 1 (
  python tools\validate_release.py .
  if errorlevel 1 exit /b 1
)
if not exist android (
  flutter create --platforms=android,windows --org org.godfirst .
  if errorlevel 1 exit /b 1
) else if not exist windows (
  flutter create --platforms=android,windows --org org.godfirst .
  if errorlevel 1 exit /b 1
)
flutter pub get
if errorlevel 1 exit /b 1
flutter analyze
if errorlevel 1 exit /b 1
flutter test
if errorlevel 1 exit /b 1
echo Controles Flutter termines avec Flutter 3.35.4.
endlocal
