// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ssh_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SshConfig _$SshConfigFromJson(Map<String, dynamic> json) => SshConfig(
  keepaliveInterval: (json['keepaliveInterval'] as num?)?.toInt() ?? 30000,
);

Map<String, dynamic> _$SshConfigToJson(SshConfig instance) => <String, dynamic>{
  'keepaliveInterval': instance.keepaliveInterval,
};
