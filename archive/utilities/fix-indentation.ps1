#!/usr/bin/env pwsh
# Fix indentation in LoadGenerator.csx for dotnet-script compatibility

$scriptPath = Join-Path $PSScriptRoot 'LoadGenerator.csx'
Write-Host "📝 Reading $scriptPath..."

$content = Get-Content $scriptPath -Raw
$lines = $content -split "`r?`n"

Write-Host "📊 Total lines: $($lines.Count)"

# Lines 1-50: Keep as is (shebang, usings, Main declaration)
# Lines 51+: Add 4 space indent (except final closing brace)
$output = @()
$insideMain = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $lineNum = $i + 1
    $line = $lines[$i]
    
    # Detect start of Main function
    if ($line -match '^async Task<int> Main\(\)') {
        $insideMain = $true
        $output += $line
        continue
    }
    
    # Detect end of Main function
    if ($line -match '^\} // End of Main\(\)') {
        $insideMain = $false
        $output += $line
        continue
    }
    
    # Lines before Main or after Main - keep as is
    if (-not $insideMain) {
        $output += $line
        continue
    }
    
    # Lines inside Main - add indent if needed
    if ($line -match '^\s*$') {
        # Empty line - keep as is
        $output += $line
    }
    elseif ($line -match '^    ') {
        # Already has 4+ spaces - keep as is
        $output += $line
    }
    else {
        # Add 4 spaces
        $output += "    $line"
    }
}

# Write back to file
$outputText = $output -join "`n"
[System.IO.File]::WriteAllText($scriptPath, $outputText, [System.Text.Encoding]::UTF8)

Write-Host "✅ Indentation fixed! Lines processed: $($lines.Count)"
