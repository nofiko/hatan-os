$count = 0
foreach ($disk in Get-Disk -ErrorAction SilentlyContinue) {
    $parts = @(Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue)
    if ($parts.Count -ge 3) {
        $hasEfi = $false
        foreach ($p in $parts) {
            if ($p.DriveLetter -eq 'G' -or $p.Type -eq 'System') { $hasEfi = $true }
        }
        if ($hasEfi) { $count = [Math]::Max($count, $parts.Count) }
    }
}
Write-Output $count
