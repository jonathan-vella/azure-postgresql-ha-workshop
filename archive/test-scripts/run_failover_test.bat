@echo off
REM Simple batch file wrapper to run the PowerShell script
REM This allows double-clicking in Windows Explorer

powershell.exe -ExecutionPolicy Bypass -File "%~dp0run_failover_test.ps1" %*
