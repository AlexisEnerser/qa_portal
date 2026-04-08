import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../features/auth/login_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/projects/project_detail_screen.dart';
import '../../features/projects/module_detail_screen.dart';
import '../../features/projects/test_case_form_screen.dart';
import '../../features/execution/executions_screen.dart';
import '../../features/execution/execution_run_screen.dart';
import '../../features/execution/execution_dashboard_screen.dart';
import '../../features/bugs/bugs_screen.dart';
import '../../features/bugs/bug_form_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/projects/projects_controller.dart';
import '../../features/execution/execution_controller.dart';
import '../../features/bugs/bugs_controller.dart';
import '../../features/reports/reports_controller.dart';
import '../providers/auth_controller.dart';

class AppPages {
  static const initial = '/login';

  static final routes = [
    // Auth
    GetPage(
      name: '/login',
      page: () => const LoginScreen(),
      middlewares: [GuestMiddleware()],
    ),

    // Projects
    GetPage(
      name: '/projects',
      page: () => const ProjectsScreen(),
      binding: BindingsBuilder(() => Get.lazyPut(() => ProjectsController())),
      middlewares: [AuthMiddleware()],
      transition: Transition.noTransition,
    ),
    GetPage(
      name: '/projects/detail',
      page: () => const ProjectDetailScreen(),
      binding: BindingsBuilder(() => Get.lazyPut(() => ProjectsController())),
      middlewares: [AuthMiddleware()],
      transition: Transition.noTransition,
    ),

    // Modules
    GetPage(
      name: '/modules/detail',
      page: () => const ModuleDetailScreen(),
      binding: BindingsBuilder(() => Get.lazyPut(() => ProjectsController())),
      middlewares: [AuthMiddleware()],
      transition: Transition.noTransition,
    ),

    // Test cases
    GetPage(
      name: '/test-case/form',
      page: () => const TestCaseFormScreen(),
      binding: BindingsBuilder(() => Get.lazyPut(() => ProjectsController())),
      middlewares: [AuthMiddleware()],
      transition: Transition.noTransition,
    ),

    // Executions
    GetPage(
      name: '/executions',
      page: () => const ExecutionsScreen(),
      binding: BindingsBuilder(() => Get.lazyPut(() => ExecutionController())),
      middlewares: [AuthMiddleware()],
      transition: Transition.noTransition,
    ),
    GetPage(
      name: '/execution/run',
      page: () => const ExecutionRunScreen(),
      binding: BindingsBuilder(() => Get.lazyPut(() => ExecutionController())),
      middlewares: [AuthMiddleware()],
      transition: Transition.noTransition,
    ),
    GetPage(
      name: '/execution/dashboard',
      page: () => const ExecutionDashboardScreen(),
      binding: BindingsBuilder(() => Get.lazyPut(() => ExecutionController())),
      middlewares: [AuthMiddleware()],
      transition: Transition.noTransition,
    ),

    // Bugs
    GetPage(
      name: '/bugs',
      page: () => const BugsScreen(),
      binding: BindingsBuilder(() => Get.lazyPut(() => BugsController())),
      middlewares: [AuthMiddleware()],
      transition: Transition.noTransition,
    ),
    GetPage(
      name: '/bug/form',
      page: () => const BugFormScreen(),
      binding: BindingsBuilder(() => Get.lazyPut(() => BugsController())),
      middlewares: [AuthMiddleware()],
      transition: Transition.noTransition,
    ),

    // Reports
    GetPage(
      name: '/reports',
      page: () => const ReportsScreen(),
      binding: BindingsBuilder(() => Get.lazyPut(() => ReportsController())),
      middlewares: [AuthMiddleware()],
      transition: Transition.noTransition,
    ),

    // Profile
    GetPage(
      name: '/profile',
      page: () => const ProfileScreen(),
      middlewares: [AuthMiddleware()],
      transition: Transition.noTransition,
    ),
  ];
}

// Redirige a /projects si ya está autenticado
class GuestMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final auth = AuthController.to;
    if (auth.authReady.value && auth.isAuthenticated) {
      return const RouteSettings(name: '/projects');
    }
    return null;
  }
}

// Redirige a /login si no está autenticado
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final auth = AuthController.to;
    if (auth.authReady.value && !auth.isAuthenticated) {
      return const RouteSettings(name: '/login');
    }
    return null;
  }
}
