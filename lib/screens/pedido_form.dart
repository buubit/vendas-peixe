import 'package:flutter/material.dart';

import '../config.dart';
import '../db.dart';
import '../format.dart';
import '../models.dart';
import '../ui.dart';
import 'cliente_picker.dart';
import 'item_dialog.dart';
import 'produto_picker.dart';

/// Formulário de pedido. Sem [pedidoId] é a tela principal (novo pedido + pedidos do dia).
/// Com [pedidoId] edita aquele pedido e fecha a página ao salvar/excluir.
class PedidoForm extends StatefulWidget {
  final int? pedidoId;
  const PedidoForm({super.key, this.pedidoId});

  @override
  State<PedidoForm> createState() => PedidoFormState();
}

class PedidoFormState extends State<PedidoForm> {
  Cliente? cliente;
  DateTime data = hoje();
  final List<ItemPedido> itens = [];
  int? editandoId;
  List<Peixe> peixes = [];
  Map<int, double> precos = {};
  List<Pedido> doDia = [];
  bool carregando = true;

  double? comissaoEditando;

  bool get modoPagina => widget.pedidoId != null;

  Map<int, String> ultimas = {};

  /// Produtos da tabela do cliente, os comprados mais recentemente primeiro.
  List<Peixe> get doCliente {
    final l = peixes.where((p) => precos.containsKey(p.id)).toList();
    l.sort((a, b) => (ultimas[b.id] ?? '').compareTo(ultimas[a.id] ?? ''));
    return l;
  }

  Future<void> _buscarProduto() async {
    final p = await escolherProduto(context, peixes, precos: precos);
    if (p != null && mounted) await _adicionar(p);
  }
  double get total => arred(itens.fold(0.0, (s, i) => s + i.subtotal));

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    peixes = await Db.peixes(soAtivos: true);
    if (widget.pedidoId != null) await _carregarPedido(widget.pedidoId!);
    await _carregarDia();
    if (mounted) setState(() => carregando = false);
  }

  Future<void> recarregar() async {
    peixes = await Db.peixes(soAtivos: true);
    if (cliente != null) {
      cliente = await Db.cliente(cliente!.id!);
      precos = cliente == null ? {} : await Db.precos(cliente!.id!);
      ultimas = cliente == null ? {} : await Db.ultimasCompras(cliente!.id!);
    }
    await _carregarDia();
    if (mounted) setState(() {});
  }

  Future<void> _carregarDia() async {
    if (modoPagina) return;
    doDia = await Db.pedidosEntre(data, data);
  }

  Future<void> _carregarPedido(int id) async {
    final p = await Db.pedido(id);
    if (p == null) return;
    cliente = await Db.cliente(p.clienteId);
    precos = await Db.precos(p.clienteId);
    ultimas = await Db.ultimasCompras(p.clienteId);
    data = p.data;
    itens
      ..clear()
      ..addAll(p.itens);
    editandoId = p.id;
    comissaoEditando = p.comissaoPct;
  }

  Future<void> _escolherCliente() async {
    final c = await escolherCliente(context);
    if (c == null) return;
    final pr = await Db.precos(c.id!);
    ultimas = await Db.ultimasCompras(c.id!);
    peixes = await Db.peixes(soAtivos: true);
    setState(() {
      cliente = c;
      precos = pr;
    });
  }

  Future<void> _escolherData() async {
    final d = await showDatePicker(
        context: context, initialDate: data, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d == null) return;
    data = DateTime(d.year, d.month, d.day);
    await _carregarDia();
    if (mounted) setState(() {});
  }

  Future<void> _aplicarItem((ItemPedido, bool)? r, {int? indice}) async {
    if (r == null) return;
    final (item, salvar) = r;
    if (salvar) {
      await Db.salvarPreco(cliente!.id!, item.peixeId, item.preco);
      precos[item.peixeId] = item.preco;
    }
    setState(() {
      if (indice == null) {
        itens.add(item);
      } else {
        itens[indice] = item;
      }
    });
  }

  Future<void> _adicionar(Peixe p) async {
    final r = await dialogItem(context, p, precos[p.id]);
    await _aplicarItem(r);
  }

  Future<void> _editarItem(int i) async {
    final it = itens[i];
    final p = peixes.firstWhere((x) => x.id == it.peixeId,
        orElse: () => Peixe(id: it.peixeId, nome: it.nome, unidade: it.unidade));
    final r = await dialogItem(context, p, precos[p.id], atual: it);
    await _aplicarItem(r, indice: i);
  }

  void _limpar() {
    setState(() {
      cliente = null;
      precos = {};
      itens.clear();
      editandoId = null;
      comissaoEditando = null;
    });
  }

  Future<void> _salvar() async {
    final ped = Pedido(
      id: editandoId,
      clienteId: cliente!.id!,
      clienteNome: cliente!.nome,
      clienteTelefone: cliente!.telefone,
      data: data,
      itens: List.of(itens),
      comissaoPct: comissaoEditando ?? AppConfig.comissao,
    );
    final eraNovo = editandoId == null;
    ped.id = await Db.salvarPedido(ped);
    if (!mounted) return;
    final enviar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: Text(eraNovo ? 'Pedido salvo' : 'Pedido atualizado'),
        content: Text(
            '${ped.clienteNome}\nTotal: ${moeda(ped.total)}\nComissão: ${moeda(arred(ped.comissao))}\n'
            'Pagamento: ${br(AppConfig.vencimento(ped.quinzena))}',
            style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('OK')),
          FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.send),
              label: const Text('WhatsApp')),
        ],
      ),
    );
    if (!mounted) return;
    if (enviar == true) await abrirWhatsApp(context, msgPedido(ped));
    if (!mounted) return;
    if (modoPagina) {
      Navigator.pop(context, true);
      return;
    }
    _limpar();
    await _carregarDia();
    if (mounted) setState(() {});
  }

  Future<void> _excluirPedido(int id) async {
    if (!await confirmar(context, 'Excluir pedido?', 'Essa ação não pode ser desfeita.', ok: 'Excluir')) return;
    await Db.excluirPedido(id);
    if (!mounted) return;
    if (modoPagina) {
      Navigator.pop(context, true);
      return;
    }
    _limpar();
    await _carregarDia();
    if (mounted) setState(() {});
  }

  Future<void> _editarDoDia(Pedido p) async {
    await _carregarPedido(p.id!);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) return const Center(child: CircularProgressIndicator());
    final tema = Theme.of(context);
    final ehHoje = data == hoje();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (editandoId != null && !modoPagina)
          Card(
            color: tema.colorScheme.tertiaryContainer,
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: Text('Editando pedido nº $editandoId'),
              trailing: TextButton(onPressed: _limpar, child: const Text('Cancelar')),
            ),
          ),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(child: Icon(cliente == null ? Icons.person_search : Icons.person)),
            title: Text(cliente?.nome ?? 'Escolher cliente', style: tema.textTheme.titleLarge),
            subtitle: Text(cliente == null
                ? 'Toque para escolher'
                : (cliente!.obs.isEmpty ? 'Toque para trocar' : cliente!.obs)),
            onTap: _escolherCliente,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: const Icon(Icons.calendar_today, size: 18),
            label: Text(ehHoje ? 'Hoje, ${br(data)}' : br(data)),
            onPressed: _escolherData,
          ),
        ),
        if (cliente != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _buscarProduto,
              icon: const Icon(Icons.search),
              label: const Text('Buscar produto', style: TextStyle(fontSize: 17)),
            ),
          ),
          const SizedBox(height: 12),
          if (doCliente.isNotEmpty) ...[
            Text('Produtos recentes', style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
          ],
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.0,
            children: [
              for (final p in doCliente)
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(8),
                  ),
                  onPressed: () => _adicionar(p),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(p.nome,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    Text(precos[p.id] != null ? '${moeda(precos[p.id]!)}/${p.unidade}' : 'sem preço',
                        style: const TextStyle(fontSize: 13)),
                  ]),
                ),
            ],
          ),
        ],
        if (itens.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Column(children: [
              for (var i = 0; i < itens.length; i++)
                ListTile(
                  title: Text(itens[i].nome),
                  subtitle: Text.rich(TextSpan(children: [
                    TextSpan(text: itens[i].descricao),
                    if (itens[i].promo)
                      TextSpan(
                          text: '\n${itens[i].aviso}',
                          style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                  ])),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(moeda(itens[i].subtotal), style: tema.textTheme.titleMedium),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => itens.removeAt(i))),
                  ]),
                  onTap: () => _editarItem(i),
                ),
              const Divider(height: 1),
              ListTile(
                title: Text('TOTAL', style: tema.textTheme.titleLarge),
                trailing: Text(moeda(total),
                    style: tema.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold, color: tema.colorScheme.primary)),
              ),
            ]),
          ),
        ],
        if (cliente != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: itens.isEmpty ? null : _salvar,
              icon: const Icon(Icons.check),
              label: Text(editandoId == null ? 'SALVAR PEDIDO' : 'SALVAR ALTERAÇÕES',
                  style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
        if (editandoId != null)
          TextButton.icon(
            onPressed: () => _excluirPedido(editandoId!),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Excluir pedido', style: TextStyle(color: Colors.red)),
          ),
        if (!modoPagina) ...[
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: Text(ehHoje ? 'Pedidos de hoje' : 'Pedidos de ${br(data)}',
                    style: tema.textTheme.titleMedium)),
            Text('${doDia.length} · ${moeda(arred(doDia.fold(0.0, (s, p) => s + p.total)))}',
                style: tema.textTheme.titleMedium),
          ]),
          if (doDia.isNotEmpty)
            Text('Minha comissão: ${moeda(arred(doDia.fold(0.0, (s, p) => s + p.comissao)))}',
                style: tema.textTheme.titleSmall?.copyWith(color: Colors.green.shade800)),
          Text('Toque para editar · segure para enviar no WhatsApp', style: tema.textTheme.bodySmall),
          const SizedBox(height: 4),
          if (doDia.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Nenhum pedido lançado.')),
          for (final p in doDia.reversed)
            Card(
              child: ListTile(
                title: Text(p.clienteNome),
                subtitle: Text(p.itens.map((i) => '${i.nome} ${numero(i.qtd)}${i.unidade}${i.promo ? ' ⚠PROMO' : ''}').join(', ')),
                trailing: Text(moeda(p.total), style: tema.textTheme.titleMedium),
                onTap: () => _editarDoDia(p),
                onLongPress: () => abrirWhatsApp(context, msgPedido(p)),
              ),
            ),
        ],
      ],
    );
  }
}

class EditarPedidoPage extends StatelessWidget {
  final int pedidoId;
  const EditarPedidoPage({super.key, required this.pedidoId});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Editar pedido')),
        body: PedidoForm(pedidoId: pedidoId),
      );
}
