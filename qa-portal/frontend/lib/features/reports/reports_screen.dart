import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/api/api_client.dart';
import 'reports_controller.dart';
import 'sonar_pdf_service.dart';
import 'qengine_pdf_service.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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
                Tab(text: 'QEngine'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _SonarTab(),
                _PostingSheetTab(),
                _QEngineTab(),
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

// ---------------------------------------------------------------------------
// Tab 3 — QEngine
// ---------------------------------------------------------------------------

class _QEngineTab extends StatefulWidget {
  const _QEngineTab();

  @override
  State<_QEngineTab> createState() => _QEngineTabState();
}

class _QEngineTabState extends State<_QEngineTab> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedLogo;

  // Project / suite
  List<Map<String, dynamic>> _projects = [];
  String? _selectedProjectId;
  List<Map<String, dynamic>> _suites = [];
  String? _selectedSuiteId;
  final _testRunIdCtrl = TextEditingController();

  bool _loadingProjects = false;
  bool _loadingSuites = false;
  bool _loadingPdf = false;

  // Normative fields
  String _environment = 'QA';
  final _ipCtrl = TextEditingController();
  final _analystaCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _moduloCtrl = TextEditingController();
  final _solicitanteCtrl = TextEditingController();
  final _puestoSolicitanteCtrl = TextEditingController();
  final _developerCtrl = TextEditingController();
  final _techLeadCtrl = TextEditingController();
  final _puestoTechLeadCtrl = TextEditingController();
  final _coordinadorCtrl = TextEditingController();
  final _huCtrl = TextEditingController();
  final _zohoProjectCtrl = TextEditingController();

  bool _extractImages = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedLogo = ReportsController.to.logoOptions.isNotEmpty
        ? ReportsController.to.logoOptions.first
        : null;
    _loadProjects();
  }

  @override
  void dispose() {
    _testRunIdCtrl.dispose();
    _ipCtrl.dispose();
    _analystaCtrl.dispose();
    _areaCtrl.dispose();
    _moduloCtrl.dispose();
    _solicitanteCtrl.dispose();
    _puestoSolicitanteCtrl.dispose();
    _developerCtrl.dispose();
    _techLeadCtrl.dispose();
    _puestoTechLeadCtrl.dispose();
    _coordinadorCtrl.dispose();
    _huCtrl.dispose();
    _zohoProjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loadingProjects = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiClient.to.get('/qengine/projects');
      final List data = response.body is List ? response.body as List : [];
      setState(() {
        _projects = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (e) {
      setState(() => _errorMessage = 'Error al cargar proyectos QEngine: $e');
    } finally {
      setState(() => _loadingProjects = false);
    }
  }

  Future<void> _loadSuites(String projectId) async {
    setState(() {
      _loadingSuites = true;
      _suites = [];
      _selectedSuiteId = null;
      _errorMessage = null;
    });
    try {
      final response =
          await ApiClient.to.get('/qengine/suites/$projectId');
      final List data = response.body is List ? response.body as List : [];
      setState(() {
        _suites = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (e) {
      setState(() => _errorMessage = 'Error al cargar suites: $e');
    } finally {
      setState(() => _loadingSuites = false);
    }
  }

  Future<void> _generatePdf() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProjectId == null) {
      setState(() => _errorMessage = 'Selecciona un proyecto');
      return;
    }
    if (_testRunIdCtrl.text.isEmpty) {
      setState(() => _errorMessage = 'Ingresa el Test Run ID');
      return;
    }

    setState(() {
      _loadingPdf = true;
      _errorMessage = null;
    });

    try {
      final payload = {
        'project_id': _selectedProjectId,
        'test_run_id': _testRunIdCtrl.text,
        'suite_id': _selectedSuiteId,
        'logo': _selectedLogo ?? '',
        'environment': _environment,
        'ip_address': _ipCtrl.text,
        'analista_qa': _analystaCtrl.text,
        'area': _areaCtrl.text,
        'modulo': _moduloCtrl.text,
        'solicitante': _solicitanteCtrl.text,
        'puesto_solicitante': _puestoSolicitanteCtrl.text,
        'desarrollador': _developerCtrl.text,
        'tech_lead': _techLeadCtrl.text,
        'puesto_tech_lead': _puestoTechLeadCtrl.text,
        'coordinador': _coordinadorCtrl.text,
        'hu_entregable': _huCtrl.text,
        'nombre_zoho_projects': _zohoProjectCtrl.text,
        'extract_images': _extractImages,
      };

      final response =
          await ApiClient.to.post('/qengine/report-data', payload);

      if (response.statusCode != 200) {
        throw Exception('Error ${response.statusCode}: ${response.bodyString}');
      }

      final pdfBytes = await QenginePdfService.generate(
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
              _sectionTitle('Reporte QEngine'),

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

              // Project selector
              _loadingProjects
                  ? const Center(
                      child: CircularProgressIndicator(color: _kPrimary))
                  : DropdownButtonFormField<String>(
                      value: _selectedProjectId,
                      decoration: _inputDecoration('Proyecto QEngine'),
                      dropdownColor: _kSurface,
                      style: const TextStyle(color: Colors.white),
                      items: _projects.map((p) {
                        final id = p['id']?.toString() ?? '';
                        final name = p['name']?.toString() ?? id;
                        return DropdownMenuItem(value: id, child: Text(name));
                      }).toList(),
                      onChanged: (v) {
                        setState(() => _selectedProjectId = v);
                        if (v != null) _loadSuites(v);
                      },
                      validator: (v) =>
                          v == null ? 'Selecciona un proyecto' : null,
                    ),
              _gap(),

              // Suite selector
              if (_loadingSuites)
                const Center(
                    child: CircularProgressIndicator(color: _kPrimary))
              else if (_suites.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedSuiteId,
                  decoration: _inputDecoration('Test Suite'),
                  dropdownColor: _kSurface,
                  style: const TextStyle(color: Colors.white),
                  items: _suites.map((s) {
                    final id = s['id']?.toString() ?? '';
                    final name = s['name']?.toString() ?? id;
                    return DropdownMenuItem(value: id, child: Text(name));
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedSuiteId = v;
                      if (v != null) _testRunIdCtrl.text = v;
                    });
                  },
                ),
              _gap(),

              // Test run ID
              TextFormField(
                controller: _testRunIdCtrl,
                decoration: _inputDecoration('Test Run ID'),
                style: const TextStyle(color: Colors.white),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              _gap(24),

              // Normative fields
              _sectionTitle('Datos normativos (opcionales)'),

              // Environment
              DropdownButtonFormField<String>(
                value: _environment,
                decoration: _inputDecoration('Ambiente'),
                dropdownColor: _kSurface,
                style: const TextStyle(color: Colors.white),
                items: ['QA', 'UAT', 'Staging', 'Producción']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _environment = v ?? 'QA'),
              ),
              _gap(),

              _buildOptionalField(_ipCtrl, 'IP Address'),
              _buildOptionalField(_analystaCtrl, 'Analista QA'),
              _buildOptionalField(_areaCtrl, 'Área'),
              _buildOptionalField(_moduloCtrl, 'Módulo'),
              _buildOptionalField(_solicitanteCtrl, 'Solicitante'),
              _buildOptionalField(_puestoSolicitanteCtrl, 'Puesto solicitante'),
              _buildOptionalField(_developerCtrl, 'Desarrollador'),
              _buildOptionalField(_techLeadCtrl, 'Tech Lead'),
              _buildOptionalField(_puestoTechLeadCtrl, 'Puesto Tech Lead'),
              _buildOptionalField(_coordinadorCtrl, 'Coordinador'),
              _buildOptionalField(_huCtrl, 'HU Entregable'),
              _buildOptionalField(_zohoProjectCtrl, 'Nombre Zoho Projects'),

              // Extract images checkbox
              _gap(8),
              Row(
                children: [
                  Checkbox(
                    value: _extractImages,
                    onChanged: (v) =>
                        setState(() => _extractImages = v ?? true),
                    activeColor: _kPrimary,
                    checkColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  const Text(
                    'Extraer imágenes (Selenium)',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
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
                    : const Text('Generar PDF QEngine',
                        style: TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionalField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        decoration: _inputDecoration(label),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

