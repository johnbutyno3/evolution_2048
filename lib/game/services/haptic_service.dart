import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HapticService {
  HapticService._();

  static const MethodChannel _androidChannel =
      MethodChannel('rebirth_2048/haptics');

  static Future<void> evolutionImpact() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _androidChannel.invokeMethod<void>('evolutionImpact');
        return;
      } on MissingPluginException {
        // Fall through to Flutter's cross-platform haptic feedback.
      } on PlatformException {
        // Fall through to Flutter's cross-platform haptic feedback.
      }
    }

    await HapticFeedback.mediumImpact();
  }
}
