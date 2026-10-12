# KartPad and WiiCompiled reports

KartPad builds on [WiiCompiled](https://github.com/patchzyy/Wiicompiled), created
by [patchzyy](https://github.com/patchzyy). WiiCompiled supplies the original
Mario Kart Wii static translator and runtime. KartPad maintains its modified
Apple/Android integration, controls, installation and packaging. The projects
are independently maintained.

## Choose a destination

- **KartPad app, installation, touch controls, or an uncertain cause:** use the
  [KartPad issue chooser](https://github.com/chrissotraidis/kartpad/issues/new/choose).
- **A suspected WiiCompiled runtime problem, or using WiiCompiled directly:** use
  the [WiiCompiled issue chooser](https://github.com/patchzyy/Wiicompiled/issues/new/choose).
  KartPad users can submit directly; no KartPad maintainer handoff is required.
  Clearly identify the modified KartPad build and whether the problem has also
  been reproduced on unmodified WiiCompiled. **Not tested** is a valid answer.

[Search reports in both projects](https://github.com/search?q=is%3Aissue+repo%3Achrissotraidis%2Fkartpad+repo%3Apatchzyy%2FWiicompiled&type=issues)
and add evidence to a matching issue instead of creating another. If reports already exist in both projects, cross-link
them. You do not need to open one in each project.

A race crash or graphics problem can involve KartPad changes too; the symptom
alone does not establish ownership. You do not need to diagnose the source
code to ask for help. Use KartPad when unsure.

WiiCompiled's forms ask about its latest release and include Windows log paths.
Do not check a statement that is untrue for your KartPad build or claim that
KartPad logs came from a stock WiiCompiled run. If the available form requires
a claim you cannot make, use KartPad and link any relevant upstream issue.
Each project's maintainers decide which reports they can investigate.

## Collect once, review, then attach

Use the [platform collection steps](SUPPORT.md#collect-a-useful-report).

| Platform | Start here |
| --- | --- |
| Android | **Report a Problem…** for a short report; **Export Private Diagnostics…** for runtime logs. |
| iPhone / iPad | **••• → Report a Problem…**; review/share the file and attach it manually on GitHub. |
| macOS | **Help → Save Diagnostics Report…**; review the saved report before attaching. |
| Experimental tvOS | Use the [tvOS testing guide](TVOS-TESTING.md) and its diagnostic collection script. There is no promised mobile-style sharing flow. |

A report ID is not an upload. Opening GitHub does not attach a file. Share the
same reviewed evidence when adding information to a linked upstream report;
do not create duplicate issues merely to copy the logs.

Include the exact app/build, device and OS, Original or Retro Rewind and pack
version, steps, and the session/time of the failure. Runtime `console.log` and
`crash_*.txt` files, when present, are different from a short app summary or an
OS exit record. Keep their startup/version information and relevant failure
context. Do not label an old log with the version installed when exporting it.
Mark missing runtime revision or stock-WiiCompiled reproduction as **unknown**
or **not tested**; do not infer either from the current repository.

Review text before sharing: omit game data, saves, NAND, credentials, console
identities, personal paths and network/account identifiers. The private Android
archive is for local inspection, not automatic public upload. Keep your
installation and saves intact while troubleshooting.

Repository migration is a separate decision; see
[Fork connection options](FORK-OPTIONS.md).

On Android and iPhone/iPad, **⋯ → Report a Problem…** lets you choose KartPad
or WiiCompiled and search both projects; on Mac it's **Help → Report a
Problem…**. Nothing is submitted automatically. The
[support guide](SUPPORT.md#collect-a-useful-report) explains which logs to
save on each platform.
