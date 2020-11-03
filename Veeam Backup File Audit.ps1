# Veeam Audit

# Get Backup Files

Function Get-BackupName ($FileName)
{
    $ServerName = [regex]"[A-Za-z]{2}[0-9]{1}-[A-Za-z0-9]{1,15}" # Server Name Regex
    $BackupName = select-string -InputObject $FileName -Pattern $ServerName -List | % { $_.Matches } | % { $_.Value }
    Return $BackupName
}


$BackupObj = @()
$Imports = Import-Csv "Z:\Git\Veeam\ServerInfo.csv"

foreach ($Import in $Imports)
{
    $ServerName = $Import.Name
    $Path = $Import.Path
    
    # Get folders within folder
    $Folders = Get-ChildItem "FileSystem::\\$ServerName\$Path\" | Where-Object {$_.PSIsContainer -eq $true}

    Foreach ($folder in $Folders | Where-Object {$_.name -ne "VeeamConfigBackup"})
    {
        if (!$FolderInclude -and !$FolderExclude)
        {
    $FolderInclude = $Import.FolderInclude
    $FolderExclude = $Import.FolderExclude
            "1"
            $Files = Get-ChildItem "FileSystem::$($Folder.fullname)\" -Recurse
        }

        if ($FolderInclude)
        {
            "2"
            $Files = Get-ChildItem "FileSystem::$($Folder.fullname)\" -Recurse -Include "*$FolderInclude*"
        }
        if ($FolderExclude)
        {
            "3"
            $Files = Get-ChildItem "FileSystem::$($Folder.fullname)\" -Recurse -Exclude "*$FolderExclude*" 
        }
    
    
        $BackupFiles = $Files | Where-Object {$_.extension -eq ".vrb" -or $_.extension -eq ".vbk" -or $_.extension -eq ".vib"}


        $Now = Get-Date
        $NowFormatted = get-date -Format "ddMMyyhhmmss"
        $Retention = $Now.AddDays(-31)

        Foreach ($backupFile in $BackupFiles | Where-Object {$_.LastWriteTime -gt $Retention})
        {
            $FolderName = $Folder.Name
            $BackupFileName = $backupFile.Name
            $NewName = Get-BackupName -FileName $BackupFileName

            If ($NewName)
            {
                if ($backupFile.Extension -eq ".vbk")
                {
                    # If the backup file name had the server name in it. then
                    $Hash = @{
                        VeeamServer = $ServerName
                        FolderName = $FolderName
                        Path = $Path
                        Type = "Full Backup (Seed)"
                        Name = $BackupFile.Name
                        BackupName = $NewName
                        SizeGB = $backupFile.Length / 1024 / 1024 / 1024
        
                    }
                }
                elseif ($backupFile.Extension -eq ".vrb")
                {
                    $Hash = @{
                        VeeamServer = $ServerName
                        FolderName = $FolderName
                        Path = $Path
                        Type = "Reverse-Incremental Backup"
                        Name = $BackupFile.Name
                        BackupName = $NewName
                        SizeGB = $backupFile.Length / 1024 / 1024 / 1024
                    }
                }
                elseif ($backupFile.Extension -eq ".vib")
                {
                    $Hash = @{
                        VeeamServer = $ServerName
                        FolderName = $FolderName
                        Path = $Path
                        Type = "Incremental Backup"
                        Name = $BackupFile.Name
                        BackupName = $NewName
                        SizeGB = $backupFile.Length / 1024 / 1024 / 1024
                    }
                }
                else
                {
                    Write-Error "Unknown file extension $($backupFile.Extension)"
                    $Hash = @{
                        VeeamServer = $ServerName
                        FolderName = $FolderName
                        Path = $Path
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
                        VeeamServer = $ServerName
                        FolderName = $FolderName
                        Path = $Path
                        Type = "Full Backup (Seed)"
                        Name = $BackupFile.Name
                        BackupName = ($BackupFile.Name.Split("_")[0]).trim()
                        SizeGB = $backupFile.Length / 1024 / 1024 / 1024
        
                    }
                }
                elseif ($backupFile.Extension -eq ".vrb")
                {
                    $Hash = @{
                        VeeamServer = $ServerName
                        FolderName = $FolderName
                        Path = $Path
                        Type = "Reverse-Incremental Backup"
                        BackupName = ($BackupFile.Name.Split('(\s+)-')[0]).trim() # split on <space> + - (e.g. " -") for some reason, instead of just a space character, i had to use \s+ regular expression
                        Name = $BackupFile.Name
                        SizeGB = $backupFile.Length / 1024 / 1024 / 1024
                    }
                }
                elseif ($backupFile.Extension -eq ".vib")
                {
                    $Hash = @{
                        VeeamServer = $ServerName
                        FolderName = $FolderName
                        Path = $Path
                        Type = "Incremental"
                        BackupName = ($BackupFile.Name.Split('(\s+)-')[0]).trim() # split on <space> + - (e.g. " -") for some reason, instead of just a space character, i had to use \s+ regular expression
                        Name = $BackupFile.Name
                        SizeGB = $backupFile.Length / 1024 / 1024 / 1024
                    }
                }
                else
                {
                    Write-Error "Unknown file extension $($backupFile.Extension)"
                    $Hash = @{
                        VeeamServer = $ServerName
                        FolderName = $FolderName
                        Path = $Path
                        Type = "Unknown"
                        BackupName = "Unknown"
                        SizeGB = $backupFile.Length / 1024 / 1024 / 1024
                    }
                }
            }

            $BackupObj += New-Object psobject -Property $hash

        }
    
    }
}



  # Group the backups and calculate the size in GB
$VeeamReport = $BackupObj | Group-Object -Property FolderName,path, veeamserver, Type, BackupName| % {New-Object psobject -Property @{    
        BackupName = $_.Name
        SizeGB = [math]::Round(($_.group | Measure-Object SizeGB -Sum).sum,2)

        }
    }


# Convert results into an Object
$FinalBackUpReport = @()
foreach ($Item in $VeeamReport)
{
    $Hash = @{
        FolderName = $Item.BackupName.tostring().Split(",").trim()[0]
        Path = $Item.BackupName.tostring().Split(",").trim()[1]
        VeeamServer = $Item.BackupName.tostring().Split(",").trim()[2]
        BackupType = $Item.BackupName.tostring().Split(",").trim()[3]
        BackupName = $Item.BackupName.tostring().Split(",").trim()[4]
        BackupSizeGB = $Item.SizeGB
    }
    $FinalBackUpReport += New-Object psobject -Property $hash
}

# Export to CSV
$FinalBackUpReport | Select VeeamServer,Path, FolderName, BackupName, BackupSizeGB, BackupType | export-csv "Z:\Git\Veeam\Veeam Backup Size Report - $NowFormatted.csv" -NoTypeInformation

# Send an Email
Send-MailMessage -SmtpServer PANGlexch01 -To Andy@panoptics.com -cc "judd@panoptics.com" -From VeeamPowershell@Panoptics.com `
    -Subject "Veeam Backup Size Report" -Attachments "Z:\Git\Veeam\Veeam Backup Size Report - $NowFormatted.csv" `
    -BodyAsHtml

