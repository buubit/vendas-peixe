import 'package:flutter/material.dart';

import '../db.dart';
import '../format.dart';
import '../models.dart';
import '../ui.dart';
import 'fechamento_screen.dart';

class AReceberScreen extends StatefulWidget {
  const AReceberScreen({super.key});

  @override
  State<AReceberScreen> createState() => _AReceberScreenState();
}

class _AReceberScreenState extends State<AReceberScreen> {
  List<Fechamento> lista = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final l = await Db.fechamentos(soAbertos: true);
    if (!mounted) return;
    setState(() {
      lista = l;
      carregando = false;
    });
  }

  Future<void> _receber(Fechamento f) async {
    if (!await confirmar(context, 'Confirmar recebimento?', '${f.clienteNome}\n${f.quinzena.rotulo}: ${moeda(f.total)}',
        ok: 'Recebido')) {
      return;
    }
    await Db.marcarRecebido(f.clienteId, f.quinzena, f.total);
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final total = arred(lista.fold(0.0, (s, f) => s + f.total));
    final vencido = arred(lista.where((f) => f.situacao == Situacao.vencido).fold(0.0, (s, f) => s + f.total));
    return Scaffold(
      appBar: AppBar(title: const Text('A receber')),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  Expanded(
                    child: Card(
                      color: tema.colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Total a receber'),
                          Text(moeda(total), style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Comissão: ${moeda(arred(lista.fold(0.0, (s, f) => s + f.comissao)))}',
                              style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Card(
                      color: vencido > 0 ? Colors.red.shade100 : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Vencido'),
                          Text(moeda(vencido),
                              style: tema.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold, color: vencido > 0 ? Colors.red.shade800 : null)),
                        ]),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                if (lista.isEmpty)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Nada a receber. 🎉'))),
                for (final f in lista)
                  Card(
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => FechamentoDetalhePage(clienteId: f.clienteId, quinzena: f.quinzena)));
                        _carregar();
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(f.clienteNome, style: tema.textTheme.titleMedium)),
                            Text(moeda(f.total), style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            Expanded(child: Text('${f.quinzena.rotulo}\nPagamento: ${br(f.vencimento)}')),
                            SituacaoChip(f.situacao),
                          ]),
                          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            TextButton.icon(
                              onPressed: () => abrirWhatsApp(context, msgCobranca(f)),
                              icon: const Icon(Icons.notifications_active),
                              label: const Text('Cobrar'),
                            ),
                            TextButton.icon(
                              onPressed: () => _receber(f),
                              icon: const Icon(Icons.check),
                              label: const Text('Recebido'),
                            ),
                          ]),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
    );
  }
}
