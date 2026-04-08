class TestExecutionSummary {
  final String id;
  final String name;
  final String? version;
  final String environment;
  final String? startedAt;
  final String? finishedAt;
  final int total;
  final int passed;
  final int failed;
  final int blocked;
  final int notApplicable;
  final int pending;

  const TestExecutionSummary({
    required this.id,
    required this.name,
    this.version,
    required this.environment,
    this.startedAt,
    this.finishedAt,
    required this.total,
    required this.passed,
    required this.failed,
    required this.blocked,
    required this.notApplicable,
    required this.pending,
  });

  factory TestExecutionSummary.fromJson(Map<String, dynamic> json) {
    return TestExecutionSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String?,
      environment: json['environment'] as String,
      startedAt: json['started_at'] as String?,
      finishedAt: json['finished_at'] as String?,
      total: json['total'] as int,
      passed: json['passed'] as int,
      failed: json['failed'] as int,
      blocked: json['blocked'] as int,
      notApplicable: json['not_applicable'] as int,
      pending: json['pending'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'environment': environment,
      'started_at': startedAt,
      'finished_at': finishedAt,
      'total': total,
      'passed': passed,
      'failed': failed,
      'blocked': blocked,
      'not_applicable': notApplicable,
      'pending': pending,
    };
  }
}

class TestExecution {
  final String id;
  final String projectId;
  final String name;
  final String? version;
  final String environment;
  final String? startedAt;
  final String? finishedAt;
  final List<ExecutionResult> results;

  const TestExecution({
    required this.id,
    required this.projectId,
    required this.name,
    this.version,
    required this.environment,
    this.startedAt,
    this.finishedAt,
    required this.results,
  });

  factory TestExecution.fromJson(Map<String, dynamic> json) {
    return TestExecution(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      name: json['name'] as String,
      version: json['version'] as String?,
      environment: (json['environment'] as String?) ?? '',
      startedAt: json['started_at'] as String?,
      finishedAt: json['finished_at'] as String?,
      results: (json['results'] as List<dynamic>? ?? [])
          .map((r) => ExecutionResult.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'version': version,
      'environment': environment,
      'started_at': startedAt,
      'finished_at': finishedAt,
      'results': results.map((r) => r.toJson()).toList(),
    };
  }
}

class ExecutionResult {
  final String id;
  final String executionId;
  final String testCaseId;
  final String? assignedTo;
  final String status;
  final String? notes;
  final String? route;
  final String? executedAt;
  final int? durationSeconds;
  final Map<String, dynamic>? testCase;
  final List<dynamic>? screenshots;

  const ExecutionResult({
    required this.id,
    required this.executionId,
    required this.testCaseId,
    this.assignedTo,
    required this.status,
    this.notes,
    this.route,
    this.executedAt,
    this.durationSeconds,
    this.testCase,
    this.screenshots,
  });

  factory ExecutionResult.fromJson(Map<String, dynamic> json) {
    return ExecutionResult(
      id: json['id'] as String,
      executionId: json['execution_id'] as String,
      testCaseId: json['test_case_id'] as String,
      assignedTo: json['assigned_to'] as String?,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      route: json['route'] as String?,
      executedAt: json['executed_at'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      testCase: json['test_case'] as Map<String, dynamic>?,
      screenshots: json['screenshots'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'execution_id': executionId,
      'test_case_id': testCaseId,
      'assigned_to': assignedTo,
      'status': status,
      'notes': notes,
      'route': route,
      'executed_at': executedAt,
      'duration_seconds': durationSeconds,
      'test_case': testCase,
      'screenshots': screenshots,
    };
  }
}
