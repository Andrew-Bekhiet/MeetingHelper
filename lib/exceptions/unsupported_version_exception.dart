class UnsupportedVersionException implements Exception {
  final String? version;
  UnsupportedVersionException({
    required this.version,
  });

  @override
  String toString() {
    return 'Exception: App version is not supported and is not allowed to run\n'
        'version:$version';
  }
}
