class AppProject {
  final String id;
  final String name;
  final String description;
  final bool isActive;
  final String? createdAt;

  const AppProject({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    this.createdAt,
  });

  factory AppProject.fromJson(Map<String, dynamic> json) {
    return AppProject(
      id: json['id'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt,
    };
  }
}

class AppModule {
  final String id;
  final String projectId;
  final String name;
  final String? description;
  final int order;
  final String? createdAt;

  const AppModule({
    required this.id,
    required this.projectId,
    required this.name,
    this.description,
    required this.order,
    this.createdAt,
  });

  factory AppModule.fromJson(Map<String, dynamic> json) {
    return AppModule(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      order: json['order'] as int,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'description': description,
      'order': order,
      'created_at': createdAt,
    };
  }
}

class TestCase {
  final String id;
  final String moduleId;
  final String title;
  final String? preconditions;
  final String? postconditions;
  final String status;
  final List<TestStep> steps;
  final String? createdAt;

  const TestCase({
    required this.id,
    required this.moduleId,
    required this.title,
    this.preconditions,
    this.postconditions,
    required this.status,
    required this.steps,
    this.createdAt,
  });

  factory TestCase.fromJson(Map<String, dynamic> json) {
    return TestCase(
      id: json['id'] as String,
      moduleId: json['module_id'] as String,
      title: json['title'] as String,
      preconditions: json['preconditions'] as String?,
      postconditions: json['postconditions'] as String?,
      status: json['status'] as String,
      steps: (json['steps'] as List<dynamic>? ?? [])
          .map((s) => TestStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'module_id': moduleId,
      'title': title,
      'preconditions': preconditions,
      'postconditions': postconditions,
      'status': status,
      'steps': steps.map((s) => s.toJson()).toList(),
      'created_at': createdAt,
    };
  }
}

class TestStep {
  final String id;
  final String testCaseId;
  final int order;
  final String action;
  final String? testData;
  final String expectedResult;

  const TestStep({
    required this.id,
    required this.testCaseId,
    required this.order,
    required this.action,
    this.testData,
    required this.expectedResult,
  });

  factory TestStep.fromJson(Map<String, dynamic> json) {
    return TestStep(
      id: json['id'] as String,
      testCaseId: json['test_case_id'] as String,
      order: json['order'] as int,
      action: json['action'] as String,
      testData: json['test_data'] as String?,
      expectedResult: json['expected_result'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'test_case_id': testCaseId,
      'order': order,
      'action': action,
      'test_data': testData,
      'expected_result': expectedResult,
    };
  }
}
