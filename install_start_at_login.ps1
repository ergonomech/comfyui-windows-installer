$TaskName = "ComfyUI_AutoLaunch"
$ScriptPath = "$PSScriptRoot\launch_comfyui.bat"
$Action = New-ScheduledTaskAction -Execute "$ScriptPath"
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -RunLevel Highest -User $env:USERNAME -Force
Write-Output "Scheduled task '$TaskName' created to run at user login."
