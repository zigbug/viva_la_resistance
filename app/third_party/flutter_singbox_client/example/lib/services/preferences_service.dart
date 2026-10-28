import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _keyNetworkMode = 'networkMode';
  static const _keyAllowBypass = 'allowBypass';
  static const _keySystemProxy = 'systemProxyEnabled';
  static const _keyNotifTitle = 'notificationTitle';
  static const _keyNotifChannel = 'notificationChannelName';
  static const _keyShowTraffic = 'showTrafficInNotification';
  static const _keyShowStop = 'showStopButtonInNotification';
  static const _keySelectedProfile = 'selectedProfileId';
  static const _keyPerAppProxyEnabled = 'perAppProxyEnabled';
  static const _keyPerAppProxyMode = 'perAppProxyMode';
  static const _keyPerAppProxyPackages = 'perAppProxyPackages';
  static const _keyEnableMemoryLimit = 'enableMemoryLimit';
  static const _keyMemoryLimitMb = 'memoryLimitMb';
  static const _keyKillConnectionsOnLimit = 'killConnectionsOnLimit';
  static const _keyKillSwitch = 'killSwitch';

  final SharedPreferences _prefs;

  PreferencesService._(this._prefs);

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService._(prefs);
  }

  String get networkMode => _prefs.getString(_keyNetworkMode) ?? 'vpn';
  set networkMode(String v) => _prefs.setString(_keyNetworkMode, v);

  bool get allowBypass => _prefs.getBool(_keyAllowBypass) ?? false;
  set allowBypass(bool v) => _prefs.setBool(_keyAllowBypass, v);

  bool get systemProxyEnabled => _prefs.getBool(_keySystemProxy) ?? false;
  set systemProxyEnabled(bool v) => _prefs.setBool(_keySystemProxy, v);

  String get notificationTitle => _prefs.getString(_keyNotifTitle) ?? 'Singbox';
  set notificationTitle(String v) => _prefs.setString(_keyNotifTitle, v);

  String get notificationChannelName => _prefs.getString(_keyNotifChannel) ?? 'Singbox Service';
  set notificationChannelName(String v) => _prefs.setString(_keyNotifChannel, v);

  bool get showTrafficInNotification => _prefs.getBool(_keyShowTraffic) ?? true;
  set showTrafficInNotification(bool v) => _prefs.setBool(_keyShowTraffic, v);

  bool get showStopButtonInNotification => _prefs.getBool(_keyShowStop) ?? true;
  set showStopButtonInNotification(bool v) => _prefs.setBool(_keyShowStop, v);

  bool get perAppProxyEnabled => _prefs.getBool(_keyPerAppProxyEnabled) ?? false;
  set perAppProxyEnabled(bool v) => _prefs.setBool(_keyPerAppProxyEnabled, v);

  String get perAppProxyMode => _prefs.getString(_keyPerAppProxyMode) ?? 'exclude';
  set perAppProxyMode(String v) => _prefs.setString(_keyPerAppProxyMode, v);

  List<String> get perAppProxyPackages =>
      _prefs.getStringList(_keyPerAppProxyPackages) ?? [];
  set perAppProxyPackages(List<String> v) =>
      _prefs.setStringList(_keyPerAppProxyPackages, v);

  bool get enableMemoryLimit => _prefs.getBool(_keyEnableMemoryLimit) ?? false;
  set enableMemoryLimit(bool v) => _prefs.setBool(_keyEnableMemoryLimit, v);

  int get memoryLimitMb => _prefs.getInt(_keyMemoryLimitMb) ?? 50;
  set memoryLimitMb(int v) => _prefs.setInt(_keyMemoryLimitMb, v);

  bool get killConnectionsOnLimit => _prefs.getBool(_keyKillConnectionsOnLimit) ?? false;
  set killConnectionsOnLimit(bool v) => _prefs.setBool(_keyKillConnectionsOnLimit, v);

  bool get killSwitch => _prefs.getBool(_keyKillSwitch) ?? false;
  set killSwitch(bool v) => _prefs.setBool(_keyKillSwitch, v);

  int? get selectedProfileId {
    final v = _prefs.getInt(_keySelectedProfile);
    return v == -1 ? null : v;
  }
  set selectedProfileId(int? v) => _prefs.setInt(_keySelectedProfile, v ?? -1);
}
