import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;
  bool _isInit = false;

  // Keys
  static const String _keyOutputFolder = 'output_folder';
  static const String _keyDefaultSize = 'default_size';
  static const String _keyDefaultOrientation = 'default_orientation';
  static const String _keyWhiteBorderOn = 'white_border_on';
  static const String _keyBorderSizeMm = 'border_size_mm';
  static const String _keyImageScale = 'image_scale';
  static const String _keySelectedFolders = 'selected_folders';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isInit = true;
    
    // Set default output folder if not present
    if (getOutputFolder().isEmpty) {
      String defaultPath = '';
      try {
        if (Platform.isLinux) {
          final home = Platform.environment['HOME'];
          if (home != null) {
            defaultPath = '$home/Pictures/Collages';
          }
        } else {
          final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
          defaultPath = '${directory.path}/Collages';
        }
      } catch (e) {
        defaultPath = '/tmp/Collages';
      }
      
      // Ensure folder exists
      try {
        final dir = Directory(defaultPath);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        await setOutputFolder(defaultPath);
      } catch (_) {}
    }
  }

  // Getters & Setters
  String getOutputFolder() => _isInit ? (_prefs.getString(_keyOutputFolder) ?? '') : '';
  Future<void> setOutputFolder(String value) async {
    if (_isInit) await _prefs.setString(_keyOutputFolder, value);
  }

  String getDefaultSize() => _isInit ? (_prefs.getString(_keyDefaultSize) ?? 'A4 Paper') : 'A4 Paper';
  Future<void> setDefaultSize(String value) async {
    if (_isInit) await _prefs.setString(_keyDefaultSize, value);
  }

  String getDefaultOrientation() => _isInit ? (_prefs.getString(_keyDefaultOrientation) ?? 'Landscape') : 'Landscape';
  Future<void> setDefaultOrientation(String value) async {
    if (_isInit) await _prefs.setString(_keyDefaultOrientation, value);
  }

  bool getWhiteBorderOn(String template) => _isInit ? (_prefs.getBool('${_keyWhiteBorderOn}_$template') ?? true) : true;
  Future<void> setWhiteBorderOn(String template, bool value) async {
    if (_isInit) await _prefs.setBool('${_keyWhiteBorderOn}_$template', value);
  }

  double getBorderSizeMm(String template) => _isInit ? (_prefs.getDouble('${_keyBorderSizeMm}_$template') ?? 2.0) : 2.0;
  Future<void> setBorderSizeMm(String template, double value) async {
    if (_isInit) await _prefs.setDouble('${_keyBorderSizeMm}_$template', value);
  }

  double getImageScale(String template) => _isInit ? (_prefs.getDouble('${_keyImageScale}_$template') ?? 1.0) : 1.0;
  Future<void> setImageScale(String template, double value) async {
    if (_isInit) await _prefs.setDouble('${_keyImageScale}_$template', value);
  }

  int getCanvasBgColor(String template) => _isInit ? (_prefs.getInt('canvas_bg_color_$template') ?? 0xFFFFFFFF) : 0xFFFFFFFF;
  Future<void> setCanvasBgColor(String template, int value) async {
    if (_isInit) await _prefs.setInt('canvas_bg_color_$template', value);
  }

  List<String> getSelectedFolders() => _isInit ? (_prefs.getStringList(_keySelectedFolders) ?? []) : [];
  Future<void> setSelectedFolders(List<String> values) async {
    if (_isInit) await _prefs.setStringList(_keySelectedFolders, values);
  }
}
