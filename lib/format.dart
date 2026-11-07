import 'package:intl/intl.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _numero = NumberFormat('#,##0.###', 'pt_BR');
final _preco = NumberFormat('#,##0.00', 'pt_BR');

String moeda(num v) => _moeda.format(v);
String numero(num v) => _numero.format(v);
String precoTxt(num v) => _preco.format(v);

String _dd(int n) => n.toString().padLeft(2, '0');

DateTime hoje() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String dbData(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_dd(d.month)}-${_dd(d.day)}';

DateTime deDb(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String br(DateTime d) => '${_dd(d.day)}/${_dd(d.month)}/${d.year}';
String brCurto(DateTime d) => '${_dd(d.day)}/${_dd(d.month)}';

int diasEntre(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Aceita "3,5", "3.5", "1.250,50".
double? lerNumero(String s) {
  var t = s.trim().replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(t);
}

double arred(double v) => (v * 100).roundToDouble() / 100;

String semAcento(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = de.indexOf(c);
    b.write(i >= 0 ? para[i] : c);
  }
  return b.toString().toLowerCase();
}
