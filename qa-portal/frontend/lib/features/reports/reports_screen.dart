import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/api/api_client.dart';
import 'reports_controller.dart';
import 'sonar_pdf_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _kBg = Color(0xFF1E1E2E);
const _kSurface = Color(0xFF2A2A3E);
const _kPrimary = Color(0xFF6C63FF);
const _kRadius = 12.0;

InputDecoration _inputDecoration(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: _kBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kRadius),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kRadius),
        borderSide: const BorderSide(color: _kPrimary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kRadius),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kRadius),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );

Widget _card({required Widget child}) => Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_kRadius),
      ),
      child: child,
    );

Widget _sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

Widget _gap([double h = 16]) => SizedBox(height: h);

// ---------------------------------------------------------------------------
// ReportsScreen
// ---------------------------------------------------------------------------

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Reportes',
      child: Column(
        children: [
          Container(
            color: _kSurface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: _kPrimary,
              labelColor: _kPrimary,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(text: 'SonarQube'),
                Tab(text: 'Hoja de Posteo'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _SonarTab(),
                _PostingSheetTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1 — SonarQube
// ---------------------------------------------------------------------------

class _SonarTab extends StatefulWidget {
  const _SonarTab();

  @override
  State<_SonarTab> createState() => _SonarTabState();
}

class _SonarTabState extends State<_SonarTab> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedLogo;
  List<Map<String, dynamic>> _projects = [];
  String? _selectedProject;
  String _severity = 'CRITICAL';
  bool _loadingProjects = false;
  bool _loadingPdf = false;
  String? _errorMessage;

  static const _severities = ['INFO', 'MINOR', 'MAJOR', 'CRITICAL', 'BLOCKER'];

  @override
  void initState() {
    super.initState();
    _selectedLogo = ReportsController.to.logoOptions.isNotEmpty
        ? ReportsController.to.logoOptions.first
        : null;
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loadingProjects = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiClient.to.get('/sonar/projects');
      final List data = response.body is List ? response.body as List : [];
      setState(() {
        _projects = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (e) {
      setState(() => _errorMessage = 'Error al cargar proyectos: $e');
    } finally {
      setState(() => _loadingProjects = false);
    }
  }

  Future<void> _generatePdf() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProject == null) {
      setState(() => _errorMessage = 'Selecciona un proyecto');
      return;
    }

    setState(() {
      _loadingPdf = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.to
          .get('/sonar/analysis/$_selectedProject?severity=$_severity');

      if (response.statusCode != 200) {
        throw Exception('Error ${response.statusCode}: ${response.bodyString}');
      }

      final pdfBytes = await SonarPdfService.generate(
        Map<String, dynamic>.from(response.body as Map),
        _selectedLogo ?? '',
      );

      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    } catch (e) {
      setState(() => _errorMessage = 'Error al generar PDF: $e');
    } finally {
      setState(() => _loadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoOptions = ReportsController.to.logoOptions;

    return SingleChildScrollView(
      child: _card(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('Reporte SonarQube'),

              // Logo selector
              DropdownButtonFormField<String>(
                value: _selectedLogo,
                decoration: _inputDecoration('Logo'),
                dropdownColor: _kSurface,
                style: const TextStyle(color: Colors.white),
                items: logoOptions
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _selectedLogo = v);
                  if (v != null) ReportsController.to.selectedLogo.value = v;
                },
                validator: (v) => v == null ? 'Requerido' : null,
              ),
              _gap(),

              // Project selector
              _loadingProjects
                  ? const Center(
                      child: CircularProgressIndicator(color: _kPrimary))
                  : DropdownButtonFormField<String>(
                      value: _selectedProject,
                      decoration: _inputDecoration('Proyecto'),
                      dropdownColor: _kSurface,
                      style: const TextStyle(color: Colors.white),
                      items: _projects.map((p) {
                        final key = p['key']?.toString() ?? p['id']?.toString() ?? '';
                        final name = p['name']?.toString() ?? key;
                        return DropdownMenuItem(value: key, child: Text(name));
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedProject = v),
                      validator: (v) => v == null ? 'Selecciona un proyecto' : null,
                    ),
              _gap(),

              // Severity selector
              DropdownButtonFormField<String>(
                value: _severity,
                decoration: _inputDecoration('Severidad'),
                dropdownColor: _kSurface,
                style: const TextStyle(color: Colors.white),
                items: _severities
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _severity = v ?? 'CRITICAL'),
              ),
              _gap(24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(_kRadius),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                _gap(),
              ],

              FilledButton(
                onPressed: _loadingPdf ? null : _generatePdf,
                style: FilledButton.styleFrom(
                  backgroundColor: _kPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_kRadius)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _loadingPdf
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Generar PDF',
                        style: TextStyle(fontSize: 15, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2 — Hoja de Posteo
// ---------------------------------------------------------------------------

class _PostingSheetTab extends StatefulWidget {
  const _PostingSheetTab();

  @override
  State<_PostingSheetTab> createState() => _PostingSheetTabState();
}

class _PostingSheetTabState extends State<_PostingSheetTab> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedLogo;

  // GitHub fields
  final _orgCtrl = TextEditingController();
  final _repoCtrl = TextEditingController();
  final _branchCtrl = TextEditingController(text: 'main');
  final _commitShaCtrl = TextEditingController();

  List<Map<String, dynamic>> _commits = [];
  String? _selectedCommit;
  bool _loadingCommits = false;

  // Normative fields
  final _businessCtrl = TextEditingController();
  final _productCtrl = TextEditingController();
  final _projectDetailCtrl = TextEditingController();
  final _userRollbackCtrl = TextEditingController();
  final _userRollbackMailCtrl = TextEditingController();

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedLogo = ReportsController.to.logoOptions.isNotEmpty
        ? ReportsController.to.logoOptions.first
        : null;
  }

  @override
  void dispose() {
    _orgCtrl.dispose();
    _repoCtrl.dispose();
    _branchCtrl.dispose();
    _commitShaCtrl.dispose();
    _businessCtrl.dispose();
    _productCtrl.dispose();
    _projectDetailCtrl.dispose();
    _userRollbackCtrl.dispose();
    _userRollbackMailCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCommits() async {
    if (_orgCtrl.text.isEmpty || _repoCtrl.text.isEmpty) {
      setState(() => _errorMessage = 'Ingresa organización y repositorio');
      return;
    }
    setState(() {
      _loadingCommits = true;
      _errorMessage = null;
      _commits = [];
      _selectedCommit = null;
    });
    try {
      final branch = _branchCtrl.text.isEmpty ? 'main' : _branchCtrl.text;
      final response = await ApiClient.to.get(
        '/github/commits?org=${Uri.encodeComponent(_orgCtrl.text)}'
        '&repo=${Uri.encodeComponent(_repoCtrl.text)}'
        '&branch=${Uri.encodeComponent(branch)}',
      );
      if (response.statusCode != 200) {
        throw Exception('Error ${response.statusCode}');
      }
      final List data = response.body is List ? response.body as List : [];
      setState(() {
        _commits = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (e) {
      setState(() => _errorMessage = 'Error al buscar commits: $e');
    } finally {
      setState(() => _loadingCommits = false);
    }
  }

  Future<void> _generatePdf() async {
    if (!_formKey.currentState!.validate()) return;

    final sha = _commitShaCtrl.text.isNotEmpty
        ? _commitShaCtrl.text
        : _selectedCommit ?? '';

    if (sha.isEmpty) {
      setState(() => _errorMessage = 'Selecciona o ingresa un commit SHA');
      return;
    }

    setState(() => _errorMessage = null);

    final data = {
      'logo': _selectedLogo ?? '',
      'org': _orgCtrl.text,
      'repo': _repoCtrl.text,
      'branch': _branchCtrl.text,
      'commit_sha': sha,
      'business': _businessCtrl.text,
      'product': _productCtrl.text,
      'project_detail': _projectDetailCtrl.text,
      'user_rollback': _userRollbackCtrl.text,
      'user_rollback_mail': _userRollbackMailCtrl.text,
    };

    await ReportsController.to.downloadPostingSheetPdf(data);
  }

  @override
  Widget build(BuildContext context) {
    final logoOptions = ReportsController.to.logoOptions;

    return SingleChildScrollView(
      child: _card(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('Hoja de Posteo'),

              // Logo
              DropdownButtonFormField<String>(
                value: _selectedLogo,
                decoration: _inputDecoration('Logo'),
                dropdownColor: _kSurface,
                style: const TextStyle(color: Colors.white),
                items: logoOptions
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _selectedLogo = v);
                  if (v != null) ReportsController.to.selectedLogo.value = v;
                },
                validator: (v) => v == null ? 'Requerido' : null,
              ),
              _gap(),

              // GitHub section
              _sectionTitle('Repositorio GitHub'),
              TextFormField(
                controller: _orgCtrl,
                decoration: _inputDecoration('Organización'),
                style: const TextStyle(color: Colors.white),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              _gap(),
              TextFormField(
                controller: _repoCtrl,
                decoration: _inputDecoration('Repositorio'),
                style: const TextStyle(color: Colors.white),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              _gap(),
              TextFormField(
                controller: _branchCtrl,
                decoration: _inputDecoration('Rama'),
                style: const TextStyle(color: Colors.white),
              ),
              _gap(),
              TextFormField(
                controller: _commitShaCtrl,
                decoration: _inputDecoration('Commit SHA (manual)'),
                style: const TextStyle(color: Colors.white),
              ),
              _gap(),

              // Fetch commits button
              OutlinedButton.icon(
                onPressed: _loadingCommits ? null : _fetchCommits,
                icon: _loadingCommits
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kPrimary),
                      )
                    : const Icon(Icons.search, color: _kPrimary),
                label: const Text('Buscar commits',
                    style: TextStyle(color: _kPrimary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kPrimary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_kRadius)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              _gap(),

              if (_commits.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: _selectedCommit,
                  decoration: _inputDecoration('Seleccionar commit'),
                  dropdownColor: _kSurface,
                  style: const TextStyle(color: Colors.white),
                  isExpanded: true,
                  items: _commits.map((c) {
                    final sha = c['sha']?.toString() ?? '';
                    final msg = c['message']?.toString() ?? sha;
                    final short = sha.length > 7 ? sha.substring(0, 7) : sha;
                    return DropdownMenuItem(
                      value: sha,
                      child: Text(
                        '$short — $msg',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedCommit = v;
                      if (v != null) _commitShaCtrl.text = v;
                    });
                  },
                ),
                _gap(),
              ],

              // Normative fields
              _sectionTitle('Datos normativos'),
              TextFormField(
                controller: _businessCtrl,
                decoration: _inputDecoration('Negocio'),
                style: const TextStyle(color: Colors.white),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              _gap(),
              TextFormField(
                controller: _productCtrl,
                decoration: _inputDecoration('Producto'),
                style: const TextStyle(color: Colors.white),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              _gap(),
              TextFormField(
                controller: _projectDetailCtrl,
                decoration: _inputDecoration('Detalle del proyecto'),
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              _gap(),
              TextFormField(
                controller: _userRollbackCtrl,
                decoration: _inputDecoration('Responsable de rollback'),
                style: const TextStyle(color: Colors.white),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              _gap(),
              TextFormField(
                controller: _userRollbackMailCtrl,
                decoration: _inputDecoration('Email de rollback'),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (!v.contains('@')) return 'Email inválido';
                  return null;
                },
              ),
              _gap(24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(_kRadius),
                  ),
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: Colors.redAccent)),
                ),
                _gap(),
              ],

              Obx(() => FilledButton(
                    onPressed: ReportsController.to.isLoading.value
                        ? null
                        : _generatePdf,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_kRadius)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: ReportsController.to.isLoading.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Generar Hoja de Posteo',
                            style: TextStyle(fontSize: 15)),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

