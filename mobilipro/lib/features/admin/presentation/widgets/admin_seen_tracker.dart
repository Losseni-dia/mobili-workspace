import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSeenTracker {
  static Future<int> getOrInitSeenCount(String key, int currentTotalIfUnset) async {
    final prefs = await SharedPreferences.getInstance();
    final storeKey = 'admin_seen_$key';
    if (prefs.containsKey(storeKey)) {
      return prefs.getInt(storeKey) ?? currentTotalIfUnset;
    }
    await prefs.setInt(storeKey, currentTotalIfUnset);
    return currentTotalIfUnset;
  }

  static Future<void> markSeen(String key, int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('admin_seen_$key', count);
  }
}

final adminSeenCountProvider = FutureProvider.autoDispose
    .family<int, ({String key, int currentTotal})>(
      (ref, args) => AdminSeenTracker.getOrInitSeenCount(args.key, args.currentTotal),
    );