# Reply drafts for 0.8.13 (28 November 2026)

Not posted. Post each one when 0.8.13 is published, and close an issue only when its reporter confirms or Chris decides to. Each draft names what the release changes and what still isn't checked.

## #131 (iStraySh, Retro Rewind crash after a cup; Spanish)

> Hola iStraySh,
>
> Encontré la causa y está corregida en la 0.8.13. Retro Rewind cambia los archivos de la pantalla de premios al idioma que eliges en sus ajustes, pero su lista de archivos no incluye los de premios, así que con cualquier idioma que no sea inglés el juego recibía un archivo vacío y se cerraba al empezar la ceremonia. Pasaba con Retro Rewind en español, y por eso no lo veía en mis pruebas en inglés.
>
> La 0.8.13 añade los archivos de premios que Retro Rewind trae para cada idioma. En el emulador, con Retro Rewind en español, la copa terminó con la ceremonia del trofeo y también con el final para los últimos puestos, y volvió al menú sin cerrarse. Todavía no lo he probado en un teléfono: si puedes, termina una copa con la 0.8.13 (instalada encima, sin desinstalar) y dime si llegas al menú.
>
> Mientras tanto, en la 0.8.12 puedes evitarlo poniendo Retro Rewind en inglés.
>
> Chris

## #493 (jossol27, closed; same crash)

> Hola jossol27, el cierre al terminar una copa en Retro Rewind tenía una causa concreta: Retro Rewind en un idioma distinto del inglés. Está corregido en la 0.8.13 (detalles en #131). Si lo pruebas, cuéntame si la copa llega al menú.
>
> Chris

## Retro Rewind upstream (rr-pulsar #204), for Chris to post if he wants to

> The awards crash (`ARCInitHandle: bad archive format` after the last race of a GP) reproduces whenever the Pulsar language setting is anything but English. `RenameAward()` in `PulsarEngine/Languages.cpp` renames `/Scene/UI/Award` to `/Ucene/UI/Award` (Spanish US), `/Fcene/…` (French) and so on, but `RetroRewind6.xml` only maps the per-language `Race` and `Common` archives. `/?cene/UI/Award.szs` and `/?cene/UI/Award_E.szs` then don't exist, the awards scene's UI holder keeps two empty slots, and `AttachLayoutResources` passes their null archive to `ARCInitHandle`. Adding `<file disc="/Ucene/UI/Award.szs" external="/RetroRewind6/UI/Award.szs"/>` and `Award_E/_J/_U` → `Language/SPA(NTSC)/UI/Award_AS.szs` (and the same for each language, as for Race) should fix it. KartPad 0.8.13 adds those mappings in its runtime as a workaround.

## #576 (AchieveFreedom, slow on Helio G99)

> AchieveFreedom, 0.8.13 is out. Three things in it are for phones like yours:
>
> - **⋯ → Speed & Graphics → Speed → Smoothest** turns on 30 FPS Races and Simpler Computer Karts in one tap. After a slow race KartPad also offers it once.
> - The menu movies are decoded by KartPad's own code now, which cut the video thread's work by about 43% on the emulator at the main menu and Select Cup. That's the part of cup and course select that was slowest in #584's Helio G99 log.
> - The engine choices now say **Classic (Vulkan)** and **WiiCompiled 0.9 Beta (Vulkan)**, since both already draw with Vulkan.
>
> None of this has run on a Helio G99 yet. If you try it, a diagnostic log from a slow moment (**⋯ → Report a Problem… → Save Diagnostic Log…**) would show how much it helped.
>
> Chris

## #584 (Helio G99 menu stutter)

> 0.8.13 decodes the menu movies natively instead of through the translated decoder. On the emulator the video thread's time per frame fell by about 43% at the main menu and Select Cup (1.16–1.26 → 0.69–0.71 ms, and 3.98–4.22 → 2.00–2.71 ms), and every frame of the disc's 27 movies decodes the same as before. It hasn't run on a Helio G99. If you update, could you say whether cup and course select feel better, and attach a diagnostic log from Select Cup?
>
> The track-confirm pause is a separate cause (pipelines created the first time a course is chosen) and isn't changed in 0.8.13.
>
> Chris

## #104 and #301 (Snapdragon 512.762 missing characters)

> 0.8.13 makes the Turnip fix easier to find. On Adreno 6xx and 7xx phones with Qualcomm's 512.762 driver, KartPad shows **Recommended for This Phone** once, a few seconds after the game first starts, with **Get a Driver…**. **Download a Driver…** lists Mr. Purple's Turnip first, and the advice names the builds that worked here: Mr. Purple's Turnip T30 on Adreno 7xx (Galaxy S24 Ultra) and a K11MCH1 Turnip on Adreno 6xx (Moto G85). The menu is now called **⋯ → Speed & Graphics**.
>
> Chris

## #554 (Retro WFC frame drops with touch auto-accelerate)

> 0.8.13 adds four fields to the diagnostic log's health lines: time since the last touch, fingers on the controls, whether auto-accelerate is holding A, and each CPU core's clock. If you can, play one online race with auto-accelerate holding A and one holding A with your finger, then save a diagnostic log (**⋯ → Report a Problem… → Save Diagnostic Log…**) and attach it. It should show whether the phone lowers its clocks when no finger is on the screen.
>
> Chris

## #537 (online "disc error" kick)

No reply in 0.8.13. Checked for the same cause as #131: it isn't. #537 is a failed file read during an online lobby, with no awards section involved. It still needs the reporter's `ERROR: DVD read failed` line.
