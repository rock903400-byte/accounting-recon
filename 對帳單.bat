@echo off
chcp 950 >nul
setlocal

:MENU
cls
echo.
echo ================================================
echo    異常社員篩選 — 對帳單寄發優先排序
echo ================================================
echo.
echo   1. 執行異常偵測
echo   2. 自訂篩選比例
echo   3. 結束
echo.
echo ================================================
set /p CHOICE=請輸入選項 (1-3):

if "%CHOICE%"=="1" goto RUN_ANOMALY
if "%CHOICE%"=="2" goto FILTER_PERCENT
if "%CHOICE%"=="3" goto END
goto MENU

:RUN_ANOMALY
cls
echo.
echo 正在執行異常偵測...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0find_anomaly_members.ps1" -CubPassword REDACTED %*
echo.
pause
goto MENU

:FILTER_PERCENT
cls
echo.
echo 正在依百分比過濾 M_對帳單...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0filter_by_percent.ps1" -CubPassword REDACTED %*
echo.
pause
goto MENU

:END
cls
echo.
echo 再見！
timeout /t 2 /nobreak >nul