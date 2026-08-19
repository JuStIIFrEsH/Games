param(
    [string]$WorkDir = "$PSScriptRoot\work"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Step([string]$Text) {
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Download-File([string]$Url, [string]$OutFile) {
    if (Test-Path $OutFile) {
        Write-Host "Using cached: $OutFile"
        return
    }
    Write-Host "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
}

function Utf8NoBom([string]$Path, [string]$Text) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

$Tag = "4.7-stable"
$BaseUrl = "https://github.com/godotengine/godot/releases/download/$Tag"

$GodotZip = Join-Path $WorkDir "Godot_v4.7-stable_win64.exe.zip"
$Templates = Join-Path $WorkDir "Godot_v4.7-stable_export_templates.tpz"
$GodotDir = Join-Path $WorkDir "godot"
$TemplateDir = Join-Path $WorkDir "templates"
$Dummy = Join-Path $WorkDir "dummy"
$Output = Join-Path $PSScriptRoot "launcher_build"

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

Step "Getting official Godot 4.7 Web runtime"
Download-File "$BaseUrl/Godot_v4.7-stable_win64.exe.zip" $GodotZip
Download-File "$BaseUrl/Godot_v4.7-stable_export_templates.tpz" $Templates

if (Test-Path $GodotDir) { Remove-Item $GodotDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $GodotDir | Out-Null
Expand-Archive $GodotZip $GodotDir -Force

$Godot = Get-ChildItem $GodotDir -Filter "Godot_v4.7-stable_win64_console.exe" | Select-Object -First 1
if (-not $Godot) { throw "Godot console executable not found." }

if (Test-Path $TemplateDir) { Remove-Item $TemplateDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $TemplateDir | Out-Null

$TemplateZip = Join-Path $WorkDir "templates.zip"
Copy-Item $Templates $TemplateZip -Force
Expand-Archive $TemplateZip $TemplateDir -Force

$Release = Get-ChildItem $TemplateDir -Recurse -Filter "web_nothreads_release.zip" | Select-Object -First 1
$Debug = Get-ChildItem $TemplateDir -Recurse -Filter "web_nothreads_debug.zip" | Select-Object -First 1

$UserTemplates = Join-Path $env:APPDATA "Godot\export_templates\4.7.stable"
New-Item -ItemType Directory -Force -Path $UserTemplates | Out-Null
Copy-Item $Release.FullName (Join-Path $UserTemplates "web_nothreads_release.zip") -Force
Copy-Item $Debug.FullName (Join-Path $UserTemplates "web_nothreads_debug.zip") -Force

Step "Creating launcher bootstrap"
if (Test-Path $Dummy) { Remove-Item $Dummy -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Dummy | Out-Null

Copy-Item (Join-Path $PSScriptRoot "launcher_shell.html") (Join-Path $Dummy "launcher_shell.html") -Force

@'
[application]

config/name="Regenesis Launcher"
run/main_scene="res://main.tscn"

[display]

window/size/viewport_width=640
window/size/viewport_height=360
window/stretch/mode="canvas_items"

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
'@ | Set-Content (Join-Path $Dummy "project.godot") -Encoding UTF8

@'
[gd_scene format=3]

[node name="Bootstrap" type="Node"]
'@ | Set-Content (Join-Path $Dummy "main.tscn") -Encoding UTF8

$ShellPath = (Join-Path $Dummy "launcher_shell.html").Replace("\","/")

$Preset = @"
[preset.0]

name="Web"
platform="Web"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path=""
patches=PackedStringArray()
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=false
vram_texture_compression/for_mobile=false
html/export_icon=false
html/custom_html_shell="$ShellPath"
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
"@

Utf8NoBom (Join-Path $Dummy "export_presets.cfg") $Preset

Step "Building local-file launcher"
if (Test-Path $Output) { Remove-Item $Output -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Output | Out-Null

& $Godot.FullName --headless --path $Dummy --export-release "Web" (Join-Path $Output "index.html")
if ($LASTEXITCODE -ne 0) { throw "Godot Web export failed: $LASTEXITCODE" }

# The exported dummy PCK is intentionally not part of this launcher.
Remove-Item (Join-Path $Output "index.pck") -Force -ErrorAction SilentlyContinue

Copy-Item (Join-Path $PSScriptRoot "icon-192.png") $Output -Force
Copy-Item (Join-Path $PSScriptRoot "icon-512.png") $Output -Force

$Manifest = @'
{
  "name": "Mega Man X Regenesis",
  "short_name": "Regenesis",
  "start_url": "./index.html",
  "scope": "./",
  "display": "standalone",
  "orientation": "landscape",
  "background_color": "#000000",
  "theme_color": "#000000",
  "icons": [
    { "src": "./icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "./icon-512.png", "sizes": "512x512", "type": "image/png" }
  ]
}
'@
Utf8NoBom (Join-Path $Output "manifest.webmanifest") $Manifest

# Cache ONLY the launcher/runtime. Never cache a game PCK.
$RuntimeFiles = Get-ChildItem $Output -File |
    Where-Object { $_.Extension -in ".html",".js",".wasm",".png",".webmanifest",".css",".json" } |
    Sort-Object Name

$Urls = @()
foreach ($f in $RuntimeFiles) {
    $Urls += '  "./' + $f.Name + '"'
}
$UrlList = $Urls -join ",`n"

$SW = @"
const CACHE = "regenesis-local-launcher-v1";
const ASSETS = [
$UrlList
];

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE)
      .then(async cache => {
        for (const asset of ASSETS) {
          await cache.add(asset);
        }
      })
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(names => Promise.all(
        names.filter(n => n.startsWith("regenesis-local-launcher-") && n !== CACHE)
             .map(n => caches.delete(n))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return;

  if (event.request.mode === "navigate") {
    event.respondWith(
      caches.match("./index.html", { ignoreSearch: true })
        .then(hit => hit || fetch(event.request))
    );
    return;
  }

  event.respondWith(
    caches.match(event.request, { ignoreSearch: true })
      .then(hit => hit || fetch(event.request))
  );
});
"@
Utf8NoBom (Join-Path $Output "service-worker.js") $SW

# Register launcher SW silently.
$HtmlPath = Join-Path $Output "index.html"
$Html = [System.IO.File]::ReadAllText($HtmlPath)
$Register = @'
<script>
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("./service-worker.js", {scope:"./"})
      .catch(err => console.error("Launcher offline install failed:", err));
  });
}
</script>
'@
$Html = $Html.Replace("</body>", $Register + "`n</body>")
Utf8NoBom $HtmlPath $Html

$Serve = @'
param([int]$Port = 8060)
python -m http.server $Port --bind 0.0.0.0 --directory $PSScriptRoot
'@
Utf8NoBom (Join-Path $Output "serve.ps1") $Serve

$Start = @'
param(
  [int]$Port = 8060,
  [string]$Cloudflared = "D:\cloudflared.exe"
)

$Serve = Join-Path $PSScriptRoot "serve.ps1"

Start-Process powershell -ArgumentList @(
  "-ExecutionPolicy","Bypass","-NoExit","-File","`"$Serve`"","-Port","$Port"
)

Start-Sleep 2

Start-Process powershell -ArgumentList @(
  "-NoExit","-Command","`"& '$Cloudflared' tunnel --url http://localhost:$Port`""
)
'@
Utf8NoBom (Join-Path $Output "start_iphone_install.ps1") $Start

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "LOCAL-FILES LAUNCHER BUILD COMPLETE" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Launcher:"
Write-Host "  $Output"
Write-Host ""
Write-Host "Game PCK (copy this to the iPhone Files app):"
Write-Host "  $(Join-Path $PSScriptRoot 'Regenesis_iPhone_Local.pck')"
Write-Host ""
Write-Host "Install launcher via HTTPS:"
Write-Host "  powershell -ExecutionPolicy Bypass -File `"$Output\start_iphone_install.ps1`""
