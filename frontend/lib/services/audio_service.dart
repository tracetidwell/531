import 'package:audioplayers/audioplayers.dart';

/// Service for playing audio cues during workouts.
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  AudioPlayer? _player;

  /// Play the timer completion beep.
  /// Uses an audio context that mixes with other audio (e.g. Spotify)
  /// instead of pausing it.
  Future<void> playTimerBeep() async {
    try {
      // Create a new player each time for reliability on mobile
      _player?.dispose();
      _player = AudioPlayer();
      await _player!.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.notificationEvent,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
        ),
      ));
      await _player!.setVolume(1.0);
      await _player!.play(AssetSource('audio/timer_beep.wav'));
    } catch (e) {
      // Log error for debugging but don't crash
      print('Audio playback error: $e');
    }
  }

  /// Dispose resources when no longer needed.
  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
