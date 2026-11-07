import 'package:flutter/material.dart';

import '../db.dart';
import '../format.dart';
import '../models.dart';
import '../quinzena.dart';
import '../ui.dart';

enum Periodo { dia, semana, quinzena, mes }

class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({super.key});

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatoriosPage> {
  Periodo periodo = Periodo.dia;
  DateTime ref = hoje();
  List<Pedido> pedidos = [];

  (DateTime, DateTime) get intervalo => switch (periodo) {
        Periodo.dia => (ref, ref),
        Periodo.semana => (
            DateTime(ref.year, ref.month, ref.day - (ref.weekday - 1)),
            DateTime(ref.year, ref.month, ref.day - (ref.weekday - 1) + 6)
          ),
        Periodo.quinzena => (Quinzena.de(ref).inicio, Quinzena.de(ref).fim),
        Periodo.mes => (DateTime(ref.year, ref.month, 1), DateTime(ref.year, ref.month + 1, 0)),
      };

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final (a, b) = intervalo;
    final l = await Db.pedidosEntre(a, b);
    if (mounted) setState(() => pedidos = l);
  }

  void _mover(int dir) {
    ref = switch (periodo) {
      Periodo.dia => DateTime(ref.year, ref.month, ref.day + dir),
      Periodo.semana => DateTime(ref.year, ref.month, ref.day + 7 * dir),
      Periodo.quinzena => dir > 0 ? Quinzena.de(ref).proxima.inicio : Quinzena.de(ref).anterior.inicio,
      Periodo.mes => DateTime(ref.year, ref.month + dir, 1),
    };
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final (a, b) = intervalo;
    final total = arred(pedidos.fold(0.0, (s, p) => s + p.total));

    final porCliente = <String, double>{};
    final comCliente = <String, double>{};
    final porPeixe = <String, (double qtd, String un, double valor)>{};
    for (final p in pedidos) {
      porCliente[p.clienteNome] = (porCliente[p.clienteNome] ?? 0) + p.total;
      comCliente[p.clienteNome] = (comCliente[p.clienteNome] ?? 0) + p.comissao;
      for (final i in p.itens) {
        final atual = porPeixe[i.nome] ?? (0.0, i.unidade, 0.0);
        porPeixe[i.nome] = (atual.$1 + i.qtd, i.unidade, atual.$3 + i.subtotal);
      }
    }
    final promos = [
      for (final p in pedidos)
        for (final i in p.itens)
          if (i.promo) (p, i),
    ];
    final clientes = porCliente.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
    final peixes = porPeixe.entries.toList()..sort((x, y) => y.value.$3.compareTo(x.value.$3));

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<Periodo>(
          segments: const [
            ButtonSegment(value: Periodo.dia, label: Text('Dia')),
            ButtonSegment(value: Periodo.semana, label: Text('Semana')),
            ButtonSegment(value: Periodo.quinzena, label: Text('Quinz.')),
            ButtonSegment(value: Periodo.mes, label: Text('Mês')),
          ],
          selected: {periodo},
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            periodo = s.first;
            _carregar();
          },
        ),
        Row(children: [
          IconButton(onPressed: () => _mover(-1), icon: const Icon(Icons.chevron_left, size: 32)),
          Expanded(
            child: Text(a == b ? br(a) : '${br(a)} a ${br(b)}',
                textAlign: TextAlign.center, style: tema.textTheme.titleMedium),
          ),
          IconButton(onPressed: () => _mover(1), icon: const Icon(Icons.chevron_right, size: 32)),
        ]),
        TotalComissao(
          titulo: 'Total vendido',
          total: total,
          comissao: pedidos.fold(0.0, (s, p) => s + p.comissao),
          extra: Padding(padding: const EdgeInsets.only(top: 8), child: Text('${pedidos.length} pedido(s)')),
        ),
        if (promos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('⚠ ${ItemPedido.avisoPromo} (${promos.length})',
                    style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                for (final (p, i) in promos)
                  Text('${brCurto(p.data)} · ${p.clienteNome} · ${i.nome}: ${moeda(i.preco)}'
                      '${i.precoTabela != null ? ' (tabela ${moeda(i.precoTabela!)})' : ''}'),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text('Por cliente', style: tema.textTheme.titleMedium),
        if (clientes.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Sem vendas no período.')),
        for (final e in clientes)
          ListTile(
            dense: true,
            title: Text(e.key),
            subtitle: Text('Comissão: ${moeda(arred(comCliente[e.key] ?? 0))}'),
            trailing: Text(moeda(arred(e.value)), style: tema.textTheme.titleSmall),
          ),
        const SizedBox(height: 16),
        Text('Por peixe', style: tema.textTheme.titleMedium),
        if (peixes.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Sem vendas no período.')),
        for (final e in peixes)
          ListTile(
            dense: true,
            title: Text(e.key),
            subtitle: Text('${numero(e.value.$1)} ${e.value.$2}'),
            trailing: Text(moeda(arred(e.value.$3)), style: tema.textTheme.titleSmall),
          ),
      ]),
    );
  }
}
