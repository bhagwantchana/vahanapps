import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static Future<bool> setValue(String key, String value) async {
    final SharedPreferences storage = await SharedPreferences.getInstance();
    final result = await storage.setString(key, value);
    log('Stored value for $key');
    return result;
  }

  static Future<String?> readValue(String key) async {
    final SharedPreferences storage = await SharedPreferences.getInstance();
    return storage.getString(key);
  }

  static Future<bool> clearValue(String key) async {
    final SharedPreferences storage = await SharedPreferences.getInstance();
    final result = await storage.remove(key);
    log('Removed value for $key');
    return result;
  }

  static Future<bool> clearSession() async {
    await clearValue('isLogin');
    await clearValue('token');
    // Also clear role/identity so a stale isSubUser/username can't bleed into
    // the next login (e.g. the logout → failed-login window).
    await clearValue('isSubUser');
    await clearValue('username');
    return true;
  }

  static Future<bool> clearAll() async {
    final SharedPreferences storage = await SharedPreferences.getInstance();
    final result = await storage.clear();
    log('Cleared local storage');
    return result;
  }
}
