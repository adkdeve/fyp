// ignore_for_file: avoid_print

import 'dart:io';

Future<void> generateLocalization() async {
  print('🌐 Generating localization files...');
  final result =
      await Process.run('get', ['generate', 'locales', 'assets/locales']);

  if (result.exitCode == 0) {
    const generatedPath = 'lib/generated/locales.g.dart';
    const destinationPath = 'lib/app/core/localization/locales.g.dart';

    final generatedFile = File(generatedPath);
    if (await generatedFile.exists()) {
      await generatedFile.rename(destinationPath);
      print('✅ locales.g.dart moved to $destinationPath');

      // 🔥 Remove the lib/generated/ folder
      final generatedFolder = Directory('lib/generated');
      if (await generatedFolder.exists()) {
        await generatedFolder.delete(recursive: true);
        print('🧹 Removed lib/generated folder');
      }
    } else {
      print('⚠️ locales.g.dart not found at $generatedPath');
    }
  } else {
    print('❌ Failed to generate locales: ${result.stderr}');
  }
}

Future<void> generateAppImages() async {
  final buffer = StringBuffer();
  final imageDir = Directory('assets/images');
  const className = 'AppImages';

  buffer.writeln('/// Auto-generated. Do not edit manually.');
  buffer.writeln('class $className {');

  void processFile(File file) {
    final relativePath = file.path.replaceAll('\\', '/');
    final fileNameWithExt = relativePath.split('/').last;
    final fileNameWithoutExt = fileNameWithExt.split('.').first;

    final cleanedName = fileNameWithoutExt
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
        .replaceAll('-', '_');

    final isSvg = fileNameWithExt.endsWith('.svg');
    final prefix = isSvg ? 'ic_' : 'img_';
    final variableName = '$prefix$cleanedName';

    buffer.writeln("  final String $variableName = '$relativePath';");
  }

  void walk(Directory dir) {
    for (var entity in dir.listSync(recursive: true)) {
      if (entity is File &&
          (entity.path.endsWith('.png') ||
              entity.path.endsWith('.jpg') ||
              entity.path.endsWith('.jpeg') ||
              entity.path.endsWith('.svg'))) {
        processFile(entity);
      }
    }
  }

  walk(imageDir);
  buffer.writeln('}');

  final outputFile = File('lib/app/core/resources/app_images.dart');
  await outputFile.writeAsString(buffer.toString());
  print('✅ AppImages class generated at ${outputFile.path}');
}

Future<void> main() async {
  await generateLocalization();
  await generateAppImages();
  print('🚀 All resources generated successfully!');
}
