<#
.SYNOPSIS

A script used to create a Backup protection policy in a Recovery Services vault to backup AVD personal session-hosts.

.DESCRIPTION

A script used to create a Backup protection policy in a Recovery Services vault to backup AVD personal session-hosts.
The script will do all of the following:

Remove the breaking change warning messages.
Change the current context to the specified Azure Virtual Desktop (AVD) subscription.
Save the Recovery Services vault from the AVD subscription in a variable.
Create a Backup retention policy.

.NOTES

Filename:       Create-Backup-protection-policy-to-backup-AVD-personal-session-hosts.ps1
Created:        10/10/2023
Last modified:  10/10/2023
Author:         Wim Matthyssen
Version:        1.0
PowerShell:     Azure PowerShell and Azure Cloud Shell
Requires:       PowerShell Az (v10.4.1)
Action:         Change variables were needed to fit your needs. 
Disclaimer:     This script is provided "as is" with no warranties.

.EXAMPLE

Connect-AzAccount
Get-AzTenant (if not using the default tenant)
Set-AzContext -tenantID "xxxxxxxx-xxxx-xxxx-xxxxxxxxxxxx" (if not using the default tenant)
.\Create-Backup-protection-policy-to-backup-AVD-personal-session-hosts -SubscriptionName <"your Azure (AVD) subscription name here"> -VaultName <"your Azure Recovery Services vault name here">  

.LINK

https://wmatthyssen.com/2023/10/11/set-up-an-azure-backup-recovery-services-vault-and-backup-protection-policy-to-backup-your-avd-personal-session-hosts/
#>

## -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Parameters

param(
    # $subscriptionName -> Name of the Azure Subscription
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $subscriptionName,
    # $vaultName -> Name of the Recovery Services vault
    [parameter(Mandatory =$true)][ValidateNotNullOrEmpty()] [string] $vaultName
)

## -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Variables

$abbraviationBackupPolicyResourceType = "vm"

$rgNameBackup = #<your backup resource group name here> The name of the Azure resource group in which your new or existing Recovery Services vault deployed. Example: "rg-prd-myh-avd-backup-01"
$rgNameBackupIrpWithoutSuffix = #<your backup irp resource group name here without suffix> The name of the Azure resource group in which your store your instant restore snapshots. Example: "rg-prd-myh-avd-backup-irp-0"

$backupTime = #<your backup schedule time here> The time of your backup schedule. Example: "23:00"
$backupDayOfWeek = #<your backup retention day here> The day of your weekly, monthly and yearly backup retention. Example: "Thursday"
$backupNumberOfWeek = #<your backup retention number of week here> The number of week of your monthly and yearly backup retention. Example: "Third"
$backupYMonthOfYear = #<your backup retention month of year here> The month of your yearly backup retention. Example: "December"

$durationCountInDays = #<your daily backup number here> The number of dialy backup points. Example: 27
$durationCountInWeeks = #<your daily backup number here> The number of weekly backup points. Example: 54
$durationCountInMonths = #<your daily backup number here> The number of monthly backup points. Example: 12
$durationCountInYears = #<your daily backup number here> The number of yearly backup points. Example: 3

$backupPolicyWorkloadType = "AzureVM"
$backupPolicyTime = #<your backup policy name time part here> The time part of your backup policy name. Example: "11pm"
$backupPolicyDayShort = #<your backup policy name shortend day part here> The shortend day part of your backup policy name. Example: "thu"
$backupPolicyInstantRestoreDays = "ir" + "2"
$backupPolicyRetentionDays = "d" + $durationCountInDays.ToString()
$backupPolicyRetentionWeeks = "w" + $durationCountInWeeks.ToString()
$backupPolicyRetentionMonths = "m" + $durationCountInMonths.ToString()
$backupPolicyRetentionYears = "y" + $durationCountInYears.ToString()
 
$backupPolicyRetentionSettings = $backupPolicyInstantRestoreDays + "-" + $backupPolicyRetentionDays + "-" + $backupPolicyRetentionWeeks + "-" + $backupPolicyRetentionMonths + "-" + $backupPolicyRetentionYears 
$backupPolicyName = "bp" + "-" + $spoke + "-" + $abbraviationLZPurpose + "-" + $abbraviationBackupPolicyResourceType + "-" + $backupPolicyTime + "-" + $backupPolicyDayShort + "-" + $backupPolicyRetentionSettings

Set-PSBreakpoint -Variable currenttime -Mode Read -Action {$global:currenttime = Get-Date -Format "dddd MM/dd/yyyy HH:mm"} | Out-Null 
$foregroundColor1 = "Green"
$foregroundColor2 = "Yellow"
$writeEmptyLine = "`n"
$writeSeperatorSpaces = " - "

## -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Remove the breaking change warning messages

Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true | Out-Null
Update-AzConfig -DisplayBreakingChangeWarning $false | Out-Null
$warningPreference = "SilentlyContinue"

## -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script started

Write-Host ($writeEmptyLine + "# Script started. Without errors, it can take up to 1 minute to complete" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Change the current context to the specified subscription

$subName = Get-AzSubscription | Where-Object {$_.Name -like $subscriptionName}

Set-AzContext -SubscriptionId $subName.SubscriptionId | Out-Null 

Write-Host ($writeEmptyLine + "# Specified subscription in current tenant selected" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Save the Recovery Services vault from the AVD subscription in a variable

$vault = Get-AzRecoveryServicesVault -Name $vaultName -ResourceGroupName $rgNameBackup

Write-Host ($writeEmptyLine + "# Recovery Services vault variable created" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Create a Backup retention policy

$backupTimeObject = Get-Date -Date ("2023-10-1 " + $backupTime + ":00Z")

# Gets a base SchedulePolicyObject and stores it in the $schedulePolicy variable
$schedulePolicy = Get-AzRecoveryServicesBackupSchedulePolicyObject -WorkloadType $backupPolicyWorkloadType

# Set timezone, remove all the scheduled run times from the $schedulePolicy, and set the backup time
$timeZone = Get-TimeZone
$schedulePolicy.ScheduleRunTimeZone = $timeZone.Id
$schedulePolicy.ScheduleRunTimes.Clear()
$schedulePolicy.ScheduleRunTimes.Add($backupTimeObject.ToUniversalTime())

# Gets the base RetentionPolicy object and then stores it in the $retentionPolicy variable
$retentionPolicy = Get-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType $backupPolicyWorkloadType
$retentionPolicy.ScheduleRunTimes

# Sets the retention duration policy settings
# Number of backups
$retentionPolicy.DailySchedule.DurationCountInDays = $durationCountInDays
$retentionPolicy.WeeklySchedule.DurationCountInWeeks = $durationCountInWeeks
$retentionPolicy.MonthlySchedule.DurationCountInMonths = $durationCountInMonths
$retentionPolicy.YearlySchedule.DurationCountInYears = $durationCountInYears

# Additional weekly settings
$retentionPolicy.WeeklySchedule.DaysOfTheWeek  = $backupDayOfWeek

# Additional monthly settings
$retentionPolicy.MonthlySchedule.RetentionScheduleWeekly.WeeksOfTheMonth = $backupNumberOfWeek
$retentionPolicy.MonthlySchedule.RetentionScheduleWeekly.DaysOfTheWeek = $backupDayOfWeek

# Additional yearly settings
$retentionPolicy.YearlySchedule.MonthsOfYear = $backupYMonthOfYear
$retentionPolicy.YearlySchedule.RetentionScheduleWeekly.WeeksOfTheMonth = $backupNumberOfWeek
$retentionPolicy.YearlySchedule.RetentionScheduleWeekly.DaysOfTheWeek = $backupDayOfWeek

# Create new policy with Archive smart tiering with TieringMode TierRecommended enabled
New-AzRecoveryServicesBackupProtectionPolicy -Name $backupPolicyName -RetentionPolicy $retentionPolicy -SchedulePolicy $schedulePolicy -VaultId $vault.ID -WorkloadType $backupPolicyWorkloadType `
-MoveToArchiveTier $true -TieringMode TierRecommended -BackupSnapshotResourceGroup $rgNameBackupIrpWithoutSuffix | Out-Null 

Write-Host ($writeEmptyLine + "# Backup retention policy with name $backupPolicyName available" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine

## -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Write script completed

Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine 

## -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

