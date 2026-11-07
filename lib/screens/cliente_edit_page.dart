import 'package:flutter/material.dart';

import '../db.dart';
import '../format.dart';
import '../models.dart';
import '../ui.dart';
import 'produto_picker.dart';

/// Cadastro do cliente com a tabela de preços dele. Retorna o cliente salvo.
class ClienteEditPage extends StatefulWidget {
  final Cliente? cliente;
  const ClienteEditPage({super.key, this.cliente});

  @override
  State<ClienteEditPage> createState() => _ClienteEditPageState();
}

class _ClienteEditPageState extends State<ClienteEditPage> {
  late final nomeC = TextEditingController(text: widget.cliente?.nome ?? '');
  late final telC = TextEditingController(text: widget.cliente?.telefone ?? '');
  late final obsC = TextEditingController(text: widget.cliente?.obs ?? '');
  List<Peixe> peixes = [];
  final Map<int, TextEditingController> precoC = {};
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Set<int> originais = {};

  Future<void> _carregar() async {
    peixes = await Db.peixes();
    final pr = widget.cliente?.id == null ? <int, double>{} : await Db.precos(widget.cliente!.id!);
    originais = pr.keys.toSet();
    for (final p in peixes) {
      if (pr[p.id] != null) precoC[p.id!] = TextEditingController(text: precoTxt(pr[p.id]!));
    }
    if (mounted) setState(() => carregando = false);
  }

  Future<void> _adicionarProduto() async {
    final disp = peixes.where((p) => p.ativo && !precoC.containsKey(p.id)).toList();
    final p = await escolherProduto(context, disp);
    if (p == null) return;
    setState(() => precoC[p.id!] = TextEditingController());
  }

  void _removerProduto(int id) {
    setState(() => precoC.remove(id)?.dispose());
  }

  @override
  void dispose() {
    for (final c in [nomeC, telC, obsC, ...precoC.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = nomeC.text.trim();
    if (nome.isEmpty) {
      snack(context, 'Informe o nome do cliente.');
      return;
    }
    final c = widget.cliente ?? Cliente(nome: nome);
    c
      ..nome = nome
      ..telefone = telC.text.trim()
      ..obs = obsC.text.trim();
    await Db.salvarCliente(c);
    for (final id in originais.difference(precoC.keys.toSet())) {
      await Db.removerPreco(c.id!, id);
    }
    for (final e in precoC.entries) {
      final v = lerNumero(e.value.text);
      if (v != null && v > 0) {
        await Db.salvarPreco(c.id!, e.key, v);
      } else {
        await Db.removerPreco(c.id!, e.key);
      }
    }
    if (mounted) Navigator.pop(context, c);
  }

  Future<void> _excluir() async {
    if (!await confirmar(context, 'Excluir cliente?', widget.cliente!.nome, ok: 'Excluir')) return;
    final ok = await Db.excluirCliente(widget.cliente!.id!);
    if (!mounted) return;
    if (!ok) {
      snack(context, 'Este cliente tem pedidos e não pode ser excluído.');
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cliente == null ? 'Novo cliente' : 'Editar cliente'),
        actions: [
          if (widget.cliente != null) IconButton(onPressed: _excluir, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              TextField(
                controller: nomeC,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telC,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefone (opcional)', hintText: '(11) 99999-9999'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: obsC,
                decoration: const InputDecoration(labelText: 'Observação'),
              ),
              const SizedBox(height: 24),
              Text('Preços deste cliente', style: tema.textTheme.titleMedium),
              Text('Também dá para definir o preço na hora do pedido.', style: tema.textTheme.bodySmall),
              const SizedBox(height: 12),
              for (final p in peixes.where((x) => precoC.containsKey(x.id)))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: precoC[p.id],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: '${p.nome} (por ${p.unidade})', prefixText: r'R$ '),
                      ),
                    ),
                    IconButton(onPressed: () => _removerProduto(p.id!), icon: const Icon(Icons.close)),
                  ]),
                ),
              OutlinedButton.icon(
                onPressed: _adicionarProduto,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar produto'),
              ),
            ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 52,
            child: FilledButton(onPressed: carregando ? null : _salvar, child: const Text('Salvar', style: TextStyle(fontSize: 18))),
          ),
        ),
      ),
    );
  }
}
