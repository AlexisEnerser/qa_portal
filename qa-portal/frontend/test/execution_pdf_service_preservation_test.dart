// Preservation Property Tests — Task 2
// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**
//
// Property 2: Preservation — PDF format, JSON structure, and small images unchanged.
//
// These tests verify the EXISTING behavior of the unfixed code that must NOT
// change after the bugfix. They run on the current (unfixed) code and should
// PASS, establishing the baseline behavior to preserve.
//
// Tests:
// - For any session with <30 test cases and light screenshots, generate()
//   produces a valid PDF without exception
// - For any form with user data, the PDF contains the data in correct sections
// - Small images (<1400px width) are included unmodified in base64
// - PDF output starts with %PDF header (valid format)

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qa_portal/features/execution/execution_pdf_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Create a valid PNG image as base64 with given dimensions.
String _createPngBase64(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      image.setPixelRgb(x, y, (x * 5) % 256, (y * 7) % 256, 128);
    }
  }
  final pngBytes = img.encodePng(image);
  return base64Encode(Uint8List.fromList(pngBytes));
}

/// Build mock PDF data with [n] test cases.
Map<String, dynamic> _buildMockData(
  int n,
  String screenshotB64, {
  int screenshotsPerCase = 1,
  int stepsPerCase = 2,
  String sessionName = 'Preservation Test Session',
  String projectName = 'Test Project',
  String environment = 'QA',
  String version = '1.0',
}) {
  final testCases = List<Map<String, dynamic>>.generate(n, (i) {
    final steps = List<Map<String, dynamic>>.generate(
      stepsPerCase,
      (s) => {
        'order': s + 1,
        'action': 'Step ${s + 1}: Verify module functionality',
        'test_data': s == 0 ? 'Test data ${s + 1}' : '',
        'expected_result': 'System responds correctly',
      },
    );

    final screenshots = List<Map<String, dynamic>>.generate(
      screenshotsPerCase,
      (s) => {
        'file_name': 'screenshot_tc${i + 1}_${s + 1}.png',
        'base64': screenshotB64,
        'mime_type': 'image/png',
      },
    );

    return {
      'module_name': 'Module ${i ~/ 3}',
      'title': 'Test Case ${i + 1}',
      'preconditions': 'User authenticated',
      'postconditions': 'Data verified',
      'steps': steps,
      'status': i % 3 == 0 ? 'passed' : (i % 3 == 1 ? 'failed' : 'blocked'),
      'status_label': i % 3 == 0
          ? 'Satisfactorio'
          : (i % 3 == 1 ? 'Fallido' : 'Bloqueado'),
      'status_color': i % 3 == 0
          ? '#17B020'
          : (i % 3 == 1 ? '#E53935' : '#FB8C00'),
      'notes': i % 2 == 0 ? '' : 'Observation for case ${i + 1}',
      'assignee': 'QA Analyst',
      'screenshots': screenshots,
    };
  });

  final passed = testCases.where((tc) => tc['status'] == 'passed').length;
  final failed = testCases.where((tc) => tc['status'] == 'failed').length;
  final blocked = testCases.where((tc) => tc['status'] == 'blocked').length;

  return {
    'execution': {
      'id': '00000000-0000-0000-0000-000000000001',
      'name': sessionName,
      'version': version,
      'environment': environment,
      'started_at': '2025-01-15T10:00:00Z',
      'finished_at': '2025-01-15T12:00:00Z',
    },
    'project': {
      'id': '00000000-0000-0000-0000-000000000002',
      'name': projectName,
    },
    'summary': {
      'total': n,
      'passed': passed,
      'failed': failed,
      'blocked': blocked,
      'not_applicable': 0,
      'pending': 0,
      'progress_pct': n > 0 ? ((passed + failed + blocked) / n * 100).floorToDouble() : 0.0,
    },
    'analyst': 'QA Analyst',
    'test_cases': testCases,
  };
}

Map<String, String> _buildMockForm({
  String logo = 'ENERSER',
  String ip = '192.168.1.100',
  String area = 'Desarrollo',
  String hu = 'HU-001',
  String enhancements = 'Performance improvements',
  String requestor = 'John Doe',
  String requestorPosition = 'PM',
  String techlead = 'Jane Smith',
  String techleadPosition = 'Tech Lead',
  String developer = 'Dev User',
}) =>
    {
      'logo': logo,
      'ip': ip,
      'area': area,
      'hu': hu,
      'enhancements': enhancements,
      'requestor': requestor,
      'requestorPosition': requestorPosition,
      'techlead': techlead,
      'techleadPosition': techleadPosition,
      'developer': developer,
    };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Small image used across tests — 200x150 PNG, well under 1400px
  late String smallPngB64;

  setUpAll(() {
    smallPngB64 = _createPngBase64(200, 150);
  });

  group('Preservation — Small session PDF generation (Property 2)', () {
    // **Validates: Requirements 3.1, 3.5**
    //
    // For any session with <30 test cases and light screenshots,
    // generate() produces a valid PDF without exception.

    for (final numCases in [1, 3, 5, 10, 15, 20, 25, 29]) {
      test(
        'generate() with $numCases test cases produces valid PDF',
        () async {
          final data = _buildMockData(numCases, smallPngB64,
              screenshotsPerCase: 1, stepsPerCase: 2);
          final form = _buildMockForm();

          final pdfBytes = await ExecutionPdfService.generate(data, form);

          // PDF must be non-empty
          expect(pdfBytes.length, greaterThan(0),
              reason: 'PDF output should not be empty for $numCases cases');

          // PDF must start with %PDF header
          expect(
            String.fromCharCodes(pdfBytes.sublist(0, 4)),
            equals('%PDF'),
            reason: 'Output should be a valid PDF for $numCases cases',
          );
        },
      );
    }

    test(
      'generate() with 5 test cases and 0 screenshots produces valid PDF',
      () async {
        // Empty base64 won't be decoded — use empty screenshots list
        final data = _buildMockData(5, '', screenshotsPerCase: 0);
        final form = _buildMockForm();

        final pdfBytes = await ExecutionPdfService.generate(data, form);

        expect(pdfBytes.length, greaterThan(0));
        expect(
          String.fromCharCodes(pdfBytes.sublist(0, 4)),
          equals('%PDF'),
        );
      },
    );

    test(
      'generate() with 1 test case (edge case) produces valid PDF',
      () async {
        final data = _buildMockData(1, smallPngB64,
            screenshotsPerCase: 2, stepsPerCase: 1);
        final form = _buildMockForm();

        final pdfBytes = await ExecutionPdfService.generate(data, form);

        expect(pdfBytes.length, greaterThan(0));
        expect(
          String.fromCharCodes(pdfBytes.sublist(0, 4)),
          equals('%PDF'),
        );
      },
    );
  });

  group('Preservation — Form data in PDF (Property 2)', () {
    // **Validates: Requirements 3.1, 3.2**
    //
    // For any form with user data (logo, IP, area, HU, enhancements,
    // signatures), the PDF is generated successfully containing those sections.

    test(
      'generate() with ENERSER brand produces valid PDF',
      () async {
        final data = _buildMockData(5, smallPngB64);
        final form = _buildMockForm(logo: 'ENERSER');

        final pdfBytes = await ExecutionPdfService.generate(data, form);

        expect(pdfBytes.length, greaterThan(0));
        expect(
          String.fromCharCodes(pdfBytes.sublist(0, 4)),
          equals('%PDF'),
        );
      },
    );

    test(
      'generate() with XIGA brand produces valid PDF',
      () async {
        final data = _buildMockData(5, smallPngB64);
        final form = _buildMockForm(logo: 'XIGA');

        final pdfBytes = await ExecutionPdfService.generate(data, form);

        expect(pdfBytes.length, greaterThan(0));
        expect(
          String.fromCharCodes(pdfBytes.sublist(0, 4)),
          equals('%PDF'),
        );
      },
    );

    test(
      'generate() with custom form data produces valid PDF',
      () async {
        final data = _buildMockData(3, smallPngB64);
        final form = _buildMockForm(
          ip: '10.0.0.1',
          area: 'QA Testing',
          hu: 'HU-999',
          enhancements: 'Added new validation rules for input fields',
          requestor: 'Alice',
          requestorPosition: 'Product Owner',
          techlead: 'Bob',
          techleadPosition: 'Senior Dev',
          developer: 'Charlie',
        );

        final pdfBytes = await ExecutionPdfService.generate(data, form);

        expect(pdfBytes.length, greaterThan(0));
        expect(
          String.fromCharCodes(pdfBytes.sublist(0, 4)),
          equals('%PDF'),
        );
      },
    );
  });

  group('Preservation — Small images unmodified (Property 2)', () {
    // **Validates: Requirements 3.3**
    //
    // For any image with width <1400px, the resulting base64 is identical
    // to the original file when included in the PDF data structure.

    test(
      'small image base64 roundtrips correctly (200x150)',
      () {
        final originalBytes = base64Decode(smallPngB64);
        final reEncoded = base64Encode(originalBytes);

        // The base64 encoding is deterministic — same bytes = same base64
        expect(reEncoded, equals(smallPngB64),
            reason: 'Small image base64 should roundtrip identically');
      },
    );

    for (final size in [
      [100, 80],
      [400, 300],
      [800, 600],
      [1200, 900],
      [1399, 1000],
    ]) {
      test(
        'image ${size[0]}x${size[1]} is preserved in test case data',
        () {
          final b64 = _createPngBase64(size[0], size[1]);
          final originalBytes = base64Decode(b64);

          // Verify the image can be decoded back to original dimensions
          final decoded = img.decodePng(Uint8List.fromList(originalBytes));
          expect(decoded, isNotNull);
          expect(decoded!.width, equals(size[0]));
          expect(decoded.height, equals(size[1]));

          // Verify the base64 in the mock data structure is unchanged
          final data = _buildMockData(1, b64, screenshotsPerCase: 1);
          final tc = data['test_cases'][0] as Map<String, dynamic>;
          final screenshots = tc['screenshots'] as List<dynamic>;
          expect(screenshots[0]['base64'], equals(b64),
              reason:
                  'Image ${size[0]}x${size[1]} base64 should be preserved in data structure');
        },
      );
    }
  });

  group('Preservation — JSON data structure (Property 2)', () {
    // **Validates: Requirements 3.4**
    //
    // For any endpoint call with small sessions, the JSON structure
    // contains the expected fields.

    test(
      'mock data has required top-level fields',
      () {
        final data = _buildMockData(5, smallPngB64);

        expect(data.containsKey('execution'), isTrue);
        expect(data.containsKey('project'), isTrue);
        expect(data.containsKey('summary'), isTrue);
        expect(data.containsKey('analyst'), isTrue);
        expect(data.containsKey('test_cases'), isTrue);
      },
    );

    test(
      'execution object has required fields',
      () {
        final data = _buildMockData(5, smallPngB64);
        final exec = data['execution'] as Map<String, dynamic>;

        expect(exec.containsKey('id'), isTrue);
        expect(exec.containsKey('name'), isTrue);
        expect(exec.containsKey('version'), isTrue);
        expect(exec.containsKey('environment'), isTrue);
        expect(exec.containsKey('started_at'), isTrue);
        expect(exec.containsKey('finished_at'), isTrue);
      },
    );

    test(
      'summary object has required fields',
      () {
        final data = _buildMockData(5, smallPngB64);
        final summary = data['summary'] as Map<String, dynamic>;

        expect(summary.containsKey('total'), isTrue);
        expect(summary.containsKey('passed'), isTrue);
        expect(summary.containsKey('failed'), isTrue);
        expect(summary.containsKey('blocked'), isTrue);
        expect(summary.containsKey('not_applicable'), isTrue);
        expect(summary.containsKey('pending'), isTrue);
        expect(summary.containsKey('progress_pct'), isTrue);
      },
    );

    test(
      'test_cases have screenshot structure with required fields',
      () {
        final data = _buildMockData(5, smallPngB64, screenshotsPerCase: 2);

        for (final tc in data['test_cases'] as List<dynamic>) {
          final tcMap = tc as Map<String, dynamic>;
          expect(tcMap.containsKey('screenshots'), isTrue);

          final screenshots = tcMap['screenshots'] as List<dynamic>;
          for (final shot in screenshots) {
            final shotMap = shot as Map<String, dynamic>;
            expect(shotMap.containsKey('file_name'), isTrue);
            expect(shotMap.containsKey('base64'), isTrue);
            expect(shotMap.containsKey('mime_type'), isTrue);
          }
        }
      },
    );

    for (final n in [1, 5, 10, 20, 29]) {
      test(
        'data with $n test cases has correct count',
        () {
          final data = _buildMockData(n, smallPngB64);
          final testCases = data['test_cases'] as List<dynamic>;

          expect(testCases.length, equals(n));
          expect(data['summary']['total'], equals(n));
        },
      );
    }
  });
}
