<#
.SYNOPSIS
    Configures Windows to start HomeSeer automatically, and shut HomeSeer down gracefully.
.DESCRIPTION
    Configures Windows so HomeSeer is started automatically when the system starts, and is shut down properly when the user running HomeSeer is logged off (because of, for example, a reboot).

    The script makes changes to Windows that will result in the following: automatically logging on (without requiring a password) the user running HomeSeer, a task that starts HomeSeer as an administrator, a logon script that will start the task, and a logoff script that will gracefully shut down HomeSeer.

    Based on the following instructions on the HomeSeer forum:
    - https://forums.homeseer.com/forum/homeseer-products-services/system-software-controllers/hs3-hs3pro-software/hs3-hs3pro-discussion/99619-windows-10-hs3-automatic-start-from-a-cold-boot#post1116636
    - https://forums.homeseer.com/forum/homeseer-products-services/system-software-controllers/hs3-hs3pro-software/hs3-hs3pro-discussion/99619-windows-10-hs3-automatic-start-from-a-cold-boot#post1106573

    This script must be run by an administrator.

    WARNING: This script will overwrite your Group Policy files, which (normally) can be found in "C:\Windows\System32\GroupPolicy". It will also use very high version numbers, so changes will be picked up if you have set group policies before.
.NOTES
    Author: Johan Stuyts
#>
[CmdletBinding()]
Param(
    # The name of the user, who must be an administrator.
    [Parameter(Mandatory=$True,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
    [String]$Username,

    # The password of the user.
    [Parameter(Mandatory=$True,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
    [System.Security.SecureString]$Password = ( Read-Host -AsSecureString ),

    # The installation path of HomeSeer. Default: <Program Files(x86)>\HomeSeer HS3
    [Parameter(Mandatory=$False,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
    [String]$HomeseerInstallationFolder = ( Join-Path ( [Environment]::GetFolderPath( 'ProgramFilesX86' ) ) 'HomeSeer HS3' ),

    # The name of the task scheduler group to create the tasks in. Default: HomeSeer
    [Parameter(Mandatory=$False,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
    [String]$TasksGroupName = 'HomeSeer',

    # The name of the task starting HomeSeer. Default: Start HomeSeer
    [Parameter(Mandatory=$False,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
    [String]$StartTaskName = 'Start HomeSeer'
)

$SystemFolder = [Environment]::GetFolderPath( 'System' )

$CurrentIdentity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$AdministratorRole = [Security.Principal.WindowsBuiltInRole]::Administrator
if ( -not ( $CurrentIdentity.IsInRole( $AdministratorRole ) ) ) {
	Write-Error 'This script must be run as an administrator. Start PowerShell as an administrator and try again: Windows+X, Windows PowerShell (Admin)'
} else {
    # Check that the user that must run HomeSeer is an administrator
    $UserPrincipal = Get-LocalGroupMember -SID S-1-5-32-544 -Member $Username -ErrorAction SilentlyContinue
    if ( $null -eq $UserPrincipal ) {
    	Write-Error 'The user that will run HomeSeer must be an administrator.'
    } else {
        # Automatically log on the Windows user
        Write-Verbose "Configuring Windows to automatically log on: $Username"
        $WinlogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
        Set-ItemProperty $WinlogonPath 'AutoAdminLogon' -Value '1' -type String
	    Set-ItemProperty $WinlogonPath 'DefaultUsername' -Value $Username -type String
        $DecryptedPassword = ( New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList '-', $Password ).GetNetworkCredential().Password
	    Set-ItemProperty $WinlogonPath 'DefaultPassword' -Value $DecryptedPassword -type String

        # Create a task that will start HomeSeer
        $StartHomeseerTask = Get-ScheduledTask -TaskPath "\$TasksGroupName\" -TaskName $StartTaskName -ErrorAction SilentlyContinue
        if ( $null -eq $StartHomeseerTask ) {
            $StartHomeseerAction = New-ScheduledTaskAction -WorkingDirectory $HomeseerInstallationFolder -Execute ( Join-Path $HomeseerInstallationFolder 'HS3.exe' )
            # TODO: The parameter ExecutionTimeLimit may have to be 'PT0S' for older versions of Windows. If so, detect the Windows version and adjust accordingly
            #           https://powershell.org/forums/topic/new-scheduledtasksettingsset-executiontimelimit-how-to-not-have-one/
            $StartHomeseerSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit '00:00:00'
            Register-ScheduledTask -Action $StartHomeseerAction -Settings $StartHomeseerSettings -TaskPath $TasksGroupName -TaskName $StartTaskName -RunLevel Highest | Out-Null
        }

        # Creata a logon script to run the previously created task
        "@echo off
$SystemFolder\schtasks.exe /RUN /TN `"$TasksGroupName\$StartTaskName`"
$SystemFolder\rundll32.exe user32.dll,LockWorkStation" | Set-Content -Path ( Join-Path ( [Environment]::GetFolderPath( 'Startup' ) ) 'Start HomeSeer.cmd' ) -Encoding Oem

        # Create a logoff script to stop HomeSeer, and Group Policy configuration files for it
        $GroupPolicyFolderPath = ( Join-Path $SystemFolder GroupPolicy )
        $GroupPolicyMachineScriptsFolderPath = ( Join-Path $GroupPolicyFolderPath Machine\Scripts )
        $GroupPolicyUserScriptsFolderPath = ( Join-Path $GroupPolicyFolderPath User\Scripts )

        "@echo off
$SystemFolder\taskkill.exe /IM HS3.exe" | Set-Content -Path ( Join-Path $GroupPolicyMachineScriptsFolderPath 'Shutdown\Stop HomeSeer.cmd' ) -Encoding Oem

        "@echo off
$SystemFolder\taskkill.exe /IM HS3.exe" | Set-Content -Path ( Join-Path $GroupPolicyUserScriptsFolderPath 'Logoff\Stop HomeSeer.cmd' ) -Encoding Oem

"
[Shutdown]
0CmdLine=Stop HomeSeer.cmd
0Parameters=" | Set-Content -Path ( Join-Path $GroupPolicyMachineScriptsFolderPath scripts.init ) -Encoding Unicode

        "
[Logoff]
0CmdLine=Stop HomeSeer.cmd
0Parameters=" | Set-Content -Path ( Join-Path $GroupPolicyUserScriptsFolderPath scripts.ini ) -Encoding Unicode

        "[General]
gPCUserExtensionNames=[{42B5FAAE-6536-11D2-AE5A-0000F87571E3}{40B66650-4972-11D1-A7CA-0000F87571E3}] 
gPCMachineExtensionNames=[{42B5FAAE-6536-11D2-AE5A-0000F87571E3}{40B6664F-4972-11D1-A7CA-0000F87571E3}]
Version=4295000064" | Set-Content -Path ( Join-Path $GroupPolicyFolderPath gpt.ini ) -Encoding UTF8

        gpupdate
    }
}
