@echo off
SET /p f=Enter file path:
C:\Windows\Microsoft.NET\Framework\v2.0.50727\aspnet_regiis -pef "connectionStrings" %f%
pause