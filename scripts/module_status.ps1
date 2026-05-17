$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Modules = [ordered]@{
    CORE = @(
        @{ Source = "autonomy_profile.cfg"; Target = "system\behavior\autonomy" },
        @{ Source = "codex_mk3.schema"; Target = "system\parser\v3" },
        @{ Source = "mimic_engine.map"; Target = "system\mimic\engine" },
        @{ Source = "core_manifest.json"; Target = "system\manifest" }
    )
    WEB = @(
        @{ Source = "index.layout"; Target = "web\ui\root" },
        @{ Source = "routes.map"; Target = "web\router" },
        @{ Source = "api_endpoints.list"; Target = "web\api\definitions" },
        @{ Source = "branding.embed"; Target = "web\ui\branding" }
    )
    APP = @(
        @{ Source = "ui_frameset.json"; Target = "app\ui\screens" },
        @{ Source = "app_logic.flow"; Target = "app\logic\flow" },
        @{ Source = "permissions.map"; Target = "app\security\permissions" }
    )
    MANTRA = @(
        @{ Source = "codex_identity.txt"; Target = "branding\core" },
        @{ Source = "logo_positions.map"; Target = "branding\placement" },
        @{ Source = "tone_guide.md"; Target = "branding\tone" }
    )
    PRELAUNCH = @(
        @{ Source = "phase1_tease.plan"; Target = "marketing\prelaunch\phase1" },
        @{ Source = "phase2_identity.plan"; Target = "marketing\prelaunch\phase2" },
        @{ Source = "phase3_capabilities.plan"; Target = "marketing\prelaunch\phase3" },
        @{ Source = "phase4_hype.plan"; Target = "marketing\prelaunch\phase4" },
        @{ Source = "phase5_launch.plan"; Target = "marketing\prelaunch\phase5" }
    )
}

$Report = foreach ($Name in $Modules.Keys) {
    $Rows = foreach ($Mapping in $Modules[$Name]) {
        $Path = Join-Path (Join-Path $Root $Mapping.Target) $Mapping.Source
        [pscustomobject]@{
            source = $Mapping.Source
            target = "/" + $Mapping.Target.Replace("\", "/") + "/"
            installed = Test-Path $Path
        }
    }

    $Missing = @($Rows | Where-Object { -not $_.installed })
    [pscustomobject]@{
        module = $Name
        status = if ($Missing.Count -eq 0) { "$($Name)_ONLINE" } else { "$($Name)_MISSING_PACKETS" }
        installed_count = @($Rows | Where-Object installed).Count
        missing_count = $Missing.Count
        missing = $Missing
    }
}

$Report | ConvertTo-Json -Depth 5
