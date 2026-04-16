import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const _storageKey = 'quiz_master_app_state_v3';

  Future<Map<String, dynamic>?> loadState() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_storageKey);

      if (raw == null || raw.isEmpty) {
        return null;
      }

      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (error, stackTrace) {
      debugPrint('Failed to load local state: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> saveState(Map<String, dynamic> data) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_storageKey, jsonEncode(data));
    } catch (error, stackTrace) {
      debugPrint('Failed to save local state: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
