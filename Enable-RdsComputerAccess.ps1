<#
.SYNOPSIS
 Configures everything required for a user to access their work computer externally through the RDS Gateway.

.DESCRIPTION
 1. Adds user to RDS Users security group
 2. Adds computer to RDS Computers security group
 3. Confirms users is a member of either the Local Administrators group or the Remote Desktop Users group on the local computer. 
 4. If the user is not a member of either group, they are added to the local Remote Desktop Users group.
 5. Saves RDP file on your desktop unless the Specify output directory parameter is used.
 6. Emails the RDP file and indicated attachments to the user's mail address in AD
 7. If -cc, also emails a CC address.

.EXAMPLE
 PS C:\> Enable-RdsComputerAccess.ps1 -Computername 'jdoe-pc' -samAccountName 'jdoe'
 Enables user jdoe to remote desktop in to computer 

 PS C:\> Enable-RdsComputerAccess.ps1 -Computername 'jdoe-pc' -samAccountName 'jdoe' -PromptOutputDirectory
 Enables user jdoe to remote desktop in to computer jdoe-pc and asks where to save the RDP file

 PS C:\> Enable-RdsComputerAccess.ps1 -Computername 'jdoe-pc' -samAccountName 'jdoe' -SendAsEmailAttachment
 Enables user jdoe to remote desktop in to computer jdoe-pc and sends the RDP file as an email attachment to the users' mail address in ad

 PS C:\> Enable-RdsComputerAccess.ps1 -Computername 'jdoe-pc' -samAccountName 'jdoe' -SendAsEmailAttachment -cc 'personalEmail@gmail.com'
 Enables user jdoe to remote desktop in to computer jdoe-pc and sends the RDP file as an email attachment to the users' mail address in ad and to personalEmail@gmail.com


.INPUTS
 Computername - short name of the computer
 samAccountName - username of the user
 PromptOutputDirectory - (optional) prompts for output location before saving RDP file (if you don't want it on your desktop)
 SendAsEmailAttachment - (optional) sends the RDP file and the attachments specified (aka how to documents) to the user email address listed in AD
 cc - (optional) used to specify a personal email address in case they aren't able to check their work email remotely

.OUTPUTS
 .RDP file automatically saved on your desktop

 
.NOTES
 Requires powershell is running in the context of a user with permission to run Invoke-Command (passwordless) on the workstations in question.
 Requires powershell is running in the context of an authenticated user who can send email on port 25 to the smtpServer in quest. If not, modify the Send-MailMessage line as needed.
 
#>

param (
 # Computer name
 [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
 [string]
 $Computername,
 # User samAccountName
 [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
 [string]
 $samAccountName,
 # Ask for output path
 [Parameter(ValueFromPipelineByPropertyName)]
 [switch]
 $PromptOutputDirectory,
 # Email End User
 [Parameter(ValueFromPipelineByPropertyName)]
 [switch]
 $SendAsEmailAttachment,
 # CC
 [Parameter(ValueFromPipelineByPropertyName)]
 [string]
 $cc
)

# ********** variables section ***********


# ad Domain or generating FQDN from computername
$adDomain = 'ad.local'

# ad Domain DNS short name
$dnsShortName = 'ad'

# formatted username
$rdUserName = $dnsShortName + '\' + $samAccountName

# ad rds users group name
$adRdsUsersGroup = 'RDS Users'

# ad rds computers group name
$adRdsComputersGroup = 'RDS Computers'

# public hostname for RD Gateway
$rdGateway = 'rds.ad.com'

# fqdn of target computer
$fqdn = $Computername + '.' + $adDomain

# File attachments to suppliment our email and reduce helpldesk calls
$rdsDirectionsPdf = '\\server\share\Access Remote Desktop Gateway from Any Computer.pdf'
$emailDirectionsPdf = '\\server\share\How to Access Email and Teams.pdf'
$attachments = ($rdsFileName, $rdsDirectionsPdf)

# helpdesk email address:
$helpdeskEmail = 'helpdesk@domain.com'

# emailFrom
$from = 'helpdesk@domain.com'

# smtp Server
$smtpServer = 'mail.domain.com'


# ******** END variables section **********

# validate parameters
Write-Host 'Validating parameters...' -ForegroundColor Yellow
$adComputer = Get-ADComputer $Computername -ErrorAction SilentlyContinue
$adUser = Get-ADUser $samAccountName -ErrorAction SilentlyContinue

if (-not $adComputer) {
 Write-Host 'Error: computer not found in AD.' -ForegroundColor Red
 Break;
}
else {
 Write-Host $adComputer' is a valid computer.' -ForegroundColor Green

}

if (-not $adUser) {
 Write-Host 'Error: computer not found in AD.' -ForegroundColor Red
 Break;
}
else {
 Write-Host $adUser' is a valid user.'
}

# Check if user is already in RDS Users group
Write-Host 'Checking RDS Users security group' -ForegroundColor Yellow
if (Get-ADGroup $adRdsUsersGroup | Get-ADGroupMember | Where-Object { $_.samAccountName -eq $adUser.samAccountName }) {
 # confirmed user is already a member
 Write-Host 'Users is already a member of RDS Users' -ForegroundColor Yellow
}
else {
 # user is not in group, need to add them
 Write-Host 'User is not a member of RDS users, adding...' -ForegroundColor Yellow
 Get-ADGroup $adRdsUsersGroup | Add-ADGroupMember -Members $adUser
 Write-Host 'User added successfully.' -ForegroundColor Green
}

Write-Host 'Checking RDS Computers security group' -ForegroundColor Yellow
if (Get-ADGroup $adRdsComputersGroup | Get-ADGroupMember | Where-Object { $_.samAccountName -eq $adComputer.samAccountName }) {
 # confirmed user is already a member
 Write-Host 'Computer is already a member of RDS Computers' -ForegroundColor Yellow
}
else {
 # user is not in group, need to add them
 Write-Host 'Computer is not a member of RDS Computers, adding...' -ForegroundColor Yellow
 Get-ADGroup $adRdsComputersGroup | Add-ADGroupMember -Members $adComputer
 Write-Host 'Computer added successfully.' -ForegroundColor Green
}

# script block to run on the remote computer in order to add user to the local Remote Desktop Users group
$scriptBlock = {
 Write-host 'Checking local administrators group...' -ForegroundColor Yellow
 if (-not $(Get-Localgroup 'Administrators' | Get-LocalGroupMember | Where-Object { $_.samAccountName -eq $using:adUser.samAccountName })) {
  Write-Host 'User is NOT a member of local administrators' -ForegroundColor Yellow
  Write-Host 'Checking local Remote Desktop Users Group...' -ForegroundColor Yellow
  if (-not $(Get-Localgroup 'Remote Desktop Users' | Get-LocalGroupMember | Where-Object { $_.samAccountName -eq $using:adUser.samAccountName })) {
Write-Host 'User is NOT a member of local Remote Desktop Users Group, adding...' -ForegroundColor Yellow
Add-LocalGroupMember -Group 'Remote Desktop Users' -Member $using:adUser.samAccountName

  }
 }
 Write-Host 'Local Administrators:' -ForegroundColor Green
 Get-LocalGroup 'Administrators' | Get-LocalGroupMember
 Write-Host 'Remote Desktop Users' -ForegroundColor Green
 Get-LocalGroup 'Remote Desktop Users' | Get-LocalGroupMember
}

# invoke the script block on the remote computer
Invoke-Command -ComputerName $Computername -ScriptBlock $scriptBlock

# literal string to use for writing out RDS file
$rdsFileData = @"
screen mode id:i:2
use multimon:i:0
desktopwidth:i:1920
desktopheight:i:1080
session bpp:i:32
winposstr:s:0,1,375,101,1795,999
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:$fqdn
audiomode:i:0
redirectprinters:i:1
redirectcomports:i:0
redirectsmartcards:i:1
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:2
prompt for credentials:i:0
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:$rdGateway
gatewayusagemethod:i:2
gatewaycredentialssource:i:0
gatewayprofileusagemethod:i:1
promptcredentialonce:i:1
gatewaybrokeringtype:i:0
use redirection server name:i:0
rdgiskdcproxy:i:0
kdcproxyname:s:
drivestoredirect:s:C:\;
username:s:$rdUserName
"@

[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
if ($PromptOutputDirectory) {
 # prompt for invoice file
 $outoutFileDialog = New-Object -TypeName System.Windows.Forms.FolderBrowserDialog
 $outoutFileDialog.Description = 'Select the main folder containing work order files'
 $outoutFileDialog.ShowDialog() | Out-Null
 $rdsFileName = $outoutFileDialog.SelectedPath + '\' + $Computername + '.rdp'
 if (-not $rdsFileName) {
  Exit
 }
 Write-Host 'Directory selected: '$outoutFileDialog.SelectedPath
}
else {
 $rdsFileName = $env:USERPROFILE + '\desktop\' + $Computername + '.rdp'
}

if (Test-Path $rdsFileData) {
 $fileExists = Read-Host -Prompt 'File already exists, overwrite? (y/n)'
 switch ($fileExists.ToLower()) {
  'y' { Write-Host 'Overwriting file contents...' -ForegroundColor DarkYellow }
  'n' { $rdsFileName = $rdsfilename.Replace(".rdp", $(Get-Date.ticks).tostring() + ".rdp") }
 }

}

$rdsFileData | Set-Content -Path $rdsFileName -Force

if ($SendAsEmailAttachment) {
 # define email body
 $body = @"
Please save the attached .RDP file to your personal computer then double 
click it to for remote access to your work computer. If you have a Mac or 
get an error message, please see directions in attached PDF.<br>
<br>
<br>
<h3>How to Connect to Remote Desktop (Windows)</h3>
<ul>
<li>
Wait until you receive an email from IT with your Remote Desktop link.</li>
<li>
Check your email from your personal computer and find the email from IT.</li>
<li>
Save the Remote Desktop link to your personal computer&#39;s desktop.</li>
<li>
Double click the link when you want to connect.</li>
<li>
If you get a warning about a publisher, check &quot;Don&#39;t ask me again&quot; and Click Allow.</li>
<li>
If you get prompted for your username and it isn&#39;t pre-populated, use your full work email address.</li>
<li>
Enter your work computer password when prompted.&#160;</li>
<li>
Your work desktop will connect.</li>
</ul><br>
<br>
<br>
<h3><strong>How to Connect to Remote Desktop (Mac)</h3>
<ul>
<li>
Download the Microsoft Remote Desktop app from the Apple App store: <a href="https://apps.apple.com/us/app/microsoft-remote-desktop-10/id1295203466?mt=12">https://apps.apple.com/us/app/microsoft-remote-desktop-10/id1295203466?mt=12</a>
</li>
<li>
Wait until you receive an email from IT with your Remote Desktop link.</li>
<li>
Check your email from your Mac.</li>
<li>
Save the Remote Desktop link to your Mac. Note the location where it was saved.</li>
<li>
Double click the file you saved.</li>
<li>
If prompted to select an app, select the Microsoft Remote Desktop app you downloaded above.</li>
<li>
<span style="font-size: 13pt;">If you get a warning about a publisher, select the option to proceed (Yes/Allow/Continue)<br/></li>
<li>
<span style="font-size: 13pt;">If you get prompted for your username and it isn&#39;t pre-populated, use your full work email address.<br/></li>
<li>
<span style="font-size: 13pt;">Enter your work computer password when prompted.&#160;<br/></li>
<li>
<span style="font-size: 13pt;">Your work desktop will connect.<br/></li>

</ul><br>
<br>
<br>
​If you have issues connecting, please email $helpdeskEmail and include as much detail as possible (screenshot, error message, etc).

"@

 $to = (Get-ADUser $samAccountName -Properties mail).mail; # get user email address from AD
 

 $mailParams = @{
  To = $to;
  From = $from; # email from
  Subject  = 'Remote Desktop Access' ; # email subject
  Attachments = $attachments; # email attachments from above
  Body  = $body; # email body using above vairable
  BodyAsHtml = $true; # flag body as html
  SmtpServer = $smtpServer
 }

 if ($cc) {$mailParams += @{ CC = $cc } }

 Send-MailMessage @mailParams -Verbose
 
}
else {
 & explorer "/select,$rdsFileName"
}


