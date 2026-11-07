import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../db.dart';
import '../format.dart';
import '../ui.dart';
import 'relatorios_page.dart';

class MaisScreen extends StatefulWidget {
  const MaisScreen({super.key});

  @override
  State<MaisScreen> createState() => _MaisScreenState();
}

class _MaisScreenState extends State<MaisScreen> {
  Future<void> _datas() async {
    final q1 = TextEditingController(text: '${AppConfig.diaQ1}');
    final q2 = TextEditingController(text: '${AppConfig.diaQ2}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Datas de pagamento'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: q1,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Vendas de 1 a 15: dia do mesmo mês'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: q2,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Vendas de 16 a 31: dia do mês seguinte'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );
    final a = int.tryParse(q1.text), b = int.tryParse(q2.text);
    q1.dispose();
    q2.dispose();
    if (ok != true) return;
    if (a == null || b == null || a < 1 || a > 31 || b < 1 || b > 31) {
      if (mounted) snack(context, 'Informe dias entre 1 e 31.');
      return;
    }
    await AppConfig.salvar(a, b);
    if (mounted) setState(() {});
  }

  Future<String?> _pedirTexto(String titulo, String label, String atual, TextInputType teclado,
      {String? sufixo}) async {
    final c = TextEditingController(text: atual);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: teclado,
          decoration: InputDecoration(labelText: label, suffixText: sufixo),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );
    final t = c.text.trim();
    c.dispose();
    return ok == true ? t : null;
  }

  Future<void> _whats() async {
    final t = await _pedirTexto('WhatsApp da base', 'Número com DDD', AppConfig.whatsBase, TextInputType.phone);
    if (t == null) return;
    if (t.replaceAll(RegExp(r'\D'), '').length < 10) {
      if (mounted) snack(context, 'Número inválido. Use DDD + número.');
      return;
    }
    await AppConfig.salvarWhats(t);
    if (mounted) setState(() {});
  }

  Future<void> _comissao() async {
    final t = await _pedirTexto('Comissão', 'Percentual sobre as vendas', numero(AppConfig.comissao),
        const TextInputType.numberWithOptions(decimal: true),
        sufixo: '%');
    if (t == null) return;
    final v = lerNumero(t);
    if (v == null || v < 0 || v > 100) {
      if (mounted) snack(context, 'Percentual inválido.');
      return;
    }
    await AppConfig.salvarComissao(v);
    if (mounted) {
      snack(context, 'Vale para os próximos pedidos. Os já lançados mantêm o percentual antigo.');
      setState(() {});
    }
  }

  Future<void> _backup() async {
    await Db.fechar();
    final src = File(await Db.caminho());
    if (!await src.exists()) {
      if (mounted) snack(context, 'Ainda não há dados para salvar.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final dst = p.join(dir.path, 'backup_vendas_peixe_${dbData(hoje())}.db');
    await src.copy(dst);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(dst)],
      subject: 'Backup Vendas de Peixe ${br(hoje())}',
    ));
  }

  Future<void> _restaurar() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty || files.first.path == null) return;
    final f = File(files.first.path!);
    final cab = await f.openRead(0, 15).fold<List<int>>([], (a, b) => a..addAll(b));
    if (String.fromCharCodes(cab) != 'SQLite format 3') {
      if (mounted) snack(context, 'Este arquivo não é um backup válido.');
      return;
    }
    if (!mounted) return;
    if (!await confirmar(context, 'Restaurar backup?',
        'Todos os dados atuais do app serão SUBSTITUÍDOS pelos do backup.', ok: 'Restaurar')) {
      return;
    }
    await Db.fechar();
    final destino = await Db.caminho();
    for (final ext in ['-wal', '-shm', '-journal']) {
      final x = File('$destino$ext');
      if (await x.exists()) await x.delete();
    }
    await f.copy(destino);
    await AppConfig.carregar(); // reabre o banco (e migra, se o backup for de versão antiga)
    if (mounted) {
      snack(context, 'Backup restaurado.');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.bar_chart),
          title: const Text('Relatórios'),
          subtitle: const Text('Vendas por período, cliente e peixe'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RelatoriosPage())),
        ),
        ListTile(
          leading: const Icon(Icons.event),
          title: const Text('Datas de pagamento'),
          subtitle: Text('Vendas de 1 a 15: dia ${AppConfig.diaQ1}\n'
              'Vendas de 16 a 31: dia ${AppConfig.diaQ2} do mês seguinte'),
          isThreeLine: true,
          onTap: _datas,
        ),
        ListTile(
          leading: const Icon(Icons.chat),
          title: const Text('WhatsApp da base'),
          subtitle: Text('${AppConfig.whatsBase} · pedidos, extratos e cobranças vão para este número'),
          onTap: _whats,
        ),
        ListTile(
          leading: const Icon(Icons.percent),
          title: const Text('Minha comissão'),
          subtitle: Text('${pctTxt(AppConfig.comissao)} sobre todas as vendas'),
          onTap: _comissao,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.cloud_upload),
          title: const Text('Fazer backup'),
          subtitle: const Text('Salve uma cópia no Google Drive'),
          onTap: _backup,
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('Restaurar backup'),
          subtitle: const Text('Substitui todos os dados atuais'),
          onTap: _restaurar,
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Vendas de Peixe'),
          subtitle: Text('Versão 1.1 · dados salvos só neste celular. Faça backup com frequência.'),
        ),
      ]),
    );
  }
}
