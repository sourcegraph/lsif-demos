library crossdart.parser;

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:crossdart/src/parser/ast_visitor.dart';
import 'package:crossdart/src/environment.dart';
import 'package:crossdart/src/parsed_data.dart';
import 'package:logging/logging.dart' as logging;

var _logger = new logging.Logger("parser");

class Parser {
  final Environment environment;

  Parser(this.environment);

  Future<ParsedData> parseProject() async {
    // TODO need to use these?
    // var absolutePaths = environment.packages.map((p) => p.absolutePaths).expand((i) => i);
    _logger.info("Building computation unit");
    AnalysisContextCollection collection = new AnalysisContextCollection(
        includedPaths: [environment.config.input]);
    _logger.info("Done with building computation unit");
    var parsedData = new ParsedData();
    for (var absolutePath in environment.package.absolutePaths) {
      _logger.info("Parsing file $absolutePath");
      AnalysisContext context =
          collection.contextFor(absolutePath); // TODO or relative?
      (await context.currentSession.getResolvedUnit(absolutePath)).unit.accept(
          new ASTVisitor(
              environment, absolutePath, parsedData)); // TODO or relative?
    }
    return parsedData;
  }
}
