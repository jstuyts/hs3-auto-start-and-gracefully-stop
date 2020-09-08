# HomeSeer 3 Start and Stop

The following HomeSeer forum posts describe how to start HomeSeer 3 automatically, and how to gracefully stop it when the user logs off. This script simply automates these Windows configuration steps:

* [Start](https://forums.homeseer.com/forum/homeseer-products-services/system-software-controllers/hs3-hs3pro-software/hs3-hs3pro-discussion/99619-windows-10-hs3-automatic-start-from-a-cold-boot)
* [Stop](https://forums.homeseer.com/forum/homeseer-products-services/system-software-controllers/hs3-hs3pro-software/hs3-hs3pro-discussion/99619-windows-10-hs3-automatic-start-from-a-cold-boot#post1106573)

**WARNING**: This script will overwrite your Group Policy files, which (normally) can be found in `C:\Windows\System32\GroupPolicy`. It will also use very high version numbers, so changes will be picked up if you have set group policies before.

Run the script as an administrator.

## How to Use?

1. Download [Enable-HomeSeerToStartAndStopAutomatically.ps1](Enable-HomeSeerToStartAndStopAutomatically.ps1). Use button *raw* after clicking on this link.
1. Start a PowerShell console as an administrator (Windows+X, Windows PowerShell (Admin))
1. Use `help Enable-HomeSeerToStartAndStopAutomatically.ps1 -detailed` for information about how to use the script. It accepts the following parameters:
    * Username (mandatory)
    * Password (mandatory)
    * HomeseerInstallationFolder
    * TasksGroupName
    * StartTaskName
1. Run the script using `.\Enable-HomeSeerToStartAndStopAutomatically.ps1`, appending the parameters. It is best to not add the password on the command line. PowerShell will ask for it if it is not given.
