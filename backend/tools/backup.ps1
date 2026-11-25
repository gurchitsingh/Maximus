<#
Backs up the production Postgres (Neon) to a LOCAL, gitignored folder with pg_dump.

  powershell -ExecutionPolicy Bypass -File backend\tools\backup.ps1

The connection string is Neon's DIRECT (non-pooled) URL. It is read from the DATABASE_URL_DIRECT environment
variable, or asked for (hidden input) when that is unset. It is never written to disk or printed.

The dump holds personal data. It stays in backend\backups\ (gitignored). This script never uploads anything:
do not put dumps in GitHub, GitHub Actions artifacts or any public place (this repo is public).
Needs pg_dump and pg_restore on PATH (PostgreSQL client tools, version 16 or newer to match Neon).
#>
param(
    [string]$OutDir = (Join-Path $PSScriptRoot "..\backups"),
    [int]$KeepDays = 28
)
$ErrorActionPreference = "Stop"

foreach ($tool in "pg_dump", "pg_restore") {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool not found on PATH. Install the PostgreSQL client tools (https://www.postgresql.org/download/windows/)."
    }
}

$url = $env:DATABASE_URL_DIRECT
if (-not $url) {
    $secure = Read-Host "Neon DIRECT connection string" -AsSecureString
    $url = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}
if ($url -notmatch '^postgres(ql)?://') { throw "That does not look like a postgres:// URL." }
if ($url -match '-pooler\.') { throw "That is the POOLED url. pg_dump needs the DIRECT one (no -pooler in the host name)." }

New-Item -ItemType Directory -Force $OutDir | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
$file = Join-Path $OutDir "maximus-$stamp.dump"

try {
    & pg_dump --format=custom --no-owner --no-privileges --file $file $url
    if ($LASTEXITCODE -ne 0) { throw "pg_dump failed (exit $LASTEXITCODE)" }
    & pg_restore --list $file | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "the dump does not read back (pg_restore --list failed)" }
} catch {
    if (Test-Path $file) { Remove-Item $file -Force }
    throw
}

Get-ChildItem $OutDir -Filter "maximus-*.dump" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$KeepDays) } |
    Remove-Item -Force

$size = [math]::Round((Get-Item $file).Length / 1KB)
Write-Host "Backup written: $file ($size KB). Older than $KeepDays days are deleted."
Write-Host "Restore test (into an EMPTY database): pg_restore --no-owner --dbname <url> $file"
