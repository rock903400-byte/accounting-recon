@echo off
chcp 950 >nul
setlocal

:MENU
cls
echo.
echo ================================================
echo    ���`�����z�� �X ��b��H�o�u���Ƨ�
echo ================================================
echo.
echo   1. ���沧�`����
echo   2. �ۭq�z����
echo   3. ����
echo.
echo ================================================
set /p CHOICE=�п�J�ﶵ (1-3):

if "%CHOICE%"=="1" goto RUN_ANOMALY
if "%CHOICE%"=="2" goto FILTER_PERCENT
if "%CHOICE%"=="3" goto END
goto MENU

:RUN_ANOMALY
cls
echo.
echo ���b���沧�`����...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0find_anomaly_members.ps1" %*
echo.
pause
goto MENU

:FILTER_PERCENT
cls
echo.
echo ���b�̦ʤ���L�o M_��b��...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0filter_by_percent.ps1" %*
echo.
pause
goto MENU

:END
cls
echo.
echo �A���I
timeout /t 2 /nobreak >nul