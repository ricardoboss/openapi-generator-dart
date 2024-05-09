import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:build/build.dart';
import 'package:logging/logging.dart';
import 'package:openapi_generator/src/models/output_message.dart';
import 'package:openapi_generator/src/utils.dart';

Future<String> getOpenApiGeneratorJarPath({
  String? version,
  bool usePackaged = false,
}) async {
  if (usePackaged) {
    return _getPackagedOpenApiGeneratorJarPath();
  }

  try {
    if (!await _isDownloadedOpenApiGeneratorJarAvailable(version)) {
      await _downloadOpenApiGeneratorJar(version);
    }

    return _getDownloadedOpenApiGeneratorJarPath(version);
  } catch (e, s) {
    logOutputMessage(
      log: log,
      communication: OutputMessage(
        message: 'Failed to download the OpenAPI Generator JAR file, '
            'falling back to the packaged version.',
        level: Level.WARNING,
        additionalContext: e,
        stackTrace: s,
      ),
    );

    return _getPackagedOpenApiGeneratorJarPath();
  }
}

Future<bool> _isDownloadedOpenApiGeneratorJarAvailable(String? version) async {
  final path = await _getDownloadedOpenApiGeneratorJarPath(version);

  return await File(path).exists();
}

Future<String> _getDownloadedOpenApiGeneratorJarPath(String? version) async {
  final toolDir =
      Directory(Directory.systemTemp.absolute.path + '/openapi-generator');
  if (!await toolDir.exists()) {
    await toolDir.create();
  }

  version ??= 'latest';

  return toolDir.path + '/openapi-generator-$version.jar';
}

Future<void> _downloadOpenApiGeneratorJar(String? version) async {
  final bool isLatest;
  if (version != null) {
    isLatest = false;

    logOutputMessage(
      log: log,
      communication: OutputMessage(
        message: 'Using explicitly defined OpenAPI Generator version: $version',
      ),
    );
  } else if (Platform.environment['OPENAPI_GENERATOR_VERSION'] != null) {
    isLatest = false;
    version = Platform.environment['OPENAPI_GENERATOR_VERSION'];

    logOutputMessage(
      log: log,
      communication: OutputMessage(
        message:
            'Using OPENAPI_GENERATOR_VERSION environment variable: $version',
      ),
    );
  } else {
    isLatest = true;
    version = await _getLatestVersionFromGitHub();

    logOutputMessage(
      log: log,
      communication: OutputMessage(
        message: 'Using the latest OpenAPI Generator version: $version',
      ),
    );
  }

  assert(version != null, 'Could not determine the OpenAPI Generator version.');

  final downloadUrl = Uri.parse(
    'https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/$version/openapi-generator-cli-$version.jar',
  );

  final jarPath = await _getDownloadedOpenApiGeneratorJarPath(version);

  final jarFile = File(jarPath);
  await jarFile.create(recursive: true);

  final request = await HttpClient().getUrl(downloadUrl);
  final response = await request.close();

  if (response.statusCode != 200) {
    throw Exception(
      'Failed to download the OpenAPI Generator JAR file (HTTP ${response.statusCode})',
    );
  }

  await response.pipe(jarFile.openWrite());

  // create symlink to latest
  if (isLatest) {
    final latestPath = await _getDownloadedOpenApiGeneratorJarPath(null);
    if (await File(latestPath).exists()) {
      await File(latestPath).delete();
    }

    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'mklink', latestPath, jarPath]);
    } else {
      await Process.run('ln', ['-s', jarPath, latestPath]);
    }
  }

  logOutputMessage(
    log: log,
    communication: OutputMessage(
      message: 'Downloaded OpenAPI Generator JAR file to: $jarPath',
    ),
  );
}

Future<String> _getLatestVersionFromGitHub() async {
  final request = await HttpClient().getUrl(
    Uri.parse(
      'https://api.github.com/repos/openapitools/openapi-generator/releases/latest',
    ),
  );

  final response = await request.close();
  if (response.statusCode != 200) {
    throw Exception(
        'Failed to fetch the latest OpenAPI Generator version (HTTP ${response.statusCode})');
  }

  final body = await response.transform(utf8.decoder).join();
  final json = jsonDecode(body) as Map<String, dynamic>?;
  if (json == null ||
      !json.containsKey('tag_name') ||
      json['tag_name'] == null) {
    throw Exception('Failed to parse GitHub response');
  }

  final tagName = json['tag_name'] as String;
  if (tagName.startsWith('v')) {
    return tagName.substring(1);
  }

  return tagName;
}

Future<String> _getPackagedOpenApiGeneratorJarPath() async {
  final jarUri =
      Uri.parse('package:openapi_generator_cli/openapi-generator.jar');
  final actualLocation = await Isolate.resolvePackageUri(jarUri);

  assert(actualLocation != null,
      'Could not find the OpenAPI Generator JAR file in the package.');

  return actualLocation!.toFilePath(windows: Platform.isWindows);
}
