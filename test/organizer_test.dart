import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:epic_pattern/organizer.dart';

void main() {
  late Directory root;
  late Directory bases;
  final organizer = Organizer();

  setUp(() async {
    root = await Directory.systemTemp.createTemp('epic_pattern_test_');
    bases = await Directory(p.join(root.path, 'Bases')).create();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('detects rename without doubling underscore', () async {
    await File(p.join(root.path, 'Test.stl')).writeAsString('mesh');
    await File(p.join(root.path, '_Already.stl')).writeAsString('mesh');
    final result = await organizer.scan(root.path, bases.path,
        rename: true, replace: false, remove: false);
    expect(result.changes.length, 1);
    expect(result.changes.single.operation, Operation.rename);
    expect(p.basename(result.changes.single.destination!), '_Test.stl');
  });

  test('quarantines One Piece file with recoverable backup', () async {
    final original = File(p.join(root.path, '[One Piece] Fence.stl'));
    await original.writeAsString('original mesh');
    final result = await organizer.scan(root.path, bases.path,
        rename: true, replace: false, remove: true);
    expect(result.changes.single.operation, Operation.remove);
    final execution = await organizer.execute(root.path, result.changes);
    expect(execution.success, 1);
    expect(await original.exists(), false);
    expect(await File(p.join(execution.backupPath!, '[One Piece] Fence.stl')).readAsString(),
        'original mesh');
  });

  test('replaces only exact matching bases and preserves originals', () async {
    final model = await Directory(p.join(root.path, '7301 - Hero')).create();
    final original = File(p.join(model.path, 'Base 01 - 25_5mm - Medium - 1 Inch.stl'));
    final supported = File(p.join(bases.path, p.basename(original.path)));
    await original.writeAsString('unsupported');
    await supported.writeAsString('supported');
    final result = await organizer.scan(root.path, bases.path,
        rename: false, replace: true, remove: false);
    expect(result.changes.length, 1);
    expect(result.changes.single.operation, Operation.replace);
    final execution = await organizer.execute(root.path, result.changes);
    expect(execution.errors, isEmpty);
    expect(await original.readAsString(), 'supported');
    expect(await File(p.join(execution.backupPath!, '7301 - Hero',
        p.basename(original.path))).readAsString(), 'unsupported');
  });

  test('removes only names beginning with [One Piece]', () async {
    await File(p.join(root.path, '[One Piece] Fence.stl')).writeAsString('a');
    await File(p.join(root.path, 'Fence [One Piece].stl')).writeAsString('b');
    final result = await organizer.scan(root.path, bases.path,
        rename: false, replace: false, remove: true);
    expect(result.changes.length, 1);
    expect(p.basename(result.changes.single.file.path), '[One Piece] Fence.stl');
  });

  test('never renames STL files inside the source bases folder', () async {
    await File(p.join(bases.path, 'Base 01.stl')).writeAsString('supported');
    await File(p.join(root.path, 'Hero.stl')).writeAsString('model');
    final result = await organizer.scan(root.path, bases.path,
        rename: true, replace: false, remove: false);
    expect(result.changes.length, 1);
    expect(p.basename(result.changes.single.file.path), 'Hero.stl');
  });

  test('does not overwrite an existing rename destination', () async {
    await File(p.join(root.path, 'Hero.stl')).writeAsString('old');
    await File(p.join(root.path, '_Hero.stl')).writeAsString('other');
    final result = await organizer.scan(root.path, bases.path,
        rename: true, replace: false, remove: false);
    expect(result.changes, isEmpty);
    expect(result.warnings, isNotEmpty);
  });
}
