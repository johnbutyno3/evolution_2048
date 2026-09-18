import 'package:cloud_functions/cloud_functions.dart';

import '../game/services/gold_manager.dart';
import '../game/services/life_manager.dart';

/// Development-only controls backed by admin-protected Firebase callables.
class DeveloperService {
  DeveloperService._();

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static Future<void> setLives(int lives) async {
    await _functions
        .httpsCallable('developerSetLives')
        .call(<String, dynamic>{'lives': lives});
    await LifeManager.refreshFromServer();
  }

  static Future<void> restoreLives() async {
    await LifeManager.restoreFiveLivesForDeveloper();
  }

  static Future<int> grantGold([int amount = 10000]) async {
    final result = await _functions
        .httpsCallable('developerGrantGold')
        .call(<String, dynamic>{'amount': amount});
    await GoldManager.refresh();
    final data = result.data;
    return data is Map && data['balance'] is num
        ? (data['balance'] as num).toInt()
        : GoldManager.balance;
  }

  static Future<void> grantTools([int amount = 20]) async {
    await _functions
        .httpsCallable('developerGrantTools')
        .call(<String, dynamic>{'amount': amount});
  }

  static Future<void> setMembership(String type) async {
    await _functions
        .httpsCallable('developerSetMembership')
        .call(<String, dynamic>{'type': type});
    await LifeManager.refreshFromServer();
  }

  static Future<int> setUnlockedChapters(int index) async {
    final result = await _functions
        .httpsCallable('developerSetProgress')
        .call(<String, dynamic>{'unlockedChapterIndex': index});
    final data = result.data;
    return data is Map && data['unlockedChapterIndex'] is num
        ? (data['unlockedChapterIndex'] as num).toInt()
        : index;
  }

  static Future<void> resetProgress() async {
    await _functions.httpsCallable('developerResetProgress').call();
  }
}
