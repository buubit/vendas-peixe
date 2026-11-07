import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';

/// Lista de produtos com busca, agrupada por categoria.
Future<Peixe?> escolherProduto(BuildContext context, List<Peixe> produtos, {Map<int, double> precos = const {}}) =>
    showModalBottomSheet<Peixe>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProdutoPicker(produtos: produtos, precos: precos),
    );

class _ProdutoPicker extends StatefulWidget {
  final List<Peixe> produtos;
  final Map<int, double> precos;
  const _ProdutoPicker({required this.produtos, required this.precos});

  @override
  State<_ProdutoPicker> createState() => _ProdutoPickerState();
}

class _ProdutoPickerState extends State<_ProdutoPicker> {
  String filtro = '';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final termos = semAcento(filtro).split(' ').where((t) => t.isNotEmpty).toList();
    final lista = widget.produtos.where((p) {
      final n = semAcento('${p.nome} ${p.categoria}');
      return termos.every(n.contains);
    }).toList();

    final filhos = <Widget>[];
    String? cat;
    for (final p in lista) {
      if (p.categoria != cat) {
        cat = p.categoria;
        filhos.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(cat.isEmpty ? 'Outros' : cat,
              style: tema.textTheme.titleSmall?.copyWith(color: tema.colorScheme.primary)),
        ));
      }
      final preco = widget.precos[p.id];
      filhos.add(ListTile(
        title: Text(p.nome),
        trailing: Text(preco != null ? '${moeda(preco)}/${p.unidade}' : '',
            style: tema.textTheme.titleSmall),
        onTap: () => Navigator.pop(context, p),
      ));
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar produto (ex.: tilapia fresca)'),
              onChanged: (v) => setState(() => filtro = v),
            ),
          ),
          Expanded(
            child: lista.isEmpty
                ? const Center(child: Text('Nenhum produto encontrado.'))
                : ListView(children: filhos),
          ),
        ]),
      ),
    );
  }
}
