import 'package:json_annotation/json_annotation.dart';

part 'ssh_connection.g.dart';

/// SSH 连接配置模型
@JsonSerializable()
class SshConnection {
  /// 连接唯一标识
  final String id;

  /// 连接名称
  final String name;

  /// 主机地址
  final String host;

  /// 端口号
  final int port;

  /// 用户名
  final String username;

  /// 认证方式
  final AuthType authType;

  /// 密码（加密存储）
  final String? encryptedPassword;

  /// SSH 密钥路径
  final String? privateKeyPath;

  /// 密钥密码（加密存储）
  final String? encryptedKeyPassphrase;

  /// 跳板机配置
  final JumpHostConfig? jumpHost;

  /// 备注
  final String? notes;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 版本号（用于同步冲突检测）
  final int version;

  SshConnection({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    required this.authType,
    this.encryptedPassword,
    this.privateKeyPath,
    this.encryptedKeyPassphrase,
    this.jumpHost,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.version = 1,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 从 JSON 创建
  factory SshConnection.fromJson(Map<String, dynamic> json) =>
      _$SshConnectionFromJson(json);

  /// 转换为 JSON
  Map<String, dynamic> toJson() => _$SshConnectionToJson(this);

  /// 创建副本
  SshConnection copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    AuthType? authType,
    String? encryptedPassword,
    String? privateKeyPath,
    String? encryptedKeyPassphrase,
    JumpHostConfig? jumpHost,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return SshConnection(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authType: authType ?? this.authType,
      encryptedPassword: encryptedPassword ?? this.encryptedPassword,
      privateKeyPath: privateKeyPath ?? this.privateKeyPath,
      encryptedKeyPassphrase:
          encryptedKeyPassphrase ?? this.encryptedKeyPassphrase,
      jumpHost: jumpHost ?? this.jumpHost,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }
}

/// 认证方式枚举
enum AuthType {
  @JsonValue('password')
  password,

  @JsonValue('key')
  key,

  @JsonValue('keyWithPassword')
  keyWithPassword,
}

/// 跳板机配置
@JsonSerializable()
class JumpHostConfig {
  /// 跳板机主机
  final String host;

  /// 跳板机端口
  final int port;

  /// 跳板机用户名
  final String username;

  /// 跳板机认证方式
  final AuthType authType;

  /// 跳板机密码（加密存储）
  final String? encryptedPassword;

  /// 跳板机密钥路径
  final String? privateKeyPath;

  JumpHostConfig({
    required this.host,
    this.port = 22,
    required this.username,
    required this.authType,
    this.encryptedPassword,
    this.privateKeyPath,
  });

  factory JumpHostConfig.fromJson(Map<String, dynamic> json) =>
      _$JumpHostConfigFromJson(json);

  Map<String, dynamic> toJson() => _$JumpHostConfigToJson(this);
}
