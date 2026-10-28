enum AppProfileType { local, remote }

class AppProfile {
  final int id;
  final String name;
  final AppProfileType type;
  final String? content;
  final String? remoteURL;
  final bool autoUpdate;
  final int autoUpdateIntervalSeconds;
  final DateTime? lastUpdated;

  const AppProfile({
    required this.id,
    required this.name,
    required this.type,
    this.content,
    this.remoteURL,
    this.autoUpdate = false,
    this.autoUpdateIntervalSeconds = 3600,
    this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'content': content,
        'remoteURL': remoteURL,
        'autoUpdate': autoUpdate,
        'autoUpdateIntervalSeconds': autoUpdateIntervalSeconds,
        'lastUpdated': lastUpdated?.millisecondsSinceEpoch,
      };

  factory AppProfile.fromJson(Map<String, dynamic> json) {
    return AppProfile(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] == 'remote' ? AppProfileType.remote : AppProfileType.local,
      content: json['content'] as String?,
      remoteURL: json['remoteURL'] as String?,
      autoUpdate: json['autoUpdate'] as bool? ?? false,
      autoUpdateIntervalSeconds: _parseInt(json['autoUpdateIntervalSeconds']) ??
          (_parseInt(json['autoUpdateIntervalMinutes']) ?? 60) * 60,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastUpdated'] as int)
          : null,
    );
  }

  AppProfile copyWith({
    String? name,
    String? content,
    String? remoteURL,
    bool? autoUpdate,
    int? autoUpdateIntervalSeconds,
    DateTime? lastUpdated,
  }) =>
      AppProfile(
        id: id,
        name: name ?? this.name,
        type: type,
        content: content ?? this.content,
        remoteURL: remoteURL ?? this.remoteURL,
        autoUpdate: autoUpdate ?? this.autoUpdate,
        autoUpdateIntervalSeconds:
            autoUpdateIntervalSeconds ?? this.autoUpdateIntervalSeconds,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
}

int? _parseInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}
