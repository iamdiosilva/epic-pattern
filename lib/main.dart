import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'organizer.dart';

void main() => runApp(const EpicPatternApp());

class EpicPatternApp extends StatelessWidget {
  const EpicPatternApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Epic STL Organizer',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF2688FA),
      scaffoldBackgroundColor: const Color(0xFF0B1520),
    ),
    home: const OrganizerPage(),
  );
}

class OrganizerPage extends StatefulWidget {
  const OrganizerPage({super.key});
  @override
  State<OrganizerPage> createState() => _OrganizerPageState();
}

class _OrganizerPageState extends State<OrganizerPage> {
  final Organizer service = Organizer();
  final rootController = TextEditingController();
  final basesController = TextEditingController();
  ScanReport? report;
  bool rename = true;
  bool replace = true;
  bool remove = true;
  bool busy = false;
  String status = 'Selecione a pasta e faça a varredura.';
  int progressDone = 0;
  int progressTotal = 0;

  @override
  void dispose() {
    rootController.dispose();
    basesController.dispose();
    super.dispose();
  }

  Future<void> chooseRoot() async {
    final path = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Pasta Epic Miniatures');
    if (path == null) return;
    setState(() {
      rootController.text = path;
      basesController.text = p.join(path, 'Bases');
      report = null;
    });
  }

  Future<void> chooseBases() async {
    final path = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Pasta de bases suportadas');
    if (path != null) setState(() {
      basesController.text = path;
      report = null;
    });
  }

  Future<void> scan() async {
    if (rootController.text.trim().isEmpty) {
      setState(() => status = 'Selecione uma pasta antes de escanear.');
      return;
    }
    setState(() { busy = true; status = 'Escaneando...'; report = null; });
    try {
      final found = await service.scan(rootController.text.trim(), basesController.text.trim(),
          rename: rename, replace: replace, remove: remove);
      if (!mounted) return;
      setState(() {
        report = found;
        status = 'Varredura concluída. Revise a prévia antes de executar.';
      });
    } catch (e) {
      if (mounted) setState(() => status = 'Erro: ' + e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> execute() async {
    final current = report;
    if (current == null || !current.changes.any((e) => e.selected)) return;
    final count = current.changes.where((e) => e.selected).length;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar alterações'),
        content: Text('Executar ' + count.toString() +
          ' operações? Arquivos removidos e bases substituídas terão cópias na pasta .epic_pattern_backups. Renomeações não geram backup.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Executar')),
        ],
      ),
    );
    if (accepted != true) return;
    setState(() { busy = true; progressDone = 0; progressTotal = count; });
    try {
      final outcome = await service.execute(rootController.text.trim(), current.changes,
        progress: (done, total) {
          if (mounted) setState(() { progressDone = done; progressTotal = total; });
        },
      );
      if (!mounted) return;
      setState(() {
        report = null;
        status = 'Concluídas: ' + outcome.success.toString() +
          ' | Falhas: ' + outcome.errors.length.toString() +
          (outcome.backupPath == null ? '' : ' | Backup: ' + outcome.backupPath!);
      });
      if (outcome.errors.isNotEmpty && mounted) {
        await showDialog<void>(context: context, builder: (context) => AlertDialog(
          title: const Text('Falhas da execução'),
          content: SizedBox(width: 700, child: SingleChildScrollView(child: SelectableText(outcome.errors.join('\n')))),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
        ));
      }
    } catch (e) {
      if (mounted) setState(() => status = 'Erro: ' + e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget option(String title, String subtitle, bool value, ValueChanged<bool> changed, IconData icon) {
    return Expanded(child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: const Color(0xFF60A5FA)),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
            Switch(value: value, onChanged: busy ? null : changed),
          ]),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade400)),
        ]),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final changes = report?.changes ?? <Change>[];
    final selected = changes.where((e) => e.selected).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Epic STL Organizer'), backgroundColor: const Color(0xFF111D2B)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Organização de STLs da Epic Miniatures', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: rootController, readOnly: true,
              decoration: const InputDecoration(labelText: 'Pasta da coleção', border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            OutlinedButton.icon(onPressed: busy ? null : chooseRoot, icon: const Icon(Icons.folder_open), label: const Text('Selecionar')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: basesController, readOnly: true,
              decoration: const InputDecoration(labelText: 'Pasta de bases suportadas', border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            OutlinedButton.icon(onPressed: busy ? null : chooseBases, icon: const Icon(Icons.folder), label: const Text('Alterar')),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            option('Bases', 'Substituir por base suportada de nome idêntico.', replace,
              (v) => setState(() { replace = v; report = null; }), Icons.sync),
            option('Renomear', 'Adicionar _ no início dos nomes STL.', rename,
              (v) => setState(() { rename = v; report = null; }), Icons.drive_file_rename_outline),
            option('One Piece', 'Mover arquivos [One Piece] para backup.', remove,
              (v) => setState(() { remove = v; report = null; }), Icons.delete_outline),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            FilledButton.icon(onPressed: busy ? null : scan, icon: const Icon(Icons.search), label: const Text('Escanear e visualizar')),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(onPressed: busy || selected == 0 ? null : execute,
              icon: const Icon(Icons.play_arrow), label: Text('Executar (' + selected.toString() + ')')),
            const SizedBox(width: 16),
            Expanded(child: Text(status, maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
          if (busy && progressTotal > 0) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progressDone / progressTotal),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Text('Prévia (' + changes.length.toString() + ' alterações)',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (report != null) Text(report!.count.toString() + ' arquivos STL analisados'),
          ]),
          if (report != null && report!.warnings.isNotEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(report!.warnings.take(3).join(' | '),
                style: const TextStyle(color: Colors.amber))),
          const SizedBox(height: 8),
          Expanded(child: Card(child: changes.isEmpty
            ? const Center(child: Text('Nenhuma alteração na prévia.'))
            : ListView.builder(
              itemCount: changes.length,
              itemBuilder: (context, index) {
                final change = changes[index];
                final color = switch(change.operation) {
                  Operation.rename => Colors.lightBlueAccent,
                  Operation.replace => Colors.lightGreenAccent,
                  Operation.remove => Colors.redAccent,
                };
                return CheckboxListTile(
                  value: change.selected,
                  onChanged: busy ? null : (v) => setState(() => change.selected = v ?? false),
                  secondary: Icon(switch(change.operation) {
                    Operation.rename => Icons.edit,
                    Operation.replace => Icons.sync,
                    Operation.remove => Icons.delete_outline,
                  }, color: color),
                  title: Text(p.basename(change.file.path), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(change.message + '\n' + change.file.path,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  isThreeLine: true,
                );
              },
            ),
          )),
        ]),
      ),
    );
  }
}
