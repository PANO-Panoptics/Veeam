# Veeam Audit

# Servers = pano-veeam01, panglveeam03

# Get Backup Files

Function Get-BackupName ($FileName)
{
    $ServerName = [regex]"[A-Za-z]{2}[0-9]{1}-[A-Za-z0-9]{1,15}"
    $BackupName = select-string -InputObject $FileName -Pattern $ServerName -List | % { $_.Matches } | % { $_.Value }
    Return $BackupName
}

$Imports = Import-Csv "C:\Users\JuddDavey\Documents\GitHub\Pano-Internal\Veeam\Veeam\ServerInfo.csv"

foreach ($Import in $Imports[1])
{
    $ServerName = $Import.Name
    $Path = $Import.Path
    $FolderInclude = $Import.FolderInclude
    $FolderExclude = $Import.FolderExclude
    
    $Files = Get-ChildItem "FileSystem::\\$ServerName\$Path\" -Recurse -Include $FolderInclude -Exclude $FolderExclude




}




$Files = Get-ChildItem "FileSystem::\\$Server\$DriveLetter\$Subfolder" -Recurse 

$BackupFiles = $Files | Where-Object {$_.extension -eq ".vrb" -or $_.extension -eq ".vbk"}

$Now = Get-Date
$NowFormatted = get-date -Format "ddMMyyhhmmss"
$Retention = $Now.AddDays(-31)

$BackupObj = @()

Foreach ($backupFile in $BackupFiles | Where-Object {$_.LastWriteTime -gt $Retention})
{
    $BackupFileName = $backupFile.Name
    $NewName = Get-BackupName -FileName $BackupFileName

    If ($NewName)
    {
        if ($backupFile.Extension -eq ".vbk")
        {
            # If the backup file name had the server name in it. then
            $Hash = @{
                Type = "Seed"
                Name = $BackupFile.Name
                BackupName = $NewName
                SizeGB = $backupFile.Length / 1024 / 1024 / 1024
        
            }
        }
        elseif ($backupFile.Extension -eq ".vrb")
        {
            $Hash = @{
                Type = "Incredmental"
                Name = $BackupFile.Name
                BackupName = $NewName
                SizeGB = $backupFile.Length / 1024 / 1024 / 1024
            }
        }
        else
        {
            Write-Error "Unknown file extension $($backupFile.Extension)"
            $Hash = @{
                Type = "Unknown"
                BackupName = "Unknown"
                SizeGB = $backupFile.Length / 1024 / 1024 / 1024
            }
        }
    }
    Else
    {
        if ($backupFile.Extension -eq ".vbk")
        {
            # If the backup file name does not have a server name in it
            $Hash = @{
                Type = "Seed"
                Name = $BackupFile.Name
                BackupName = ($BackupFile.Name.Split("_")[0]).trim()
                SizeGB = $backupFile.Length / 1024 / 1024 / 1024
        
            }
        }
        elseif ($backupFile.Extension -eq ".vrb")
        {
            $Hash = @{
                Type = "Incredmental"
                BackupName = ($BackupFile.Name.Split('(\s+)-')[0]).trim() # split on <space> + - (e.g. " -") for some reason, instead of just a space character, i had to use \s+ regular expression
                Name = $BackupFile.Name
                SizeGB = $backupFile.Length / 1024 / 1024 / 1024
            }
        }
        else
        {
            Write-Error "Unknown file extension $($backupFile.Extension)"
            $Hash = @{
                Type = "Unknown"
                BackupName = "Unknown"
                SizeGB = $backupFile.Length / 1024 / 1024 / 1024
            }
        }
    }
    
    

    $BackupObj += New-Object psobject -Property $hash

    # Group the backups

    $VeeamReport = $BackupObj | Group-Object -Property BackupName | 
        % {New-Object psobject -Property @{
            BackupName = $_.Name
            SizeGB = [math]::Round(($_.group | Measure-Object SizeGB -Sum).sum,2)
            #ServerName = 
        }
    }

}
$VeeamReport | select BackupName, SizeGB | export-csv "Veeam Backup Size Report - $NowFormatted.csv" -NoTypeInformation

Send-MailMessage -SmtpServer PANGlexch01 -To Judd@panoptics.com -From VeeamPowershell@Panoptics.com `
    -Subject "Veeam Backup Size Report" -Attachments "Veeam Backup Size Report - $NowFormatted.csv" `
    -BodyAsHtml










