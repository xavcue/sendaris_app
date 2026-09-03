import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/viewmodels/auth_view_model.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class SendarisApp extends StatefulWidget {
  const SendarisApp({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<SendarisApp> createState() => _SendarisAppState();
}

class _SendarisAppState extends State<SendarisApp> {
  late final AuthViewModel _authViewModel;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _authViewModel = AuthViewModel(widget.authRepository);
    _router = AppRouter.create(_authViewModel);
  }

  @override
  void dispose() {
    _router.dispose();
    _authViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthViewModel>.value(
      value: _authViewModel,
      child: MaterialApp.router(
        title: 'Sendaris',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
