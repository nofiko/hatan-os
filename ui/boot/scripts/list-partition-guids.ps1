Get-Disk | ForEach-Object {
    $disk = $_
    Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | ForEach-Object {
        $_.Guid.ToString().ToLower()
    }
}
