import 'dart:html';

import 'package:hello/src/other.dart';

/** Just hello world! */
String greetingWords = 'Hello world!';

void main() {
  var content = querySelector('#content');
  content.text = greetingWords;
  var config = new Config._(output: "some output", format: OutputFormat.LSIF);
  print(config);
  print(otherVar);
}

/**
 * Holds information about a foo. Code `${}`:
 *
 *     var x = "hi";
 *     print(x)
 *
 * Links:
 *
 * * [Dart Cookbook](https://www.dartlang.org/docs/cookbook/#strings)
 *   for String examples and recipes.
 * * [Dart Up and Running](https://www.dartlang.org/docs/dart-up-and-running/ch03.html#strings-and-regular-expressions)
 */
class Config {
  /** Absolute path to the output directory, comes from --output, defaults to --input */
  final String output;
  /** Some format. */
  final OutputFormat format;

  /** A static string. */
  static const String DART_SDK = "dart-sdk";

  Config._({this.output, this.format});

  String get getoutput {
    return output;
  }
}

/** JSON, HTML, GitHub, LSIF. */
enum OutputFormat { JSON, HTML, GITHUB, LSIF }
