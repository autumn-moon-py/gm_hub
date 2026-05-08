import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor_plugins/appflowy_editor_plugins.dart';
import 'package:markdown/markdown.dart' as md;

const String notesCodeBlockLanguage = 'plaintext';

class NotesMarkdownCodeBlockParser extends CustomMarkdownParser {
  const NotesMarkdownCodeBlockParser();

  @override
  List<Node> transform(
    md.Node element,
    List<CustomMarkdownParser> parsers, {
    MarkdownListType listType = MarkdownListType.unknown,
    int? startNumber,
  }) {
    if (element is! md.Element || element.tag != 'pre') {
      return [];
    }

    final children = element.children;
    if (children == null || children.isEmpty) {
      return [];
    }

    final code = children.first;
    if (code is! md.Element || code.tag != 'code') {
      return [];
    }

    return [
      codeBlockNode(
        language: notesCodeBlockLanguage,
        delta: Delta()..insert(code.textContent.trimRight()),
      ),
    ];
  }
}
