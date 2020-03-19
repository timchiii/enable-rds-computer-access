# enable-rds-computer-access
sets up a user and computer for remote access through a remote desktop gateway

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
 
