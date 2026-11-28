# Reply drafts — 23 November 2026

Not posted. Chris decides whether and when. Each says which release it needs.

## #584 (kevinguerrero1826-cpu), when native menu-movie decoding ships (#595)

> kevinguerrero1826-cpu, thanks for running both tests and for the second log. It answered the question.
>
> The shader cache does stick: on your second launch all 299 saved shaders loaded from it. Two things remain, and the log shows both.
>
> 1. **The menu videos.** The thumbnails and the moving backgrounds in the menus are videos that the game decodes on a separate thread. On your phone that thread took up to about 23 ms per frame in the slowest stretch, more than a 60 FPS frame has. The next version decodes those videos with native code, which cut that thread's time by about 40% in my tests. It should make character and track select noticeably smoother, though probably not perfectly smooth on a Helio G99.
> 2. **Confirming the track.** That screen loads the course and prepares its graphics, which on your phone takes most of a second. Phones with less than 6 GB of memory prepare fewer graphics ahead of time, to keep memory free for the game. I'm keeping that as it is for now.
>
> When the version with the video change is out, a log from the same menus would show how much it helped on your phone.
>
> Chris

## #576 (AchieveFreedom), when #599 ships

> AchieveFreedom, thanks for the details. I understand the confusion: "Classic" and "WiiCompiled 0.9 (Beta)" are the two graphics engines, and **both already draw with Vulkan**. DriftDroid's OpenGL ES option is a slower backup for phones whose Vulkan doesn't work, so it wouldn't make your phone faster.
>
> What holds your Redmi Note 14 back is the processor. The game needs more time per frame than a 60 FPS frame has, so it plays in slow motion. Two settings in **⋯ → Graphics & Performance** are made for this: **30 FPS Races** keeps races at full speed by drawing half as many frames, and **Simpler Computer Karts** saves more processor time. The next version suggests both by itself after a slow race. It also decodes the menu videos faster, which helps the cup and track select screens.
>
> If races still feel slow with both on, please attach a diagnostic log (**⋯ → Report a Problem… → Save Diagnostic Log…**) from that session.
>
> Chris

## #104, #301, #472, #492, #552 (Snapdragon missing characters), when #594 ships

> The next version adds **Mr. Purple's Turnip** to **GPU Driver → Add Driver… → Download a Driver…**. Its T30 build drew every character on a Galaxy S24 Ultra with both graphics engines (thanks, Deivmsr). **Recommended for This Phone** now names it, and on the affected Qualcomm driver KartPad offers it once when the game starts. If you try it, please tell me whether the characters show up, with a diagnostic log if you can.
>
> Chris

(Chris planned to fold #301, #472, #492 and #552 into #104. Post this once in #104 and close the others with a link to it.)

## #575 (jstack01): fixed in 0.8.12

> jstack01, this is fixed in [0.8.12](https://github.com/chrissotraidis/kartpad/releases/tag/v0.8.12): the iPhone/iPad button mapping now stays open after each change, so you can set several buttons in a row. Thanks for the video, it made the problem clear. Closing this; reopen it if it still closes on you.
>
> Chris

## #539: close

> Thanks, haljen101-sketch, for finding that. For anyone else: if you use LiveContainer, long-press KartPad, open **Settings** and turn on **Fix File Picker**. Then the import folder can be chosen. It's in the [known issues](https://github.com/chrissotraidis/kartpad/blob/main/docs/KNOWN-ISSUES.md) too. Closing this.
>
> Chris

## #593 (Sharik7): Lossless frame generation

> Sharik7, thanks for the suggestion. I looked into it, and I'm not planning it for now. Lossless.dll belongs to Lossless Scaling, a paid Windows app, so KartPad couldn't include it, and each player would have to copy it from their own PC. KartPad would also have to run its frame-generation shaders itself on Android, which adds input lag and costs GPU time. The phones that would want it most have the least GPU time to spare. On fast phones with 120 Hz screens, **120 FPS Races** (with the Beta engine) already adds in-between frames.
>
> Chris

