import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'format.dart';
import 'models.dart';
import 'quinzena.dart';

void snack(BuildContext context, String texto) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

Future<bool> confirmar(BuildContext context, String titulo, String msg, {String ok = 'Confirmar'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

/// Abre a conversa do WhatsApp da BASE com a mensagem pronta.
Future<void> abrirWhatsApp(BuildContext context, String texto) async {
  var dig = AppConfig.whatsBase.replaceAll(RegExp(r'\D'), '');
  if (dig.isNotEmpty && !(dig.startsWith('55') && dig.length >= 12)) dig = '55$dig';
  final uri = dig.isEmpty
      ? Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texto)}')
      : Uri.parse('https://wa.me/$dig?text=${Uri.encodeComponent(texto)}');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) snack(context, 'Não foi possível abrir o WhatsApp.');
}

String msgPedido(Pedido p) {
  final b = StringBuffer('*Pedido ${br(p.data)}*\n${p.clienteNome}\n\n');
  for (final i in p.itens) {
    b.writeln('• ${i.nome}: ${i.descricao} = ${moeda(i.subtotal)}');
    if (i.promo) b.writeln('   *${i.aviso}*');
  }
  final q = p.quinzena;
  b.write('\n*Total: ${moeda(p.total)}*\n');
  b.write('Fechamento: ${q.rotulo}\nPagamento: ${br(AppConfig.vencimento(q))}');
  return b.toString();
}

String msgExtrato(String nome, Quinzena q, List<Pedido> peds) {
  final b = StringBuffer('*Extrato ${q.rotulo}*\n$nome\n');
  var total = 0.0;
  for (final p in peds) {
    b.write('\n*${brCurto(p.data)}* — ${moeda(p.total)}\n');
    for (final i in p.itens) {
      b.writeln('   • ${i.nome}: ${i.descricao}');
      if (i.promo) b.writeln('     *${i.aviso}*');
    }
    total += p.total;
  }
  b.write('\n*TOTAL: ${moeda(arred(total))}*\n');
  b.write('Pagamento: ${br(AppConfig.vencimento(q))}');
  return b.toString();
}

String msgCobranca(Fechamento f) {
  final venc = br(f.vencimento);
  final vencido = f.situacao == Situacao.vencido;
  return '*Cobrança — ${f.clienteNome}*\n'
      'Fechamento: ${f.quinzena.rotulo}\n'
      'Valor: *${moeda(f.total)}*\n'
      'Pagamento: $venc${vencido ? ' (VENCIDO)' : ''}';
}

/// Resumo da quinzena com todos os clientes, total e comissão.
String msgResumo(Quinzena q, List<Fechamento> lista) {
  final b = StringBuffer('*Resumo da quinzena ${q.rotulo}*\n\n');
  var total = 0.0, com = 0.0;
  for (final f in lista) {
    b.writeln('• ${f.clienteNome}: ${moeda(f.total)}${f.recebido ? ' ✅' : ''}'
        '${f.promos > 0 ? ' ⚠ ${ItemPedido.avisoPromo}' : ''}');
    total += f.total;
    com += f.comissao;
  }
  b.write('\n*Total vendido: ${moeda(arred(total))}*\n');
  b.write('*Comissão: ${moeda(arred(com))}*\n');
  b.write('Pagamento: ${br(AppConfig.vencimento(q))}');
  return b.toString();
}

String pctTxt(double p) => '${numero(p)}%';

/// Linha "Total / Comissão" usada no balancete.
class TotalComissao extends StatelessWidget {
  final String titulo;
  final double total;
  final double comissao;
  final Widget? extra;
  const TotalComissao({super.key, required this.titulo, required this.total, required this.comissao, this.extra});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      color: tema.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo),
                Text(moeda(arred(total)),
                    style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Minha comissão'),
              Text(moeda(arred(comissao)),
                  style: tema.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
            ]),
          ]),
          ?extra,
        ]),
      ),
    );
  }
}

class SituacaoChip extends StatelessWidget {
  final Situacao situacao;
  const SituacaoChip(this.situacao, {super.key});

  @override
  Widget build(BuildContext context) {
    final (String txt, MaterialColor cor) = switch (situacao) {
      Situacao.andamento => ('Quinzena aberta', Colors.blueGrey),
      Situacao.emDia => ('Em dia', Colors.green),
      Situacao.venceLogo => ('Vence logo', Colors.orange),
      Situacao.vencido => ('VENCIDO', Colors.red),
      Situacao.recebido => ('Recebido', Colors.teal),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: cor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(txt, style: TextStyle(color: cor.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

String nomeUnidade(String u) => switch (u) { 'un' => 'unidade', 'cx' => 'caixa', _ => 'kg' };
