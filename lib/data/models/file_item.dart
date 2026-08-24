class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
  final String permissions;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modified,
    this.permissions = '',
  });

  FileItem copyWith({
    String? name,
    String? path,
    bool? isDirectory,
    int? size,
    DateTime? modified,
    String? permissions,
  }) {
    return FileItem(
      name: name ?? this.name,
      path: path ?? this.path,
      isDirectory: isDirectory ?? this.isDirectory,
      size: size ?? this.size,
      modified: modified ?? this.modified,
      permissions: permissions ?? this.permissions,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileItem &&
          name == other.name &&
          path == other.path &&
          isDirectory == other.isDirectory &&
          size == other.size &&
          modified == other.modified &&
          permissions == other.permissions;

  @override
  int get hashCode =>
      Object.hash(name, path, isDirectory, size, modified, permissions);
}
