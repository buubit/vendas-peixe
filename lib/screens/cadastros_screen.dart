import 'package:flutter/material.dart';

import '../catalogo.dart';
import '../db.dart';
import '../format.dart';
import '../models.dart';
import '../ui.dart';
import 'cliente_edit_page.dart';

class CadastrosScreen extends StatelessWidget {
  const CadastrosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cadastros'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.people), text: 'Clientes'),
            Tab(icon: Icon(Icons.set_meal), text: 'Produtos'),
          ]),
        ),
        body: const TabBarView(children: [_ClientesTab(), _PeixesTab()]),
      ),
    );
  }
}

class _ClientesTab extends StatefulWidget {
  const _ClientesTab();

  @override
  State<_ClientesTab> createState() => _ClientesTabState();
}

class _ClientesTabState extends State<_ClientesTab> {
  List<Cliente> lista = [];
  String filtro = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    lista = await Db.clientes();
    if (mounted) setState(() {});
  }

  Future<void> _abrir([Cliente? c]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ClienteEditPage(cliente: c)));
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final f = semAcento(filtro);
    final l = f.isEmpty ? lista : lista.where((c) => semAcento(c.nome).contains(f)).toList();
    return Scaffold(
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar cliente', isDense: true),
            onChanged: (v) => setState(() => filtro = v),
          ),
        ),
        Expanded(
          child: l.isEmpty
              ? const Center(child: Text('Nenhum cliente. Toque em "Novo cliente".'))
              : ListView(padding: const EdgeInsets.only(bottom: 88), children: [
                  for (final c in l)
                    ListTile(
                      leading: CircleAvatar(child: Text(c.nome.isEmpty ? '?' : c.nome[0].toUpperCase())),
                      title: Text(c.nome),
                      subtitle: Text([c.telefone, c.obs].where((s) => s.isNotEmpty).join(' · ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _abrir(c),
                    ),
                ]),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'novo_cliente',
        onPressed: () => _abrir(),
        icon: const Icon(Icons.person_add),
        label: const Text('Novo cliente'),
      ),
    );
  }
}

class _PeixesTab extends StatefulWidget {
  const _PeixesTab();

  @override
  State<_PeixesTab> createState() => _PeixesTabState();
}

class _PeixesTabState extends State<_PeixesTab> {
  List<Peixe> lista = [];
  String filtro = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    lista = await Db.peixes();
    if (mounted) setState(() {});
  }

  Future<void> _abrir([Peixe? p]) async {
    final cats = {...ordemCategorias, ...lista.map((x) => x.categoria).where((c) => c.isNotEmpty)}.toList();
    await showDialog(context: context, builder: (_) => _PeixeDialog(peixe: p, categorias: cats));
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final termos = semAcento(filtro).split(' ').where((t) => t.isNotEmpty).toList();
    final l = lista.where((p) => termos.every(semAcento('${p.nome} ${p.categoria}').contains)).toList();
    final filhos = <Widget>[];
    String? cat;
    for (final p in l) {
      if (p.categoria != cat) {
        cat = p.categoria;
        filhos.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(cat.isEmpty ? 'Outros' : cat,
              style: tema.textTheme.titleSmall?.copyWith(color: tema.colorScheme.primary)),
        ));
      }
      filhos.add(ListTile(
        dense: true,
        title: Text(p.nome, style: TextStyle(color: p.ativo ? null : Colors.grey)),
        subtitle: Text('por ${nomeUnidade(p.unidade)}${p.ativo ? '' : ' · inativo'}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _abrir(p),
      ));
    }
    return Scaffold(
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search), hintText: 'Buscar produto (${lista.length})', isDense: true),
            onChanged: (v) => setState(() => filtro = v),
          ),
        ),
        Expanded(
          child: l.isEmpty
              ? const Center(child: Text('Nenhum produto encontrado.'))
              : ListView(padding: const EdgeInsets.only(bottom: 88), children: filhos),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'novo_peixe',
        onPressed: () => _abrir(),
        icon: const Icon(Icons.add),
        label: const Text('Novo produto'),
      ),
    );
  }
}

class _PeixeDialog extends StatefulWidget {
  final Peixe? peixe;
  final List<String> categorias;
  const _PeixeDialog({this.peixe, required this.categorias});

  @override
  State<_PeixeDialog> createState() => _PeixeDialogState();
}

class _PeixeDialogState extends State<_PeixeDialog> {
  late final nomeC = TextEditingController(text: widget.peixe?.nome ?? '');
  late String unidade = widget.peixe?.unidade ?? 'kg';
  late bool ativo = widget.peixe?.ativo ?? true;
  late String categoria = widget.peixe?.categoria ?? '';

  @override
  void dispose() {
    nomeC.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = nomeC.text.trim();
    if (nome.isEmpty) return;
    final p = widget.peixe ?? Peixe(nome: nome);
    p
      ..nome = nome
      ..unidade = unidade
      ..ativo = ativo
      ..categoria = categoria;
    await Db.salvarPeixe(p);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _excluir() async {
    if (!await confirmar(context, 'Excluir peixe?', widget.peixe!.nome, ok: 'Excluir')) return;
    final excluido = await Db.excluirPeixe(widget.peixe!.id!);
    if (!mounted) return;
    if (!excluido) snack(context, 'Este peixe já tem vendas, então foi apenas desativado.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.peixe == null ? 'Novo produto' : 'Editar produto'),
      content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: nomeC,
          autofocus: widget.peixe == null,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: categoria,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Categoria'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Outros')),
            for (final c in widget.categorias) DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) => setState(() => categoria = v ?? ''),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: unidade,
          decoration: const InputDecoration(labelText: 'Vendido por'),
          items: const [
            DropdownMenuItem(value: 'kg', child: Text('kg')),
            DropdownMenuItem(value: 'un', child: Text('unidade')),
            DropdownMenuItem(value: 'cx', child: Text('caixa')),
          ],
          onChanged: (v) => setState(() => unidade = v ?? 'kg'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ativo'),
          subtitle: const Text('Inativo some da tela de pedido'),
          value: ativo,
          onChanged: (v) => setState(() => ativo = v),
        ),
      ])),
      actions: [
        if (widget.peixe != null)
          TextButton(onPressed: _excluir, child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}
