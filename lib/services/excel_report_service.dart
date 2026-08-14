import 'dart:io' as io;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

class ExcelReportService {
  static Future<void> downloadExcel(List<int> bytes, String fileName) async {
    if (kIsWeb) {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      try {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/$fileName';
        final file = io.File(path);
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(
          ShareParams(files: [XFile(path)], text: 'Excel Report: $fileName'),
        );
      } catch (e) {
        debugPrint('Error saving Excel: $e');
      }
    }
  }

  static Future<void> generateStudentsExcelByYear(
      List<QueryDocumentSnapshot> docs) async {
    final excel = Excel.createExcel();

    // FIX: Remove the auto-created default sheet cleanly before adding ours.
    // Previously we were renaming it, which caused ghost sheets.
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.delete(defaultSheet);
    }

    final yearLevels = [
      '1st Year',
      '2nd Year',
      '3rd Year',
      '4th Year',
      'Other',
    ];

    // Filter out archived students upfront
    final activeDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['is_archived'] != true;
    }).toList();

    for (var y in yearLevels) {
      final sheetObject = excel[y];

      // Header row
      sheetObject.appendRow([
        TextCellValue('Student ID'),
        TextCellValue('Name'),
        TextCellValue('Course'),
        TextCellValue('Year Level'),
        TextCellValue('Email'),
      ]);

      var filteredDocs = activeDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final year = (data['year_level'] ?? '').toString();
        if (y == 'Other') {
          return !['1st Year', '2nd Year', '3rd Year', '4th Year']
              .contains(year);
        }
        return year == y;
      }).toList();

      // Sort alphabetically by name
      filteredDocs.sort((a, b) {
        final dataA = a.data() as Map<String, dynamic>;
        final dataB = b.data() as Map<String, dynamic>;
        final nameA = (dataA['name'] ?? '').toString().toLowerCase();
        final nameB = (dataB['name'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });

      for (var doc in filteredDocs) {
        final data = doc.data() as Map<String, dynamic>;
        sheetObject.appendRow([
          TextCellValue((data['student_id'] ?? '').toString()),
          TextCellValue((data['name'] ?? '').toString()),
          TextCellValue((data['course'] ?? '').toString()),
          TextCellValue((data['year_level'] ?? '').toString()),
          TextCellValue((data['email'] ?? '').toString()),
        ]);
      }
    }

    // Save and download
    final fileBytes = excel.save();
    if (fileBytes != null) {
      await downloadExcel(fileBytes, 'List_of_Students.xlsx');
    }
  }
}
