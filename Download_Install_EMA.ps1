##########################################
#                                        #
#  Author: Adriana Solano                #
#  Company: Intel Corp                   #
#  Date: 11/13/2020                      #
#                                        #
##########################################

$host = $Args[0]
$dbserver = $Args[1]
$dbname = $Args[2]
$guser = $Args[3]
$gpass = $Args[4]

# Create C:\Temp path if it doesn't exist

$path = "C:\Temp"
If(!(test-path $path)){
    New-Item -ItemType Directory -Force -Path $path
}

#Download EMA Install file from github

$url = "https://github.com/asolano2013/EMATemplate/raw/main/Ema_Install_Package_1.3.3.1.exe"
$output = "C:\Temp\EMAInstall.zip"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Ssl3
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($url, $output)


#Extract EMA Install file

add-type -AssemblyName System.IO.Compression.FileSystem
[system.io.compression.zipFile]::ExtractToDirectory('C:\Temp\EMAInstall.zip','C:\Temp\EMAInstall')

#Run EMA Installer exe

$args = @("FULLINSTALL","--host=$host","--dbserver=$dbserver","--db=$dbname","--guser=$guser","--gpass=$gpass","--verbose","--console","--accepteula")
Start-Process -Filepath "C:\Temp\EMAInstall\EMAServerInstaller.exe" -Verb RunAs -ArgumentList $args -WorkingDirectory "C:\Temp\EMAInstall"

