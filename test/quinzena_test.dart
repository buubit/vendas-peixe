import 'package:flutter_test/flutter_test.dart';
import 'package:vendas_peixe/format.dart';
import 'package:vendas_peixe/quinzena.dart';

void main() {
  group('Quinzena', () {
    test('dia 4 cai na 1ª quinzena e paga dia 30', () {
      final q = Quinzena.de(DateTime(2026, 11, 4));
      expect(q.parte, 1);
      expect(q.inicio, DateTime(2026, 11, 1));
      expect(q.fim, DateTime(2026, 11, 15));
      expect(q.vencimento(), DateTime(2026, 11, 30));
    });

    test('dia 15 ainda é 1ª quinzena, dia 16 é 2ª', () {
      expect(Quinzena.de(DateTime(2026, 11, 15)).parte, 1);
      expect(Quinzena.de(DateTime(2026, 11, 16)).parte, 2);
    });

    test('2ª quinzena paga dia 15 do mês seguinte', () {
      final q = Quinzena.de(DateTime(2026, 11, 20));
      expect(q.fim, DateTime(2026, 11, 30));
      expect(q.vencimento(), DateTime(2026, 12, 15));
    });

    test('dezembro vira o ano', () {
      final q = Quinzena.de(DateTime(2026, 12, 31));
      expect(q.fim, DateTime(2026, 12, 31));
      expect(q.vencimento(), DateTime(2027, 1, 15));
      expect(q.proxima, const Quinzena(2027, 1, 1));
      expect(const Quinzena(2027, 1, 1).anterior, q);
    });

    test('fevereiro paga no último dia do mês', () {
      expect(Quinzena.de(DateTime(2026, 2, 10)).vencimento(), DateTime(2026, 2, 28));
      expect(Quinzena.de(DateTime(2028, 2, 10)).vencimento(), DateTime(2028, 2, 29));
      expect(Quinzena.de(DateTime(2026, 2, 20)).fim, DateTime(2026, 2, 28));
    });

    test('dias configuráveis', () {
      final q = Quinzena.de(DateTime(2026, 11, 20));
      expect(q.vencimento(diaQ1: 25, diaQ2: 10), DateTime(2026, 12, 10));
      expect(q.vencimento(diaQ2: 31), DateTime(2026, 12, 31));
    });

    test('chave ida e volta', () {
      const q = Quinzena(2026, 3, 2);
      expect(Quinzena.daChave(q.chave), q);
      expect(q.rotulo, '16 a 31/03/2026');
    });
  });

  group('Formatação', () {
    test('lerNumero aceita vírgula e ponto', () {
      expect(lerNumero('3,5'), 3.5);
      expect(lerNumero('3.5'), 3.5);
      expect(lerNumero('1.250,50'), 1250.5);
      expect(lerNumero(''), null);
    });

    test('moeda em reais', () {
      expect(moeda(1250.5).replaceAll(' ', ' '), r'R$ 1.250,50');
    });
  });
}
