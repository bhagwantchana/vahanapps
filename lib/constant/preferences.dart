import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static Future<bool> setValue(String keys, String values) async {
    final SharedPreferences storage = await SharedPreferences.getInstance();
    storage.setString(keys, values);
    log("data saved");
    return true;
  }

  static Future<dynamic> readValue(String keys) async {
    final SharedPreferences storage = await SharedPreferences.getInstance();
    log("data read ${storage.toString()}");
    return storage.getString(keys);
  }

  static Future<bool> clearValue(String key) async {
    final SharedPreferences storage = await SharedPreferences.getInstance();
    storage.remove(key);
    log("data clear");
    return true;
  }

  static Future<bool> clearAll() async {
    final SharedPreferences storage = await SharedPreferences.getInstance();
    storage.clear();
    log("data all clear");
    return true;
  }
}
