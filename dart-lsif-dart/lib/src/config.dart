library crossdart.config;

import 'dart:io';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/dart/sdk/sdk.dart';
import 'package:path/path.dart' as path;
import 'package:analyzer/src/generated/sdk.dart' show DartSdk;
import 'package:package_config/discovery.dart' as packages_discovery;
import 'dart:async';

enum OutputFormat { JSON, HTML, GITHUB, LSIF }

class Config {
  /** Absolute path to the Dart SDK, comes from --dart-sdk */
  final String dartSdk;
  /** Absolute path to the project to analyze, comes from --input */
  final String input;
  /** Absolute path to the output directory, comes from --output, defaults to --input */
  final String output;
  final String hostedUrl;
  final String urlPathPrefix;
  final OutputFormat outputFormat;
  final String pubCachePath;
  final DartSdk sdk;

  static const String DART_SDK = "dart-sdk";
  static const String INPUT = "input";
  static const String OUTPUT = "output";
  static const String HOSTED_URL = "hosted-url";
  static const String URL_PATH_PREFIX = "url-path-prefix";
  static const String OUTPUT_FORMAT = "output-format";

  Config._(
      {this.dartSdk,
      this.input,
      this.output,
      this.hostedUrl,
      this.urlPathPrefix,
      this.outputFormat,
      this.pubCachePath,
      this.sdk});

  static Future<Config> build(
      {String dartSdk,
      String input,
      String output,
      String hostedUrl,
      String urlPathPrefix,
      OutputFormat outputFormat}) async {
    input ??= Directory.current.path;
    outputFormat ??= OutputFormat.HTML;
    // Defaults to $root in $root/bin/dart, the executable running this script
    dartSdk ??= new File(Platform.resolvedExecutable).parent.parent.path;
    DartSdk sdk = new FolderBasedDartSdk(PhysicalResourceProvider.INSTANCE,
        PhysicalResourceProvider.INSTANCE.getResource(dartSdk));
    if (sdk.sdkVersion == "0") {
      throw new Exception(
          "${dartSdk} is not a valid Dart SDK (set by --dart-sdk). It should have a `version` file at the root. When installed via brew on macOS, it's /usr/local/Cellar/dart/<version>/libexec");
    }
    String pubCachePath;
    if (input != dartSdk) {
      var packagesDiscovery = (await packages_discovery
              .loadPackagesFile(new Uri.file(path.join(input, ".packages"))))
          .asMap();
      pubCachePath = new File.fromUri(packagesDiscovery.values.first)
          .parent
          .parent
          .parent
          .parent
          .path;
    }
    return new Config._(
        dartSdk: dartSdk,
        input: input,
        output: output,
        hostedUrl: hostedUrl,
        urlPathPrefix: urlPathPrefix,
        outputFormat: outputFormat,
        pubCachePath: pubCachePath,
        sdk: sdk);
  }

  String get packagesPath {
    return path.join(input, ".packages");
  }

  String get urlPrefix => "${hostedUrl}/${urlPathPrefix}";

  String get hostedPackagesRoot {
    return path.join(pubCachePath, "hosted", "pub.dartlang.org");
  }

  String get gitPackagesRoot {
    return path.join(pubCachePath, "git");
  }

  String get sdkPackagesRoot {
    return path.join(pubCachePath, "sdk");
  }

  Config copy(
      {String dartSdk,
      String input,
      String output,
      String hostedUrl,
      String urlPathPrefix,
      OutputFormat outputFormat}) {
    return new Config._(
        dartSdk: dartSdk ?? this.dartSdk,
        input: input ?? this.input,
        output: output ?? this.output,
        hostedUrl: hostedUrl ?? this.hostedUrl,
        urlPathPrefix: urlPathPrefix ?? this.urlPathPrefix,
        outputFormat: outputFormat ?? this.outputFormat);
  }
}
