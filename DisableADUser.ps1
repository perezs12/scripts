#TODO
#Check if user is in groups that have licenses such as RC, Adobe, Bluebeam, etc. in order to remind admin to remove licenses 



# Original script by Patrick Deno a.k.a. GhilleHammer, with help from many Spiceworks community members and other anonymous Internet denizens
# https://community.spiceworks.com/scripts/show/4526-off-boarding-script-for-departing-users-ad-exchange

# Modified script by Sergio, for simpler use of disabling accounts and removing groups
# Added name of admin disabling account, verification before disabling,csv includes username, and printing groups of disabled user on terminal

<############################################################################################################

Purpose: Off-loading employees in Active Directory

Chain:

Active Directory Section:
* Asks admin for a user name to disable.
* Checks for active user with that name.
* Prompt admin to verify if that is the user they want to disable
* Disables user in AD.
* Resets the password of the user's AD account.
* Adds the path of the OU that the user came from as well as the date and name of the admin who ran the script to the "Description" of the disabled account.
* Exports a list of the user's group memberships (permissions) to an Excel file in a specified directory.
* Strips group memberships from user's AD account.
* Moves user's AD account to the "Disabled Users" OU.
* Print list of groups that were disabled 


######################################################################################################>

# Clear the console
Clear-Host
Write-Host "Offboard a user

"

<# --- Active Directory account dispensation section --- #>

$date = [datetime]::Today.ToString('MM-dd-yyyy')

#Name of Admin disabling Account
$admin = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.split("\")[1]

# Get the name of the account to disable from the admin
$sam = Read-Host 'Account name to disable'


# Get the properties of the account and set variables
$user = Get-ADuser $sam -properties canonicalName, distinguishedName, displayName, Title, Department
$dn = $user.distinguishedName
$cn = $user.canonicalName
$din = $user.displayName
$UserAlias = $user.mailNickname
$title = $user.Title
$dept = $user.Department

#Confirm if this is the correct user to disable
Write-Warning ("Are you sure you want to disable $din, $title, from the $dept Department?") -WarningAction Inquire


# Path of where disabled user permissions will be stored
$path1 = "C:\Disabled Users\"
$path2 = "-AD-DisabledUser-Permissions.csv"
$pathFinal = $path1 + $sam + $path2

# Disable the account
Disable-ADAccount $sam
Write-Host ("* " + $din + "'s Active Directory account is disabled.")

#Set Account Expiration Date
Set-ADAccountExpiration  $sam -DateTime $date
Write-Host ("* " + $din + "'s Active Directory account is set to expire $date.")

# Reset password
$NewPassword = (Read-Host -Prompt "Provide New Password" -AsSecureString) 
#Set-ADAccountPassword -Identity DavidChe -NewPassword $NewPassword -Reset

Set-ADAccountPassword -Identity $sam -NewPassword $NewPassword -Reset
Write-Host ("* " + $din + "'s Active Directory password has been changed.")

# Add the OU path where the account originally came from to the description of the account's properties
Set-ADUser $dn -Description ("Moved from: " + $cn + " - on $date" + " by " + $admin)
Write-Host ("* " + $din + "'s Active Directory account path saved.")

# Get the list of permissions (group names) and export them to a CSV file for safekeeping
$groupinfo = get-aduser $sam -Properties memberof | select name, 
@{ n="GroupMembership"; e={($_.memberof | foreach{get-adgroup $_}).name}}

$oldGroups = $groupinfo

$count = 0
$arrlist =  New-Object System.Collections.ArrayList
do{
    $null = $arrlist.add([PSCustomObject]@{
        #Name = $groupinfo.name
        GroupMembership = $groupinfo.GroupMembership[$count]
    })
    $count++
}until($count -eq $groupinfo.GroupMembership.count)

$arrlist | select groupmembership |
convertto-csv -NoTypeInformation |
select -Skip 1 |
out-file $pathFinal
Write-Host ("* " + $din + "'s Active Directory group memberships (permissions) exported and saved to " + $pathFinal)

# Strip the permissions from the account
Get-ADUser $User -Properties MemberOf | Select -Expand MemberOf | %{Remove-ADGroupMember $_ -member $User}
Write-Host ("* " + $din + "'s Active Directory group memberships (permissions) stripped from account")

# Move the account to the Disabled Users OU
Move-ADObject -Identity $dn -TargetPath "Ou=Disabled Users,DC=muse,DC=local"
Write-Host ("* " + $din + "'s Active Directory account moved to 'Disabled Users' OU")


#Write the groups the user has been removed from on screen
Write-Host ""
Write-Host ($din + "  has been disabled andremoved from the following groups: ")
$csvGroups = @()
import-csv $pathFinal

