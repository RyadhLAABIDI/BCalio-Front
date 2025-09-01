class UnauthorizedException implements Exception {
  final String body;
  UnauthorizedException(this.body);
  @override
  String toString() => 'UnauthorizedException: $body';
}
