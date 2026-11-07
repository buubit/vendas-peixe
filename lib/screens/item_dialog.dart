import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';

/// Retorna o item e se o preço deve ser salvo como preço do cliente.
Future<(ItemPedido, bool)?> dialogItem(BuildContext context, Peixe peixe, double? precoCliente,
    {ItemPedido? atual}) {
  return showDialog<(ItemPedido, bool)>(
    context: context,
    builder: (_) => _ItemDialog(peixe: peixe, precoCliente: precoCliente, atual: atual),
  );
}

class _ItemDialog extends StatefulWidget {
  final Peixe peixe;
  final double? precoCliente;
  final ItemPedido? atual;
  const _ItemDialog({required this.peixe, this.precoCliente, this.atual});

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late final qtdC = TextEditingController(text: widget.atual != null ? numero(widget.atual!.qtd) : '');
  late final precoC = TextEditingController(
      text: (widget.atual?.preco ?? widget.precoCliente) != null
          ? precoTxt(widget.atual?.preco ?? widget.precoCliente!)
          : '');
  late bool salvarPreco = widget.precoCliente == null;

  double? get qtd => lerNumero(qtdC.text);
  double? get preco => lerNumero(precoC.text);

  void _ok() {
    final q = qtd, p = preco;
    if (q == null || q <= 0 || p == null || p <= 0) return;
    final item = ItemPedido(
        peixeId: widget.peixe.id!, nome: widget.peixe.nome, unidade: widget.peixe.unidade, qtd: q, preco: p);
    final mudou = widget.precoCliente == null || (p - widget.precoCliente!).abs() > 0.001;
    Navigator.pop(context, (item, mudou && salvarPreco));
  }

  @override
  void dispose() {
    qtdC.dispose();
    precoC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.peixe.unidade;
    final q = qtd, p = preco;
    final sub = (q != null && p != null) ? arred(q * p) : null;
    final mostrarCheck = p != null && (widget.precoCliente == null || (p - widget.precoCliente!).abs() > 0.001);
    return AlertDialog(
      title: Text(widget.peixe.nome),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: qtdC,
              autofocus: true,
              style: const TextStyle(fontSize: 24),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Quantidade', suffixText: u),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _ok(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: precoC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Preço por $u',
                prefixText: r'R$ ',
                helperText: widget.precoCliente == null ? 'Cliente ainda sem preço para este peixe' : null,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _ok(),
            ),
            if (mostrarCheck)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: salvarPreco,
                onChanged: (v) => setState(() => salvarPreco = v ?? false),
                title: const Text('Salvar como preço deste cliente'),
              ),
            const SizedBox(height: 12),
            Text(sub == null ? 'Subtotal: —' : 'Subtotal: ${moeda(sub)}',
                style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.right),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: sub == null || sub <= 0 ? null : _ok, child: const Text('Adicionar')),
      ],
    );
  }
}
