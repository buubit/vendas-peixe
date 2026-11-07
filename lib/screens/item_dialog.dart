import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';

/// Retorna o item e se o preço deve ser salvo na tabela do cliente.
///
/// - Produto COM preço na tabela do cliente: o preço vem travado. Marcando
///   "Preço promocional / fora da tabela" dá para mudar só neste pedido, e o
///   item fica marcado com aviso no balanço.
/// - Produto SEM preço para o cliente: digita o preço e pode salvar na tabela dele.
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
  late final bool temTabela = widget.precoCliente != null;
  late bool promo = widget.atual?.promo ?? false;
  late bool salvarNaTabela = true;
  late final qtdC = TextEditingController(text: widget.atual != null ? numero(widget.atual!.qtd) : '');
  late final precoC = TextEditingController(text: _precoInicial());

  String _precoInicial() {
    final p = widget.atual?.preco ?? widget.precoCliente;
    return p != null ? precoTxt(p) : '';
  }

  double? get qtd => lerNumero(qtdC.text);
  double? get preco => temTabela && !promo ? widget.precoCliente : lerNumero(precoC.text);

  void _ok() {
    final q = qtd, p = preco;
    if (q == null || q <= 0 || p == null || p <= 0) return;
    final ehPromo = temTabela && promo && (p - widget.precoCliente!).abs() > 0.001;
    final item = ItemPedido(
      peixeId: widget.peixe.id!,
      nome: widget.peixe.nome,
      unidade: widget.peixe.unidade,
      qtd: q,
      preco: p,
      promo: ehPromo,
      precoTabela: ehPromo ? widget.precoCliente : null,
    );
    Navigator.pop(context, (item, !temTabela && salvarNaTabela));
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
    final travado = temTabela && !promo;
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
              enabled: !travado,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: travado ? 'Preço da tabela do cliente (por $u)' : 'Preço por $u',
                prefixText: r'R$ ',
                helperText: temTabela ? null : 'Cliente ainda sem preço para este produto',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _ok(),
            ),
            if (temTabela)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: promo,
                onChanged: (v) => setState(() {
                  promo = v ?? false;
                  if (!promo) precoC.text = precoTxt(widget.precoCliente!);
                }),
                title: const Text('Preço promocional / fora da tabela'),
                subtitle: promo
                    ? Text('Tabela: ${moeda(widget.precoCliente!)} · vale só neste pedido',
                        style: TextStyle(color: Colors.red.shade700))
                    : null,
              )
            else
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: salvarNaTabela,
                onChanged: (v) => setState(() => salvarNaTabela = v ?? false),
                title: const Text('Salvar na tabela deste cliente'),
              ),
            const SizedBox(height: 8),
            Text(sub == null ? 'Subtotal: —' : 'Subtotal: ${moeda(sub)}',
                style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.right),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: sub == null || sub <= 0 ? null : _ok, child: const Text('OK')),
      ],
    );
  }
}
