# Регистрирует задачу nvim-clip-html: clip-html.ps1 в интерактивной сессии пользователя при входе.
# Идемпотентно (-Force перезаписывает). Запуск на Windows из каталога с обоими файлами:
#   powershell -NoProfile -ExecutionPolicy Bypass -File register-clip-html.ps1
$ErrorActionPreference = 'Stop'
$script = Join-Path $env:USERPROFILE 'clip-html.ps1'
$src = Join-Path $PSScriptRoot 'clip-html.ps1'
if ($src -ne $script) { Copy-Item $src $script -Force }

$user = "$env:USERDOMAIN\$env:USERNAME"
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
	-Argument "-NoProfile -Sta -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
# На батарее планировщик по умолчанию гасит задачу (событие 327) — ноутбук теряет помощника.
# RestartCount срабатывает только при ненулевом коде выхода, не при ручном kill.
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
	-ExecutionTimeLimit 0 -MultipleInstances IgnoreNew `
	-RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask nvim-clip-html -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask nvim-clip-html
