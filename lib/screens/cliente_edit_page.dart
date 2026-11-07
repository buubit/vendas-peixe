import 'package:flutter/material.dart';

import '../db.dart';
import '../format.dart';
import '../models.dart';
import '../ui.dart';
import 'produto_picker.dart';

/// Cadastro do cliente + preços da tabela dele. Retorna o cliente salvo.
/// Os preços são gravados na hora (ao adicionar/alterar/remover).
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
  late Cliente? cliente = widget.cliente;
  List<Peixe> peixes = [];
  Map<int, double> precos = {};
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    peixes = await Db.peixes();
    precos = cliente?.id == null ? {} : await Db.precos(cliente!.id!);
    if (mounted) setState(() => carregando = false);
  }

  @override
  void dispose() {
    nomeC.dispose();
    telC.dispose();
    obsC.dispose();
    super.dispose();
  }

  /// Grava nome/telefone/obs. Retorna false se faltar o nome.
  Future<bool> _gravarDados() async {
    final nome = nomeC.text.trim();
    if (nome.isEmpty) {
      snack(context, 'Informe o nome do cliente primeiro.');
      return false;
    }
    final c = cliente ?? Cliente(nome: nome);
    c
      ..nome = nome
      ..telefone = telC.text.trim()
      ..obs = obsC.text.trim();
    await Db.salvarCliente(c);
    cliente = c;
    return true;
  }

  bool get _alterado =>
      nomeC.text.trim() != (cliente?.nome ?? '') ||
      telC.text.trim() != (cliente?.telefone ?? '') ||
      obsC.text.trim() != (cliente?.obs ?? '');

  Future<double?> _pedirPreco(Peixe p, double? atual) async {
    final c = TextEditingController(text: atual != null ? precoTxt(atual) : '');
    final r = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p.nome),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(fontSize: 22),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Preço para este cliente (por ${p.unidade})', prefixText: r'R$ '),
          onSubmitted: (t) => Navigator.pop(ctx, lerNumero(t)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, lerNumero(c.text)), child: const Text('Salvar')),
        ],
      ),
    );
    c.dispose();
    return r;
  }

  Future<void> _definirPreco(Peixe p) async {
    if (!await _gravarDados()) return;
    final v = await _pedirPreco(p, precos[p.id]);
    if (v == null) return;
    if (v <= 0) {
      if (mounted) snack(context, 'Preço inválido.');
      return;
    }
    await Db.salvarPreco(cliente!.id!, p.id!, v);
    setState(() => precos[p.id!] = v);
    if (mounted) snack(context, '${p.nome}: ${moeda(v)} salvo.');
  }

  Future<void> _adicionarProduto() async {
    final disp = peixes.where((p) => p.ativo && !precos.containsKey(p.id)).toList();
    final p = await escolherProduto(context, disp);
    if (p != null && mounted) await _definirPreco(p);
  }

  Future<void> _removerProduto(Peixe p) async {
    if (!await confirmar(context, 'Remover preço?', '${p.nome} sai da tabela deste cliente.', ok: 'Remover')) {
      return;
    }
    await Db.removerPreco(cliente!.id!, p.id!);
    setState(() => precos.remove(p.id));
  }

  Future<void> _salvarESair() async {
    if (!await _gravarDados()) return;
    if (mounted) Navigator.pop(context, cliente);
  }

  Future<void> _excluir() async {
    if (!await confirmar(context, 'Excluir cliente?', cliente!.nome, ok: 'Excluir')) return;
    final ok = await Db.excluirCliente(cliente!.id!);
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
    final comPreco = peixes.where((x) => precos.containsKey(x.id)).toList();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_alterado && nomeC.text.trim().isNotEmpty) await _gravarDados();
        if (context.mounted) Navigator.of(context).pop(cliente);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.cliente == null ? 'Novo cliente' : 'Editar cliente'),
          actions: [
            if (cliente?.id != null) IconButton(onPressed: _excluir, icon: const Icon(Icons.delete_outline)),
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
                Text('Tabela de preços deste cliente', style: tema.textTheme.titleMedium),
                Text('Coloque só os produtos que ele compra. Toque no produto para mudar o preço.',
                    style: tema.textTheme.bodySmall),
                const SizedBox(height: 8),
                if (comPreco.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Nenhum produto ainda.')),
                for (final p in comPreco)
                  Card(
                    child: ListTile(
                      title: Text(p.nome),
                      subtitle: Text(p.categoria),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('${moeda(precos[p.id]!)}/${p.unidade}', style: tema.textTheme.titleMedium),
                        IconButton(onPressed: () => _removerProduto(p), icon: const Icon(Icons.close)),
                      ]),
                      onTap: () => _definirPreco(p),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _adicionarProduto,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar produto'),
                  ),
                ),
              ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                  onPressed: carregando ? null : _salvarESair,
                  child: const Text('Salvar', style: TextStyle(fontSize: 18))),
            ),
          ),
        ),
      ),
    );
  }
}
