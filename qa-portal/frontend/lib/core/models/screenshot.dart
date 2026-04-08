import '../api/api_client.dart' show baseUrl;

class AppScreenshot {
  final String id;
  final String executionResultId;
  final String fileName;
  final String filePath;
  final int order;
  final String? takenAt;

  const AppScreenshot({
    required this.id,
    required this.executionResultId,
    required this.fileName,
    required this.filePath,
    required this.order,
    this.takenAt,
  });

  String get url => '$baseUrl/qa/screenshots/file/$fileName';

  factory AppScreenshot.fromJson(Map<String, dynamic> json) {
    return AppScreenshot(
      id: json['id'] as String,
      executionResultId: json['execution_result_id'] as String,
      fileName: json['file_name'] as String,
      filePath: json['file_path'] as String,
      order: json['order'] as int,
      takenAt: json['taken_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'execution_result_id': executionResultId,
      'file_name': fileName,
      'file_path': filePath,
      'order': order,
      'taken_at': takenAt,
    };
  }
}
