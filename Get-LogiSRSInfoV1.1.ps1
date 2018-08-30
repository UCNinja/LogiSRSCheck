﻿


# Script that gathers info for Logitech SRS Systems
# Author: Luke Kannel
# Version Control:
# V1.0 - Initial Release
# V1.1 - Updated Skype Room Enumeration to look for any version





#Clear Variables






function GetComputerBaseline() {

$SRSInfo = Get-ComputerInfo
return $SRSInfo
}


function GetSurfaceSerialNumber() {

$SerialQuery = “Select * from Win32_Bios”
$BIOSInfo = Get-WmiObject -Query $SerialQuery
$SRSSerialNumber = $BIOSInfo.SerialNumber


$SerialHTML = "Surface Serial Number: " + $SRSSerialNumber | ConvertTo-HTML -Fragment

#$SRSInfo | Add-Member -NotePropertyName "SurfaceSerialNumber" -NotePropertyValue $SRSSerialNumber

}

function GetWindowsVersion() {
$WinVer = New-Object -TypeName PSObject
$WinVer | Add-Member -MemberType NoteProperty -Name Major -Value $(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' CurrentMajorVersionNumber).CurrentMajorVersionNumber
$WinVer | Add-Member -MemberType NoteProperty -Name Minor -Value $(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' CurrentMinorVersionNumber).CurrentMinorVersionNumber
$WinVer | Add-Member -MemberType NoteProperty -Name Build -Value $(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' CurrentBuild).CurrentBuild
$WinVer | Add-Member -MemberType NoteProperty -Name Revision -Value $(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' UBR).UBR
$SRSFullWindowsVersion = $WinVer.Major, $WinVer.Minor, $WinVer.Build, $WinVer.Revision -join "."

Write-Host "Windows Version: " $SRSFullWindowsVersion
#$SRSInfo | Add-Member -NotePropertyName "WindowsVersion" -NotePropertyValue  $SRSFullWindowsVersion

}


function CheckWindowsActivation() {
$SRSLicenseObject = Get-CimInstance -ClassName SoftwareLicensingProduct |where PartialProductKey |select LicenseStatus
If ($SRSLicenseObject.LicenseStatus -ne "1") {
	$SRSLicenseStatus = "Not Activated" } else {
	$SRSLicenseStatus = "Activated"
	}
Write-Host "Windows Activation Status:" $SRSLicenseStatus
}

function GetSRSVersion() {

$SRSPath = get-item "C:\Program Files\WindowsApps\Microsoft.SkypeRoomSystem*\Microsoft.SkypeRoomSystem.exe"

$SRSVersion = (Get-Item $SRSPath).VersionInfo.FileVersion
Write-Host "Room System: " $SRSVersion

#$SRSInfo | Add-Member -NotePropertyName "SRSVersion" -NotePropertyValue  $SRSVersion


}

Function GetSoftware  {

  [OutputType('System.Software.Inventory')]

  [Cmdletbinding()] 

  Param( 

  [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)] 

  [String[]]$Computername=$env:COMPUTERNAME

  )         

  Begin {

  }

  Process  {     

  ForEach  ($Computer in  $Computername){ 

  If  (Test-Connection -ComputerName  $Computer -Count  1 -Quiet) {

  $Paths  = @("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall","SOFTWARE\\Wow6432node\\Microsoft\\Windows\\CurrentVersion\\Uninstall")         

  ForEach($Path in $Paths) { 

  Write-Verbose  "Checking Path: $Path"

  #  Create an instance of the Registry Object and open the HKLM base key 

  Try  { 

  $reg=[microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',$Computer,'Registry64') 

  } Catch  { 

  Write-Error $_ 

  Continue 

  } 

  #  Drill down into the Uninstall key using the OpenSubKey Method 

  Try  {

  $regkey=$reg.OpenSubKey($Path)  

  # Retrieve an array of string that contain all the subkey names 

  $subkeys=$regkey.GetSubKeyNames()      

  # Open each Subkey and use GetValue Method to return the required  values for each 

  ForEach ($key in $subkeys){   

  Write-Verbose "Key: $Key"

  $thisKey=$Path+"\\"+$key 

  Try {  

  $thisSubKey=$reg.OpenSubKey($thisKey)   

  # Prevent Objects with empty DisplayName 

  $DisplayName =  $thisSubKey.getValue("DisplayName")

  If ($DisplayName  -AND $DisplayName -like "Logitech Camera Settings" -AND $DisplayName  -notmatch '^Update  for|rollup|^Security Update|^Service Pack|^HotFix') {

  $Date = $thisSubKey.GetValue('InstallDate')

  If ($Date) {

  Try {

  $Date = [datetime]::ParseExact($Date, 'yyyyMMdd', $Null)

  } Catch{

  Write-Warning "$($Computer): $_ <$($Date)>"

  $Date = $Null

  }

  } 

  # Create New Object with empty Properties 

  $Publisher =  Try {

  $thisSubKey.GetValue('Publisher').Trim()

  } 

  Catch {

  $thisSubKey.GetValue('Publisher')

  }

  $Version = Try {

  #Some weirdness with trailing [char]0 on some strings

  $thisSubKey.GetValue('DisplayVersion').TrimEnd(([char[]](32,0)))

  } 

  Catch {

  $thisSubKey.GetValue('DisplayVersion')

  }

  $UninstallString =  Try {

  $thisSubKey.GetValue('UninstallString').Trim()

  } 

  Catch {

  $thisSubKey.GetValue('UninstallString')

  }

  $InstallLocation =  Try {

  $thisSubKey.GetValue('InstallLocation').Trim()

  } 

  Catch {

  $thisSubKey.GetValue('InstallLocation')

  }

  $InstallSource =  Try {

  $thisSubKey.GetValue('InstallSource').Trim()

  } 

  Catch {

  $thisSubKey.GetValue('InstallSource')

  }

  $HelpLink = Try {

  $thisSubKey.GetValue('HelpLink').Trim()

  } 

  Catch {

  $thisSubKey.GetValue('HelpLink')

  }

  $Object = [pscustomobject]@{

  Computername = $Computer

  DisplayName = $DisplayName

  Version  = $Version

  InstallDate = $Date

  Publisher = $Publisher

  UninstallString = $UninstallString

  InstallLocation = $InstallLocation

  InstallSource  = $InstallSource

  HelpLink = $thisSubKey.GetValue('HelpLink')

  EstimatedSizeMB = [decimal]([math]::Round(($thisSubKey.GetValue('EstimatedSize')*1024)/1MB,2))

  }

  $Object.pstypenames.insert(0,'System.Software.Inventory')

  #Write-Output $Object
  Write-Host $DisplayName ":" $Version
#$SRSInfo | Add-Member -NotePropertyName "LogiCamVersion" -NotePropertyValue  $Version


  }

  } Catch {

  Write-Warning "$Key : $_"

  }   

  }

  } Catch  {}   

  $reg.Close() 

  }                  

  } Else  {

  Write-Error  "$($Computer): unable to reach remote system!"

  }

  } 

  } 

}  

function OutputContent() {

ConvertTo-HTML -Body $SerialHTML -Title "Logitech Status" | Out-File c:\status.html

}

#Computer baseline function may be used in the future
#GetComputerBaseline


GetSurfaceSerialNumber
GetWindowsVersion
CheckWindowsActivation
GetSRSVersion
GetSoftware
OutputContent