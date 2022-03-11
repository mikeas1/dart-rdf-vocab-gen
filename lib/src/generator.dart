import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';
import 'package:http/http.dart' as http;
import 'package:quiver/collection.dart';
import 'package:rdf/rdf.dart';

import '../annotation.dart';

class Ontology {
  Map<String, RdfClass> classes = {};
  Map<String, RdfProperty> properties = {};

  String? preferredURI;
}

class RdfClass {
  final String iri;
  final String shortName;

  Map<String, String> labels = {};
  Map<String, String> comments = {};

  Multimap<String, Term> properties = Multimap();
  RdfClass(this.iri, this.shortName);
}

class RdfProperty {
  final String iri;
  final String shortName;
  Map<String, String> labels = {};
  Map<String, String> comments = {};
  Multimap<String, Term> properties = Multimap();

  RdfProperty(this.iri, this.shortName);
}

class VocabClassGenerator extends GeneratorForAnnotation<Vocab> {
  @override
  Future<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) async {
    final vocabUri = annotation.read('uri').stringValue;
    var prefix = annotation.read('prefix').literalValue?.toString() ?? vocabUri;
    String _deriveShortName(String iri) {
      // TODO: This probably isn't right.
      String ideal;
      try {
        ideal = iri
            .substring(prefix.length)
            .replaceAll(RegExp(r"[^a-zA-Z0-9_]+"), "_");
      } on Exception {
        print("Bad iri $iri");
        rethrow;
      }
      if (!ideal.startsWith(RegExp('[a-zA-Z]'))) {
        return "\$$ideal";
      }
      return ideal;
    }

    var vocabName = "_\$${element.name}";
    var uri = Uri.parse(vocabUri);
    var content = await http.get(uri, headers: {
      'Accept': 'text/turtle',
    });
    // TODO: Does this need to be expanded?
    if (content.statusCode != 200) {
      throw Exception(
          "Failed to fetch vocab contents. Response: ${content.statusCode}, ${content.body}");
    }
    print(content);
    // if (content.headers['Content-Type'] != 'text/turtle') {
    //   throw Exception(
    //       'Returned content type was "${content.headers['Content-Type']}"');
    // }
    var parsed = parseTurtle(content.body);
    if (!parsed.isSuccess) {
      throw Exception(parsed.message);
    }
    var quads = <Quad>[];
    for (var term in parsed.value) {
      if (term is Quad) {
        quads.add(term);
      }
    }
    var graph = IndexedGraph.build(quads);
    var classes = graph.pos[NamedNode(Rdf.type)]?[NamedNode(Rdfs.Class)] ?? [];
    var properties =
        graph.pos[NamedNode(Rdf.type)]?[NamedNode(Rdf.Property)] ?? [];
    var allClasses = <RdfClass>[];
    var allProperties = <RdfProperty>[];
    for (var classIRI in classes) {
      var classProperties = graph.spo[classIRI];
      var shortName = _deriveShortName(classIRI.value);
      var c = RdfClass(classIRI.value, shortName);
      classProperties?.forEach((key, value) {
        c.properties.add(key.value, value);
        if (key.value == Rdfs.comment) {
          c.comments[(value as LiteralTerm).language ?? ""] = value.value;
        }
        if (key.value == Rdfs.label) {
          c.labels[(value as LiteralTerm).language ?? ""] = value.value;
        }
      });
      allClasses.add(c);
    }
    for (var propIRI in properties) {
      var propProperties = graph.spo[propIRI];
      var shortName = _deriveShortName(propIRI.value);
      var prop = RdfProperty(propIRI.value, shortName);
      propProperties?.forEach((key, value) {
        prop.properties.add(key.value, value);
        if (key.value == Rdfs.comment) {
          prop.comments[(value as LiteralTerm).language ?? ""] = value.value;
        }
        if (key.value == Rdfs.label) {
          prop.comments[(value as LiteralTerm).language ?? ""] = value.value;
        }
      });
      allProperties.add(prop);
    }
    var output = StringBuffer();
    output.writeln("class $vocabName {");
    output.writeln("  const $vocabName._();");
    output.writeln("  // Defined classes");
    for (var c in allClasses) {
      if (c.shortName[0] == c.shortName[0].toUpperCase()) {
        output.writeln("    // ignore: non_constant_identifier_names");
      }
      output.writeln("  final ${c.shortName} = '${c.iri}';");
    }
    output.writeln("  // Defined properties");
    for (var p in allProperties) {
      output.writeln("  final ${p.shortName} = '${p.iri}';");
    }
    output.writeln("}");
    return output.toString();
  }
}
