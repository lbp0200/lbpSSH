// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ssh_connection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SshConnection _$SshConnectionFromJson(Map<String, dynamic> json) =>
    SshConnection(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: (json['port'] as num?)?.toInt() ?? 22,
      username: json['username'] as String,
      authType: $enumDecode(_$AuthTypeEnumMap, json['authType']),
      password: json['password'] as String?,
      privateKeyPath: json['privateKeyPath'] as String?,
      keyPassphrase: json['keyPassphrase'] as String?,
      jumpHost: json['jumpHost'] == null
          ? null
          : JumpHostConfig.fromJson(json['jumpHost'] as Map<String, dynamic>),
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      version: (json['version'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$SshConnectionToJson(SshConnection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'host': instance.host,
      'port': instance.port,
      'username': instance.username,
      'authType': _$AuthTypeEnumMap[instance.authType]!,
      'password': instance.password,
      'privateKeyPath': instance.privateKeyPath,
      'keyPassphrase': instance.keyPassphrase,
      'jumpHost': instance.jumpHost?.toJson(),
      'notes': instance.notes,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'version': instance.version,
    };

const _$AuthTypeEnumMap = {
  AuthType.password: 'password',
  AuthType.key: 'key',
  AuthType.keyWithPassword: 'keyWithPassword',
};

JumpHostConfig _$JumpHostConfigFromJson(Map<String, dynamic> json) =>
    JumpHostConfig(
      host: json['host'] as String,
      port: (json['port'] as num?)?.toInt() ?? 22,
      username: json['username'] as String,
      authType: $enumDecode(_$AuthTypeEnumMap, json['authType']),
      password: json['password'] as String?,
      privateKeyPath: json['privateKeyPath'] as String?,
    );

Map<String, dynamic> _$JumpHostConfigToJson(JumpHostConfig instance) =>
    <String, dynamic>{
      'host': instance.host,
      'port': instance.port,
      'username': instance.username,
      'authType': _$AuthTypeEnumMap[instance.authType]!,
      'password': instance.password,
      'privateKeyPath': instance.privateKeyPath,
    };
