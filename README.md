# CMS Test Auto Download

Automates unattended downloads of **Avaya CMS Supervisor R21** Historical/Designer reports, so they don't need to be run manually from the Supervisor GUI each day.

## How it works

1. **`SIC General 1_Admininfo.acsauto`** — an Avaya CMS Supervisor *automatic script*. It opens three Historical\Designer reports (connection log, split/skill intervals, and skill validation), sets the date automatically to the previous day, exports each to a file, and closes cleanly (`rep.quit`) so no report windows are left open. No `InputBox` or `MsgBox` prompts, so it can run with nobody watching.
2. **`run_sic_general.bat`** — a Windows batch launcher that runs every `.acsauto` file found in each configured folder, in order, logging start/end times to `run_log.txt` and killing any stuck `ACSApp.exe` process before and after each folder.
3. Task Scheduler runs the `.bat` on a schedule, through the 32-bit shell (`C:\Windows\SysWOW64\cmd.exe /C "...\run_sic_general.bat"`), since Supervisor is a 32-bit application.

## Before using this

The `.acsauto` file in this repo is **redacted** — placeholders like `<CMS_SERVER_IP>`, `<FILE_SERVER_IP>`, `<CLIENT>`, and `<SKILL_ID_n>` stand in for real values. Replace them with your own before running:

| Placeholder | Replace with |
|---|---|
| `<CMS_SERVER_IP>` | Your CMS server's address (IP, hostname, or FQDN) |
| `<FILE_SERVER_IP>` | The file server/share where exports are written |
| `<CLIENT>` | Your destination folder name under the share |
| `<SKILL_ID_n>` | Your real skill/split IDs, `;`-separated |

Keep your filled-in copy **local** — don't commit real server IPs, internal share paths, or skill IDs to a public repo.

## One-time setup in CMS Supervisor

1. **Herramientas > Opciones > Scripting > Set User** — set a dedicated administration user (not the shared `cms` account, which has shell permissions and will misbehave with autoscripts) with **automatic login**, not manual. Confirm its password hasn't expired. Without this, autoscripts fail with a generic `(null) [Line: 8] (null)` error the moment your interactive session isn't logged in.
2. Save each report block as an **automatic script** (`.acsauto`), not interactive (`.acsup`).
3. Test each `.acsauto` by double-clicking it once, manually, before scheduling it.

## Scheduling (Windows Task Scheduler)

- **Program/script:** `C:\Windows\SysWOW64\cmd.exe`
- **Arguments:** `/C "C:\path\to\run_sic_general.bat"`
- **Run as:** an account with write access to the export share
- **Settings:** "Run only when user is logged on" is simplest for a GUI app like Supervisor; "run whether logged on or not" can fail to reach network shares depending on how credentials are cached.

## Known pitfalls (and fixes) covered by this setup

- **32-bit vs 64-bit Task Scheduler:** Supervisor is 32-bit; scripts must be launched via `SysWOW64\cmd.exe` or they fail with `%1 in a not valid win32 program`.
- **Stuck report windows:** each report block ends with `rep.quit` and removes itself from `ActiveTasks`, so windows don't pile up after repeated runs.
- **Session timeout:** if the script's login is left on `$DEFAULT$`, it borrows your interactive Supervisor session's login — which fails once that session logs out or times out. Configuring a dedicated scripting user (see above) fixes this.
- **UNC path as working directory:** if the `.bat` itself lives on a network share, `cmd.exe` can't `cd` into it and falls back to `C:\Windows`. Keep the `.bat` on a local drive, or add a `pushd` to the UNC path at the top of the script.
- **Network share not reachable when run unattended:** map the share with explicit credentials (`net use`) inside the `.bat` if the scheduled task's account doesn't already have access.

## Files

- `SIC General 1_Admininfo.acsauto` — example automatic script covering 3 Historical\Designer reports (redacted).
- `run_sic_general.bat` — launcher that runs every `.acsauto` in three configured folders, in sequence.
