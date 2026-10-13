import '../../domain/services/home_clock.dart';

class SystemHomeClock implements HomeClock {
  const SystemHomeClock();

  @override
  DateTime now() {
    return DateTime.now();
  }
}
