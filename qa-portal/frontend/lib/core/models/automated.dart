class AutomatedSuiteSummary {
  final String id;
  final String projectId;
  final String name;
  final String? description;
  final String? createdAt;
  final int testCount;
  final String? lastRunStatus;
  final String? lastRunAt;
  final int lastRunPassed;
  final int lastRunTotal;

  const AutomatedSuiteSummary({
    required this.id,
    required this.projectId,
    required this.name,
    this.description,
    this.createdAt,
    this.testCount = 0,
    this.lastRunStatus,
    this.lastRunAt,
    this.lastRunPassed = 0,
    this.lastRunTotal = 0,
  });

  factory AutomatedSuiteSummary.fromJson(Map<String, dynamic> json) {
    return AutomatedSuiteSummary(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: json['created_at'] as String?,
      testCount: json['test_count'] as int? ?? 0,
      lastRunStatus: json['last_run_status'] as String?,
      lastRunAt: json['last_run_at'] as String?,
      lastRunPassed: json['last_run_passed'] as int? ?? 0,
      lastRunTotal: json['last_run_total'] as int? ?? 0,
    );
  }
}

class AutomatedTestCaseModel {
  final String id;
  final String suiteId;
  final String name;
  final String? description;
  final String? sourceTestCaseId;
  final String? scriptCode;
  final String? targetUrl;
  final int order;
  final bool isActive;
  final String? createdAt;

  const AutomatedTestCaseModel({
    required this.id,
    required this.suiteId,
    required this.name,
    this.description,
    this.sourceTestCaseId,
    this.scriptCode,
    this.targetUrl,
    this.order = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory AutomatedTestCaseModel.fromJson(Map<String, dynamic> json) {
    return AutomatedTestCaseModel(
      id: json['id'] as String,
      suiteId: json['suite_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      sourceTestCaseId: json['source_test_case_id'] as String?,
      scriptCode: json['script_code'] as String?,
      targetUrl: json['target_url'] as String?,
      order: json['order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String?,
    );
  }
}

class AutomatedRunSummary {
  final String id;
  final String suiteId;
  final String status;
  final String? environment;
  final String? version;
  final String? startedAt;
  final String? finishedAt;
  final int total;
  final int passed;
  final int failed;
  final int error;
  final int skipped;

  const AutomatedRunSummary({
    required this.id,
    required this.suiteId,
    required this.status,
    this.environment,
    this.version,
    this.startedAt,
    this.finishedAt,
    this.total = 0,
    this.passed = 0,
    this.failed = 0,
    this.error = 0,
    this.skipped = 0,
  });

  factory AutomatedRunSummary.fromJson(Map<String, dynamic> json) {
    return AutomatedRunSummary(
      id: json['id'] as String,
      suiteId: json['suite_id'] as String,
      status: json['status'] as String,
      environment: json['environment'] as String?,
      version: json['version'] as String?,
      startedAt: json['started_at'] as String?,
      finishedAt: json['finished_at'] as String?,
      total: json['total'] as int? ?? 0,
      passed: json['passed'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      error: json['error'] as int? ?? 0,
      skipped: json['skipped'] as int? ?? 0,
    );
  }
}

class AutomatedRunResult {
  final String id;
  final String runId;
  final String automatedTestCaseId;
  final String testName;
  final String status;
  final int? durationMs;
  final String? errorMessage;
  final String? consoleLog;
  final List<String> screenshots;
  final String? executedAt;

  const AutomatedRunResult({
    required this.id,
    required this.runId,
    required this.automatedTestCaseId,
    required this.testName,
    required this.status,
    this.durationMs,
    this.errorMessage,
    this.consoleLog,
    this.screenshots = const [],
    this.executedAt,
  });

  factory AutomatedRunResult.fromJson(Map<String, dynamic> json) {
    return AutomatedRunResult(
      id: json['id'] as String,
      runId: json['run_id'] as String,
      automatedTestCaseId: json['automated_test_case_id'] as String,
      testName: json['test_name'] as String? ?? '',
      status: json['status'] as String,
      durationMs: json['duration_ms'] as int?,
      errorMessage: json['error_message'] as String?,
      consoleLog: json['console_log'] as String?,
      screenshots: (json['screenshots'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      executedAt: json['executed_at'] as String?,
    );
  }
}

class RunStatusModel {
  final String id;
  final String status;
  final int total;
  final int completed;
  final int passed;
  final int failed;
  final int error;

  const RunStatusModel({
    required this.id,
    required this.status,
    this.total = 0,
    this.completed = 0,
    this.passed = 0,
    this.failed = 0,
    this.error = 0,
  });

  factory RunStatusModel.fromJson(Map<String, dynamic> json) {
    return RunStatusModel(
      id: json['id'] as String,
      status: json['status'] as String,
      total: json['total'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
      passed: json['passed'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      error: json['error'] as int? ?? 0,
    );
  }
}
