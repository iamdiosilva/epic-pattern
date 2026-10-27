import 'dart:io';
import 'package:path/path.dart' as p;

enum Operation { rename, replace, remove }

class Change {
  Change(this.file, this.operation, this.message, {this.template, this.destination});
  final File file;
  final Operation operation;
  final String message;
  final File? template;
  final String? destination;
  bool selected = true;
}

class ScanReport {
  ScanReport(this.count, this.changes, this.warnings);
  final int count;
  final List<Change> changes;
  final List<String> warnings;
}

class ExecuteReport {
  ExecuteReport(this.success, this.errors, this.backupPath);
  final int success;
  final List<String> errors;
  final String? backupPath;
}

class Organizer {
  String baseKey(String name) =>
      (name.startsWith('_') ? name.substring(1) : name).toLowerCase();

  Future<ScanReport> scan(
    String rootPath,
    String templatePath, {
    required bool rename,
    required bool replace,
    required bool remove,
  }) async {
    final root = Directory(rootPath);
    if (!await root.exists()) throw const FileSystemException('Pasta não encontrada');
    final templates = <String, File>{};
    final warnings = <String>[];
    if (replace) {
      final dir = Directory(templatePath);
      if (!await dir.exists()) {
        warnings.add('Pasta de bases suportadas não encontrada');
      } else {
        final duplicates = <String>{};
        await for (final e in dir.list(recursive: true, followLinks: false)) {
          if (e is! File || p.extension(e.path).toLowerCase() != '.stl') continue;
          final key = baseKey(p.basename(e.path));
          if (templates.containsKey(key)) duplicates.add(key);
          templates[key] = e;
        }
        for (final key in duplicates) {
          templates.remove(key);
          warnings.add('Base ambígua: ' + key);
        }
      }
    }

    final changes = <Change>[];
    var count = 0;
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is! File || p.extension(e.path).toLowerCase() != '.stl') continue;
      if (p.split(e.path).contains('.epic_pattern_backups')) continue;
      if (p.equals(p.absolute(templatePath), p.absolute(e.path)) ||
          p.isWithin(p.absolute(templatePath), p.absolute(e.path))) continue;
      count++;
      final name = p.basename(e.path);
      if (remove && name.toLowerCase().startsWith('[one piece]')) {
        changes.add(Change(e, Operation.remove, 'Mover para backup'));
      } else if (replace && baseKey(name).startsWith('base ') && templates.containsKey(baseKey(name))) {
        final supported = templates[baseKey(name)]!;
        final destination = p.join(p.dirname(e.path), p.basename(supported.path));
        if (!p.equals(e.path, destination) && await File(destination).exists()) {
          warnings.add('Base suportada já existe no destino: ' + destination);
        } else {
          changes.add(Change(e, Operation.replace,
              'Substituir e salvar como ' + p.basename(supported.path),
              template: supported, destination: destination));
        }
      } else if (rename && !name.startsWith('_')) {
        final target = p.join(p.dirname(e.path), '_' + name);
        if (await File(target).exists()) {
          warnings.add('Destino já existe: ' + target);
        } else {
          changes.add(Change(e, Operation.rename, 'Renomear para _' + name, destination: target));
        }
      }
    }
    changes.sort((a, b) => a.file.path.compareTo(b.file.path));
    return ScanReport(count, changes, warnings);
  }

  Future<ExecuteReport> execute(
    String rootPath,
    List<Change> changes, {
    void Function(int done, int total)? progress,
  }) async {
    final selected = changes.where((c) => c.selected).toList();
    final backup = Directory(p.join(rootPath, '.epic_pattern_backups',
      DateTime.now().toIso8601String().replaceAll(':', '-')));
    final errors = <String>[];
    var success = 0;
    var done = 0;
    for (final change in selected) {
      try {
        if (!p.isWithin(p.absolute(rootPath), p.absolute(change.file.path)) ||
            p.split(change.file.path).contains('.epic_pattern_backups')) {
          throw StateError('Arquivo fora da coleção');
        }
        if (!await change.file.exists()) throw StateError('Arquivo não existe mais');
        if (change.operation == Operation.remove &&
            !p.basename(change.file.path).toLowerCase().startsWith('[one piece]')) {
          throw StateError('Arquivo não corresponde à regra [One Piece]');
        }
        if (change.operation == Operation.rename) {
          final target = change.destination;
          if (target == null ||
              p.dirname(p.absolute(target)) != p.dirname(p.absolute(change.file.path)) ||
              p.basename(target) != '_' + p.basename(change.file.path) ||
              await File(target).exists()) throw StateError('Destino indisponível');
          await change.file.rename(target);
        } else {
          final relative = p.relative(change.file.path, from: rootPath);
          final copy = File(p.join(backup.path, relative));
          await copy.parent.create(recursive: true);
          if (await copy.exists()) throw StateError('Backup já existe');
          await change.file.copy(copy.path);
          if (await copy.length() != await change.file.length()) {
            await copy.delete();
            throw StateError('Backup incompleto');
          }
          if (change.operation == Operation.remove) {
            await change.file.delete();
          } else {
            final source = change.template;
            if (source == null || !await source.exists() ||
                baseKey(p.basename(source.path)) != baseKey(p.basename(change.file.path)) ||
                !baseKey(p.basename(change.file.path)).startsWith('base ')) {
              throw StateError('Template não encontrado ou não corresponde ao original');
            }
            final destination = change.destination;
            if (destination == null ||
                p.dirname(p.absolute(destination)) != p.dirname(p.absolute(change.file.path)) ||
                p.basename(destination) != p.basename(source.path) ||
                (!p.equals(destination, change.file.path) && await File(destination).exists())) {
              throw StateError('Destino de base suportada indisponível');
            }
            final temp = File(change.file.path + '.epic-tmp');
            if (await temp.exists()) throw StateError('Temporário já existe');
            try {
              await source.copy(temp.path);
              if (await temp.length() != await source.length()) throw StateError('Template incompleto');
              await change.file.delete();
              await temp.rename(destination);
            } catch (_) {
              if (await temp.exists()) await temp.delete();
              if (!await change.file.exists()) await copy.copy(change.file.path);
              rethrow;
            }
          }
        }
        success++;
      } catch (e) {
        errors.add(change.file.path + ': ' + e.toString());
      } finally {
        done++;
        progress?.call(done, selected.length);
      }
    }
    return ExecuteReport(success, errors, await backup.exists() ? backup.path : null);
  }
}
