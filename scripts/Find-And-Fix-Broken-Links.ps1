Param(
    [string]$Root = (Resolve-Path '..' ).Path,
    [switch]$Apply,
    [string[]]$IncludeExtensions = @('*.md','*.markdown','*.mdx','*.html'),
    [int]$MaxEditsPerFile = 50
)

# Utility: Write colored output
function Write-Info($msg){ Write-Host $msg -ForegroundColor Cyan }
function Write-Warn($msg){ Write-Host $msg -ForegroundColor Yellow }
function Write-Err($msg){ Write-Host $msg -ForegroundColor Red }
function Write-Ok($msg){ Write-Host $msg -ForegroundColor Green }

# Resolve relative path from one file to target using .NET Path APIs
function Get-RelativePath([string]$fromFile,[string]$toFile){
    $fromDir = [System.IO.Path]::GetFullPath([System.IO.Path]::GetDirectoryName($fromFile))
    $toFull = [System.IO.Path]::GetFullPath($toFile)
    $rel = [System.IO.Path]::GetRelativePath($fromDir, $toFull)
    # Normalize to forward slashes for Markdown
    return $rel.Replace('\\','/')
}

# Find all candidate content files
$files = @()
foreach($pattern in $IncludeExtensions){
    $files += Get-ChildItem -Path $Root -Recurse -File -Filter $pattern
}

Write-Info "Scanning $($files.Count) files under $Root for broken links..."

# Regex patterns for markdown and html links
$mdLinkPattern = '(?<!!)\[[^\]]+\]\((?<url>[^)]+)\)'
$mdImagePattern = '!\[[^\]]*\]\((?<url>[^)]+)\)'
$htmlHrefPattern = 'href\s*=\s*"(?<url>[^"]+)"'
$htmlSrcPattern = 'src\s*=\s*"(?<url>[^"]+)"'

$broken = @()
$fixedCount = 0

foreach($file in $files){
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $edits = @()

    $matches = [System.Text.RegularExpressions.Regex]::Matches($content, $mdLinkPattern)
    $matches += [System.Text.RegularExpressions.Regex]::Matches($content, $mdImagePattern)
    if($file.Extension -match 'html'){ 
        $matches += [System.Text.RegularExpressions.Regex]::Matches($content, $htmlHrefPattern)
        $matches += [System.Text.RegularExpressions.Regex]::Matches($content, $htmlSrcPattern)
    }

    foreach($m in $matches){
        $url = $m.Groups['url'].Value.Trim()
        if(-not $url){ continue }
        # Skip external links and anchors
        if($url -match '^(?i)(https?|mailto|ftp):' -or $url -match '^#'){ continue }
        # Skip absolute Windows drive paths
        if($url -match '^[A-Za-z]:\\'){ continue }
        # Normalize and split fragment
        $fragment = ''
        if($url -match '#'){ $fragment = $url.Substring($url.IndexOf('#')); $url = $url.Substring(0, $url.IndexOf('#')) }
        # Remove query string from existence check
        $qs = ''
        if($url -match '\?'){ $qs = $url.Substring($url.IndexOf('?')); $url = $url.Substring(0, $url.IndexOf('?')) }
        if([string]::IsNullOrWhiteSpace($url)){ continue }

        # Resolve candidate path
        $candidate = Join-Path (Split-Path -Parent $file.FullName) $url
        $exists = Test-Path -LiteralPath $candidate
        if($exists){ continue }

        # Heuristic: search by basename across repo
        $base = [System.IO.Path]::GetFileName($url)
        if([string]::IsNullOrWhiteSpace($base)){
            # Might be a directory reference; skip for now
            $broken += [pscustomobject]@{ File=$file.FullName; Url=$m.Value; Type='DirRef' }
            continue
        }
        $candidates = Get-ChildItem -Path $Root -Recurse -File -Filter $base | Select-Object -ExpandProperty FullName
        if($candidates.Count -eq 1){
            $target = $candidates[0]
            $rel = Get-RelativePath $file.FullName $target
            $newUrl = $rel + $qs + $fragment
            $oldSnippet = $m.Value
            $newSnippet = $oldSnippet.Replace($m.Groups['url'].Value, $newUrl)
            $broken += [pscustomobject]@{ File=$file.FullName; Url=$oldSnippet; Suggestion=$newSnippet; Type='AutoFix' }
            if($Apply){
                $content = $content.Replace($oldSnippet, $newSnippet)
                $fixedCount++
                $edits += "$oldSnippet -> $newSnippet"
                if($edits.Count -ge $MaxEditsPerFile){ break }
            }
        } elseif($candidates.Count -gt 1){
            $broken += [pscustomobject]@{ File=$file.FullName; Url=$m.Value; Matches=$candidates; Type='Ambiguous' }
        } else {
            $broken += [pscustomobject]@{ File=$file.FullName; Url=$m.Value; Type='NotFound' }
        }
    }

    if($Apply -and $edits.Count -gt 0){
        Set-Content -LiteralPath $file.FullName -Value $content -NoNewline
        Write-Ok "Updated $($file.FullName): $($edits.Count) edits"
    }
}

Write-Host ""; Write-Info "Broken link summary:"
$counts = $broken | Group-Object Type | Select-Object Name,Count
$counts | ForEach-Object { Write-Host (" - {0}: {1}" -f $_.Name,$_.Count) }
Write-Host ""

# Output detailed report to file
$reportPath = Join-Path $Root 'scripts/broken-links-report.json'
$broken | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath
Write-Info "Report written to: $reportPath"

if($Apply){ Write-Ok "Auto-fixed $fixedCount links where a unique target was found." }

# Exit code indicates if broken links remain
if(($broken | Where-Object { $_.Type -ne 'AutoFix' }).Count -gt 0){
    Write-Warn "Some links could not be auto-fixed. See report for details."
    exit 2
} else {
    Write-Ok "All broken links were auto-fixed."
    exit 0
}
