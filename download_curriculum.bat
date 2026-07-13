@echo off
title Download Curriculum PDFs
echo Starting curriculum PDF download...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0download_curriculum.ps1"
echo.
echo ==================================
echo If you see errors above, take a screenshot and show it.
echo ==================================
pause
