// Methods of KartPadMacShellController. Runtime changes are queued to the
// existing frame boundary, not applied while AppKit is pumping native events.
- (NSView *)settingsPage:(NSString *)title {
  NSView *page=[[NSView alloc] initWithFrame:NSMakeRect(0,0,780,740)];
  NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,780,740)];
  scroll.hasVerticalScroller=YES; scroll.autohidesScrollers=YES;
  scroll.drawsBackground=NO; scroll.documentView=page;
  NSTabViewItem *item=[[NSTabViewItem alloc] initWithIdentifier:title];
  item.label=title;item.view=scroll;[self.settingsTabs addTabViewItem:item];
  return page;
}
- (NSTextField *)settingsLabel:(NSString *)text page:(NSView *)page y:(CGFloat)y {
  NSTextField *label=[self label:text];label.frame=NSMakeRect(24,y,725,44);
  label.maximumNumberOfLines=2;label.lineBreakMode=NSLineBreakByWordWrapping;
  [page addSubview:label];return label;
}
- (void)setting:(NSString *)key label:(NSString *)label choices:(NSArray *)titles
        values:(NSArray *)values page:(NSView *)page y:(CGFloat)y {
  [self settingsLabel:label page:page y:y-20];
  NSPopUpButton *control=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(290,y,380,28) pullsDown:NO];
  [control addItemsWithTitles:titles];control.identifier=key;control.accessibilityLabel=label;
  control.target=self;control.action=@selector(settingChanged:);
  self.settingControls[key]=control;self.settingChoices[key]=values;
  [page addSubview:control];
}
- (void)setting:(NSString *)key checkbox:(NSString *)title page:(NSView *)page y:(CGFloat)y {
  NSButton *control=[NSButton checkboxWithTitle:title target:self action:@selector(settingChanged:)];
  control.frame=NSMakeRect(24,y,715,28);control.identifier=key;
  self.settingControls[key]=control;[page addSubview:control];
}
- (void)setting:(NSString *)key volume:(NSString *)title page:(NSView *)page y:(CGFloat)y {
  [self settingsLabel:title page:page y:y-20];
  NSSlider *control=[NSSlider sliderWithValue:100 minValue:0 maxValue:100 target:self action:@selector(settingChanged:)];
  control.frame=NSMakeRect(240,y,390,26);control.identifier=key;control.accessibilityLabel=title;
  control.continuous=NO;self.settingControls[key]=control;[page addSubview:control];
  NSTextField *value=[self label:@"100%"];
  value.frame=NSMakeRect(648,y,90,24);[page addSubview:value];self.settingValues[key]=value;
}
- (void)settingsButton:(NSString *)title action:(SEL)action page:(NSView *)page y:(CGFloat)y {
  NSButton *button=[NSButton buttonWithTitle:title target:self action:action];
  button.frame=NSMakeRect(24,y,350,32);[page addSubview:button];
}
- (void)refreshSettings {
  const auto c=RuntimeConfigFile::LoadConfigFile();
  NSDictionary *values=@{
    @"video.fullscreen_across_notch":@(KPFullscreenAcrossNotch()),
    @"video.resolution_multiplier":@(c.resolutionMultiplier.value_or(1.0f)),
    @"video.display_mode":[NSString stringWithUTF8String:c.displayMode.value_or("windowed").c_str()],
    @"video.frame_interpolation_fps":@(c.frameInterpolationFps.value_or(0)),
    @"video.show_fps":@(c.showFps.value_or(true)),
    @"video.disable_copy_filter":@(c.disableCopyFilter.value_or(true)),
    @"video.skip_unready_pipelines":@(c.skipUnreadyPipelines.value_or(true)),
    @"video.disabled_post_processing_paths":@((c.disabledPostProcessingPaths.value_or(0)&0x10)!=0),
    @"audio.volume":@(c.audioVolume.value_or(1.0f)),
    @"audio.music_volume":@(c.audioMusicVolume.value_or(1.0f)),
    @"audio.sound_effects_volume":@(c.audioSoundEffectsVolume.value_or(1.0f)),
    @"audio.ui_volume":@(c.audioUiVolume.value_or(1.0f)),
    @"audio.voices_volume":@(c.audioVoicesVolume.value_or(1.0f)),
    @"audio.muted":@(c.audioMuted.value_or(false)),
    @"audio.mix_worker":@(c.audioMixWorker.value_or(true))};
  for(NSString *key in self.settingControls) {
    NSControl *control=self.settingControls[key];id value=values[key];
    if([control isKindOfClass:NSPopUpButton.class]) {
      NSUInteger index=[self.settingChoices[key] indexOfObject:value];
      if(index!=NSNotFound)[(NSPopUpButton *)control selectItemAtIndex:index];
    } else if([control isKindOfClass:NSSlider.class]) {
      control.doubleValue=[value doubleValue]*100;
      self.settingValues[key].stringValue=[NSString stringWithFormat:@"%.0f%%",control.doubleValue];
    } else [(NSButton *)control setState:[value boolValue]?NSControlStateValueOn:NSControlStateValueOff];
  }
}
- (void)settingChanged:(NSControl *)sender {
  NSString *key=sender.identifier;NSArray *parts=[key componentsSeparatedByString:@"."];
  std::string value;
  if([sender isKindOfClass:NSPopUpButton.class]) {
    id selected=self.settingChoices[key][((NSPopUpButton *)sender).indexOfSelectedItem];
    value=[selected isKindOfClass:NSString.class] ? RuntimeConfigFile::FormatString([selected UTF8String]) : [[selected stringValue] UTF8String];
  } else if([sender isKindOfClass:NSSlider.class]) {
    std::ostringstream stream;stream<<sender.doubleValue/100.0;value=stream.str();
  } else value=((NSButton *)sender).state==NSControlStateValueOn?"true":"false";
  if([key isEqual:@"video.disabled_post_processing_paths"]) {
    uint32_t mask=RuntimeConfigFile::LoadConfigFile().disabledPostProcessingPaths.value_or(0);
    mask=((NSButton *)sender).state==NSControlStateValueOn ? mask|0x10u : mask&~0x10u;
    value=std::to_string(mask);
  }
  if(!RuntimeConfigFile::WriteSetting([parts[0] UTF8String],[parts[1] UTF8String],value)) {
    self.settingsStatus.stringValue=@"Could not save this setting. Check that Config.toml is writable.";
    [self refreshSettings];return;
  }
  if([key isEqual:@"video.fullscreen_across_notch"]) {
    self.settingsStatus.stringValue=@"Saved. Quit and reopen KartPad to change full-display fullscreen behavior.";
    [self refreshSettings];return;
  }
  // Preserve the renderer's existing high-frame-rate resolution restriction.
  auto c=RuntimeConfigFile::LoadConfigFile();
  if(c.frameInterpolationFps.value_or(0)>60 && c.resolutionMultiplier.value_or(1)>4) {
    if(!RuntimeConfigFile::WriteSetting("video","resolution_multiplier","4")) {
      self.settingsStatus.stringValue=@"Could not save the required 4× resolution limit. Check Config.toml permissions.";
      [self refreshSettings];return;
    }
    self.settingsStatus.stringValue=@"Saved. Interpolation limits render resolution to 4×.";
  } else self.settingsStatus.stringValue=[key isEqual:@"video.disabled_post_processing_paths"] ?
    @"Saved. Bloom changes apply when the next scene loads." : @"Saved. Changes apply immediately.";
  KartPadRequestSettingsReload();
  [self refreshSettings];
}
- (void)showControllerCompatibility:(id)sender {
  (void)sender;
  [KPControllers() cancelCapture];
  [KPControllers() windowWillClose:nil];
  [self.settingsPanel orderOut:nil];
  KartPadRequestControllerCompatibility();
}
- (void)showSettings:(id)sender {
  (void)sender;
  if(!self.settingsPanel) {
    CGFloat height=std::min<CGFloat>(810,NSScreen.mainScreen.visibleFrame.size.height-70);
    self.settingsPanel=[[NSPanel alloc] initWithContentRect:NSMakeRect(0,0,820,height)
      styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable
      backing:NSBackingStoreBuffered defer:NO];
    self.settingsPanel.title=@"KartPad Settings";self.settingsPanel.releasedWhenClosed=NO;
    self.settingsPanel.minSize=NSMakeSize(820,570);
    self.settingsPanel.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    self.settingsPanel.hidesOnDeactivate=YES;
    self.settingsPanel.delegate=KPControllers();
    self.settingControls=[NSMutableDictionary dictionary];self.settingChoices=[NSMutableDictionary dictionary];
    self.settingValues=[NSMutableDictionary dictionary];
    self.settingsTabs=[[NSTabView alloc] initWithFrame:NSMakeRect(10,42,800,height-52)];
    self.settingsTabs.delegate=self;
    self.settingsTabs.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    [self.settingsPanel.contentView addSubview:self.settingsTabs];
    self.settingsStatus=[self label:@"Graphics and audio changes save automatically. Controllers has its own Save Profile button."];
    self.settingsStatus.frame=NSMakeRect(24,10,775,24);
    self.settingsStatus.autoresizingMask=NSViewWidthSizable;
    self.settingsStatus.font=[NSFont systemFontOfSize:11];
    [self.settingsPanel.contentView addSubview:self.settingsStatus];

    NSView *graphics=[self settingsPage:@"Graphics"];
    [self settingsLabel:@"Graphics & Display" page:graphics y:680].font=[NSFont boldSystemFontOfSize:19];
    [self setting:@"video.resolution_multiplier" label:@"Render resolution" choices:@[@"Auto (window size)",@"Native (1×)",@"1.5×",@"2×",@"3×",@"4×",@"6×",@"8×"] values:@[@0,@1,@1.5,@2,@3,@4,@6,@8] page:graphics y:620];
    [self setting:@"video.display_mode" label:@"Display mode" choices:@[@"Windowed",@"Borderless fullscreen",@"Exclusive fullscreen"] values:@[@"windowed",@"borderless",@"exclusive"] page:graphics y:565];
    [self setting:@"video.frame_interpolation_fps" label:@"Frame interpolation" choices:@[@"Off (60 FPS)",@"120 FPS — experimental",@"180 FPS — experimental"] values:@[@0,@120,@180] page:graphics y:510];
    [self settingsLabel:@"Interpolation may show visual artifacts. Resolution is limited to 4× when enabled." page:graphics y:450];
    [self setting:@"video.show_fps" checkbox:@"Show FPS counter" page:graphics y:400];
    [self setting:@"video.disable_copy_filter" checkbox:@"Disable the Wii copy filter (sharper picture)" page:graphics y:350];
    [self setting:@"video.disabled_post_processing_paths" checkbox:@"Disable bloom (applies at the next scene)" page:graphics y:300];
    [self setting:@"video.skip_unready_pipelines" checkbox:@"Skip draws while shaders compile" page:graphics y:250];
    [self setting:@"video.fullscreen_across_notch" checkbox:@"Use full display in borderless fullscreen (including notch area)" page:graphics y:190];
    [self settingsLabel:@"Requires restart. Uses desktop fullscreen instead of a separate Space. The notch can obscure the image; game aspect ratio is preserved." page:graphics y:130];
    [self settingsLabel:@"Settings shortcut: Command-comma or F10 (Fn–F10 on media-key keyboards)." page:graphics y:65];

    NSView *audio=[self settingsPage:@"Audio"];
    [self settingsLabel:@"Audio" page:audio y:680].font=[NSFont boldSystemFontOfSize:19];
    NSArray *keys=@[@"volume",@"music_volume",@"sound_effects_volume",@"ui_volume",@"voices_volume"];
    NSArray *labels=@[@"Master volume",@"Music",@"Sound effects",@"Menu sounds",@"Character voices"];
    for(int i=0;i<5;++i)[self setting:[@"audio." stringByAppendingString:keys[i]] volume:labels[i] page:audio y:620-i*60];
    [self setting:@"audio.muted" checkbox:@"Mute game audio" page:audio y:295];
    [self setting:@"audio.mix_worker" checkbox:@"Mix audio on a worker thread" page:audio y:245];
    [self settingsLabel:@"The worker normally improves performance. Turn it off when troubleshooting audio problems." page:audio y:180];

    NSView *controllers=[self settingsPage:@"Controllers"];
    [KPControllers() prepareInPanel:self.settingsPanel];
    KPControllers().content.frame=NSMakeRect(0,0,760,740);
    KPControllers().content.autoresizingMask=NSViewWidthSizable;
    [controllers addSubview:KPControllers().content];

    NSView *data=[self settingsPage:@"Game & Data"];
    [self settingsLabel:@"Game, Player & Data" page:data y:680].font=[NSFont boldSystemFontOfSize:19];
    [self settingsButton:@"Choose Mario Kart Wii Data…" action:@selector(chooseGameData:) page:data y:615];
#if defined(KARTPAD_RUNTIME_PRODUCT_DUAL)
    [self settingsButton:@"Choose Retro Rewind Data…" action:@selector(chooseRetroRewindData:) page:data y:570];
#endif
    [self settingsLabel:@"Game-data changes apply after restarting. Existing saves are preserved." page:data y:505];
    [self settingsButton:@"Player Identity…" action:@selector(showPlayerNameEditor) page:data y:440];
    [self settingsButton:@"License Manager…" action:@selector(showLicenseManager) page:data y:395];
    [self settingsButton:@"Mii Appearance…" action:@selector(showMiiAppearanceManager:) page:data y:350];
    [self settingsButton:@"Open Application Support" action:@selector(showApplicationSupport:) page:data y:270];
    [self settingsButton:@"Open Cache Folder" action:@selector(showCache:) page:data y:225];
    [self settingsButton:@"Control Reference…" action:@selector(showControls:) page:data y:155];

    NSView *advanced=[self settingsPage:@"Advanced"];
    [self settingsLabel:@"Advanced & Diagnostics" page:advanced y:680].font=[NSFont boldSystemFontOfSize:19];
    [self settingsButton:@"Save Diagnostics Report…" action:@selector(saveDiagnostics:) page:advanced y:615];
    [self settingsButton:@"Controller Compatibility Tools…" action:@selector(showControllerCompatibility:) page:advanced y:540];
    [self settingsLabel:@"Opens the in-game tools for unmapped joysticks, GameCube adapters and legacy presets. Standard controllers use the Controllers tab." page:advanced y:480];
    [self settingsButton:@"Pair Wii Remote…" action:@selector(pairWiimote:) page:advanced y:410];
    [self settingsLabel:@"Experimental original Wii Remote / Nunchuk support. Pairing enables the existing experimental driver." page:advanced y:345];
    [self settingsButton:@"Private Wii Server…" action:@selector(showPrivateServer:) page:advanced y:275];
    [self settingsLabel:@"Private server changes apply on the next launch." page:advanced y:215];
    [self.settingsPanel center];
  }
  [self refreshSettings];
  // Exclusive SDL windows sit above the menu-bar level. A normal NSPanel
  // would open behind the game even though the hotkey was received.
  NSInteger level=NSFloatingWindowLevel;
  NSWindow *gameWindow=nil;
  for(NSWindow *window in NSApp.windows) {
    if(window!=self.settingsPanel && ![window isKindOfClass:NSPanel.class] && window.visible) {
      gameWindow=window;level=std::max<NSInteger>(level,window.level+1);break;
    }
  }
  self.settingsPanel.level=level;
  if(gameWindow.screen) {
    NSRect available=gameWindow.screen.visibleFrame;
    NSRect frame=self.settingsPanel.frame;
    frame.origin=NSMakePoint(NSMidX(available)-frame.size.width/2,NSMidY(available)-frame.size.height/2);
    [self.settingsPanel setFrame:frame display:NO];
  }
  [NSApp activateIgnoringOtherApps:YES];[KPControllers() activateInput];
  [self.settingsPanel makeKeyAndOrderFront:nil];
  // Show the top of each scrollable settings page, including smaller displays.
  for(NSTabViewItem *item in self.settingsTabs.tabViewItems) {
    NSScrollView *scroll=(NSScrollView *)item.view;
    [scroll.contentView scrollToPoint:NSMakePoint(0,std::max<CGFloat>(0,740-scroll.contentView.bounds.size.height))];
    [scroll reflectScrolledClipView:scroll.contentView];
  }
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)item {
  (void)tabView;
  // A hidden capture must never change a binding while editing another tab.
  if(![item.identifier isEqual:@"Controllers"]) [KPControllers() cancelCapture];
  NSScrollView *scroll=(NSScrollView *)item.view;
  [scroll.contentView scrollToPoint:NSMakePoint(0,std::max<CGFloat>(0,740-scroll.contentView.bounds.size.height))];
  [scroll reflectScrolledClipView:scroll.contentView];
}
