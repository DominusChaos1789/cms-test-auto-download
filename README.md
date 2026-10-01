# CMS Test Auto Download

Automates unattended downloads of **Avaya CMS Supervisor R21** Historical/Designer reports, so they don't need to be run manually from the Supervisor GUI each day.

## How it works

1. Each **`.acsauto`** file is an Avaya CMS Supervisor *automatic script*. It opens one or more Historical\Designer reports, sets the date automatically to the previous day, exports each to a file, and closes cleanly (`rep.quit`) so no report windows are left open. No `InputBox` or `MsgBox` prompts, so it can run with nobody watching.
2. **`run_cms_scripts.bat`** — a Windows batch launcher that runs the merged scripts **strictly in order, never in parallel**, killing any stuck `ACSApp.exe` process before and after each one and pausing between runs. This protects the CMS server from being overloaded by multiple simultaneous scripting sessions (which previously required manually killing the task and reconnecting).
3. Task Scheduler runs the `.bat` on a schedule, through the 32-bit shell (`C:\Windows\SysWOW64\cmd.exe /C "...\run_cms_scripts.bat"`), since Supervisor is a 32-bit application.

## Scripts (one per report group)

The original setup had 12 separate scripts (5 for intervalos, 5 for ROIF mensual, 2 for adherencia), split only because each report/export batch couldn't handle too many skills or agents at once — not because of any file-size limit. They've been merged into one script per report group; each merged script still contains the original per-batch skill/agent lists and export filenames (`_1`, `_2`, `_3`...), it's just all in a single automatic script now, which means fewer Supervisor logins and launches per run.

| File | Status | Covers |
|---|---|---|
| `1_Intervalos_Merged.acsauto` | ✅ Ready | 5 original "Intervalos" scripts (Conexión + Intervalos + DEO report blocks each) |
| `3_Adherencia_Merged.acsauto` | ✅ Ready | `[Call Center Telmex Hogar] Base_Tbl_Ag-N` (10 agent-range blocks) + `EYN Base_Tbl_Ag-N` (10 agent-range blocks) |
| `2_ROIF_Mensual_Merged.acsauto` | ⏳ Pending | Will merge the 5 original "Roif noNEXA" scripts once their full export/report sections are available |

All three use the same `SERVERNAME` and are redacted in this repo — see below.

## Before using this

All `.acsauto` files in this repo are **redacted** — placeholders like `<CMS_SERVER_IP>`, `<FILE_SERVER_IP>`, `<FILE_SERVER_IP_2>` / `<FILE_SERVER_IP_2B>`, `<CLIENT>`, and `<SKILL_IDS_..._n>` stand in for real values. Replace them with your own before running:

| Placeholder | Replace with |
|---|---|
| `<CMS_SERVER_IP>` | Your CMS server's address (IP, hostname, or FQDN) |
| `<FILE_SERVER_IP>` / `<FILE_SERVER_IP_2>` / `<FILE_SERVER_IP_2B>` | The file server(s)/share(s) where exports are written |
| `<CLIENT>` | Your destination folder name under the share |
| `<SKILL_IDS_INTERVALOS_n>` | Your real skill/split IDs for that batch, `;`-separated |

Keep your filled-in copy **local** — don't commit real server IPs, internal share paths, or skill IDs to a public repo.

## One-time setup in CMS Supervisor

1. **Herramientas > Opciones > Scripting > Set User** — set a dedicated administration user (not the shared `cms` account, which has shell permissions and will misbehave with autoscripts) with **automatic login**, not manual. Confirm its password hasn't expired. Without this, autoscripts fail with a generic `(null) [Line: 8] (null)` error the moment your interactive session isn't logged in — scripts left on `$DEFAULT$` borrow the interactive session's login and fail once that session times out (roughly every 4 hours).
2. Save each report block as an **automatic script** (`.acsauto`), not interactive (`.acsup`).
3. Test each `.acsauto` by double-clicking it once, manually, before scheduling it.

## Scheduling (Windows Task Scheduler)

- **Program/script:** `C:\Windows\SysWOW64\cmd.exe`
- **Arguments:** `/C "C:\path\to\run_cms_scripts.bat"`
- **Run as:** an account with write access to the export share
- **Settings:** "Run only when user is logged on" is simplest for a GUI app like Supervisor; "run whether logged on or not" can fail to reach network shares depending on how credentials are cached.

## Known pitfalls (and fixes) covered by this setup

- **32-bit vs 64-bit Task Scheduler:** Supervisor is 32-bit; scripts must be launched via `SysWOW64\cmd.exe` or they fail with `%1 in a not valid win32 program`.
- **Stuck report windows:** each report block ends with `rep.quit` and removes itself from `ActiveTasks`, so windows don't pile up after repeated runs.
- **Session timeout:** if the script's login is left on `$DEFAULT$`, it borrows your interactive Supervisor session's login — which fails once that session logs out or times out. Configuring a dedicated scripting user (see above) fixes this.
- **UNC path as working directory:** if the `.bat` itself lives on a network share, `cmd.exe` can't `cd` into it and falls back to `C:\Windows`. Keep the `.bat` on a local drive, or add a `pushd` to the UNC path at the top of the script.
- **Network share not reachable when run unattended:** map the share with explicit credentials (`net use`) inside the `.bat` if the scheduled task's account doesn't already have access.
- **CMS server overload from parallel scripts:** running several scripts against CMS Supervisor at once can overload and block the server, requiring a manual `taskkill` + reconnect. `run_cms_scripts.bat` always runs scripts sequentially with cleanup and a pause between each, and merging 12 scripts down to 3 further reduces the number of Supervisor logins per run.

## Files

- `1_Intervalos_Merged.acsauto` — merged automatic script covering 5 report groups (Conexión/Intervalos/DEO each), redacted.
- `3_Adherencia_Merged.acsauto` — merged automatic script covering Telmex Hogar + EYN adherencia reports (10 agent-range blocks each), redacted.
- `run_cms_scripts.bat` — launcher that runs the merged scripts in sequence, with process cleanup between each.
- `SIC General 1_Admininfo.acsauto` — original single-report example, superseded by `1_Intervalos_Merged.acsauto`; kept for reference.
