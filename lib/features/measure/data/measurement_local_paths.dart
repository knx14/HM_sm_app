import 'dart:io';

import 'package:path_provider/path_provider.dart';

class MeasurementLocalPaths {
  static const String pendingUploadsFileName = 'pending_uploads.json';

  static Future<Directory> _baseDir() async {
    return getApplicationDocumentsDirectory();
  }

  static Future<File> csvFile(String fileBase) async {
    final dir = await _baseDir();
    return File('${dir.path}/$fileBase.csv');
  }

  static Future<File> jsonFile(String fileBase) async {
    final dir = await _baseDir();
    return File('${dir.path}/$fileBase.json');
  }

  static Future<File> pendingUploadsFile() async {
    final dir = await _baseDir();
    return File('${dir.path}/$pendingUploadsFileName');
  }
}
