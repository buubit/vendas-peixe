import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Repositório do GitHub ("usuario/repositorio") de onde vêm as atualizações.
/// Vazio = verificação desligada.
const repoAtualizacao = 'buubit/vendas-peixe';

class Atualizacao {
  final String versao;
  final int build;
  final String urlApk;
  final String notas;
  Atualizacao(this.versao, this.build, this.urlApk, this.notas);
}

Future<String> versaoAtual() async {
  final i = await PackageInfo.fromPlatform();
  return '${i.version} (${i.buildNumber})';
}

/// Retorna a atualização se houver uma versão mais nova publicada; senão null.
Future<Atualizacao?> buscarAtualizacao() async {
  if (repoAtualizacao.isEmpty) return null;
  final r = await http
      .get(Uri.parse('https://api.github.com/repos/$repoAtualizacao/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json'})
      .timeout(const Duration(seconds: 15));
  if (r.statusCode != 200) return null;
  final j = jsonDecode(r.body) as Map<String, dynamic>;
  final tag = (j['tag_name'] as String?) ?? '';
  final build = int.tryParse(RegExp(r'(\d+)$').firstMatch(tag)?.group(1) ?? '') ?? 0;
  final assets = (j['assets'] as List?) ?? [];
  final apk = assets.cast<Map<String, dynamic>>().where((a) => (a['name'] as String).endsWith('.apk'));
  if (apk.isEmpty) return null;
  final atual = int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
  if (build <= atual) return null;
  return Atualizacao(
    (j['name'] as String?) ?? tag,
    build,
    apk.first['browser_download_url'] as String,
    (j['body'] as String?) ?? '',
  );
}

/// Verifica e, se houver versão nova, pergunta ao usuário. [avisarSemNovidade] mostra
/// mensagem quando já está atualizado (usado no botão manual).
Future<void> verificarAtualizacao(BuildContext context, {bool avisarSemNovidade = false}) async {
  Atualizacao? a;
  try {
    a = await buscarAtualizacao();
  } catch (_) {
    if (avisarSemNovidade && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sem internet para verificar atualização.')));
    }
    return;
  }
  if (!context.mounted) return;
  if (a == null) {
    if (avisarSemNovidade) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('O app já está na versão mais nova.')));
    }
    return;
  }
  final atualizar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.system_update, size: 40),
      title: const Text('Nova versão disponível'),
      content: SingleChildScrollView(
        child: Text('${a!.versao}\n\n${a.notas}'.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Depois')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Atualizar')),
      ],
    ),
  );
  if (atualizar != true || !context.mounted) return;
  await showDialog(context: context, barrierDismissible: false, builder: (_) => _Baixando(a!.urlApk));
}

class _Baixando extends StatefulWidget {
  final String url;
  const _Baixando(this.url);

  @override
  State<_Baixando> createState() => _BaixandoState();
}

class _BaixandoState extends State<_Baixando> {
  String status = 'Baixando...';
  double? progresso;
  bool terminou = false;

  @override
  void initState() {
    super.initState();
    OtaUpdate().execute(widget.url, destinationFilename: 'vendas-peixe.apk').listen(
      (e) {
        if (!mounted) return;
        setState(() {
          switch (e.status) {
            case OtaStatus.DOWNLOADING:
              final p = double.tryParse(e.value ?? '');
              progresso = p == null ? null : p / 100;
              status = 'Baixando... ${e.value ?? ''}%';
            case OtaStatus.INSTALLING:
            case OtaStatus.INSTALLATION_DONE:
              status = 'Toque em "Atualizar" na tela do Android para concluir.';
              progresso = 1;
              terminou = true;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              status = 'Permita "instalar apps desconhecidos" para o VDfish e tente de novo.';
              terminou = true;
            default:
              status = 'Não foi possível atualizar (${e.status.name}). Tente mais tarde.';
              terminou = true;
          }
        });
      },
      onError: (Object _) {
        if (mounted) {
          setState(() {
            status = 'Erro ao baixar a atualização.';
            terminou = true;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Atualizando'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        LinearProgressIndicator(value: progresso),
        const SizedBox(height: 16),
        Text(status),
      ]),
      actions: [
        if (terminou) TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
      ],
    );
  }
}
