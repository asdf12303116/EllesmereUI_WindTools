<#
.SYNOPSIS
    本地打包：把工作区打成一个能直接丢进 Interface\AddOns 的 addon zip。

.DESCRIPTION
    BigWigsMods/packager（release.sh）本地可跑的子集，默认发布流程对齐它的行为：
      - 读 .pkgmeta 的 package-as / ignore / plain-copy
      - 以点开头的文件和目录一律不进包（.git、.github、.pkgmeta、.luarc.json ...）
      - .lua / .xml / .toc / .md / .txt 会被处理：替换 @keyword@、处理 build type 块、行尾统一成 CRLF
      - 其余文件原样复制
      - 产物：<OutDir>\<package-as>\ 暂存目录 -> <OutDir>\<package-as>-<version>.zip
        zip 内顶层目录是 <package-as>，和 packager 的产物同结构

    未实现：externals、move-folders、nolib、@localization(...)@、多 game type 的
    TOC 拆分与上传。本项目都没用到；真需要时再补。

.PARAMETER Version
    把版本号定死成这个值，不拼短 hash，也不看 tag。要打正式包用 -Release。

.PARAMETER Release
    打发布版：版本号只取基础号（HEAD tag -> .toc 的 ## X-Version -> Core\Changelog 里最大的 x.y.z），
    不追加 git hash。默认是开发版，基础号后面直接拼短 hash，形如 0.2.8-8b28c90。

.PARAMETER OutDir
    产物目录，默认 <项目根>\.release（已在 .gitignore 里）。

.PARAMETER KeepStaging
    保留 <OutDir>\<package-as>\ 暂存目录，默认打包成功后删掉，只留 zip。

.PARAMETER NoZip
    只生成暂存目录，不压 zip。

.EXAMPLE
    pwsh -File .\package.ps1          # 开发版，如 0.2.8-1a2b3c4

.EXAMPLE
    pwsh -File .\package.ps1 -Release # 正式版，如 0.2.8

.EXAMPLE
    pwsh -File .\package.ps1 -Version 0.3.0 -KeepStaging
#>
[CmdletBinding()]
param(
    [string]$Version,
    [switch]$Release,
    [string]$OutDir,
    [switch]$KeepStaging,
    [switch]$NoZip
)

$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
if (-not $OutDir) { $OutDir = Join-Path $Root '.release' }
$OutDir = [System.IO.Path]::GetFullPath($OutDir)
$RootPrefix = $Root.TrimEnd('\') + '\'

# packager 处理的文件类型；其余按二进制原样复制
$ProcessedExtensions = @('.lua', '.xml', '.toc', '.md', '.txt')
# 发布构建里不成立的 build type 关键字：整段用块注释括起来，行号不变
$InactiveKeywords = @('debug', 'alpha')

function Invoke-Git {
    param([string[]]$Arguments)
    $output = & git -C $Root @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    $text = ($output -join "`n").Trim()
    if ($text) { return $text }
    return $null
}

# .pkgmeta 是 YAML，但这里只用得到标量和标量列表，按行解析够了
function Read-PkgMeta {
    param([string]$Path)

    $meta = @{
        'package-as'     = $null
        'ignore'         = @()
        'plain-copy'     = @()
        'unsupported'    = @()
    }
    if (-not (Test-Path -LiteralPath $Path)) { return $meta }

    $listKey = $null
    foreach ($raw in Get-Content -LiteralPath $Path -Encoding utf8) {
        $line = $raw -replace '(^|\s)#.*$', ''
        if ($line -match '^\s*$') { continue }

        if ($line -match '^([A-Za-z][\w-]*)\s*:\s*(.*)$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim()
            $listKey = $null

            if ($key -eq 'ignore' -or $key -eq 'plain-copy') {
                if ($value) { $meta[$key] += $value.Trim('"').Trim("'") }
                else { $listKey = $key }
            }
            elseif ($key -eq 'package-as') {
                $meta['package-as'] = $value.Trim('"').Trim("'")
            }
            elseif ($key -ne 'manual-changelog') {
                # 其它指令会改变包内容，不能默默忽略（manual-changelog 只影响上传元数据）
                $meta['unsupported'] += $key
            }
            continue
        }

        if ($listKey -and $line -match '^\s*-\s*(.+)$') {
            $meta[$listKey] += $Matches[1].Trim().Trim('"').Trim("'")
        }
    }
    return $meta
}

function ConvertTo-IgnoreRegex {
    param([string]$Pattern)
    $segments = ($Pattern -replace '\\', '/') -split '/'
    $parts = foreach ($segment in $segments) {
        $bits = foreach ($ch in $segment.ToCharArray()) {
            if ($ch -eq '*') { '[^/]*' }
            elseif ($ch -eq '?') { '[^/]' }
            else { [regex]::Escape([string]$ch) }
        }
        -join $bits
    }
    # 匹配文件本身，也匹配"这是一层目录、底下全忽略"
    return '^' + (@($parts) -join '/') + '(/.*)?$'
}

function Test-MatchesAny {
    param([string]$RelativePath, [regex[]]$Regexes)
    foreach ($rx in $Regexes) {
        if ($rx.IsMatch($RelativePath)) { return $true }
    }
    return $false
}

# 把 packager 的关键字和 build type 块处理掉，行尾统一 CRLF
function Invoke-TextProcessing {
    param(
        [string]$Text,
        [string]$Extension,
        [hashtable]$Substitutions,
        [hashtable]$FileSubstitutions
    )

    # 先统一成 LF：多行正则的 $ 才不会卡在 \r 前面，打包前再统一回 CRLF
    $Text = $Text -replace "`r`n", "`n"
    $Text = $Text -replace "`r", "`n"

    # build type 标记只有 Lua 的 --@kw@ 形态，套到 xml/md 上会写出坏内容
    if ($Extension -eq '.lua') {
        # do-not-package：连标记一起整段删掉
        $Text = [regex]::Replace(
            $Text,
            '(?ms)^[ \t]*--@do-not-package@[ \t]*\n.*?^[ \t]*--@end-do-not-package@[ \t]*\n?',
            '')

        # 其余不成立的 build type 关键字：改成块注释，代码不执行但行号不变
        foreach ($keyword in $InactiveKeywords) {
            $Text = [regex]::Replace(
                $Text,
                "(?m)^([ \t]*)--@$keyword@[ \t]*$",
                "`$1--[===[@$keyword")
            $Text = [regex]::Replace(
                $Text,
                "(?m)^([ \t]*)--@end-$keyword@[ \t]*$",
                "`$1--@end-$keyword]===]")
        }
    }

    foreach ($name in $Substitutions.Keys) {
        $Text = $Text.Replace("@$name@", [string]$Substitutions[$name])
    }
    foreach ($name in $FileSubstitutions.Keys) {
        $Text = $Text.Replace("@$name@", [string]$FileSubstitutions[$name])
    }

    $Text = $Text -replace "`n", "`r`n"
    return $Text
}

function Remove-WithRetry {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    # 上一次打包的产物可能还被杀软/索引器短暂占着，等一下再删
    for ($attempt = 1; $attempt -le 10; $attempt++) {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            return
        }
        catch {
            if ($attempt -eq 10) { throw "删不掉 $Path（被其它进程占用）：$($_.Exception.Message)" }
            Start-Sleep -Milliseconds 300
        }
    }
}

function Get-FileGitInfo {
    param([string]$RelativePath)

    $info = @{}
    $log = Invoke-Git @('log', '-1', '--format=%H%n%h%n%an%n%aI%n%at', '--', $RelativePath)
    if (-not $log) {
        $log = Invoke-Git @('log', '-1', '--format=%H%n%h%n%an%n%aI%n%at')
    }
    if (-not $log) { return $info }

    $lines = $log -split "`n"
    $info['file-hash'] = $lines[0]
    $info['file-abbreviated-hash'] = $lines[1]
    $info['file-author'] = $lines[2]
    $info['file-date-iso'] = $lines[3]
    if ($lines[4]) {
        $stamp = [long]$lines[4]
        $info['file-timestamp'] = $stamp
        $info['file-date-integer'] = (Get-Date -UnixTimeSeconds $stamp).ToUniversalTime().ToString('yyyyMMdd')
    }
    $info['file-revision'] = (Invoke-Git @('rev-list', '--count', 'HEAD', '--', $RelativePath))
    if (-not $info['file-revision']) { $info['file-revision'] = '0' }
    return $info
}

function Resolve-Version {
    if ($Version) { return @{ Version = $Version; Source = '-Version 参数' } }

    $tag = Invoke-Git @('describe', '--tags', '--exact-match', 'HEAD')
    if ($tag) { return @{ Version = ($tag -replace '^v', ''); Source = "git tag $tag" } }

    if ($TocPath) {
        $line = Get-Content -LiteralPath $TocPath -Encoding utf8 |
            Where-Object { $_ -match '^##\s*X-Version\s*:\s*(.+)$' } |
            Select-Object -First 1
        if ($line -match '^##\s*X-Version\s*:\s*(.+)$') {
            return @{ Version = $Matches[1].Trim(); Source = '.toc 的 ## X-Version' }
        }
    }

    $changelogDir = Join-Path $Root 'Core\Changelog'
    if (Test-Path -LiteralPath $changelogDir) {
        $versions = Get-ChildItem -LiteralPath $changelogDir -Filter '*.lua' -File |
            Where-Object { $_.BaseName -match '^\d+\.\d+\.\d+$' } |
            ForEach-Object { [version]$_.BaseName } |
            Sort-Object -Descending
        if ($versions) {
            return @{ Version = $versions[0].ToString(); Source = 'Core\Changelog 里最大的版本文件' }
        }
    }

    throw "找不到版本号：没有 HEAD tag，.toc 里也没有 ## X-Version，Core\Changelog 里也没有 x.y.z 文件。用 -Version 指定。"
}

# ---------- 1. 读配置 ----------
$pkgmetaPath = Join-Path $Root '.pkgmeta'
$pkgmeta = Read-PkgMeta -Path $pkgmetaPath

$packageName = $pkgmeta['package-as']
if (-not $packageName) {
    $firstToc = Get-ChildItem -LiteralPath $Root -Filter '*.toc' -File | Select-Object -First 1
    if (-not $firstToc) { throw "没有 .pkgmeta 的 package-as，也找不到 .toc 文件，无法确定包名。" }
    $packageName = $firstToc.BaseName
}
# 包名会被拼进路径并用于递归清理，必须挡掉 ...\ 之类的东西
if ($packageName -notmatch '^[A-Za-z0-9_.-]+$') {
    throw ".pkgmeta 的 package-as 只允许字母、数字与 _ . -，实际是：$packageName"
}

$TocPath = Join-Path $Root "$packageName.toc"
if (-not (Test-Path -LiteralPath $TocPath)) {
    throw "找不到 $packageName.toc。没有 TOC 的包游戏不认，先修好再打。"
}

if ($pkgmeta['unsupported'].Count -gt 0) {
    Write-Warning ("本脚本未实现这些 .pkgmeta 指令，已忽略：" + ($pkgmeta['unsupported'] -join ', '))
}

$ignoreRegexes = @($pkgmeta['ignore'] | Where-Object { $_ } | ForEach-Object { ConvertTo-IgnoreRegex $_ })
$plainCopyRegexes = @($pkgmeta['plain-copy'] | Where-Object { $_ } | ForEach-Object { ConvertTo-IgnoreRegex $_ })

function Get-WorkTreeDirty {
    $status = & git -C $Root status --porcelain 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    return [bool]$status
}

# 基础版本号：tag -> .toc 的 ## X-Version -> Core\Changelog 里最大的 x.y.z
$resolved = Resolve-Version
$shortHash = Invoke-Git @('rev-parse', '--short=7', 'HEAD')
$workTreeDirty = Get-WorkTreeDirty

if ($Version) {
    $projectVersion = $Version
    $versionNote = '-Version 参数，原样使用'
}
elseif ($Release) {
    $projectVersion = $resolved.Version
    $versionNote = "$($resolved.Source)，发布版"
    if ($workTreeDirty) {
        Write-Warning "工作区有未提交的改动，发布包内容和这个版本号对不上。先提交或 stash 再打发布版。"
    }
}
else {
    if (-not $shortHash) {
        throw "取不到 HEAD 的短 hash，没法生成开发版本号。用 -Version 指定，或加 -Release 打发布版。"
    }
    $projectVersion = "$($resolved.Version)-$shortHash"
    $versionNote = "$($resolved.Source)，开发版"
}

Write-Host "包名     : $packageName"
Write-Host "版本     : $projectVersion  (来源: $versionNote)"

# ---------- 2. 关键字表 ----------
$nowUtc = (Get-Date).ToUniversalTime()
$projectTimestamp = Invoke-Git @('log', '-1', '--format=%at')
$substitutions = @{
    'project-version'          = $projectVersion
    'project-hash'             = (Invoke-Git @('rev-parse', 'HEAD'))
    'project-abbreviated-hash' = (Invoke-Git @('rev-parse', '--short', 'HEAD'))
    'project-revision'         = (Invoke-Git @('rev-list', '--count', 'HEAD'))
    'project-author'           = (Invoke-Git @('log', '-1', '--format=%an'))
    'project-date-iso'         = (Invoke-Git @('log', '-1', '--format=%aI'))
    'project-timestamp'        = $projectTimestamp
    'build-date'               = $nowUtc.ToString('yyyy-MM-dd')
    'build-date-iso'           = $nowUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
    'build-date-integer'       = $nowUtc.ToString('yyyyMMdd')
    'build-timestamp'          = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
}
if ($projectTimestamp) {
    $substitutions['project-date-integer'] = (Get-Date -UnixTimeSeconds ([long]$projectTimestamp)).ToUniversalTime().ToString('yyyyMMdd')
}
foreach ($key in @($substitutions.Keys)) {
    if ($null -eq $substitutions[$key]) { $substitutions.Remove($key) }
}

# ---------- 3. 收集文件 ----------
# 不传 -Force：以点开头的条目本来就不进包，顺便跳掉 .git 这种大目录
$sourceFiles = Get-ChildItem -LiteralPath $Root -Recurse -File |
    Where-Object { -not $_.FullName.StartsWith($OutDir, [System.StringComparison]::OrdinalIgnoreCase) }

$selected = New-Object System.Collections.Generic.List[object]
$ignoredCount = 0
foreach ($file in $sourceFiles) {
    $relative = $file.FullName.Substring($RootPrefix.Length) -replace '\\', '/'

    # packager 的硬规则：以点开头的文件和目录一律不进包，不用写进 ignore
    $hasDotSegment = $false
    foreach ($segment in ($relative -split '/')) {
        if ($segment.StartsWith('.')) { $hasDotSegment = $true; break }
    }
    if ($hasDotSegment) {
        $ignoredCount++
        continue
    }

    if (Test-MatchesAny -RelativePath $relative -Regexes $ignoreRegexes) {
        $ignoredCount++
        continue
    }
    $selected.Add([pscustomobject]@{
        Source   = $file.FullName
        Relative = $relative
        Plain    = (Test-MatchesAny -RelativePath $relative -Regexes $plainCopyRegexes)
    })
}
if ($selected.Count -eq 0) { throw "没有可打包的文件，检查 .pkgmeta 的 package-as 和 ignore。" }
Write-Host "文件     : 选中 $($selected.Count) 个，按 .pkgmeta ignore 排除 $ignoredCount 个"

# 只有真用到 @file-...@ 时才逐文件查 git，否则白花几百次 git 调用
$needsFileInfo = $false
foreach ($item in $selected) {
    if ($ProcessedExtensions -notcontains [System.IO.Path]::GetExtension($item.Relative) -or $item.Plain) { continue }
    if ((Get-Content -LiteralPath $item.Source -Raw -Encoding utf8) -match '@file-[a-z-]+@') {
        $needsFileInfo = $true
        break
    }
}

# ---------- 4. 暂存 ----------
$stage = [System.IO.Path]::GetFullPath((Join-Path $OutDir $packageName))
$outPrefix = $OutDir.TrimEnd('\') + '\'
if (-not $stage.StartsWith($outPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "拒绝清理 $stage：不在产物目录 $OutDir 下。"
}
if (Test-Path -LiteralPath $stage) { Remove-WithRetry -Path $stage }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$processedCount = 0
$copiedCount = 0
$fileInfoCache = @{}

foreach ($item in $selected) {
    $destination = Join-Path $stage $item.Relative
    $destinationDir = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    $extension = [System.IO.Path]::GetExtension($item.Relative)
    if ($item.Plain -or $ProcessedExtensions -notcontains $extension) {
        Copy-Item -LiteralPath $item.Source -Destination $destination -Force
        $copiedCount++
        continue
    }

    $text = [System.IO.File]::ReadAllText($item.Source, [System.Text.Encoding]::UTF8)
    $fileSubstitutions = @{}
    if ($needsFileInfo) {
        if (-not $fileInfoCache.ContainsKey($item.Relative)) {
            $fileInfoCache[$item.Relative] = Get-FileGitInfo -RelativePath $item.Relative
        }
        $fileSubstitutions = $fileInfoCache[$item.Relative]
    }
    $text = Invoke-TextProcessing -Text $text -Extension $extension.ToLowerInvariant() -Substitutions $substitutions -FileSubstitutions $fileSubstitutions
    [System.IO.File]::WriteAllText($destination, $text, $utf8NoBom)
    $processedCount++
}

Write-Host "处理     : $processedCount 个逐文本处理，$copiedCount 个原样复制"

# ---------- 5. 压缩 ----------
if ($NoZip) {
    Write-Host "已跳过压缩，暂存目录: $stage"
    return
}

$zipPath = Join-Path $OutDir ("{0}-{1}.zip" -f $packageName, $projectVersion)
Remove-WithRetry -Path $zipPath

# includeBaseDirectory = $true：zip 内顶层目录就是 <package-as>，和 packager 一致
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $stage, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $true)

if (-not $KeepStaging) { Remove-WithRetry -Path $stage }

$sizeKb = [math]::Round((Get-Item -LiteralPath $zipPath).Length / 1KB, 1)
Write-Host ""
Write-Host "打包完成 : $zipPath  ($sizeKb KB)"
Write-Host "校验     : 解开后确认顶层是 $packageName\，里面含 $packageName.toc"
