# HATAN OS — رفع المشروع إلى GitHub وبناء ISO
# الاستخدام: .\scripts\setup-github.ps1 -Username YOUR_GITHUB_USERNAME

param(
    [Parameter(Mandatory = $true)]
    [string]$Username,

    [string]$RepoName = 'hatan-os',
    [ValidateSet('public', 'private')]
    [string]$Visibility = 'public'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host ""
Write-Host "  HATAN OS — GitHub Setup" -ForegroundColor Cyan
Write-Host ""

# ── GitHub CLI ──
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing GitHub CLI (winget)..." -ForegroundColor Yellow
    winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI not found. Install from https://cli.github.com/ then re-run."
}

$auth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Login to GitHub (browser will open)..." -ForegroundColor Yellow
    gh auth login -h github.com -p https -w
}

# ── Git repo ──
if (-not (Test-Path '.git')) {
    git init -b main
}

$env:GIT_AUTHOR_NAME = 'HATAN OS'
$env:GIT_COMMITTER_NAME = 'HATAN OS'
$env:GIT_AUTHOR_EMAIL = 'hatan-os@users.noreply.github.com'
$env:GIT_COMMITTER_EMAIL = 'hatan-os@users.noreply.github.com'

git add -A
$status = git status --porcelain
if ($status) {
    git commit -m "Prepare HATAN OS for Steam Deck with boot UI, dual-boot, and GitHub ISO build."
    Write-Host "  [OK] Git commit created" -ForegroundColor Green
} else {
    Write-Host "  [OK] Nothing new to commit" -ForegroundColor Green
}

# ── Create repo & push ──
$remote = "https://github.com/$Username/$RepoName.git"
$exists = gh repo view "$Username/$RepoName" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Creating repo $Username/$RepoName ($Visibility)..." -ForegroundColor Cyan
    gh repo create $RepoName --$Visibility --source=. --remote=origin --description "HATAN OS — Steam Deck dual boot (Windows + SteamOS)"
} else {
    git remote remove origin 2>$null
    git remote add origin $remote
}

Write-Host "  Pushing to GitHub..." -ForegroundColor Cyan
git push -u origin main

Write-Host ""
Write-Host "  [OK] Repository: https://github.com/$Username/$RepoName" -ForegroundColor Green
Write-Host ""
Write-Host "  Building ISO on GitHub Actions..." -ForegroundColor Cyan
gh workflow run build-iso.yml

Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Yellow
Write-Host "    1. Open: https://github.com/$Username/$RepoName/actions"
Write-Host "    2. Wait 15-30 min for Build HATAN OS ISO"
Write-Host "    3. Download ISO from Artifacts"
Write-Host ""
Write-Host "  Or create a release:" -ForegroundColor Yellow
Write-Host "    git tag v0.1.0 && git push origin v0.1.0"
Write-Host ""
