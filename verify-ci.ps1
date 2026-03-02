# Verification: apitool ci init (5 checks)
# Use FILE instead of binary: $env:APITOOL = "python -m apitool"; .\verify-ci.ps1
#    or: $env:APITOOL = "node C:\path\to\apitool\cli.js"; .\verify-ci.ps1
# Default: APITOOL = "apitool" (binary)

$ErrorActionPreference = "Stop"
$APITOOL = if ($env:APITOOL) { $env:APITOOL } else { "apitool" }
$root = $PSScriptRoot
$failed = 0

Write-Host "Using APITOOL: $APITOOL" -ForegroundColor Gray

function Run-Check($num, $name, $block) {
    Write-Host "`n--- Check $num : $name ---" -ForegroundColor Cyan
    try {
        & $block
        Write-Host "PASS" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "FAIL: $_" -ForegroundColor Red
        return $false
    }
}

# 1. apitool ci init --github → .github/workflows/api-tests.yml
$ok1 = Run-Check 1 "ci init --github creates .github/workflows/api-tests.yml" {
    Push-Location $root
    if (Test-Path ".github/workflows/api-tests.yml") { Remove-Item ".github/workflows/api-tests.yml" -Force }
    if (Test-Path ".github") { Remove-Item ".github" -Recurse -Force }
    Invoke-Expression "$APITOOL ci init --github"
    if (-not (Test-Path ".github/workflows/api-tests.yml")) { throw "File not created" }
    Pop-Location
}
if (-not $ok1) { $failed++ }

# 2. apitool ci init --gitlab → .gitlab-ci.yml
$ok2 = Run-Check 2 "ci init --gitlab creates .gitlab-ci.yml" {
    Push-Location $root
    if (Test-Path ".gitlab-ci.yml") { Remove-Item ".gitlab-ci.yml" -Force }
    Invoke-Expression "$APITOOL ci init --gitlab"
    if (-not (Test-Path ".gitlab-ci.yml")) { throw "File not created" }
    Pop-Location
}
if (-not $ok2) { $failed++ }

# 3. Re-run without --force → file not overwritten (skip existing)
$ok3 = Run-Check 3 "Re-run without --force leaves file unchanged" {
    Push-Location $root
    $path = ".github/workflows/api-tests.yml"
    $contentBefore = Get-Content $path -Raw
    Invoke-Expression "$APITOOL ci init --github"
    $contentAfter = Get-Content $path -Raw
    if ($contentBefore -ne $contentAfter) { throw "File was modified (should skip existing)" }
    Pop-Location
}
if (-not $ok3) { $failed++ }

# 4. apitool ci init --force → file overwritten
$ok4 = Run-Check 4 "ci init --force overwrites file" {
    Push-Location $root
    $path = ".github/workflows/api-tests.yml"
    $marker = "# force-overwrite-marker"
    Add-Content $path $marker
    Invoke-Expression "$APITOOL ci init --github --force"
    $content = Get-Content $path -Raw
    if ($content -match [regex]::Escape($marker)) { throw "File still contains marker (was not overwritten)" }
    Pop-Location
}
if (-not $ok4) { $failed++ }

# 5. apitool --help → shows ci command
$ok5 = Run-Check 5 "--help shows ci command" {
    $help = Invoke-Expression "$APITOOL --help 2>&1" | Out-String
    if ($help -notmatch "ci") { throw "Help does not mention 'ci'" }
}
if (-not $ok5) { $failed++ }

Write-Host "`n=== Result: $failed failed of 5 ===" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
exit $failed
