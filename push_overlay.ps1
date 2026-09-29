param(
    [switch]$Commit,
    [switch]$Push,
    [string]$Message = "Ship encrypted BuffTools overlay."
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Install-LocalPreCommitHook {
    $sample = Join-Path $Root "hooks\pre-commit"
    $gitDir = git rev-parse --git-dir
    if ($LASTEXITCODE -ne 0) {
        throw "Not a git repository."
    }
    $hookDst = Join-Path $gitDir "hooks\pre-commit"
    $hookDir = Split-Path -Parent $hookDst
    if (-not (Test-Path $hookDir)) {
        New-Item -ItemType Directory -Path $hookDir | Out-Null
    }
    if (Test-Path $sample) {
        Copy-Item -Path $sample -Destination $hookDst -Force
    }
}

function Invoke-Encode {
    $script = Join-Path $Root "encode_bt.py"
    if (-not (Test-Path $script)) {
        throw "encode_bt.py is missing. Do not flatten encryption; this file is required."
    }
    if (-not (Test-Path (Join-Path $Root "script.txt"))) {
        throw "script.txt is missing (readable source required)."
    }

    $py = Get-Command python -ErrorAction SilentlyContinue
    if ($py) {
        & python $script
    }
    else {
        $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
        if (-not $pyLauncher) {
            throw "python not found; cannot encrypt BuffTools.lua."
        }
        & py -3 $script
    }
    if ($LASTEXITCODE -ne 0) {
        throw "encode_bt.py failed with exit code $LASTEXITCODE"
    }
}

Install-LocalPreCommitHook
Invoke-Encode

git add -- BuffTools.lua
if ($LASTEXITCODE -ne 0) {
    throw "git add BuffTools.lua failed."
}

$blocked = git diff --cached --name-only | Select-String -Pattern '^(script\.txt|encode_bt\.py|decode_bt\.py|_pack_locals\.py|bt2713\.lua)$'
if ($blocked) {
    git restore --staged -- script.txt encode_bt.py decode_bt.py _pack_locals.py bt2713.lua 2>$null
    throw "Refusing to ship private source. Public file is BuffTools.lua only."
}

if ($Commit) {
    git -c user.name=webheartknight -c user.email=webheartknight@users.noreply.github.com commit -m $Message
    if ($LASTEXITCODE -ne 0) {
        throw "git commit failed (hooks were not skipped)."
    }
}

if ($Push) {
    git push
    if ($LASTEXITCODE -ne 0) {
        throw "git push failed."
    }
}

Write-Host "BuffTools.lua encoded and staged."
if ($Commit) { Write-Host "Committed." }
if ($Push) { Write-Host "Pushed." }
