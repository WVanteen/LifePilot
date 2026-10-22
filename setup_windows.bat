@echo off
setlocal
cd /d "%~dp0"
if not exist "pubspec.yaml" (
  echo ERROR: Not in LifePilot Flutter project root. Missing pubspec.yaml.
  exit /b 1
)
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter not found. Install Flutter SDK and add flutter\bin to PATH, then open a new terminal.
  echo See README.md for full instructions.
  exit /b 1
)
where dart >nul 2>nul
if errorlevel 1 (
  echo Dart not found. The Flutter SDK should provide dart.
  exit /b 1
)
echo [1/5] Generate Android platform files if needed...
if not exist "android\app" (
  call flutter create --project-name lifepilot --platforms=android --org com.example . || exit /b 1
) else (
  echo Android platform already exists. Skipping flutter create.
)
echo [2/5] Install dependencies...
call flutter pub get || exit /b 1
echo [3/5] Generate Drift source...
call dart run build_runner build --delete-conflicting-outputs || exit /b 1
echo [4/5] Analyze...
call flutter analyze || exit /b 1
echo [5/5] Test...
call flutter test || exit /b 1
echo.
echo Week 1 setup succeeded. Start emulator then run: flutter run
endlocal
