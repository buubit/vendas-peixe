import 'package:flutter/material.dart';

import '../config.dart';
import '../db.dart';
import '../format.dart';
import '../models.dart';
import '../quinzena.dart';
import '../ui.dart';
import 'pedido_form.dart';

class FechamentoScreen extends StatefulWidget {
  const FechamentoScreen({super.key});

  @override
  State<FechamentoScreen> createState() => _FechamentoScreenState();
}

class _FechamentoScreenState extends State<FechamentoScreen> {
  Quinzena q = Quinzena.de(hoje());
  List<Fechamento> lista = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final l = await Db.fechamentos(quinzena: q);
    l.sort((a, b) => semAcento(a.clienteNome).compareTo(semAcento(b.clienteNome)));
    if (!mounted) return;
    setState(() {
      lista = l;
      carregando = false;
    });
  }

  void _mudar(Quinzena nova) {
    setState(() {
      q = nova;
      carregando = true;
    });
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final total = arred(lista.fold(0.0, (s, f) => s + f.total));
    final recebido = arred(lista.where((f) => f.recebido).fold(0.0, (s, f) => s + f.total));
    return Scaffold(
      appBar: AppBar(title: const Text('Fechamento quinzenal')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            IconButton(onPressed: () => _mudar(q.anterior), icon: const Icon(Icons.chevron_left, size: 32)),
            Expanded(
              child: Column(children: [
                Text(q.rotulo, style: tema.textTheme.titleLarge),
                Text('Pagamento: ${br(AppConfig.vencimento(q))}'),
              ]),
            ),
            IconButton(onPressed: () => _mudar(q.proxima), icon: const Icon(Icons.chevron_right, size: 32)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TotalComissao(
            titulo: 'Total da quinzena',
            total: total,
            comissao: lista.fold(0.0, (s, f) => s + f.comissao),
            extra: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Recebido: ${moeda(recebido)}   ·   A receber: ${moeda(arred(total - recebido))}'),
            ),
          ),
        ),
        if (lista.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => abrirWhatsApp(context, msgResumo(q, lista)),
                icon: const Icon(Icons.send),
                label: const Text('Enviar resumo para a base'),
              ),
            ),
          ),
        Expanded(
          child: carregando
              ? const Center(child: CircularProgressIndicator())
              : lista.isEmpty
                  ? const Center(child: Text('Nenhum pedido nesta quinzena.'))
                  : ListView(children: [
                      for (final f in lista)
                        ListTile(
                          title: Text(f.clienteNome, style: const TextStyle(fontSize: 17)),
                          subtitle: Text.rich(TextSpan(children: [
                            TextSpan(text: '${f.pedidos} pedido(s) · comissão ${moeda(arred(f.comissao))}'),
                            if (f.promos > 0)
                              TextSpan(
                                  text: '\n⚠ ${f.promos} item(ns) com preço promocional',
                                  style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                          ])),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(moeda(f.total), style: tema.textTheme.titleMedium),
                              const SizedBox(height: 2),
                              SituacaoChip(f.situacao),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => FechamentoDetalhePage(clienteId: f.clienteId, quinzena: f.quinzena)));
                            _carregar();
                          },
                        ),
                    ]),
        ),
      ]),
    );
  }
}

/// Todos os pedidos de um cliente numa quinzena, com extrato, cobrança e baixa.
class FechamentoDetalhePage extends StatefulWidget {
  final int clienteId;
  final Quinzena quinzena;
  const FechamentoDetalhePage({super.key, required this.clienteId, required this.quinzena});

  @override
  State<FechamentoDetalhePage> createState() => _FechamentoDetalhePageState();
}

class _FechamentoDetalhePageState extends State<FechamentoDetalhePage> {
  Cliente? cliente;
  List<Pedido> pedidos = [];
  bool recebido = false;
  bool carregando = true;

  Quinzena get q => widget.quinzena;
  double get total => arred(pedidos.fold(0.0, (s, p) => s + p.total));

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    cliente = await Db.cliente(widget.clienteId);
    pedidos = await Db.pedidosEntre(q.inicio, q.fim, clienteId: widget.clienteId);
    recebido = await Db.recebido(widget.clienteId, q);
    if (mounted) setState(() => carregando = false);
  }

  Fechamento get _fech => Fechamento(
        clienteId: widget.clienteId,
        clienteNome: cliente!.nome,
        telefone: cliente!.telefone,
        quinzena: q,
        recebido: recebido,
      )
        ..total = total
        ..comissao = pedidos.fold(0.0, (s, p) => s + p.comissao);

  Future<void> _alternarRecebido() async {
    if (recebido) {
      if (!await confirmar(context, 'Desfazer recebimento?', 'A quinzena volta para "a receber".')) return;
      await Db.desmarcarRecebido(widget.clienteId, q);
    } else {
      if (!await confirmar(context, 'Confirmar recebimento?', '${cliente!.nome}: ${moeda(total)}', ok: 'Recebido')) {
        return;
      }
      await Db.marcarRecebido(widget.clienteId, q, total);
    }
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (carregando || cliente == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final sit = situacaoDe(q, recebido);
    return Scaffold(
      appBar: AppBar(title: Text(cliente!.nome)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          color: tema.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text('Quinzena ${q.rotulo}')), SituacaoChip(sit)]),
              const SizedBox(height: 8),
              Text(moeda(total), style: tema.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text('Minha comissão: ${moeda(arred(_fech.comissao))}',
                  style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
              Text('Pagamento: ${br(AppConfig.vencimento(q))}'),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: pedidos.isEmpty ? null : () => abrirWhatsApp(context, msgExtrato(cliente!.nome, q, pedidos)),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Enviar extrato'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: recebido || pedidos.isEmpty ? null : () => abrirWhatsApp(context, msgCobranca(_fech)),
              icon: const Icon(Icons.notifications_active),
              label: const Text('Cobrar'),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: recebido
              ? OutlinedButton.icon(
                  onPressed: _alternarRecebido, icon: const Icon(Icons.undo), label: const Text('Desfazer recebimento'))
              : FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                  onPressed: pedidos.isEmpty ? null : _alternarRecebido,
                  icon: const Icon(Icons.check),
                  label: const Text('Marcar como recebido'),
                ),
        ),
        const SizedBox(height: 16),
        Text('Pedidos (${pedidos.length}) · toque para editar', style: tema.textTheme.titleMedium),
        for (final p in pedidos)
          Card(
            child: InkWell(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => EditarPedidoPage(pedidoId: p.id!)));
                _carregar();
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(br(p.data), style: tema.textTheme.titleSmall)),
                    Text(moeda(p.total), style: tema.textTheme.titleMedium),
                  ]),
                  for (final i in p.itens) ...[
                    Text('• ${i.nome}: ${i.descricao} = ${moeda(i.subtotal)}'),
                    if (i.promo)
                      Text('   ${i.aviso}', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                  ],
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
