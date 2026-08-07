[CmdletBinding()]
param(
    [ValidateSet('Search', 'Audit', 'Install', 'Sync', 'Verify')]
    [string]$Action = 'Sync',
    [string]$Repository = (Get-Location).Path,
    [string]$Query,
    [string]$Source,
    [string]$Ref = 'HEAD',
    [string]$Commit,
    [string]$SkillPath,
    [string]$Name,
    [switch]$AllowWarnings
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-CanonicalGitHubUrl {
    param([Parameter(Mandatory)][string]$Url)

    $parsed = [Uri]$Url
    if ($parsed.Scheme -ne 'https' -or $parsed.Host -ne 'github.com') {
        throw 'Only HTTPS GitHub sources are allowed.'
    }
    $segments = @($parsed.AbsolutePath.Trim('/').Split('/') | Where-Object { $_ })
    if ($segments.Count -ne 2) {
        throw 'Source must identify one GitHub repository: https://github.com/OWNER/REPO'
    }
    $owner = $segments[0]
    $repo = $segments[1] -replace '\.git$', ''
    if ($owner -notmatch '^[A-Za-z0-9_.-]+$' -or $repo -notmatch '^[A-Za-z0-9_.-]+$') {
        throw 'GitHub owner or repository name contains unsupported characters.'
    }
    return "https://github.com/$owner/$repo.git"
}

function Invoke-CheckedGit {
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = & git -C $WorkingDirectory @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git failed: $($output -join [Environment]::NewLine)"
    }
    return ($output -join [Environment]::NewLine).Trim()
}

function Get-Checkout {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Revision
    )
    $canonicalUrl = ConvertTo-CanonicalGitHubUrl -Url $Url
    $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("codex-skill-audit-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
    try {
        Invoke-CheckedGit -WorkingDirectory $temporaryRoot -Arguments @('init', '--quiet') | Out-Null
        Invoke-CheckedGit -WorkingDirectory $temporaryRoot -Arguments @('remote', 'add', 'origin', $canonicalUrl) | Out-Null
        Invoke-CheckedGit -WorkingDirectory $temporaryRoot -Arguments @('fetch', '--quiet', '--depth', '1', 'origin', $Revision) | Out-Null
        Invoke-CheckedGit -WorkingDirectory $temporaryRoot -Arguments @('-c', 'advice.detachedHead=false', 'checkout', '--quiet', '--detach', 'FETCH_HEAD') | Out-Null
        $resolvedCommit = Invoke-CheckedGit -WorkingDirectory $temporaryRoot -Arguments @('rev-parse', 'HEAD')
        return [PSCustomObject]@{
            Root = $temporaryRoot
            Source = $canonicalUrl
            Commit = $resolvedCommit.Trim().ToLowerInvariant()
        }
    }
    catch {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
        throw
    }
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$FullName
    )
    return $FullName.Substring($Root.TrimEnd('\', '/').Length).TrimStart('\', '/').Replace('\', '/')
}

function Get-TreeHash {
    param([Parameter(Mandatory)][string]$Root)
    $lines = New-Object System.Collections.Generic.List[string]
    $files = @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File | Sort-Object FullName)
    foreach ($file in $files) {
        $relative = Get-RelativePath -Root $Root -FullName $file.FullName
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $lines.Add("$relative`0$hash")
    }
    $manifest = ($lines -join "`n") + "`n"
    $encoding = New-Object System.Text.UTF8Encoding -ArgumentList $false
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($hasher.ComputeHash($encoding.GetBytes($manifest)))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $hasher.Dispose()
    }
}

function Resolve-SkillDirectory {
    param(
        [Parameter(Mandatory)][string]$CheckoutRoot,
        [string]$RequestedPath
    )
    if ($RequestedPath) {
        $normalized = $RequestedPath.Replace('/', [IO.Path]::DirectorySeparatorChar).TrimStart('\', '/')
        $candidate = [IO.Path]::GetFullPath((Join-Path $CheckoutRoot $normalized))
        $rootPrefix = [IO.Path]::GetFullPath($CheckoutRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        if (-not $candidate.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'SkillPath escapes the checked-out repository.'
        }
        if (-not (Test-Path -LiteralPath (Join-Path $candidate 'SKILL.md') -PathType Leaf)) {
            throw "SKILL.md not found at '$RequestedPath'."
        }
        return $candidate
    }
    $skillFiles = @(Get-ChildItem -LiteralPath $CheckoutRoot -Recurse -Force -File -Filter 'SKILL.md' |
        Where-Object { $_.FullName -notlike '*\.git\*' })
    if ($skillFiles.Count -eq 0) {
        throw 'No SKILL.md was found in the source repository.'
    }
    if ($skillFiles.Count -gt 1) {
        $choices = $skillFiles | ForEach-Object { Get-RelativePath -Root $CheckoutRoot -FullName $_.Directory.FullName }
        throw "Multiple skills found. Repeat with -SkillPath and one of: $($choices -join ', ')"
    }
    return $skillFiles[0].Directory.FullName
}

function Get-SkillMetadata {
    param([Parameter(Mandatory)][string]$SkillRoot)
    $content = [IO.File]::ReadAllText((Join-Path $SkillRoot 'SKILL.md'))
    $frontmatter = [regex]::Match($content, '(?s)\A---\s*\r?\n(?<yaml>.*?)\r?\n---')
    if (-not $frontmatter.Success) {
        throw 'SKILL.md has no valid YAML frontmatter block.'
    }
    $yaml = $frontmatter.Groups['yaml'].Value
    $nameMatch = [regex]::Match($yaml, '(?m)^name:\s*["'']?(?<value>[^\r\n"'']+)["'']?\s*$')
    $descriptionMatch = [regex]::Match($yaml, '(?m)^description:\s*["'']?(?<value>[^\r\n]+?)["'']?\s*$')
    if (-not $nameMatch.Success -or -not $descriptionMatch.Success) {
        throw 'SKILL.md frontmatter must contain name and description.'
    }
    $skillName = $nameMatch.Groups['value'].Value.Trim()
    if ($skillName -notmatch '^[a-z0-9-]{1,64}$') {
        throw "Invalid skill name '$skillName'."
    }
    return [PSCustomObject]@{
        Name = $skillName
        Description = $descriptionMatch.Groups['value'].Value.Trim().Trim('"', "'")
    }
}

function Add-Finding {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Findings,
        [Parameter(Mandatory)][string]$Severity,
        [Parameter(Mandatory)][string]$Rule,
        [string]$File = '',
        [Parameter(Mandatory)][string]$Detail
    )
    $Findings.Add([PSCustomObject]@{ severity = $Severity; rule = $Rule; file = $File; detail = $Detail })
}

function Get-AuditReport {
    param(
        [Parameter(Mandatory)]$Checkout,
        [string]$RequestedPath
    )
    $skillRoot = Resolve-SkillDirectory -CheckoutRoot $Checkout.Root -RequestedPath $RequestedPath
    $relativeSkillPath = Get-RelativePath -Root $Checkout.Root -FullName $skillRoot
    $metadata = Get-SkillMetadata -SkillRoot $skillRoot
    $findings = New-Object 'System.Collections.Generic.List[object]'
    $files = @(Get-ChildItem -LiteralPath $skillRoot -Recurse -Force -File)
    $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $totalBytes) { $totalBytes = 0 }
    if ($files.Count -gt 1000) {
        Add-Finding -Findings $findings -Severity 'warning' -Rule 'large-file-count' -Detail "Skill contains $($files.Count) files."
    }
    if ($totalBytes -gt 25MB) {
        Add-Finding -Findings $findings -Severity 'warning' -Rule 'large-skill' -Detail "Skill contains $totalBytes bytes."
    }
    $treeRows = Invoke-CheckedGit -WorkingDirectory $Checkout.Root -Arguments @('ls-tree', '-r', 'HEAD', '--', $relativeSkillPath)
    foreach ($row in @($treeRows -split "`r?`n")) {
        if ($row -match '^120000\s') {
            Add-Finding -Findings $findings -Severity 'critical' -Rule 'symlink' -Detail 'Skill contains a symbolic link.'
        }
        if ($row -match '^160000\s') {
            Add-Finding -Findings $findings -Severity 'critical' -Rule 'submodule' -Detail 'Skill contains a Git submodule.'
        }
    }
    $binaryExtensions = @('.exe', '.dll', '.com', '.msi', '.so', '.dylib', '.class', '.jar', '.node')
    $scriptExtensions = @('.ps1', '.psm1', '.bat', '.cmd', '.sh', '.bash', '.zsh', '.py', '.js', '.mjs', '.cjs', '.ts', '.rb', '.pl')
    $textExtensions = @('.md', '.txt', '.json', '.yaml', '.yml', '.toml', '.xml', '.ini', '.cfg') + $scriptExtensions
    foreach ($file in $files) {
        $relative = Get-RelativePath -Root $skillRoot -FullName $file.FullName
        $extension = $file.Extension.ToLowerInvariant()
        if ($binaryExtensions -contains $extension) {
            Add-Finding -Findings $findings -Severity 'critical' -Rule 'executable-binary' -File $relative -Detail 'Precompiled executable content is not allowed.'
            continue
        }
        if ($file.Length -gt 2MB -or -not ($textExtensions -contains $extension)) { continue }
        $content = [IO.File]::ReadAllText($file.FullName)
        $checks = @(
            @{ Severity = 'critical'; Rule = 'instruction-override'; Pattern = '(?is)\b(ignore|disregard|override)\b.{0,80}\b(previous|prior|system|developer)\b.{0,80}\b(instruction|prompt|message)s?\b'; Detail = 'Attempts to override higher-priority instructions.' },
            @{ Severity = 'critical'; Rule = 'secret-exfiltration'; Pattern = '(?is)\b(upload|send|post|exfiltrate)\b.{0,120}(\.env|token|secret|credential|private[ _-]?key)'; Detail = 'May transmit secrets or credentials.' }
        )
        if ($scriptExtensions -contains $extension) {
            $checks += @(
                @{ Severity = 'critical'; Rule = 'download-pipe-shell'; Pattern = '(?is)(curl|wget|Invoke-WebRequest).{0,160}\|\s*(sh|bash|zsh|pwsh|powershell)'; Detail = 'Downloads content and pipes it into a shell.' },
                @{ Severity = 'critical'; Rule = 'dynamic-code-execution'; Pattern = '(?i)(Invoke-Expression|\biex\b|EncodedCommand|FromBase64String)'; Detail = 'Uses dynamic or encoded code execution.' },
                @{ Severity = 'warning'; Rule = 'destructive-command'; Pattern = '(?i)(rm\s+-rf|Remove-Item.{0,80}-Recurse.{0,80}-Force|git\s+reset\s+--hard|DROP\s+(DATABASE|TABLE))'; Detail = 'Contains a destructive command that needs manual scope review.' },
                @{ Severity = 'warning'; Rule = 'privilege-or-system-change'; Pattern = '(?i)(\bsudo\b|Verb\s+RunAs|schtasks|reg(\.exe)?\s+add|/etc/)'; Detail = 'May request privileges or modify system state.' },
                @{ Severity = 'warning'; Rule = 'network-access'; Pattern = '(?i)https?://|Invoke-RestMethod|Invoke-WebRequest|\bfetch\s*\(|\bcurl\b|\bwget\b'; Detail = 'Executable script contains network access.' }
            )
        }
        foreach ($check in $checks) {
            if ($content -match $check.Pattern) {
                Add-Finding -Findings $findings -Severity $check.Severity -Rule $check.Rule -File $relative -Detail $check.Detail
            }
        }
        if ($relative -match '(?i)(^|/)(hooks?|postinstall|preinstall)(/|\.|$)') {
            Add-Finding -Findings $findings -Severity 'warning' -Rule 'hook-or-install-script' -File $relative -Detail 'Hook or install-time behavior requires manual review.'
        }
    }
    $licenseFiles = @(Get-ChildItem -LiteralPath $Checkout.Root -Force -File |
        Where-Object { $_.Name -match '^(LICENSE|LICENCE|COPYING)(\.|$)' } | ForEach-Object Name)
    if ($licenseFiles.Count -eq 0) {
        Add-Finding -Findings $findings -Severity 'warning' -Rule 'missing-license' -Detail 'No repository-root license file was found.'
    }
    $criticalCount = @($findings | Where-Object severity -eq 'critical').Count
    $warningCount = @($findings | Where-Object severity -eq 'warning').Count
    $status = if ($criticalCount -gt 0) { 'blocked' } elseif ($warningCount -gt 0) { 'warnings' } else { 'passed' }
    return [PSCustomObject]@{
        status = $status
        source = $Checkout.Source
        commit = $Checkout.Commit
        skillPath = $relativeSkillPath
        name = $metadata.Name
        description = $metadata.Description
        treeSha256 = Get-TreeHash -Root $skillRoot
        fileCount = $files.Count
        sizeBytes = [long]$totalBytes
        licenseFiles = $licenseFiles
        findings = @($findings | ForEach-Object { $_ })
    }
}

function Copy-SkillDirectory {
    param(
        [Parameter(Mandatory)][string]$SourceDirectory,
        [Parameter(Mandatory)][string]$DestinationDirectory
    )
    New-Item -ItemType Directory -Path $DestinationDirectory | Out-Null
    Get-ChildItem -LiteralPath $SourceDirectory -Force | Copy-Item -Destination $DestinationDirectory -Recurse -Force
}

function Read-LockFile {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [PSCustomObject]@{ schemaVersion = 1; skills = @() }
    }
    $lock = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    if ($lock.schemaVersion -ne 1) {
        throw "Unsupported skill lock schema: $($lock.schemaVersion)"
    }
    return $lock
}

function Write-LockFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Lock
    )
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    $encoding = New-Object System.Text.UTF8Encoding -ArgumentList $false
    [IO.File]::WriteAllText($Path, ($Lock | ConvertTo-Json -Depth 8) + [Environment]::NewLine, $encoding)
}

function Invoke-Search {
    if ([string]::IsNullOrWhiteSpace($Query)) { throw '-Query is required for Search.' }
    $items = New-Object 'System.Collections.Generic.List[object]'
    $cursor = $null
    for ($page = 0; $page -lt 50; $page++) {
        $uri = 'https://api.colaos.ai/v1/skill-directory/skills?limit=100&sort=featured'
        if ($cursor) { $uri += '&cursor=' + [Uri]::EscapeDataString([string]$cursor) }
        $response = Invoke-RestMethod -Uri $uri -Headers @{ Accept = 'application/json' }
        foreach ($item in @($response.data.items)) { $items.Add($item) }
        $cursor = $response.data.next_cursor
        if (-not $cursor) { break }
    }
    @($items | Where-Object {
        $_.is_installable -eq $true -and $_.source_url -match '^https://github\.com/' -and
        (($_ | ConvertTo-Json -Depth 5 -Compress) -match [regex]::Escape($Query))
    } | Select-Object -First 20 slug, title, description, source_url, certification, authorization_status, license_type, stars, updated_at) |
        ConvertTo-Json -Depth 5
}

function Invoke-Audit {
    if ([string]::IsNullOrWhiteSpace($Source)) { throw '-Source is required for Audit.' }
    $checkout = Get-Checkout -Url $Source -Revision $Ref
    try { Get-AuditReport -Checkout $checkout -RequestedPath $SkillPath | ConvertTo-Json -Depth 8 }
    finally { Remove-Item -LiteralPath $checkout.Root -Recurse -Force -ErrorAction SilentlyContinue }
}

function Invoke-Install {
    if ([string]::IsNullOrWhiteSpace($Source) -or [string]::IsNullOrWhiteSpace($Commit) -or [string]::IsNullOrWhiteSpace($SkillPath)) {
        throw '-Source, -Commit, and -SkillPath are required for Install.'
    }
    if ($Commit -notmatch '^[0-9a-fA-F]{40}$') { throw '-Commit must be an exact 40-character Git commit.' }
    $repositoryRoot = [IO.Path]::GetFullPath($Repository)
    $skillsRoot = Join-Path $repositoryRoot '.agents\skills'
    $lockPath = Join-Path $repositoryRoot '.agents\skills.lock.json'
    $checkout = Get-Checkout -Url $Source -Revision $Commit
    try {
        if ($checkout.Commit -ne $Commit.ToLowerInvariant()) { throw "Resolved commit differs from requested commit." }
        $report = Get-AuditReport -Checkout $checkout -RequestedPath $SkillPath
        if ($report.status -eq 'blocked') {
            $report | ConvertTo-Json -Depth 8
            throw 'Installation blocked by critical audit findings.'
        }
        if ($report.status -eq 'warnings' -and -not $AllowWarnings) {
            $report | ConvertTo-Json -Depth 8
            throw 'Installation has audit warnings. Review them and repeat with -AllowWarnings only if justified.'
        }
        $installName = if ($Name) { $Name } else { $report.name }
        if ($installName -notmatch '^[a-z0-9-]{1,64}$') { throw "Invalid install name '$installName'." }
        $destination = Join-Path $skillsRoot $installName
        $sourceDirectory = Resolve-SkillDirectory -CheckoutRoot $checkout.Root -RequestedPath $SkillPath
        if (Test-Path -LiteralPath $destination) {
            if ((Get-TreeHash -Root $destination) -ne $report.treeSha256) {
                throw "Destination '$destination' already exists with different content."
            }
        }
        else {
            New-Item -ItemType Directory -Path $skillsRoot -Force | Out-Null
            Copy-SkillDirectory -SourceDirectory $sourceDirectory -DestinationDirectory $destination
        }
        $lock = Read-LockFile -Path $lockPath
        $entries = @($lock.skills | Where-Object { $_.name -ne $installName })
        $entries += [PSCustomObject][ordered]@{
            name = $installName
            source = $report.source
            commit = $report.commit
            path = $report.skillPath
            treeSha256 = $report.treeSha256
            reviewedAt = [DateTime]::UtcNow.ToString('o')
            auditStatus = $report.status
        }
        Write-LockFile -Path $lockPath -Lock ([PSCustomObject][ordered]@{ schemaVersion = 1; skills = @($entries | Sort-Object name) })
        [PSCustomObject]@{ status = 'installed'; name = $installName; destination = $destination; commit = $report.commit; treeSha256 = $report.treeSha256; auditStatus = $report.status } |
            ConvertTo-Json -Depth 5
    }
    finally { Remove-Item -LiteralPath $checkout.Root -Recurse -Force -ErrorAction SilentlyContinue }
}

function Invoke-Synchronize {
    param([switch]$VerifyOnly)
    $repositoryRoot = [IO.Path]::GetFullPath($Repository)
    $lock = Read-LockFile -Path (Join-Path $repositoryRoot '.agents\skills.lock.json')
    $skillsRoot = Join-Path $repositoryRoot '.agents\skills'
    $results = New-Object 'System.Collections.Generic.List[object]'
    foreach ($entry in @($lock.skills)) {
        if ($entry.name -notmatch '^[a-z0-9-]{1,64}$' -or $entry.commit -notmatch '^[0-9a-f]{40}$' -or $entry.treeSha256 -notmatch '^[0-9a-f]{64}$') {
            throw "Invalid lock entry for '$($entry.name)'."
        }
        $destination = Join-Path $skillsRoot $entry.name
        if (Test-Path -LiteralPath $destination) {
            $actualHash = Get-TreeHash -Root $destination
            if ($actualHash -ne $entry.treeSha256) {
                throw "Locked skill '$($entry.name)' was modified locally. Expected $($entry.treeSha256), found $actualHash."
            }
            $results.Add([PSCustomObject]@{ name = $entry.name; status = 'verified'; commit = $entry.commit })
            continue
        }
        if ($VerifyOnly) {
            $results.Add([PSCustomObject]@{ name = $entry.name; status = 'missing'; commit = $entry.commit })
            continue
        }
        $checkout = Get-Checkout -Url $entry.source -Revision $entry.commit
        try {
            if ($checkout.Commit -ne $entry.commit) { throw "Resolved commit for '$($entry.name)' differs from lock." }
            $sourceDirectory = Resolve-SkillDirectory -CheckoutRoot $checkout.Root -RequestedPath $entry.path
            if ((Get-TreeHash -Root $sourceDirectory) -ne $entry.treeSha256) { throw "Downloaded hash for '$($entry.name)' differs from lock." }
            New-Item -ItemType Directory -Path $skillsRoot -Force | Out-Null
            Copy-SkillDirectory -SourceDirectory $sourceDirectory -DestinationDirectory $destination
            $results.Add([PSCustomObject]@{ name = $entry.name; status = 'restored'; commit = $entry.commit })
        }
        finally { Remove-Item -LiteralPath $checkout.Root -Recurse -Force -ErrorAction SilentlyContinue }
    }
    [PSCustomObject]@{
        status = if (@($results | Where-Object status -eq 'missing').Count -gt 0) { 'missing' } else { 'ok' }
        skillCount = @($lock.skills).Count
        skills = @($results | ForEach-Object { $_ })
    } | ConvertTo-Json -Depth 6
}

switch ($Action) {
    'Search' { Invoke-Search }
    'Audit' { Invoke-Audit }
    'Install' { Invoke-Install }
    'Sync' { Invoke-Synchronize }
    'Verify' { Invoke-Synchronize -VerifyOnly }
}
