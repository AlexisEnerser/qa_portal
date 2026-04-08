class AppBug {
  final String id;
  final String executionResultId;
  final String title;
  final String description;
  final String severity;
  final String status;
  final String? stepsToReproduce;
  final String? createdAt;

  const AppBug({
    required this.id,
    required this.executionResultId,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    this.stepsToReproduce,
    this.createdAt,
  });

  factory AppBug.fromJson(Map<String, dynamic> json) {
    return AppBug(
      id: json['id'] as String,
      executionResultId: json['execution_result_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      severity: json['severity'] as String,
      status: json['status'] as String,
      stepsToReproduce: json['steps_to_reproduce'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'execution_result_id': executionResultId,
      'title': title,
      'description': description,
      'severity': severity,
      'status': status,
      'steps_to_reproduce': stepsToReproduce,
      'created_at': createdAt,
    };
  }
}
