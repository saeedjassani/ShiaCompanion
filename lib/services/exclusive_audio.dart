/// Hands the app's single background-audio player from one owner to another.
///
/// just_audio_background drives exactly one player at a time - a second one
/// loading while the first is alive throws "supports only a single player
/// instance". The zikr page's recitation player and the playlist player can
/// both be alive (a playlist keeps playing while the reader opens a zikr), so
/// whichever is about to load claims the audio first, and the previous owner
/// disposes its player before the claim returns.
class ExclusiveAudio {
  ExclusiveAudio._();

  static Object? _owner;
  static Future<void> Function()? _release;

  /// Makes [owner] the one allowed to play, awaiting the previous owner's
  /// [release] so its player is gone before [owner] loads its own.
  static Future<void> claim(
    Object owner,
    Future<void> Function() release,
  ) async {
    if (identical(_owner, owner)) {
      _release = release;
      return;
    }
    final previous = _release;
    _owner = owner;
    _release = release;
    if (previous != null) await previous();
  }

  /// Gives up the claim, if [owner] still holds it, once its player is gone.
  static void relinquish(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _release = null;
  }

  static bool isOwnedBy(Object owner) => identical(_owner, owner);
}
