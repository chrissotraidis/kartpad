#import <AVFAudio/AVFAudio.h>

#include "kartpad/audio/tvos_audio_route.h"

std::uint32_t KartPadTVPrepareAudioRoute(std::uint32_t requested_channels) {
  AVAudioSession *session = AVAudioSession.sharedInstance;
  NSError *error = nil;
  if (![session setCategory:AVAudioSessionCategoryPlayback
                        mode:AVAudioSessionModeDefault
                     options:0
                       error:&error] ||
      ![session setSupportsMultichannelContent:requested_channels >= 6
                                        error:&error] ||
      ![session setActive:YES error:&error]) {
    return 0;
  }

  if (requested_channels <=
          static_cast<std::uint32_t>(session.maximumOutputNumberOfChannels) &&
      ![session setPreferredOutputNumberOfChannels:requested_channels
                                             error:&error]) {
    return 0;
  }
  return static_cast<std::uint32_t>(session.outputNumberOfChannels);
}

std::uint32_t KartPadTVActualAudioOutputChannels() {
  return static_cast<std::uint32_t>(
      AVAudioSession.sharedInstance.outputNumberOfChannels);
}
