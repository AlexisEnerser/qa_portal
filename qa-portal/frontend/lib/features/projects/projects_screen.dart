import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/providers/auth_controller.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/models/project.dart';
import 'projects_controller.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ProjectsController>()) {
      Get.lazyPut(() => ProjectsController());
    }

    return Obx(() {
      final isAdmin = AuthController.to.user.value?.isAdmin == true;

      return AppShell(
        title: 'Proyectos',
        child: Stack(
          children: [
            Obx(() {
              final ctrl = ProjectsController.to;

              if (ctrl.loading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                );
              }

              if (ctrl.projects.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_off_outlined, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text(
                        'No hay proyectos aún',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(24),
                child: GridView.builder(
                  itemCount: ctrl.projects.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final project = ctrl.projects[index];
                    return _ProjectCard(
                      project: project,
                      isAdmin: isAdmin,
                    );
                  },
                ),
              );
            }),
            if (isAdmin)
              Positioned(
                bottom: 24,
                right: 24,
                child: FloatingActionButton(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  tooltip: 'Nuevo proyecto',
                  onPressed: () => _showProjectDialog(context),
                  child: const Icon(Icons.add),
                ),
              ),
          ],
        ),
      );
    });
  }

  void _showProjectDialog(BuildContext context, [AppProject? project]) {
    showDialog(
      context: context,
      builder: (_) => _ProjectDialog(project: project),
    );
  }
}

// ─── Project Card ─────────────────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  final AppProject project;
  final bool isAdmin;

  const _ProjectCard({required this.project, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(
        '/projects/detail',
        arguments: {'projectId': project.id, 'projectName': project.name},
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                _StatusBadge(isActive: project.isActive),
                if (isAdmin) ...[
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: const Icon(Icons.more_vert, color: Colors.white38, size: 18),
                      color: const Color(0xFF1E1E2E),
                      onSelected: (value) {
                        if (value == 'edit') {
                          showDialog(
                            context: context,
                            builder: (_) => _ProjectDialog(project: project),
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
                              Icon(Icons.edit_outlined, color: Colors.white70, size: 16),
                              SizedBox(width: 8),
                              Text('Editar', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                              SizedBox(width: 8),
                              Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                project.description.isNotEmpty ? project.description : 'Sin descripción',
                style: TextStyle(
                  color: project.description.isNotEmpty ? Colors.white54 : Colors.white24,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6C63FF),
                  side: const BorderSide(color: Color(0xFF6C63FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => Get.toNamed(
                  '/projects/detail',
                  arguments: {
                    'projectId': project.id,
                    'projectName': project.name,
                  },
                ),
                child: const Text('Ver módulos'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text(
          'Eliminar proyecto',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${project.name}"? Esta acción no se puede deshacer.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              await ProjectsController.to.deleteProject(project.id);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.green : Colors.grey,
          width: 0.8,
        ),
      ),
      child: Text(
        isActive ? 'Activo' : 'Inactivo',
        style: TextStyle(
          color: isActive ? Colors.greenAccent : Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── Project Dialog ───────────────────────────────────────────────────────────

class _ProjectDialog extends StatefulWidget {
  final AppProject? project;
  const _ProjectDialog({this.project});

  @override
  State<_ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<_ProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.project?.name ?? '');
    _descCtrl = TextEditingController(text: widget.project?.description ?? '');
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
    if (widget.project == null) {
      success = await ProjectsController.to.createProject(
        _nameCtrl.text.trim(),
        _descCtrl.text.trim(),
      );
    } else {
      success = await ProjectsController.to.updateProject(
        widget.project!.id,
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
          const SnackBar(content: Text('Error al guardar el proyecto')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.project != null;
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A3E),
      title: Text(
        isEditing ? 'Editar proyecto' : 'Nuevo proyecto',
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
