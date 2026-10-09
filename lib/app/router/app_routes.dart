abstract final class AppRoutes {
  static const String home = '/';

  static const String login = '/login';

  static const String events = '/events';

  static const String behavior = '/events/behavior';
  static const String behaviorNew = '/events/behavior/new';
  static const String behaviorDetail = '/events/behavior/detail';
  static const String behaviorEdit = '/events/behavior/edit';

  static const String sleep = '/events/sleep';
  static const String sleepNew = '/events/sleep/new';
  static const String sleepDetail = '/events/sleep/detail';
  static const String sleepEdit = '/events/sleep/edit';

  static const String feeding = '/events/feeding';
  static const String feedingNew = '/events/feeding/new';
  static const String feedingDetail = '/events/feeding/detail';
  static const String feedingEdit = '/events/feeding/edit';

  static const String socialInteraction = '/events/social-interaction';
  static const String socialInteractionNew = '/events/social-interaction/new';
  static const String socialInteractionDetail =
      '/events/social-interaction/detail';
  static const String socialInteractionEdit = '/events/social-interaction/edit';

  static const String dysregulation = '/events/dysregulation';
  static const String dysregulationNew = '/events/dysregulation/new';
  static const String dysregulationDetail = '/events/dysregulation/detail';
  static const String dysregulationEdit = '/events/dysregulation/edit';

  static const String atypicalSituation = '/events/atypical-situation';
  static const String atypicalSituationNew = '/events/atypical-situation/new';
  static const String atypicalSituationDetail =
      '/events/atypical-situation/detail';
  static const String atypicalSituationEdit = '/events/atypical-situation/edit';

  static const String routines = '/routines';

  static const String routineManagement = '/routines/manage';
  static const String routineDetail = '/routines/detail';
  static const String routineNew = '/routines/new';
  static const String routineEdit = '/routines/edit';

  static const String routineStatus = '/routines/status';
  static const String routineStatusNew = '/routines/status/new';
  static const String routineStatusDetail = '/routines/status/detail';
  static const String routineStatusEdit = '/routines/status/edit';

  static const String indicators = '/indicators';

  static const String settings = '/settings';

  static const List<String> mainDestinations = [
    home,
    events,
    routines,
    indicators,
  ];

  static const List<String> eventManagementRoutes = [
    behavior,
    sleep,
    feeding,
    socialInteraction,
    dysregulation,
    atypicalSituation,
  ];

  static const List<String> eventCreationRoutes = [
    behaviorNew,
    sleepNew,
    feedingNew,
    socialInteractionNew,
    dysregulationNew,
    atypicalSituationNew,
  ];
}
