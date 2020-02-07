library crossdart.generator.lsif_generator;

import 'dart:io';
import 'dart:convert';
import 'package:crossdart/src/entity.dart';
import 'package:crossdart/src/package.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';

var _logger = new Logger("lsif_generator");

class Emitter {
  final File file;
  Emitter(this.file);
}

void withIOSink(File file, Future Function(IOSink) f) async {
  var sink = file.openWrite();
  await f(sink);
  await sink.flush();
  await sink.close();
}

Future<String> Function(Map<String, Object>) mkEmit(IOSink sink) {
  int entryCount = 0;
  return (Map<String, Object> entry) async {
    String id = entryCount.toString();
    entryCount++;
    entry.putIfAbsent("id", () => id);
    await sink.writeln(jsonEncode(entry));
    return id;
  };
}

Future<void> withinProject(Future<String> Function(Map<String, Object>) emit,
    Future Function() inside) async {
  var projectId = await emit({
    "type": 'vertex',
    "label": 'project',
    "kind": 'dart',
  });
  await emit({
    "type": 'vertex',
    "label": '\$event',
    "kind": 'begin',
    "scope": 'project',
    "data": projectId,
  });
  await inside();
  await emit({
    "data": projectId,
    "type": 'vertex',
    "label": '\$event',
    "kind": 'end',
    "scope": 'project',
  });
}

Future<void> withinDocuments(
    Future<String> Function(Map<String, Object>) emit,
    Iterable<String> documents,
    Future<Map<String, List<String>>> Function(Map<String, String>)
        inside) async {
  Map<String, String> docToID = {};
  await Future.forEach(documents, (String doc) async {
    docToID[doc] = await emit({
      "type": 'vertex',
      "label": 'document',
      "uri": 'file://' + doc,
      "languageId": 'dart',
    });
    await emit({
      "data": docToID[doc],
      "type": 'vertex',
      "label": '\$event',
      "kind": 'begin',
      "scope": 'document',
    });
  });
  Map<String, List<String>> docToRanges = await inside(docToID);
  await Future.forEach(documents, (String doc) async {
    await emit({
      "type": 'edge',
      "label": 'contains',
      "outV": docToID[doc],
      "inVs": docToRanges[doc],
    });
    await emit({
      "data": docToID[doc],
      "type": 'vertex',
      "label": '\$event',
      "kind": 'end',
      "scope": 'document',
    });
  });
}

Map<String, Object> range(Entity entity) {
  return {
    "type": "vertex",
    "label": "range",
    "start": {
      "line": entity.lineNumber != null ? entity.lineNumber : 0,
      "character": entity.lineOffset != null ? entity.lineOffset : 0,
    },
    "end": {
      "line": entity.lineNumber != null ? entity.lineNumber : 0,
      "character": (entity.lineOffset != null ? entity.lineOffset : 0) +
          entity.name.length,
    },
  };
}

Future<void> emitHover(emit, docstring, resultSetId) async {
  var hoverId = await emit({
    "type": "vertex",
    "label": "hoverResult",
    "result": {
      'contents': {
        'kind': 'markdown',
        'value': docstring,
      }
    }
  });
  await emit({
    "type": "edge",
    "label": "textDocument/hover",
    "outV": resultSetId,
    "inV": hoverId
  });
}

Future<void> emitDefinition(emit, resultSetId, rangeId, documentId) async {
  var definitionId = await emit({
    "type": "vertex",
    "label": "definitionResult",
  });
  await emit({
    "type": "edge",
    "label": "textDocument/definition",
    "outV": resultSetId,
    "inV": definitionId,
  });
  await emit({
    "type": "edge",
    "label": "item",
    "outV": definitionId,
    "inVs": [rangeId],
    "document": documentId,
  });
}

Future<void> emitReferences(
    emit,
    String resultSetId,
    String rangeId,
    Set<Reference> allReferences,
    String documentId,
    Map<String, List<String>> docToRanges,
    Map<String, String> docToID) async {
  var referenceId = await emit({
    "type": "vertex",
    "label": "referenceResult",
  });

  var referencesByDoc = new Map<String, List<Reference>>();
  for (var reference in allReferences) {
    referencesByDoc.putIfAbsent(reference.location.file, () => []);
    referencesByDoc[reference.location.file].add(reference);
  }

  for (var entry in referencesByDoc.entries) {
    var currentDoc = entry.key;
    var currentDocReferences = entry.value;

    List<String> referenceRangeIds = [];
    await Future.forEach<Reference>(currentDocReferences, (reference) async {
      var referenceRangeId = await emit(range(reference));
      await emit({
        "type": "edge",
        "label": "next",
        "outV": referenceRangeId,
        "inV": resultSetId
      });
      referenceRangeIds.add(referenceRangeId);
      docToRanges[reference.location.file].add(referenceRangeId);
    });
    await emit({
      "type": "edge",
      "label": "item",
      "outV": referenceId,
      "inVs": referenceRangeIds,
      "document": docToID[currentDoc],
      "property": "references",
    });
    await emit({
      "type": "edge",
      "label": "item",
      "outV": referenceId,
      "inVs": [rangeId],
      "document": documentId,
      "property": "definitions",
    });
  }

  await emit({
    "type": "edge",
    "label": "textDocument/references",
    "outV": resultSetId,
    "inV": referenceId
  });
}

String toMarkdown(String docstring) {
  return docstring
      .replaceAll(new RegExp(r'^/\*\*\n', multiLine: true), '')
      .replaceAll(new RegExp(r'^/\*\* ', multiLine: true), '')
      .replaceAll(new RegExp(r'^ \*$', multiLine: true), '')
      .replaceAll(new RegExp(r'^ \* ', multiLine: true), '')
      .replaceAll(new RegExp(r'\*/$', multiLine: true), '');
}

class LsifGenerator {
  final Environment _environment;
  final ParsedData _parsedData;
  LsifGenerator(this._environment, this._parsedData);

  bool isFileInProject(String file) {
    return file.startsWith(_environment.config.output);
  }

  void generate() async {
    _logger.fine("Generating LSIF output");
    new Directory(_environment.config.output).createSync(recursive: true);
    var file = new File(path.join(_environment.config.output, "dump.lsif"));
    var pubspecLockPath = path.join(_environment.config.input, "pubspec.lock");
    await withIOSink(file, (sink) async {
      var emit = mkEmit(sink);
      await emit({
        "id": 'meta',
        "type": 'vertex',
        "label": 'metaData',
        "projectRoot": "file://${_environment.config.output}",
        "version": '0.4.0',
        "positionEncoding": 'utf-16',
        "toolInfo": {"name": 'crossdart', "args": [], "version": 'dev'}
      });
      await withinProject(emit, () async {
        var docs = _parsedData.files.keys.toList().where(isFileInProject);
        await withinDocuments(emit, docs, (documentToId) async {
          Map<String, List<String>> docToRanges =
              Map.fromIterable(docs, key: (doc) => doc, value: (key) => []);

          await Future.forEach<Declaration>(_parsedData.declarations.keys,
              (declaration) async {
            if (declaration.name == null) {
              return;
            }
            if (!isFileInProject(declaration.location.file)) {
              // TODO monikers
              return;
            }

            _logger.fine(
                "    Definition    ${declaration.location.file}:${declaration.lineNumber.toString()}:${declaration.lineOffset} symbol ${declaration.name}");
            _parsedData.declarations[declaration].forEach((reference) {
              _logger.fine(
                  "        Reference ${reference.location.file}:${reference.lineNumber.toString()}:${reference.lineOffset}");
            });

            var rangeId = await emit(range(declaration));
            docToRanges[declaration.location.file].add(rangeId);
            var resultSetId = await emit({
              "type": "vertex",
              "label": "resultSet",
            });

            if (declaration.docstring != null) {
              emitHover(emit, toMarkdown(declaration.docstring), resultSetId);
            } else {
              emitHover(
                  emit,
                  "```dart\n" +
                      new File(declaration.location.file)
                          .readAsStringSync()
                          .split("\n")[declaration.lineNumber] +
                      "\n```",
                  resultSetId);
            }
            await emitDefinition(emit, resultSetId, rangeId,
                documentToId[declaration.location.file]);
            await emitReferences(
                emit,
                resultSetId,
                rangeId,
                _parsedData.declarations[declaration],
                documentToId[declaration.location.file],
                docToRanges,
                documentToId);
            _logger.fine("");

            await emit({
              "type": "edge",
              "label": "next",
              "outV": rangeId,
              "inV": resultSetId
            });
          });
          return docToRanges;
        });
      });
    });
    _logger.info("Saved LSIF output to ${file.path}");
  }
}
