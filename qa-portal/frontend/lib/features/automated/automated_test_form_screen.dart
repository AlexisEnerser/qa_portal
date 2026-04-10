import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/api/api_client.dart';
import 'automated_controller.dart';

const _kBg = Color(0xFF1E1E2E);
const _kSurface = Color(0xFF2A2A3E);
const _kPrimary = Color(0xFF6C63FF);
const _kRadius = 12.0;

class AutomatedTestFormScreen extends StatefulWidget {
  const AutomatedTestFormScreen({super.key});

  @override
  State<AutomatedTestFormScreen> createState() => _AutomatedTestFormScreenState();
}

class _AutomatedTestFormScreenState extends State<AutomatedTestFormScreen> {
  late final String suiteId;
  late final String suiteName;
  late final String projectId;
  late final String projectName;
  String? testId;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _scriptCtrl = TextEditingController();
  final _aiDescCtrl = TextEditingController();
  final _refineCtrl = TextEditingController();

  bool _isEditing = false;
  bool _saving = false;

  // Para clonar desde manual
  List<Map<String, dynamic>> _manualTestCases = [];
  bool _loadingManual = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    suiteId = args['suiteId'] as String? ?? '';
    suiteName = args['suiteName'] as String? ?? '';
    projectId = args['projectId'] as String? ?? '';
    projectName = args['projectName'] as String? ?? '';
    testId = args['testId'] as String?;

    if (testId != null) {
      _isEditing = true;
      _nameCtrl.text = args['testName'] as String? ?? '';
      _scriptCtrl.text = args['scriptCode'] as String? ?? '';
      _urlCtrl.text = args['targetUrl'] as String? ?? '';
      _descCtrl.text = args['description'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    _scriptCtrl.dispose();
    _aiDescCtrl.dispose();
    _refineCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadManualTestCases() async {
    setState(() => _loadingManual = true);
    try {
      // Cargar módulos del proyecto y luego test cases
      final modResp = await ApiClient.to.get('/projects/$projectId/modules');
      if (modResp.isOk) {
        final modules = modResp.body as List;
        final allCases = <Map<String, dynamic>>[];
        for (final m in modules) {
          final modId = m['id'];
          final tcResp = await ApiClient.to.get('/qa/modules/$modId/test-cases');
          if (tcResp.isOk) {
            for (final tc in tcResp.body as List) {
              allCases.add({
                ...Map<String, dynamic>.from(tc as Map),
                'module_name': m['name'],
              });
            }
          }
        }
        setState(() => _manualTestCases = allCases);
      }
    } catch (_) {}
    setState(() => _loadingManual = false);
  }

  void _showCloneDialog() async {
    if (_manualTestCases.isEmpty) await _loadManualTestCases();
    if (_manualTestCases.isEmpty) {
      Get.snackbar('Sin datos', 'No se encontraron test cases manuales',
          backgroundColor: _kSurface, colorText: Colors.white);
      return;
    }
    if (_urlCtrl.text.isEmpty) {
      Get.snackbar('URL requerida', 'Ingresa la URL objetivo antes de clonar',
          backgroundColor: _kSurface, colorText: Colors.white);
      return;
    }

    Get.dialog(AlertDialog(
      backgroundColor: _kSurface,
      title: const Text('Clonar desde test manual', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 500,
        height: 400,
        child: _loadingManual
            ? const Center(child: CircularProgressIndicator(color: _kPrimary))
            : ListView.builder(
                itemCount: _manualTestCases.length,
                itemBuilder: (_, i) {
                  final tc = _manualTestCases[i];
                  return ListTile(
                    title: Text(tc['title'] ?? '', style: const TextStyle(color: Colors.white)),
                    subtitle: Text(tc['module_name'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    onTap: () async {
                      Get.back();
                      final result = await AutomatedController.to.cloneFromManual(
                        suiteId, tc['id'] as String, _urlCtrl.text);
                      if (result != null) {
                        setState(() {
                          _nameCtrl.text = result.name;
                          _descCtrl.text = result.description ?? '';
                          _scriptCtrl.text = result.scriptCode ?? '';
                          testId = result.id;
                          _isEditing = true;
                        });
                        Get.snackbar('Clonado', 'Test creado con script generado por IA',
                            backgroundColor: Colors.green.withValues(alpha: 0.3), colorText: Colors.white);
                      }
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancelar', style: TextStyle(color: Colors.white70))),
      ],
    ));
  }

  Future<void> _generateWithAI() async {
    if (_aiDescCtrl.text.isEmpty || _urlCtrl.text.isEmpty) {
      Get.snackbar('Campos requeridos', 'Ingresa descripción y URL',
          backgroundColor: _kSurface, colorText: Colors.white);
      return;
    }
    final code = await AutomatedController.to.generateScript(_aiDescCtrl.text, _urlCtrl.text);
    if (code != null) {
      setState(() => _scriptCtrl.text = code);
    }
  }

  Future<void> _refineWithAI() async {
    if (_refineCtrl.text.isEmpty || _scriptCtrl.text.isEmpty) return;
    final code = await AutomatedController.to.refineScript(_scriptCtrl.text, _refineCtrl.text);
    if (code != null) {
      setState(() => _scriptCtrl.text = code);
      _refineCtrl.clear();
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty) return;
    setState(() => _saving = true);
    bool ok;
    if (_isEditing && testId != null) {
      ok = await AutomatedController.to.updateTest(testId!, {
        'name': _nameCtrl.text,
        'description': _descCtrl.text,
        'script_code': _scriptCtrl.text,
        'target_url': _urlCtrl.text,
      });
    } else {
      ok = await AutomatedController.to.createTest(
        suiteId, _nameCtrl.text, _descCtrl.text, _scriptCtrl.text, _urlCtrl.text, null);
    }
    setState(() => _saving = false);
    if (ok) {
      Get.snackbar('Guardado', 'Test guardado correctamente',
          backgroundColor: Colors.green.withValues(alpha: 0.3), colorText: Colors.white);
      AutomatedController.to.loadTests(suiteId);
      Get.offNamed('/automated/suite', arguments: {
        'suiteId': suiteId, 'suiteName': suiteName,
        'projectId': projectId, 'projectName': projectName,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: _isEditing ? 'Editar Test' : 'Nuevo Test Automatizado',
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)),
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Regresar'),
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel izquierdo — formulario
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Nombre
                  TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco('Nombre del test')),
                  const SizedBox(height: 12),
                  // URL
                  TextField(controller: _urlCtrl, style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco('URL de la aplicación')),
                  const SizedBox(height: 12),
                  // Descripción
                  TextField(controller: _descCtrl, style: const TextStyle(color: Colors.white),
                    maxLines: 2, decoration: _inputDeco('Descripción (opcional)')),
                  const SizedBox(height: 16),

                  // Acciones IA
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(_kRadius)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Generar con IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        TextField(controller: _aiDescCtrl, style: const TextStyle(color: Colors.white),
                          maxLines: 3, decoration: _inputDeco('Describe qué quieres probar...')),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Obx(() => FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: _kPrimary),
                                onPressed: AutomatedController.to.isGenerating.value ? null : _generateWithAI,
                                icon: AutomatedController.to.isGenerating.value
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                                label: const Text('Generar Script', style: TextStyle(color: Colors.white)),
                              )),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.amber, side: const BorderSide(color: Colors.amber)),
                              onPressed: _showCloneDialog,
                              icon: const Icon(Icons.copy_all, size: 18),
                              label: const Text('Clonar desde manual'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Guardar
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isEditing ? 'Guardar cambios' : 'Crear Test', style: const TextStyle(fontSize: 15, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),

          // Panel derecho — editor de código + chat refinamiento
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Editor de código
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0, 16, 16, 8),
                    decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(_kRadius), border: Border.all(color: Colors.white12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(color: _kSurface, borderRadius: BorderRadius.only(topLeft: Radius.circular(_kRadius), topRight: Radius.circular(_kRadius))),
                          child: const Text('Script Playwright (Python)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _scriptCtrl,
                            style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 13),
                            maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top,
                            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Chat de refinamiento
                Container(
                  margin: const EdgeInsets.fromLTRB(0, 0, 16, 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(_kRadius)),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _refineCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Pide ajustes a la IA: "cambia el selector", "agrega espera"...',
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                            border: InputBorder.none, isDense: true,
                          ),
                          onSubmitted: (_) => _refineWithAI(),
                        ),
                      ),
                      Obx(() => IconButton(
                        icon: AutomatedController.to.isGenerating.value
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary))
                            : const Icon(Icons.send, color: _kPrimary, size: 20),
                        onPressed: AutomatedController.to.isGenerating.value ? null : _refineWithAI,
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(color: Colors.white70),
    filled: true, fillColor: _kBg,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(_kRadius), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_kRadius), borderSide: const BorderSide(color: Colors.white12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_kRadius), borderSide: const BorderSide(color: _kPrimary)),
  );
}
