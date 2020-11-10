# Start
$Obj = @()
$BackupJobs = Get-VBRJob
foreach ($BackupJob in $BackupJobs)
{
    $JobName = $BackupJob.name
    write-host "`nJobName = $JobName`n" -ForegroundColor Yellow
    $VMs = $BackupJob.getobjectsinjob()

    foreach ($VM in $VMs)
    {
        write-host "VM Name = $($VM.name)" -ForegroundColor Cyan
        $Hash = @{
            JobName = $JobName
            Name = $vm.Name
            Location = $vm.location
            Enabled = $vm.VssOptions.Enabled
            ApproxSize = $vm.ApproxSizeString

        }

        $Obj += New-Object psobject -Property $hash
    }

}

$Obj | select Name, Location, Enabled, ApproxSize | export-csv Veeam03.csv -NoTypeInformation

explorer.exe .\


# End