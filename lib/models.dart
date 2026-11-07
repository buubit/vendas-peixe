import 'config.dart';
import 'format.dart';
import 'quinzena.dart';

class Peixe {
  int? id;
  String nome;
  String unidade; // kg, un, cx
  bool ativo;
  String categoria;

  Peixe({this.id, required this.nome, this.unidade = 'kg', this.ativo = true, this.categoria = ''});

  factory Peixe.fromMap(Map<String, Object?> m) => Peixe(
        id: m['id'] as int,
        nome: m['nome'] as String,
        unidade: m['unidade'] as String,
        ativo: (m['ativo'] as int) == 1,
        categoria: (m['categoria'] as String?) ?? '',
      );

  Map<String, Object?> toMap() =>
      {'nome': nome, 'unidade': unidade, 'ativo': ativo ? 1 : 0, 'categoria': categoria};
}

class Cliente {
  int? id;
  String nome;
  String telefone;
  String obs;

  Cliente({this.id, required this.nome, this.telefone = '', this.obs = ''});

  factory Cliente.fromMap(Map<String, Object?> m) => Cliente(
        id: m['id'] as int,
        nome: m['nome'] as String,
        telefone: m['telefone'] as String,
        obs: m['obs'] as String,
      );

  Map<String, Object?> toMap() => {'nome': nome, 'telefone': telefone, 'obs': obs};
}

class ItemPedido {
  int peixeId;
  String nome;
  String unidade;
  double qtd;
  double preco;

  /// Preço promocional / fora da tabela do cliente.
  bool promo;

  /// Preço da tabela do cliente no momento (quando [promo]).
  double? precoTabela;

  ItemPedido({
    required this.peixeId,
    required this.nome,
    required this.unidade,
    required this.qtd,
    required this.preco,
    this.promo = false,
    this.precoTabela,
  });

  double get subtotal => arred(qtd * preco);

  String get descricao => '${numero(qtd)} $unidade × ${moeda(preco)}';

  static const avisoPromo = 'PREÇO PROMOCIONAL / FORA DA TABELA';

  String get aviso =>
      promo ? '⚠ $avisoPromo${precoTabela != null ? ' (tabela ${moeda(precoTabela!)})' : ''}' : '';

  factory ItemPedido.fromMap(Map<String, Object?> m) => ItemPedido(
        peixeId: m['peixe_id'] as int,
        nome: m['nome'] as String,
        unidade: m['unidade'] as String,
        qtd: (m['qtd'] as num).toDouble(),
        preco: (m['preco'] as num).toDouble(),
        promo: ((m['promo'] as int?) ?? 0) == 1,
        precoTabela: (m['preco_tabela'] as num?)?.toDouble(),
      );

  Map<String, Object?> toMap(int pedidoId) => {
        'pedido_id': pedidoId,
        'peixe_id': peixeId,
        'nome': nome,
        'unidade': unidade,
        'qtd': qtd,
        'preco': preco,
        'subtotal': subtotal,
        'promo': promo ? 1 : 0,
        'preco_tabela': precoTabela,
      };
}

class Pedido {
  int? id;
  int clienteId;
  String clienteNome;
  String clienteTelefone;
  DateTime data;
  List<ItemPedido> itens;
  double totalSalvo;

  /// Percentual de comissão gravado no pedido (não muda se a configuração mudar depois).
  double comissaoPct;

  /// Quantidade de itens com preço promocional (preenchido nas consultas resumidas).
  int promosSalvo;

  int get promos => itens.isEmpty ? promosSalvo : itens.where((i) => i.promo).length;

  Pedido({
    this.id,
    required this.clienteId,
    required this.clienteNome,
    this.clienteTelefone = '',
    required this.data,
    required this.itens,
    this.totalSalvo = 0,
    this.comissaoPct = 5,
    this.promosSalvo = 0,
  });

  double get total => itens.isEmpty ? totalSalvo : arred(itens.fold(0.0, (s, i) => s + i.subtotal));

  double get comissao => total * comissaoPct / 100;

  Quinzena get quinzena => Quinzena.de(data);
}

enum Situacao { andamento, emDia, venceLogo, vencido, recebido }

Situacao situacaoDe(Quinzena q, bool recebido) {
  if (recebido) return Situacao.recebido;
  final h = hoje();
  if (!h.isAfter(q.fim)) return Situacao.andamento;
  final dias = diasEntre(h, AppConfig.vencimento(q));
  if (dias < 0) return Situacao.vencido;
  if (dias <= 3) return Situacao.venceLogo;
  return Situacao.emDia;
}

/// Total de um cliente numa quinzena.
class Fechamento {
  final int clienteId;
  final String clienteNome;
  final String telefone;
  final Quinzena quinzena;
  bool recebido;
  double total = 0;
  double comissao = 0;
  int pedidos = 0;
  int promos = 0;

  Fechamento({
    required this.clienteId,
    required this.clienteNome,
    required this.telefone,
    required this.quinzena,
    required this.recebido,
  });

  DateTime get vencimento => AppConfig.vencimento(quinzena);
  Situacao get situacao => situacaoDe(quinzena, recebido);
}
