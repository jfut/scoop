# Usage: scoop status
# Summary: Show status and check for new app versions

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\depends.ps1"
. "$psscriptroot\..\lib\config.ps1"
. "$psscriptroot\..\lib\git.ps1"

reset_aliases

# check if scoop needs updating
$currentdir = fullpath $(versiondir 'scoop' 'current')
$needs_update = $false

if(test-path "$currentdir\.git") {
    Push-Location $currentdir
    git_fetch -q origin
    $commits = $(git log "HEAD..origin/$(scoop config SCOOP_BRANCH)" --oneline)
    if($commits) { $needs_update = $true }
    Pop-Location
}
else {
    $needs_update = $true
}

if($needs_update) {
    warn "Scoop is out of date. Run 'scoop update' to get the latest changes."
}
else { success "Scoop is up to date."}

$failed = @()
$outdated = @()
$removed = @()
$missing_deps = @()

$true, $false | ForEach-Object { # local and global apps
    $global = $_
    $dir = appsdir $global
    if(!(test-path $dir)) { return }

    Get-ChildItem $dir | Where-Object name -ne 'scoop' | ForEach-Object {
        $app = $_.name
        $status = app_status $app $global
        $install_info = install_info $app $status.version $global
        if($status.failed) {
            $failed += @{ $app = $status.version }
        }
        if($status.removed) {
            $removed += @{ $app = $status.version }
        }
        if($status.outdated) {
            $outdated += @{ $app = @($status.version, $status.latest_version, $install_info.bucket, $global) }
        }
        if($status.missing_deps) {
            $missing_deps += ,(@($app) + @($status.missing_deps))
        }
    }
}

if($outdated) {
    write-host -f DarkCyan 'Updates are available for:'
    $outdated.keys | ForEach-Object {
        $versions = $outdated.$_
        write-host "    $_`: $($versions[0]) -> $($versions[1])" -NoNewline
        if($versions[2]) { write-host -f Yellow " [$($versions[2])]" -NoNewline }
        if($versions[3]) { write-host -f DarkGreen ' *global*' -NoNewline }
        write-host ''
    }
}

if($removed) {
    write-host -f DarkCyan 'These app manifests have been removed:'
    $removed.keys | ForEach-Object {
        "    $_"
    }
}

if($failed) {
    write-host -f DarkCyan 'These apps failed to install:'
    $failed.keys | ForEach-Object {
        "    $_"
    }
}

if($missing_deps) {
    write-host -f DarkCyan 'Missing runtime dependencies:'
    $missing_deps | ForEach-Object {
        $app, $deps = $_
        "    '$app' requires '$([string]::join("', '", $deps))'"
    }
}

if(!$old -and !$removed -and !$failed -and !$missing_deps -and !$needs_update) {
    success "Everything is ok!"
}

exit 0
