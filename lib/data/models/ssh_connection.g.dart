// GENERATED CODE - DO NOT MODIFY BY HAND
// 这是一个占位符文件，实际应该通过运行 build_runner 生成
// 运行: dart run build_runner build

part of 'ssh_connection.dart';

SshConnection _$SshConnectionFromJson(Map<String, dynamic> json) =>
    SshConnection(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int? ?? 22,
      username: json['username'] as String,
      authType: _$enumDecode(_$AuthTypeEnumMap, json['authType']),
      encryptedPassword: json['encryptedPassword'] as String?,
      privateKeyPath: json['privateKeyPath'] as String?,
      encryptedKeyPassphrase: json['encryptedKeyPassphrase'] as String?,
      jumpHost: json['jumpHost'] == null
          ? null
          : JumpHostConfig.fromJson(json['jumpHost'] as Map<String, dynamic>),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      version: json['version'] as int? ?? 1,
    );

Map<String, dynamic> _$SshConnectionToJson(SshConnection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'host': instance.host,
      'port': instance.port,
      'username': instance.username,
      'authType': _$AuthTypeEnumMap[instance.authType]!,
      'encryptedPassword': instance.encryptedPassword,
      'privateKeyPath': instance.privateKeyPath,
      'encryptedKeyPassphrase': instance.encryptedKeyPassphrase,
      'jumpHost': instance.jumpHost?.toJson(),
      'notes': instance.notes,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'version': instance.version,
    };

K _$enumDecode<K, V>(
  Map<K, V> enumValues,
  Object? source, {
  K? unknownValue,
}) {
  if (source == null) {
    throw ArgumentError(
      'A value must be provided. Supported values: '
      '${enumValues.values.join(', ')}',
    );
  }

  return enumValues.entries.singleWhere(
    (e) => e.value == source,
    orElse: () {
      if (unknownValue == null) {
        throw ArgumentError(
          '`$source` is not one of the supported values: '
          '${enumValues.values.join(', ')}',
        );
      }
      return MapEntry(unknownValue as K, enumValues[unknownValue] as V);
    },
  ).key;
}

const _$AuthTypeEnumMap = {
  AuthType.password: 'password',
  AuthType.key: 'key',
  AuthType.keyWithPassword: 'keyWithPassword',
};

JumpHostConfig _$JumpHostConfigFromJson(Map<String, dynamic> json) =>
    JumpHostConfig(
      host: json['host'] as String,
      port: json['port'] as int? ?? 22,
      username: json['username'] as String,
      authType: _$enumDecode(_$AuthTypeEnumMap, json['authType']),
      encryptedPassword: json['encryptedPassword'] as String?,
      privateKeyPath: json['privateKeyPath'] as String?,
    );

Map<String, dynamic> _$JumpHostConfigToJson(JumpHostConfig instance) =>
    <String, dynamic>{
      'host': instance.host,
      'port': instance.port,
      'username': instance.username,
      'authType': _$AuthTypeEnumMap[instance.authType]!,
      'encryptedPassword': instance.encryptedPassword,
      'privateKeyPath': instance.privateKeyPath,
    };
