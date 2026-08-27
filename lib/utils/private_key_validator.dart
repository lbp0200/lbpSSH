/// 私钥格式校验工具
/// 从 connection_form.dart 抽离，降低长文件复杂度并便于单元测试复用
library;

/// 校验字符串是否为合法的 SSH 私钥格式
///
/// 支持：PEM / OpenSSH / RSA / DSA / EC 五种格式
bool isValidPrivateKey(String content) {
  final trimmed = content.trim();

  if (trimmed.startsWith('-----BEGIN') &&
      trimmed.contains('PRIVATE KEY-----') &&
      trimmed.endsWith('-----END PRIVATE KEY-----')) {
    return true;
  }

  if (trimmed.startsWith('-----BEGIN') &&
      trimmed.contains('OPENSSH PRIVATE KEY-----') &&
      trimmed.endsWith('-----END OPENSSH PRIVATE KEY-----')) {
    return true;
  }

  if (trimmed.startsWith('-----BEGIN') &&
      trimmed.contains('RSA PRIVATE KEY-----') &&
      trimmed.endsWith('-----END RSA PRIVATE KEY-----')) {
    return true;
  }

  if (trimmed.startsWith('-----BEGIN') &&
      trimmed.contains('DSA PRIVATE KEY-----') &&
      trimmed.endsWith('-----END DSA PRIVATE KEY-----')) {
    return true;
  }

  if (trimmed.startsWith('-----BEGIN') &&
      trimmed.contains('EC PRIVATE KEY-----') &&
      trimmed.endsWith('-----END EC PRIVATE KEY-----')) {
    return true;
  }

  return false;
}
