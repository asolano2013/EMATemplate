###################################################################################################
#                                        
#  Author: Adriana Solano                
#  Company: Intel Corp                   
#  Date: 11/13/2020                      
#                                        
###################################################################################################
#
#  Copyright 2021 Intel Corporation.
#
#  This software and the related documents are Intel copyrighted materials, and your use of them is 
#  governed by the express license under which they were provided to you ("License"). Unless the 
#  License provides otherwise, you may not use, modify, copy, publish, distribute, disclose or 
#  transmit this software or the related documents without Intel's prior written permission.
#
#  This software and the related documents are provided as is, with no express or implied warranties, 
#  other than those that are expressly stated in the License.                    
#                                        
###################################################################################################

$hostname = #Add the fully quialified domain name of your hostname/virtual machine.
$dbserver = #Add the Database server name. The same you use when created the VM.
$dbname = #Add the name of your EMA Database.
$guser = #Add a valid email address for the a Global Username for your EMA instance. 
$gpass = #Add the password for your global account linked to your EMA instance.

# Verify if temp path exists. If it doesn't exist, create C:\Temp path

$path = "C:\Temp"
If(!(test-path $path)){
    New-Item -ItemType Directory -Force -Path $path
    Write-Host "Temp folder has been created"
}

# Download EMA Install file from GitLab

$url = "https://github.com/asolano2013/EMATemplate/raw/main/Ema_Install_Package_1.3.3.1.exe"
$output = "C:\Temp\EMAInstall.zip"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Ssl3
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($url, $output)

# Extract EMA Install file

add-type -AssemblyName System.IO.Compression.FileSystem
[system.io.compression.zipFile]::ExtractToDirectory('C:\Temp\EMAInstall.zip','C:\Temp\EMAInstall')
Write-Host "Please wait for EMA install to start......"

# Run EMA Installer.exe

try{
$args = @("FULLINSTALL","--host=$hostname","--dbserver=$dbserver","--db=$dbname","--guser=$guser","--gpass=$gpass","--verbose","--console","--accepteula")
Start-Process -Filepath "C:\Temp\EMAInstall\EMAServerInstaller.exe" -ArgumentList $args -WorkingDirectory "C:\Temp\EMAInstall"
Write-Host "EMA install started...."
}
catch {Write-Host "An error ocurred! Please try again..."}

