# Various-Code

### Check-IsValidIPAddress
Small function to check if a given IP address is a valid one
### 
 
### Check-RebootPending
Checks various system settings to see if the machine is waiting for a reboot
### 
 
### CleanUserProfileFolders
Useful for terminal servers with lots of users.  Removes all files and folders from the listed entires for all user profiles.  It will try to detect the correct path, or if you have multiple paths, has an override parameter.
###

### ConvertFrom-ISO8601Duration & ConvertTo-ISO8601Duration
Converts a timespan value into and from an ISO8601 time duration.  Natural language can also be used
###

### Copy-VMGuestFileGUI
Small GUI that helps to copy files to and from a VM.  May have the odd bug or two!
###

### Manage-KeePass
Manage KeePass database from within PowerShell
### 
 
### PasswordGenerator
GUI form to generate random passwords for you
### 

### Read-ClusterValidationReport
Reads in a Cluster Validation HTM report and returns a PowerShell object of results
###

### Remove-VMwareSnapshots
Quick an dirty script to remove any snapshots from VMware that contain the string "(Remove On dd/mm/yyyy)" anywhere in the description.  I run this daily in my environment so that anyone creating snapshots can have them automatically removed on the specific date.
###

### SCOM-MaintenanceMode.ps1
A PowerShell version of my SCOM Maintentance Mode tool.  This works with SCOM 2016 only.
###

### Show-InputForm
Multiple use GUI for asking for a variety of input types that can also perform simple validation.  See https://imgur.com/a/ZRXGT for images
###
