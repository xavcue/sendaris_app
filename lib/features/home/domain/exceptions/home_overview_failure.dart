class HomeOverviewFailure implements Exception {
  const HomeOverviewFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
