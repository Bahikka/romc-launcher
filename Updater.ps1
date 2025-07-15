param(
    [Parameter(ValueFromPipeline=$true, Position=0)]
    [string]$Repository,
    [switch]$PassThru,
    [switch]$ps1
)

begin {
    $received = $null
}

process {
    if ($Repository) { $received = $Repository }
    elseif ($_ -ne $null) { $received = $_ }
}

end {
    if (-not $received) {
        Write-Error 'No repository specified.'
        return
    }

    if ($ps1) {
        if ($received -match '^(http|https)://') {
            $fileName = [IO.Path]::GetFileName($received)
            $localPath = Join-Path $env:TEMP $fileName
            $needsUpdate = $true
            if (Test-Path $localPath) {
                try {
                    $remoteSize = (Invoke-WebRequest -Uri $received -Method Head -UseBasicParsing).Headers['Content-Length']
                    $localSize = (Get-Item $localPath).Length
                    if ($remoteSize -eq $localSize) { $needsUpdate = $false }
                } catch { $needsUpdate = $true }
            }
            if ($PassThru) {
                if ($needsUpdate) { Write-Output $received } else { Write-Output $localPath }
            } else {
                if ($needsUpdate) {
                    Invoke-WebRequest -Uri $received -OutFile $localPath -UseBasicParsing
                }
                Write-Output $localPath
            }
        } else {
            Write-Output $received
        }
    } else {
        $name = [IO.Path]::GetFileNameWithoutExtension($received.TrimEnd('/').Split('/')[-1])
        $cacheRoot = Join-Path $env:TEMP 'repo_cache'
        if (-not (Test-Path $cacheRoot)) { New-Item -ItemType Directory -Path $cacheRoot | Out-Null }
        $localPath = Join-Path $cacheRoot $name
        $needsUpdate = $true
        if (Test-Path $localPath) {
            try {
                $remoteHash = (git ls-remote $received HEAD | ForEach-Object { $_.Split()[0] })
                $localHash = git -C $localPath rev-parse HEAD
                if ($remoteHash -eq $localHash) { $needsUpdate = $false }
            } catch { $needsUpdate = $true }
        }
        if ($PassThru) {
            if ($needsUpdate) { Write-Output $received } else { Write-Output $localPath }
        } else {
            if ($needsUpdate) {
                if (Test-Path $localPath) { git -C $localPath pull | Out-Null } else { git clone $received $localPath | Out-Null }
            }
            Write-Output $localPath
        }
    }
}
