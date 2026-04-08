// Bug Condition Exploration Test — Task 1
// **Validates: Requirements 1.1**
//
// Bug A: TooManyPages
// The dart pdf library throws TooManyPagesException when a SINGLE MultiPage
// widget generates more than 20 pages. The unfixed code creates a separate
// pw.MultiPage per test case. When a test case has many/large screenshots,
// its individual MultiPage can exceed the 20-page limit.
//
// Additionally, the structural issue of creating N+2 MultiPage objects
// (instead of 1) is wasteful and causes failures with real-world data.
//
// EXPECTED: This test FAILS on unfixed code (confirming the bug exists).

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qa_portal/features/execution/execution_pdf_service.dart';

/// Create a valid PNG image of given size as base64.
String _createPngBase64(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      image.setPixelRgb(
        x, y,
        (x * 7 + y * 3) % 256,
        (x * 3 + y * 11) % 256,
        (x * 13 + y * 5) % 256,
      );
    }
  }
  final pngBytes = img.encodePng(image);
  return base64Encode(Uint8List.fromList(pngBytes));
}

/// Build mock data with [n] test cases.
Map<String, dynamic> _buildMockData(
  int n,
  String screenshotB64, {
  int screenshotsPerCase = 1,
  int stepsPerCase = 3,
}) {
  final testCases = List<Map<String, dynamic>>.generate(n, (i) {
    final steps = List<Map<String, dynamic>>.generate(
      stepsPerCase,
      (s) => {
        'order': s + 1,
        'action': 'Paso ${s + 1}: Verificar funcionalidad del módulo',
        'test_data': 'Datos de prueba ${s + 1}',
        'expected_result': 'El sistema responde correctamente',
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
      'module_name': 'Module ${i ~/ 5}',
      'title': 'Test Case ${i + 1}',
      'preconditions': 'Usuario autenticado',
      'postconditions': 'Datos verificados',
      'steps': steps,
      'status': 'passed',
      'status_label': 'Satisfactorio',
      'status_color': '#17B020',
      'notes': '',
      'assignee': 'QA Analyst',
      'screenshots': screenshots,
    };
  });

  return {
    'execution': {
      'id': '00000000-0000-0000-0000-000000000001',
      'name': 'Bug Exploration Session',
      'version': '1.0',
      'environment': 'QA',
      'started_at': '2025-01-15T10:00:00Z',
      'finished_at': '2025-01-15T12:00:00Z',
    },
    'project': {
      'id': '00000000-0000-0000-0000-000000000002',
      'name': 'Test Project',
    },
    'summary': {
      'total': n,
      'passed': n,
      'failed': 0,
      'blocked': 0,
      'not_applicable': 0,
      'pending': 0,
      'progress_pct': 100.0,
    },
    'analyst': 'QA Analyst',
    'test_cases': testCases,
  };
}

Map<String, String> _buildMockForm() => {
  'logo': 'ENERSER',
  'ip': '192.168.1.100',
  'area': 'Desarrollo',
  'hu': 'HU-001',
  'enhancements': 'Mejoras de rendimiento',
  'requestor': 'John Doe',
  'requestorPosition': 'PM',
  'techlead': 'Jane Smith',
  'techleadPosition': 'Tech Lead',
  'developer': 'Dev User',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bug Exploration — TooManyPages (Property 1: Bug Condition)', () {
    // The pdf library throws TooManyPagesException when a single MultiPage
    // generates >20 pages. With the unfixed code, each test case gets its
    // own MultiPage. A test case with many large screenshots can exceed
    // this limit within its own MultiPage.
    //
    // We create test cases with enough large screenshots to trigger this.
    // A 550px wide image at full width on a letter page takes ~1 page.
    // With 25 screenshots per test case, a single MultiPage exceeds 20 pages.

    test(
      'generate() with test case having 25 large screenshots should not '
      'throw TooManyPages — EXPECTED TO FAIL on unfixed code',
      () async {
        // 550x400 image — fills most of a letter page width
        final largePng = _createPngBase64(550, 400);

        // 5 test cases, each with 25 screenshots
        // On unfixed code: each test case gets its own MultiPage
        // 25 screenshots × ~1 page each = ~25 pages per MultiPage > 20 limit
        final data = _buildMockData(5, largePng,
            screenshotsPerCase: 25, stepsPerCase: 2);
        final form = _buildMockForm();

        final pdfBytes = await ExecutionPdfService.generate(data, form);

        expect(pdfBytes.length, greaterThan(0),
            reason: 'PDF should be generated without TooManyPages');
        expect(
          String.fromCharCodes(pdfBytes.sublist(0, 4)),
          equals('%PDF'),
          reason: 'Output should be a valid PDF',
        );
      },
    );

    test(
      'generate() with 35 test cases (3 screenshots each) should produce '
      'valid PDF — EXPECTED TO FAIL on unfixed code with large content',
      () async {
        // 500x350 image
        final mediumPng = _createPngBase64(500, 350);

        // 35 test cases with 3 screenshots each
        // Unfixed code creates 37 MultiPage objects
        final data = _buildMockData(35, mediumPng,
            screenshotsPerCase: 3, stepsPerCase: 5);
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
}
