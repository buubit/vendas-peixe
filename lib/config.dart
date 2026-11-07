import 'db.dart';
import 'quinzena.dart';

class AppConfig {
  static int diaQ1 = 30;
  static int diaQ2 = 15;

  /// Número da base (JJE): todas as mensagens de WhatsApp vão para ele.
  static String whatsBase = '11911755030';

  /// Comissão sobre todas as vendas (%).
  static double comissao = 5;

  static Future<void> carregar() async {
    diaQ1 = int.tryParse(await Db.config('dia_q1') ?? '') ?? 30;
    diaQ2 = int.tryParse(await Db.config('dia_q2') ?? '') ?? 15;
    whatsBase = await Db.config('whats_base') ?? '11911755030';
    comissao = double.tryParse(await Db.config('comissao') ?? '') ?? 5;
  }

  static Future<void> salvar(int q1, int q2) async {
    await Db.setConfig('dia_q1', '$q1');
    await Db.setConfig('dia_q2', '$q2');
    diaQ1 = q1;
    diaQ2 = q2;
  }

  static Future<void> salvarWhats(String numero) async {
    await Db.setConfig('whats_base', numero);
    whatsBase = numero;
  }

  static Future<void> salvarComissao(double pct) async {
    await Db.setConfig('comissao', '$pct');
    comissao = pct;
  }

  static DateTime vencimento(Quinzena q) => q.vencimento(diaQ1: diaQ1, diaQ2: diaQ2);
}
