# Regenesis iPhone GitHub Pages launcher — handoff

This package contains the source files from the known-working **Godot 4.7 local-PCK iPhone launcher**.

## Critical architecture

- GitHub Pages hosts only the launcher + Godot Web runtime.
- **Never commit a game `.pck` file.**
- On iPhone, the launcher opens the Files picker and the user chooses their local PCK.
- The launcher loads the selected PCK into Godot's virtual filesystem and starts it with `--main-pack`.
- The known working Regenesis PCK is stored separately by the user.

## Source files in this handoff

- `launcher_shell.html` — known-working file-picker launcher shell.
- `build_local_files_launcher.ps1` — builds the Godot 4.7 no-threads Web runtime/export and creates the PWA assets.
- `icon-192.png`, `icon-512.png` — Home Screen/PWA icons.
- `.gitignore` — blocks PCKs and build artifacts from accidental commits.

## What the build script produces

Running `build_local_files_launcher.ps1` creates `launcher_build/` containing the static site, including:

- `index.html`
- Godot-generated JavaScript runtime
- Godot-generated `.wasm`
- `manifest.webmanifest`
- `service-worker.js`
- icons

The generated dummy `index.pck` is deliberately deleted. The game PCK is NOT part of the site.

## GitHub Pages adaptation

For the repository deployment, use the generated contents of `launcher_build/` as the Pages site. The existing service worker uses relative URLs, which is appropriate for a project Pages path such as `/Games/`.

Do not include the local Cloudflare helper scripts (`serve.ps1` / `start_iphone_install.ps1`) in the published site; GitHub Pages replaces that hosting step.

## Known launcher fixes already folded in

- Initializes the engine using `GODOT_CONFIG.executable`, fixing the earlier base-path initialization error.
- No instructional paragraph in the launcher UI.
- Status text is hidden unless there is an actual status/error.
- PCK magic (`GDPC`) is checked before launch.
- PWA metadata uses the custom Regenesis icons.

## Important next step for the new ChatGPT conversation

Use the connected GitHub integration to inspect `JuStIIFrEsH/Games`, then add these source files. If the environment can build/commit generated artifacts, generate the Godot 4.7 static runtime and publish it. Otherwise preserve these source files in the repo and tell the user exactly what build artifact still needs to be generated.

Do not substitute a different Godot runtime version: the previous iPhone testing showed that mismatched runtime files caused broken/artifacted menu text and achievement/input UI.
