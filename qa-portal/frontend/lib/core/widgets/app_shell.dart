import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/auth_controller.dart';
import '../../features/ai_chat/ai_chat_widget.dart';

class AppShell extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;

  const AppShell({
    required this.title,
    required this.child,
    this.actions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      body: Stack(
        children: [
          Column(
            children: [
              _TopBar(title: title, actions: actions),
              Expanded(
                child: Row(
                  children: [
                    _Sidebar(),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
          const AiChatWidget(),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;

  const _TopBar({required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: const Color(0xFF2A2A3E),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
          const SizedBox(width: 12),
          Obx(() {
            final user = AuthController.to.user.value;
            final userName = user?.name ?? '';
            return InkWell(
              onTap: () => Get.toNamed('/profile'),
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                    backgroundImage: user?.avatarFileName != null
                        ? NetworkImage('${baseUrl}/auth/profile/avatar/${user!.avatarFileName}')
                        : null,
                    child: user?.avatarFileName == null
                        ? Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    userName,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              final confirmed = await Get.dialog<bool>(
                AlertDialog(
                  backgroundColor: const Color(0xFF2A2A3E),
                  title: const Text('Cerrar sesión',
                      style: TextStyle(color: Colors.white)),
                  content: const Text(
                    '¿Estás seguro de que deseas cerrar sesión?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text('Cancelar',
                          style: TextStyle(color: Colors.white70)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935)),
                      onPressed: () => Get.back(result: true),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                AuthController.to.logout();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final currentRoute = Get.currentRoute;

    return Container(
      width: 220,
      color: const Color(0xFF2A2A3E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Text(
              'QA Portal',
              style: TextStyle(
                color: Color(0xFF6C63FF),
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),
          _NavItem(
            icon: Icons.folder_outlined,
            label: 'Proyectos',
            route: '/projects',
            isActive: currentRoute == '/projects' ||
                currentRoute.startsWith('/projects'),
            onTap: () => Get.offAllNamed('/projects'),
          ),
          _NavItem(
            icon: Icons.assessment_outlined,
            label: 'Reportes',
            route: '/reports',
            isActive: currentRoute == '/reports' ||
                currentRoute.startsWith('/reports'),
            onTap: () => Get.offAllNamed('/reports'),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF6C63FF) : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF6C63FF) : Colors.white70,
                fontSize: 14,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
