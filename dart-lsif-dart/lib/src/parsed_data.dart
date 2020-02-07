library crossdart.parsed_data;

import 'package:crossdart/src/entity.dart';

class ParsedData {
  Map<Declaration, Set<Reference>> declarations = {};
  Map<Reference, Declaration> references = {};
  Map<Declaration, TypeInfo> typeInfos = {};
  // Can contain `TypeInfo`s that do not appear in the `typeInfos` map above
  // Example: the `var` in "var x = 5;" can have a `TypeInfo` of "int", but there is no declaration for it
  Map<String, Set<Entity>> files = {};

  ParsedData copy() {
    var data = new ParsedData();
    declarations.forEach((declaration, references) {
      data.declarations[declaration] = new Set.from(references);
    });

    data.references = new Map.from(references);

    files.forEach((path, entities) {
      data.files[path] = new Set.from(entities);
    });

    return data;
  }
}
