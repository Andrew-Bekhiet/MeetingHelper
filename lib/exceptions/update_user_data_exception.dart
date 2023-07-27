class UpdateUserDataException implements Exception {
  final DateTime? lastTanawol;
  final DateTime? lastConfession;
  UpdateUserDataException({
    required this.lastTanawol,
    required this.lastConfession,
  });

  @override
  String toString() {
    return 'Exception: User lastTanawol and lastConfession'
        ' are not up to date\n'
        'lastTanawol: $lastTanawol, lastConfession:$lastConfession';
  }
}
