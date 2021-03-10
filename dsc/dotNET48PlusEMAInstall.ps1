Configuration dotNET48PlusEMAInstall
{

    param
    (
        [Parameter(Mandatory)]
        [String]$hostname,

        [Parameter(Mandatory)]
        [String]$vmName,
       
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [PSCredential]$globalCred
    ) # end param

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    $dbname = "emadb"

    node "localhost"
    {

        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
            ConfigurationMode = 'ApplyAndMonitor'
			ActionAfterReboot = 'ContinueConfiguration'
			AllowModuleOverwrite = $true
        }
        
        Script Install_Net_4.8
        {
            SetScript = {

                $path = "C:\Temp"
                If(!(test-path $path)){
                New-Item -ItemType Directory -Force -Path $path
                Write-Host "Temp folder has been created"
                }

                ## Download .NET 4.8 Installer from MS
 
                $url = "https://go.microsoft.com/fwlink/?linkid=2088631"
                $output = "C:\Temp\ndp48-x86-x64-allos-enu.exe"
 
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Ssl3
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($url, $output)
 
                # Pause
 
                $currentTime = Get-Date
                Write-Host "Pausing 20 seconds... $currentTime"
                Start-Sleep -s 20
 
                ## Run .NET 4.8 Installer from MS
 
                try
                {
                    $args = "/q /x86 /x64 /redist /norestart"
                    $currentTime = Get-Date
                    Write-Host ".Net 4.8 install starting... $currentTime"
                    Start-Process -Filepath "C:\Temp\ndp48-x86-x64-allos-enu.exe" -ArgumentList $args -WorkingDirectory "C:\Temp" -Wait 
                    $currentTime = Get-Date
                    Write-Host ".Net 4.8 install complete.  $currentTime"
                    New-Item -Path HKLM:\SOFTWARE\MyMainKey\RebootKey -Force
                    $global:DSCMachineStatus = 1
                } # end try
                catch {Write-Host "An error occurred! Please try again..."}
            }
            TestScript = {

                return (Test-Path HKLM:\SOFTWARE\MyMainKey\RebootKey)

                [int]$NetBuildVersion = 528040

                if (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' | %{$_ -match 'Release'})
                {
                    [int]$CurrentRelease = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').Release
                    if ($CurrentRelease -lt $NetBuildVersion)
                    {
                        Write-Verbose "Current .Net build version is less than 4.8 ($CurrentRelease)"
                        return $false
                    }
                    else
                    {
                        Write-Verbose "Current .Net build version is the same as or higher than 4.8 ($CurrentRelease)"
                        return $true
                    }
                }
                else
                {
                    Write-Verbose ".Net build version not recognized"
                    return $false
                }
            }
            GetScript = {

                return @{result = 'result'}

                if (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' | %{$_ -match 'Release'})
                {
                    $NetBuildVersion =  (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').Release
                    return $NetBuildVersion
                }
                else
                {
                    Write-Verbose ".Net build version not recognised"
                    return ".Net 4.8 not found"
                }
            }
        } # end resource

        Script Install_EMA
        {
            SetScript = {

                # Check for and create temp directory if necessary.
                $pathEma = "C:\Temp"
                If(!(test-path $pathEma))
                {
                    New-Item -ItemType Directory -Force -Path $pathEma
                    Write-Host "Temp folder has been created"
                } # end if

                # Download EMA Install file from GitLab

                $urlEma = "https://downloadmirror.intel.com/28994/eng/Ema_Install_Package_1.4.0.0.exe"
                $outputEma = "C:\Temp\EMAInstall.zip"

                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Ssl3
                $wcEma = New-Object System.Net.WebClient
                $wcEma.DownloadFile($urlEma, $outputEma)
 
                # Extract EMA Install file

                add-type -AssemblyName System.IO.Compression.FileSystem
                [system.io.compression.zipFile]::ExtractToDirectory('C:\Temp\EMAInstall.zip','C:\Temp\EMAInstall')

                $currentTimeEma = Get-Date
                Write-Host "Pausing 120 seconds to ensure database is ready... $currentTimeEma"
                Start-Sleep -s 120

                NET STOP MSSQLSERVER
                NET START MSSQLSERVER /mSQLCMD 

                Write-Host "Enabling system account to create Intel EMA database... "
                SQLCMD -Q "EXEC master..sp_addsrvrolemember @loginame = N'NT AUTHORITY\SYSTEM', @rolename = N'sysadmin'" 

                NET STOP MSSQLSERVER
                NET START MSSQLSERVER

                # Run EMA Installer.exe

                $globalUsername = $globalCred.UserName
                $globalPassword = $globalCred
                #$gPass = (New-Object PSCredential $globalUsername, $globalPassword).GetNetworkCredential().Password
                #$gpass = ConvertTo-SecureString $globalPassword -AsPlainText -Force
                #$adminCreds = New-Object PSCredential $globalUsername, $gpass

                try
                {
                    $emaArgs = @("FULLINSTALL","--host=$hostname","--dbserver=$vmName","--db=$dbname","--guser=$globalUsername","--gpass=$globalPassword","--verbose","--autoexit","--accepteula")
                    $currentTimeEmaStart = Get-Date
                    Write-Host "EMA install starting... $currentTimeEmaStart"
                    Start-Process -Filepath "C:\Temp\EMAInstall\EMAServerInstaller.exe" -ArgumentList $emaArgs -WorkingDirectory "C:\Temp\EMAInstall" -Wait 
                    $currentTimeEmaStop = Get-Date
                    Write-Host "EMA install process complete.  $currentTimeEmaStop"
                } # end try
                catch 
                {
                    Write-Host "An error ocurred! Please try again..."
                } # end catch
                finally 
                {
                    # Clean up permissions
                    Write-Host "Restoring database permissions... "
                    SQLCMD -Q "EXEC master..sp_dropsrvrolemember @loginame = N'NT AUTHORITY\SYSTEM', @rolename = N'sysadmin'" 
                } # end finally
            } # end SetScript

            TestScript = {

                $script:targetServiceName = "PlatformManager"

                $checkForService = $null

                # $checkForService = (Get-Service -Name $targetServiceName -ErrorAction SilentlyContinue).Name
                $checkForService = (Get-Service -Name $targetServiceName -ErrorAction SilentlyContinue).Name

                if ($checkForService -ne $targetServiceName)
                {
                    Write-Verbose "Intel Endpoint Management Assistant is not installed."
                    return $false
                } # end if
                else
                {
                    Write-Verbose "Intel Endpoint Management Assistant is installed."
                    return $true
                } # end else
            } # end TestScript
            
            GetScript = {
                $currentTargetService = ((Get-Service -Name $targetServiceName).Name)
                return @{ 'result' = "$currentTargetService" }
            } # end GetScript
            DependsOn = "[Script]Install_Net_4.8"
        } # end resource
    } # end node
} # end configuration

# (Preston) Original commands below were interfering with the native Azure DSC extension engine to apply the configuration 
<#
dotNET48PlusEMAInstall -OutputPath $env:SystemDrive:\DSCconfig
Set-DscLocalConfigurationManager -ComputerName localhost -Path $env:SystemDrive\DSCconfig -Verbose
Start-DscConfiguration -ComputerName localhost -Path $env:SystemDrive:\DSCconfig -Verbose -Wait -Force
#>

# (Preston) Uncomment below for interactive testing on the VM if necessary
<#
$globalUserName = "adm.infra.user@dev.adatum.com"
$globalCred = Get-Credential -Message "Enter credentials for $globalUserName" -UserName $globalUserName
$mofPath = ".\dotNET48PlusEMAInstall"

dotNET48PlusEMAInstall -hostname "azrema2801.eastus2.cloudapp.azure.com" -vmName "azrema2801" -globalCred $globalCred
Set-DscLocalConfigurationManager -ComputerName localhost -Path $mofPath -Verbose
Start-DscConfiguration -ComputerName localhost -Path $mofPath -Verbose -Wait -Force
#>