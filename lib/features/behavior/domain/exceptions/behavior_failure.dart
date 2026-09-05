class BehaviorFailure implements Exception {
  const BehaviorFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
