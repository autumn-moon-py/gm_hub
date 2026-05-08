import 'dart:async' as async_lib;
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/project_model.dart';

class ProjectFileService {
  static const String projectFileExtension = 'gmh';
  static const String projectFileDotExtension = '.gmh';
  static const String defaultProjectFileName =
      'untitled$projectFileDotExtension';
  static const String legacyProjectFileName = 'project.json';

  async_lib.Future<ProjectModel?> loadProject(String projectFilePath) async {
    final file = File(projectFilePath);
    if (!file.existsSync()) {
      return null;
    }
    final bytes = await file.readAsBytes();
    final decoded = _decodeProjectJson(bytes);
    if (decoded is! Map) {
      return null;
    }
    return ProjectModel.fromJson(decoded.cast<String, dynamic>());
  }

  async_lib.Future<void> saveProject(
    String projectFilePath,
    ProjectModel project,
  ) async {
    await _ensureSaveParentExists(projectFilePath);
    await _writeProjectFile(projectFilePath, project);
  }

  void saveProjectSync(
    String projectFilePath,
    ProjectModel project,
  ) {
    _ensureSaveParentExistsSync(projectFilePath);
    _writeProjectFileSync(projectFilePath, project);
  }

  async_lib.Future<void> _ensureSaveParentExists(String projectFilePath) async {
    final file = File(projectFilePath);
    final parent = file.parent;
    if (!parent.existsSync()) {
      await parent.create(recursive: true);
    }
  }

  void _ensureSaveParentExistsSync(String projectFilePath) {
    final file = File(projectFilePath);
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
  }

  async_lib.Future<void> _writeProjectFile(
    String projectFilePath,
    ProjectModel project,
  ) async {
    final file = File(projectFilePath);
    final jsonText = project.toPrettyJson();
    final ext = p.extension(projectFilePath).toLowerCase();
    if (ext == '.json') {
      await file.writeAsString(jsonText);
      return;
    }
    final compressed = gzip.encode(utf8.encode(jsonText));
    await file.writeAsBytes(compressed, flush: true);
  }

  void _writeProjectFileSync(
    String projectFilePath,
    ProjectModel project,
  ) {
    final file = File(projectFilePath);
    final jsonText = project.toPrettyJson();
    final ext = p.extension(projectFilePath).toLowerCase();
    if (ext == '.json') {
      file.writeAsStringSync(jsonText, flush: true);
      return;
    }
    final compressed = gzip.encode(utf8.encode(jsonText));
    file.writeAsBytesSync(compressed, flush: true);
  }

  async_lib.Future<String> importImageFile(String sourcePath) async {
    return p.normalize(sourcePath);
  }

  async_lib.Future<String> importAudioFile(String sourcePath) async {
    return p.normalize(sourcePath);
  }

  dynamic _decodeProjectJson(List<int> rawBytes) {
    try {
      final uncompressed = gzip.decode(rawBytes);
      final text = utf8.decode(uncompressed);
      return jsonDecode(text);
    } catch (_) {
      // Ignore and fallback to plain JSON decoding.
    }
    try {
      final text = utf8.decode(rawBytes);
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }
}
