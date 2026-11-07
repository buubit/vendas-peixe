import 'dart:math';

int ultimoDia(int ano, int mes) => DateTime(ano, mes + 1, 0).day;

String _dd(int n) => n.toString().padLeft(2, '0');

/// Uma quinzena: parte 1 = dias 1 a 15, parte 2 = dia 16 ao fim do mês.
class Quinzena {
  final int ano;
  final int mes;
  final int parte;

  const Quinzena(this.ano, this.mes, this.parte);

  factory Quinzena.de(DateTime d) => Quinzena(d.year, d.month, d.day <= 15 ? 1 : 2);

  factory Quinzena.daChave(String k) {
    final p = k.split('-');
    return Quinzena(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  String get chave => '$ano-${_dd(mes)}-$parte';

  DateTime get inicio => DateTime(ano, mes, parte == 1 ? 1 : 16);

  DateTime get fim => parte == 1 ? DateTime(ano, mes, 15) : DateTime(ano, mes, ultimoDia(ano, mes));

  /// Data de pagamento.
  /// 1ª quinzena: dia [diaQ1] do mesmo mês (limitado ao último dia, ex.: fevereiro).
  /// 2ª quinzena: dia [diaQ2] do mês seguinte.
  DateTime vencimento({int diaQ1 = 30, int diaQ2 = 15}) {
    if (parte == 1) return DateTime(ano, mes, min(diaQ1, ultimoDia(ano, mes)));
    final n = DateTime(ano, mes + 1, 1);
    return DateTime(n.year, n.month, min(diaQ2, ultimoDia(n.year, n.month)));
  }

  Quinzena get anterior {
    if (parte == 2) return Quinzena(ano, mes, 1);
    return mes == 1 ? Quinzena(ano - 1, 12, 2) : Quinzena(ano, mes - 1, 2);
  }

  Quinzena get proxima {
    if (parte == 1) return Quinzena(ano, mes, 2);
    return mes == 12 ? Quinzena(ano + 1, 1, 1) : Quinzena(ano, mes + 1, 1);
  }

  bool contem(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(inicio) && !x.isAfter(fim);
  }

  /// Ex.: "01 a 15/11/2026"
  String get rotulo => '${_dd(inicio.day)} a ${_dd(fim.day)}/${_dd(mes)}/$ano';

  @override
  bool operator ==(Object other) =>
      other is Quinzena && other.ano == ano && other.mes == mes && other.parte == parte;

  @override
  int get hashCode => Object.hash(ano, mes, parte);

  @override
  String toString() => chave;
}
