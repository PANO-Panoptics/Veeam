# Load snapin
Add-PSSnapin VeeamPSSnapin

# Set-location
Set-location "c:\scripts\Veeam"

# Set Date Variables
$Now = get-date
$NowMonth = (Get-Culture).DateTimeFormat.GetMonthName($now.Month)
$NowYear = $now.Year

# Other Variables
$Server = $env:COMPUTERNAME

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
            VeeamServerName = $server
            JobName = $JobName
            VMName = $vm.Name
            Location = $vm.location
            Enabled = $vm.VssOptions.Enabled
            ApproxSize = $vm.ApproxSizeString

        }

        $Obj += New-Object psobject -Property $hash
    }

}

$AttachmentName = "Veeam VM Count for $Server - $NowMonth $NowYear.csv"

$Obj | 
    select VeeamServerName, VMName, Location, Enabled, ApproxSize | 
        export-csv $AttachmentName -NoTypeInformation

# Send an Email
Send-MailMessage -SmtpServer PANGlexch01 -To "judd@panoptics.com" -From "Veeam-$Server@Panoptics.com" `
    -Subject "Veeam VM Count for $Server - $NowMonth $NowYear" -Attachments $AttachmentName -BodyAsHtml



