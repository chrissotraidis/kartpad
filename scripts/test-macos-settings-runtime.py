#!/usr/bin/env python3
"""Run the actual prepared runtime's native settings bridge with fake backends."""
from pathlib import Path
import tempfile,subprocess,sys
root=Path(sys.argv[1] if len(sys.argv)>1 else 'build/self-build-macos-source')
s=(root/'src/settings_overlay.cpp').read_text()
start=s.index('void ReloadNativeSettings()');end=s.index('{',start)+1;depth=1
while depth:
    depth+=(s[end]=='{')-(s[end]=='}');end+=1
function=s[start:end]
source=r'''
#include <algorithm>
#include <atomic>
#include <array>
#include <cassert>
#include <cmath>
#include <cstdint>
#include <optional>
#include <string>
struct Config {
 std::optional<float> resolutionMultiplier,audioVolume,audioMusicVolume,audioSoundEffectsVolume,audioUiVolume,audioVoicesVolume;
 std::optional<uint32_t> frameInterpolationFps,disabledPostProcessingPaths;
 std::optional<std::string> displayMode;
 std::optional<bool> showFps,disableCopyFilter,skipUnreadyPipelines,audioMuted,audioMixWorker;
};
Config disk, memory;
namespace RuntimeConfigFile {
 Config LoadConfigFile(){return disk;}
 Config& Mutable(){return memory;}
 void SetDisplayMode(std::string v){disk.displayMode=v;}
}
std::atomic_bool g_nativeSettingsReload{false};
float g_resolutionScale=1, scale=1;
int g_frameInterpolationMode=0,g_displayMode=0;
bool g_showFps=true,g_disableCopyFilter=true,g_skipUnreadyPipelines=true,g_audioMixWorker=true,g_audioMuted=false;
uint32_t g_disabledPostProcessingPaths=0,bloom=0,frames=0;
int g_audioVolumePercent=100,g_musicVolumePercent=100,g_soundEffectsVolumePercent=100,g_uiVolumePercent=100,g_voicesVolumePercent=100;
constexpr std::array<uint32_t,3> kFrameInterpolationTargetFps{0,120,180};
constexpr std::array<const char*,3> kDisplayModeConfigNames{"windowed","borderless","exclusive"};
enum AuroraDisplayMode{AURORA_DISPLAY_MODE_WINDOWED,AURORA_DISPLAY_MODE_BORDERLESS,AURORA_DISPLAY_MODE_EXCLUSIVE};
int displayCalls=0,workerCalls=0;bool failDisplay=false;AuroraDisplayMode display=AURORA_DISPLAY_MODE_WINDOWED;
void VISetFrameBufferScale(float v){scale=v;}
void LimitResolutionForFrameRate(){if(g_frameInterpolationMode && g_resolutionScale>4)scale=g_resolutionScale=4;}
void aurora_set_frame_interpolation_fps(uint32_t v){frames=v;}
void aurora_set_display_mode(AuroraDisplayMode v){++displayCalls;if(!failDisplay)display=v;}
AuroraDisplayMode aurora_get_display_mode(){return display;}
void aurora_set_disable_copy_filter(bool){}
void aurora_set_skip_unready_pipelines(bool){}
namespace RuntimeGameGraphicsOptions {void SetDisabledPostProcessingPaths(uint32_t v){bloom=v;}}
struct AudioBackend {float volume=1;bool muted=false;static AudioBackend& Instance(){static AudioBackend a;return a;}
 void SetMasterVolume(float v){volume=v;}void SetMuted(bool v){muted=v;}};
namespace MusicAttenuation {
 float music=1,sfx=1,ui=1,voices=1;
 void SetMusicVolume(float v){music=v;}void SetSoundEffectsVolume(float v){sfx=v;}
 void SetUiVolume(float v){ui=v;}void SetVoicesVolume(float v){voices=v;}
}
namespace AxDspHle {void SetMixWorkerEnabled(bool){++workerCalls;}}
'''
source+=function+r'''
int main(){
 disk.resolutionMultiplier=3;disk.frameInterpolationFps=120;disk.displayMode="borderless";
 disk.audioVolume=0.4f;disk.audioMusicVolume=0.3f;disk.audioSoundEffectsVolume=0.2f;
 disk.audioUiVolume=0.1f;disk.audioVoicesVolume=0.8f;disk.audioMuted=true;disk.audioMixWorker=false;
 disk.showFps=false;disk.disabledPostProcessingPaths=0x10;
 ReloadNativeSettings();assert(scale==1); // no request, no mutation
 g_nativeSettingsReload=true;ReloadNativeSettings();
 assert(scale==3 && frames==120 && display==AURORA_DISPLAY_MODE_BORDERLESS);
 assert(!g_showFps && bloom==0x10 && AudioBackend::Instance().muted);
 assert(AudioBackend::Instance().volume==0.4f && MusicAttenuation::music==0.3f);
 assert(MusicAttenuation::sfx==0.2f && MusicAttenuation::ui==0.1f && MusicAttenuation::voices==0.8f);
 assert(workerCalls==1 && memory.audioVolume==disk.audioVolume);
 g_nativeSettingsReload=true;ReloadNativeSettings();assert(displayCalls==1 && workerCalls==1);
 disk.displayMode="exclusive";failDisplay=true;g_nativeSettingsReload=true;ReloadNativeSettings();
 assert(disk.displayMode=="borderless"); // failed platform transition is not persisted as successful
 disk.resolutionMultiplier=8;g_nativeSettingsReload=true;ReloadNativeSettings();assert(scale==4);
}
'''
assert 'SDL_SCANCODE_F10' not in s and 'DrawTopBar' not in s
controllers = (Path(__file__).resolve().parents[1] / 'apple/macos/KartPadControllers.inc.mm').read_text()
for marker in ('PADGetKeyButtonBindings', 'PADSetKeyButtonBinding',
               'PADGetKeyAxisBindings', 'PADSetKeyAxisBinding',
               'Keyboard', 'NSEventMaskKeyDown',
               'scancodeForPhysicalKeyCode', 'KPMacPhysicalScancode',
               'self.keyboardCaptureKind=-1; self.keyboardCaptureIndex=-1'):
    assert marker in controllers, marker
assert 'ControllerProfiles.json' not in controllers.split('- (void)refreshKeyboardLabels', 1)[1].split('- (void)captureKeyboard', 1)[0]
assert 'DrawAudioSettings' not in s and 'DrawGraphicsSettings' not in s
assert 'DrawFpsOverlay();' in s and 'DrawShaderCompilationStatus();' in s
with tempfile.TemporaryDirectory() as d:
    path=Path(d)/'test.cpp';path.write_text(source);exe=Path(d)/'test'
    subprocess.run(['clang++','-std=c++20','-Wall','-Wextra','-Werror',str(path),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
print('PASS: live graphics/audio bridge, coalescing, failed fullscreen fallback, resolution limit; redundant F10 UI removed')
