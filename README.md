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
| `2_ROIF_Mensual_Merged.acsauto` | ✅ Ready | 5 original "Roif noNEXA" scripts, 11 `CARGUE` blocks total |
| `3_Adherencia_Merged.acsauto` | ✅ Ready | `[Call Center Telmex Hogar] Base_Tbl_Ag-N` (10 agent-range blocks) + `EYN Base_Tbl_Ag-N` (10 agent-range blocks) |

All three use the same `SERVERNAME` and are redacted in this repo — see below.

### Notes on each merged script

- **Intervalos** — the "Conexión" report (`ConexiondesconexionDeocms`) block for each of the 5 groups now pulls the **last 3 days** (yesterday, 2 days ago, 3 days ago) in a single report session, exporting one `LOGIN_n_<date>.txt` per day. The "Intervalos" and "DEO" blocks stay single-day (yesterday only), unchanged. DEO 2 still carries the original extra export of a WFM occupation file (`OCUPACION-INFNEWMOV.csv`) to a third file server, in the same report session.
- **ROIF Mensual** — the 11 `CARGUE` output files are produced across the 5 original scripts like this: script 1 → CARGUE 1, 2, 9, 10; script 2 → CARGUE 3; script 3 → CARGUE 4; script 4 → CARGUE 5, 6, 7, 8; script 5 → CARGUE 11. Report used: `Historical\Designer\Validacion Skill Por Agente` (no "P-1" suffix, unlike Intervalos' DEO report). One assumption carried over from the original scripts: within script 1 and script 4 (each originally split into 4 skill batches), the batch-to-CARGUE order is assumed sequential (1st batch → lowest CARGUE number, ...). Only CARGUE 1/2 were directly confirmed against the original screenshots — double check CARGUE 9/10 (script 1) and 5/6/7/8 (script 4) produce the right agents the first time you run it. Also, the original scripts had a redundant `z = cvsSrv.Reports.CreateReport(Info,Rep)` line right after the real `b = ...CreateReport(...)` call in every ROIF block — that looked like an accidental duplicate (it would open a second, never-closed report task per block), so it was dropped here rather than carried forward, since leaked report tasks are part of what causes the CMS server overload this project is trying to avoid.
- **Adherencia** — unchanged from the original scripts aside from automatic dates and no `MsgBox`. Note: this report's date property is named `"Fecha"` (singular), unlike every other report in this repo (Conexión/Intervalos/DEO/ROIF), which all use `"Fechas"` (plural). Setting the wrong one doesn't raise an error under `On Error Resume Next` — it's silently dropped, `cvs.log` shows the date field blank, and `ExportData` then fails with `Invalid procedure call or argument`. If you ever add another report to this pattern, check its actual property name first (e.g. record a one-off interactive script against it) rather than assuming `"Fechas"`.

### Code structure (all 3 merged scripts)

All three keep the same shape as the original, proven-working scripts: one `Public Sub Main() ... End Sub`.

- **Paths and report names as variables at the top of `Main`** — every network path (file-server roots, subfolders) and every `Historical\Designer\...` report name is assigned to a plain variable (`FILE_SERVER_...`, `REPORTE_...`) right under `On Error Resume Next`, the same way the original scripts already did for `SK=`/skill lists. Nothing is hardcoded inline further down; every block references these variables instead. Change a path or report name once, at the top.
- **Inline error handling, same pattern the originals already used** — the "report not found" branch is untouched (MsgBox if interactive, `ACSERR.cvsLog` otherwise). What's new: every `CreateReport` failure and every `ExportData` failure now gets an explicit `Else` / `If Not b Then` branch that logs via `CreateObject("ACSERR.cvsLog")` + `AutoLogWrite`, instead of disappearing silently under `On Error Resume Next`.

This doesn't change what data is pulled or where it's exported — same reports, same skills/agents, same destinations — it just makes failures visible in `cvs.log` instead of disappearing, and keeps the paths/report names in one place without changing the file's shape.

### If a merged script won't load (stuck at "Loading Script:" in `cvs.log` forever)

Two things actually caused this while developing these scripts — **neither was the `Sub Main` structure**, despite that being the first suspect:

1. **Line endings must be CRLF, not LF.** CMS Supervisor's script host silently fails to get past `Loading Script:` — it never even reaches `Begin Script Host` in `cvs.log` — if the `.acsauto` file has Unix-style (LF-only) line endings. Save/re-save the file with Windows (CRLF) line endings (e.g. in Notepad++: Edit > EOL Conversion > Windows (CR LF), or in VS Code: click the line-ending indicator in the status bar and switch to CRLF).
2. **`'SERVERNAME=` at the top of the file, and every `sServer`-equivalent value, must be your real CMS server address** — not a placeholder. CMS Supervisor looks up the stored scripting-user credentials in the registry using that exact server string. If it's still `<CMS_SERVER_IP>` (i.e. you copied straight from this public repo without replacing placeholders), the script loads and starts, but login fails with `No se puede crear el objeto ServidorLogin failed.` and `GetAutoUser_Err1: registry key doesn't exist` in `cvs.log`, because there's no stored login for a server literally named `<CMS_SERVER_IP>`.

If you hit either of these: fix the line endings first (`Loading Script:` with nothing after it, not even `Begin Script Host`, points to this), then confirm every placeholder — especially `'SERVERNAME=` — has been replaced with your real values (`Begin Script Host` appears but login fails, points to this).

## Before using this

All `.acsauto` files in this repo are **redacted** — placeholders like `<CMS_SERVER_IP>`, `<FILE_SERVER_IP>`, `<FILE_SERVER_IP_2>` / `<FILE_SERVER_IP_2B>`, `<CLIENT>`, and `<SKILL_IDS_..._n>` stand in for real values. Replace them with your own before running:

| Placeholder | Replace with |
|---|---|
| `<CMS_SERVER_IP>` | Your CMS server's address (IP, hostname, or FQDN) |
| `<FILE_SERVER_IP>` / `<FILE_SERVER_IP_2>` / `<FILE_SERVER_IP_2B>` | The file server(s)/share(s) where exports are written |
| `<CLIENT>` | Your destination folder name under the share |
| `<SKILL_IDS_INTERVALOS_n>` / `<SKILL_IDS_ROIF_S1_n>` / `<SKILL_IDS_ROIF_S2>` / etc. | Your real skill/split IDs for that batch, `;`-separated |

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

- `1_Intervalos_Merged.acsauto` — merged automatic script covering 5 report groups (Conexión/Intervalos/DEO each; Conexión pulls the last 3 days), redacted.
- `2_ROIF_Mensual_Merged.acsauto` — merged automatic script covering all 11 ROIF `CARGUE` blocks across the 5 original scripts, redacted.
- `3_Adherencia_Merged.acsauto` — merged automatic script covering Telmex Hogar + EYN adherencia reports (10 agent-range blocks each), redacted.
- `run_cms_scripts.bat` — launcher that runs the 3 merged scripts in sequence, with process cleanup between each.
- `SIC General 1_Admininfo.acsauto` — original single-report example, superseded by `1_Intervalos_Merged.acsauto`; kept for reference.
