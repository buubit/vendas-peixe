import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vendas_peixe/catalogo.dart';
import 'package:vendas_peixe/db.dart';
import 'package:vendas_peixe/format.dart';
import 'package:vendas_peixe/models.dart';
import 'package:vendas_peixe/quinzena.dart';

void main() {
  late Directory tmp;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await Db.fechar();
    tmp = await Directory.systemTemp.createTemp('vp_test');
    await databaseFactory.setDatabasesPath(tmp.path);
  });

  tearDown(() async {
    await Db.fechar();
    await tmp.delete(recursive: true);
  });

  test('catálogo tem 95 produtos sem nomes repetidos', () {
    final nomes = catalogoInicial.values.expand((l) => l).map(semAcento).toList();
    expect(nomes.length, 95);
    expect(nomes.toSet().length, 95);
  });

  test('banco novo já vem com o catálogo, tudo por kg', () async {
    final l = await Db.peixes();
    expect(l.length, 95);
    expect(l.every((p) => p.unidade == 'kg' && p.ativo), isTrue);
    expect(l.first.categoria, 'Salmão');
  });

  test('migração v1 -> v3 mantém dados e não duplica produto existente', () async {
    final path = await Db.caminho();
    final v1 = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
                "CREATE TABLE peixes(id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL, unidade TEXT NOT NULL DEFAULT 'kg', ativo INTEGER NOT NULL DEFAULT 1)");
            await db.execute(
                "CREATE TABLE clientes(id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL, telefone TEXT NOT NULL DEFAULT '', obs TEXT NOT NULL DEFAULT '')");
            await db.execute(
                'CREATE TABLE precos(cliente_id INTEGER NOT NULL, peixe_id INTEGER NOT NULL, preco REAL NOT NULL, PRIMARY KEY(cliente_id, peixe_id))');
            await db.execute(
                'CREATE TABLE pedidos(id INTEGER PRIMARY KEY AUTOINCREMENT, cliente_id INTEGER NOT NULL, data TEXT NOT NULL, total REAL NOT NULL)');
            await db.execute(
                'CREATE TABLE itens(id INTEGER PRIMARY KEY AUTOINCREMENT, pedido_id INTEGER NOT NULL, peixe_id INTEGER NOT NULL, nome TEXT NOT NULL, unidade TEXT NOT NULL, qtd REAL NOT NULL, preco REAL NOT NULL, subtotal REAL NOT NULL)');
            await db.execute(
                'CREATE TABLE recebimentos(cliente_id INTEGER NOT NULL, quinzena TEXT NOT NULL, valor REAL NOT NULL, data TEXT NOT NULL, PRIMARY KEY(cliente_id, quinzena))');
            await db.execute('CREATE TABLE config(chave TEXT PRIMARY KEY, valor TEXT NOT NULL)');
          },
        ));
    await v1.insert('peixes', {'nome': 'Kani', 'unidade': 'kg', 'ativo': 1});
    await v1.insert('peixes', {'nome': 'Peixe de Teste', 'unidade': 'kg', 'ativo': 1});
    await v1.insert('clientes', {'nome': 'Zé'});
    await v1.insert('pedidos', {'cliente_id': 1, 'data': '2026-11-04', 'total': 200.0});
    await v1.insert('itens', {
      'pedido_id': 1, 'peixe_id': 1, 'nome': 'Kani', 'unidade': 'kg', 'qtd': 10.0, 'preco': 20.0, 'subtotal': 200.0
    });
    await v1.close();

    final peixes = await Db.peixes();
    expect(peixes.length, 96); // 95 do catálogo (Kani já existia) + Peixe de Teste
    expect(peixes.where((p) => p.nome == 'Kani').length, 1);

    final f = await Db.fechamentos(quinzena: const Quinzena(2026, 11, 1));
    expect(f.single.total, 200);
    expect(f.single.comissao, closeTo(10, 0.001)); // 5% padrão
  });

  test('comissão fica gravada no pedido', () async {
    final c = Cliente(nome: 'Ana');
    await Db.salvarCliente(c);
    final p = (await Db.peixes()).first;
    await Db.salvarPedido(Pedido(
      clienteId: c.id!,
      clienteNome: c.nome,
      data: DateTime(2026, 11, 20),
      comissaoPct: 5,
      itens: [ItemPedido(peixeId: p.id!, nome: p.nome, unidade: 'kg', qtd: 3.5, preco: 40)],
    ));
    final l = await Db.pedidosEntre(DateTime(2026, 11, 16), DateTime(2026, 11, 30));
    expect(l.single.total, 140);
    expect(l.single.comissao, closeTo(7, 0.001));
  });

  test('item com preço promocional fica marcado e aparece no fechamento', () async {
    final c = Cliente(nome: 'Bia');
    await Db.salvarCliente(c);
    final p = (await Db.peixes()).first;
    await Db.salvarPedido(Pedido(
      clienteId: c.id!,
      clienteNome: c.nome,
      data: DateTime(2026, 11, 5),
      itens: [
        ItemPedido(peixeId: p.id!, nome: p.nome, unidade: 'kg', qtd: 2, preco: 30, promo: true, precoTabela: 35),
        ItemPedido(peixeId: p.id!, nome: p.nome, unidade: 'kg', qtd: 1, preco: 35),
      ],
    ));
    final ped = (await Db.pedidosEntre(DateTime(2026, 11, 1), DateTime(2026, 11, 15))).single;
    expect(ped.itens.first.promo, isTrue);
    expect(ped.itens.first.precoTabela, 35);
    expect(ped.itens.last.promo, isFalse);
    final f = await Db.fechamentos(quinzena: const Quinzena(2026, 11, 1));
    expect(f.single.promos, 1);
  });
}
