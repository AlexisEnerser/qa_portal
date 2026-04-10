import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/providers/auth_controller.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/models/project.dart';
import 'projects_controller.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late final String projectId;
  late final String projectName;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args == null || args['projectId'] == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed('/projects');
      });
      projectId = '';
      projectName = '';
      return;
    }
    projectId = args['projectId'] as String;
    projectName = args['projectName'] as String? ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProjectsController.to.loadModules(projectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AuthController.to.user.value?.isAdmin == true;

    return AppShell(
      title: projectName,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    // Breadcrumb
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: const Text(
                        'Proyectos',
                        style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                    const Text(
                      ' > ',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                    Text(
                      projectName,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: const Text('Sesiones de Ejecución'),
                      onPressed: () => Get.toNamed(
                        '/executions',
                        arguments: {
                          'projectId': projectId,
                          'projectName': projectName,
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6C63FF),
                        side: const BorderSide(color: Color(0xFF6C63FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.science_outlined, size: 18),
                      label: const Text('Pruebas Automatizadas'),
                      onPressed: () => Get.toNamed(
                        '/automated/suites',
                        arguments: {
                          'projectId': projectId,
                          'projectName': projectName,
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white12, height: 1),

              // ── Module list ─────────────────────────────────────────────
              Expanded(
                child: Obx(() {
                  final ctrl = ProjectsController.to;

                  if (ctrl.loading.value) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                    );
                  }

                  if (ctrl.modules.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.view_module_outlined,
                            size: 64,
                            color: Colors.white24,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No hay módulos aún',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: ctrl.modules.length,
                    itemBuilder: (context, index) {
                      final mod = ctrl.modules[index];
                      return _ModuleCard(
                        module: mod,
                        projectId: projectId,
                        projectName: projectName,
                        isAdmin: isAdmin,
                      );
                    },
                  );
                }),
              ),
            ],
          ),

          // ── FAB ──────────────────────────────────────────────────────────
          if (isAdmin)
            Positioned(
              bottom: 24,
              right: 24,
              child: FloatingActionButton(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                tooltip: 'Nuevo módulo',
                onPressed: () => _showModuleDialog(context),
                child: const Icon(Icons.add),
              ),
            ),
        ],
      ),
    );
  }

  void _showModuleDialog(BuildContext context, [AppModule? module]) {
    showDialog(
      context: context,
      builder: (_) => _ModuleDialog(
        projectId: projectId,
        module: module,
      ),
    );
  }
}

// ─── Module Card ──────────────────────────────────────────────────────────────

class _ModuleCard extends StatelessWidget {
  final AppModule module;
  final String projectId;
  final String projectName;
  final bool isAdmin;

  const _ModuleCard({
    required this.module,
    required this.projectId,
    required this.projectName,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.view_module_outlined, color: Color(0xFF6C63FF), size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (module.description != null && module.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    module.description!,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6C63FF),
              side: const BorderSide(color: Color(0xFF6C63FF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Get.toNamed(
              '/modules/detail',
              arguments: {
                'moduleId': module.id,
                'projectId': projectId,
                'projectName': projectName,
                'moduleName': module.name,
              },
            ),
            child: const Text('Ver casos'),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              color: const Color(0xFF2A2A3E),
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              onSelected: (value) {
                if (value == 'edit') {
                  showDialog(
                    context: context,
                    builder: (_) => _ModuleDialog(
                      projectId: projectId,
                      module: module,
                    ),
                  );
                } else if (value == 'delete') {
                  _confirmDelete(context);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                      SizedBox(width: 8),
                      Text('Editar', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text('Eliminar módulo', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Eliminar el módulo "${module.name}"?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              await ProjectsController.to.deleteModule(projectId, module.id);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Module Dialog ────────────────────────────────────────────────────────────

class _ModuleDialog extends StatefulWidget {
  final String projectId;
  final AppModule? module;

  const _ModuleDialog({required this.projectId, this.module});

  @override
  State<_ModuleDialog> createState() => _ModuleDialogState();
}

class _ModuleDialogState extends State<_ModuleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.module?.name ?? '');
    _descCtrl = TextEditingController(text: widget.module?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    bool success;
    if (widget.module == null) {
      success = await ProjectsController.to.createModule(
        widget.projectId,
        _nameCtrl.text.trim(),
        _descCtrl.text.trim(),
      );
    } else {
      success = await ProjectsController.to.updateModule(
        widget.projectId,
        widget.module!.id,
        _nameCtrl.text.trim(),
        _descCtrl.text.trim(),
      );
    }

    if (mounted) {
      setState(() => _saving = false);
      if (success) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar el módulo')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.module != null;
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A3E),
      title: Text(
        isEditing ? 'Editar módulo' : 'Nuevo módulo',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DarkTextFormField(
                controller: _nameCtrl,
                label: 'Nombre',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
              ),
              const SizedBox(height: 16),
              _DarkTextFormField(
                controller: _descCtrl,
                label: 'Descripción',
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isEditing ? 'Guardar' : 'Crear', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ─── Shared dark text field ────────────────────────────────────────────────────

class _DarkTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final String? Function(String?)? validator;

  const _DarkTextFormField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF1E1E2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF6C63FF)),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
