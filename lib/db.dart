import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'catalogo.dart';
import 'format.dart';
import 'models.dart';
import 'quinzena.dart';

class Db {
  static Database? _db;

  static Future<String> caminho() async => p.join(await getDatabasesPath(), 'vendas_peixe.db');

  static Future<Database> get _d async => _db ??= await _abrir();

  static Future<void> fechar() async {
    await _db?.close();
    _db = null;
  }

  static Future<void> _semearCatalogo(DatabaseExecutor db) async {
    final existentes = (await db.query('peixes', columns: ['nome']))
        .map((m) => semAcento(m['nome'] as String))
        .toSet();
    for (final e in catalogoInicial.entries) {
      for (final nome in e.value) {
        if (existentes.contains(semAcento(nome))) continue;
        await db.insert('peixes', {'nome': nome, 'unidade': 'kg', 'ativo': 1, 'categoria': e.key});
      }
    }
  }

  static Future<Database> _abrir() async => openDatabase(
        await caminho(),
        version: 3,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onUpgrade: (db, de, para) async {
          if (de < 2) {
            await db.execute("ALTER TABLE peixes ADD COLUMN categoria TEXT NOT NULL DEFAULT ''");
            await db.execute('ALTER TABLE pedidos ADD COLUMN comissao REAL NOT NULL DEFAULT 5');
            await _semearCatalogo(db);
          }
          if (de < 3) {
            await db.execute('ALTER TABLE itens ADD COLUMN promo INTEGER NOT NULL DEFAULT 0');
            await db.execute('ALTER TABLE itens ADD COLUMN preco_tabela REAL');
          }
        },
        onCreate: (db, v) async {
          await db.execute(
              "CREATE TABLE peixes(id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL, unidade TEXT NOT NULL DEFAULT 'kg', ativo INTEGER NOT NULL DEFAULT 1, categoria TEXT NOT NULL DEFAULT '')");
          await db.execute(
              "CREATE TABLE clientes(id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL, telefone TEXT NOT NULL DEFAULT '', obs TEXT NOT NULL DEFAULT '')");
          await db.execute(
              'CREATE TABLE precos(cliente_id INTEGER NOT NULL REFERENCES clientes(id) ON DELETE CASCADE, peixe_id INTEGER NOT NULL REFERENCES peixes(id) ON DELETE CASCADE, preco REAL NOT NULL, PRIMARY KEY(cliente_id, peixe_id))');
          await db.execute(
              'CREATE TABLE pedidos(id INTEGER PRIMARY KEY AUTOINCREMENT, cliente_id INTEGER NOT NULL REFERENCES clientes(id), data TEXT NOT NULL, total REAL NOT NULL, comissao REAL NOT NULL DEFAULT 5)');
          await db.execute('CREATE INDEX idx_pedidos_data ON pedidos(data)');
          await db.execute(
              'CREATE TABLE itens(id INTEGER PRIMARY KEY AUTOINCREMENT, pedido_id INTEGER NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE, peixe_id INTEGER NOT NULL, nome TEXT NOT NULL, unidade TEXT NOT NULL, qtd REAL NOT NULL, preco REAL NOT NULL, subtotal REAL NOT NULL, promo INTEGER NOT NULL DEFAULT 0, preco_tabela REAL)');
          await db.execute(
              'CREATE TABLE recebimentos(cliente_id INTEGER NOT NULL REFERENCES clientes(id) ON DELETE CASCADE, quinzena TEXT NOT NULL, valor REAL NOT NULL, data TEXT NOT NULL, PRIMARY KEY(cliente_id, quinzena))');
          await db.execute('CREATE TABLE config(chave TEXT PRIMARY KEY, valor TEXT NOT NULL)');
          await _semearCatalogo(db);
        },
      );

  // ---------- Peixes ----------
  static Future<List<Peixe>> peixes({bool soAtivos = false}) async {
    final r = await (await _d).query('peixes', where: soAtivos ? 'ativo = 1' : null);
    final l = r.map(Peixe.fromMap).toList();
    l.sort((a, b) {
      final c = ordemCategoria(a.categoria).compareTo(ordemCategoria(b.categoria));
      return c != 0 ? c : semAcento(a.nome).compareTo(semAcento(b.nome));
    });
    return l;
  }

  static Future<void> salvarPeixe(Peixe x) async {
    final d = await _d;
    if (x.id == null) {
      x.id = await d.insert('peixes', x.toMap());
    } else {
      await d.update('peixes', x.toMap(), where: 'id = ?', whereArgs: [x.id]);
    }
  }

  /// true = excluído; false = já tinha vendas, então só foi desativado.
  static Future<bool> excluirPeixe(int id) async {
    final d = await _d;
    final usado = Sqflite.firstIntValue(await d.rawQuery('SELECT COUNT(*) FROM itens WHERE peixe_id = ?', [id])) ?? 0;
    if (usado > 0) {
      await d.update('peixes', {'ativo': 0}, where: 'id = ?', whereArgs: [id]);
      return false;
    }
    await d.delete('peixes', where: 'id = ?', whereArgs: [id]);
    return true;
  }

  // ---------- Clientes ----------
  static Future<List<Cliente>> clientes() async {
    final r = await (await _d).query('clientes', orderBy: 'nome COLLATE NOCASE');
    return r.map(Cliente.fromMap).toList();
  }

  static Future<Cliente?> cliente(int id) async {
    final r = await (await _d).query('clientes', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Cliente.fromMap(r.first);
  }

  static Future<void> salvarCliente(Cliente c) async {
    final d = await _d;
    if (c.id == null) {
      c.id = await d.insert('clientes', c.toMap());
    } else {
      await d.update('clientes', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    }
  }

  /// false = cliente tem pedidos e não pode ser excluído.
  static Future<bool> excluirCliente(int id) async {
    final d = await _d;
    final n = Sqflite.firstIntValue(await d.rawQuery('SELECT COUNT(*) FROM pedidos WHERE cliente_id = ?', [id])) ?? 0;
    if (n > 0) return false;
    await d.delete('clientes', where: 'id = ?', whereArgs: [id]);
    return true;
  }

  // ---------- Preços por cliente ----------
  static Future<Map<int, double>> precos(int clienteId) async {
    final r = await (await _d).query('precos', where: 'cliente_id = ?', whereArgs: [clienteId]);
    return {for (final m in r) m['peixe_id'] as int: (m['preco'] as num).toDouble()};
  }

  /// Última data (yyyy-MM-dd + id do pedido) em que cada produto foi vendido para o cliente.
  static Future<Map<int, String>> ultimasCompras(int clienteId) async {
    final r = await (await _d).rawQuery(
        "SELECT i.peixe_id, MAX(p.data || '#' || printf('%09d', p.id)) AS ult FROM itens i "
        'JOIN pedidos p ON p.id = i.pedido_id WHERE p.cliente_id = ? GROUP BY i.peixe_id',
        [clienteId]);
    return {for (final m in r) m['peixe_id'] as int: m['ult'] as String};
  }

  static Future<void> salvarPreco(int clienteId, int peixeId, double preco) async {
    await (await _d).insert('precos', {'cliente_id': clienteId, 'peixe_id': peixeId, 'preco': preco},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> removerPreco(int clienteId, int peixeId) async {
    await (await _d).delete('precos', where: 'cliente_id = ? AND peixe_id = ?', whereArgs: [clienteId, peixeId]);
  }

  // ---------- Pedidos ----------
  static Future<int> salvarPedido(Pedido ped) async {
    final d = await _d;
    return d.transaction((t) async {
      final m = {
        'cliente_id': ped.clienteId,
        'data': dbData(ped.data),
        'total': ped.total,
        'comissao': ped.comissaoPct,
      };
      int id;
      if (ped.id == null) {
        id = await t.insert('pedidos', m);
      } else {
        id = ped.id!;
        await t.update('pedidos', m, where: 'id = ?', whereArgs: [id]);
        await t.delete('itens', where: 'pedido_id = ?', whereArgs: [id]);
      }
      for (final i in ped.itens) {
        await t.insert('itens', i.toMap(id));
      }
      return id;
    });
  }

  static Future<void> excluirPedido(int id) async {
    await (await _d).delete('pedidos', where: 'id = ?', whereArgs: [id]);
  }

  static Future<Pedido?> pedido(int id) async {
    final l = await _pedidos('p.id = ?', [id]);
    return l.isEmpty ? null : l.first;
  }

  static Future<List<Pedido>> pedidosEntre(DateTime ini, DateTime fim, {int? clienteId}) => _pedidos(
        'p.data BETWEEN ? AND ?${clienteId != null ? ' AND p.cliente_id = ?' : ''}',
        [dbData(ini), dbData(fim), ?clienteId],
      );

  static Future<List<Pedido>> _pedidos(String where, List<Object?> args, {bool comItens = true}) async {
    final d = await _d;
    final r = await d.rawQuery(
        'SELECT p.id, p.cliente_id, p.data, p.total, p.comissao, c.nome, c.telefone, '
        '(SELECT COUNT(*) FROM itens i WHERE i.pedido_id = p.id AND i.promo = 1) AS promos FROM pedidos p '
        'JOIN clientes c ON c.id = p.cliente_id WHERE $where ORDER BY p.data, p.id',
        args);
    final peds = r
        .map((m) => Pedido(
              id: m['id'] as int,
              clienteId: m['cliente_id'] as int,
              clienteNome: m['nome'] as String,
              clienteTelefone: m['telefone'] as String,
              data: deDb(m['data'] as String),
              totalSalvo: (m['total'] as num).toDouble(),
              comissaoPct: (m['comissao'] as num).toDouble(),
              promosSalvo: m['promos'] as int,
              itens: [],
            ))
        .toList();
    if (comItens && peds.isNotEmpty) {
      final porId = {for (final p in peds) p.id!: p};
      final it = await d.rawQuery('SELECT * FROM itens WHERE pedido_id IN (${porId.keys.join(',')}) ORDER BY id');
      for (final m in it) {
        porId[m['pedido_id'] as int]!.itens.add(ItemPedido.fromMap(m));
      }
    }
    return peds;
  }

  // ---------- Fechamentos / recebimentos ----------
  static Future<Set<String>> _recebidos() async {
    final r = await (await _d).query('recebimentos');
    return {for (final m in r) '${m['cliente_id']}|${m['quinzena']}'};
  }

  static Future<List<Fechamento>> fechamentos({Quinzena? quinzena, bool soAbertos = false}) async {
    final peds = quinzena == null
        ? await _pedidos('1 = 1', [], comItens: false)
        : await _pedidos('p.data BETWEEN ? AND ?', [dbData(quinzena.inicio), dbData(quinzena.fim)], comItens: false);
    final rec = await _recebidos();
    final mapa = <String, Fechamento>{};
    for (final p in peds) {
      final q = Quinzena.de(p.data);
      final k = '${p.clienteId}|${q.chave}';
      final f = mapa.putIfAbsent(
          k,
          () => Fechamento(
                clienteId: p.clienteId,
                clienteNome: p.clienteNome,
                telefone: p.clienteTelefone,
                quinzena: q,
                recebido: rec.contains(k),
              ));
      f.total = arred(f.total + p.total);
      f.comissao += p.comissao;
      f.promos += p.promos;
      f.pedidos++;
    }
    var l = mapa.values.toList();
    if (soAbertos) l = l.where((f) => !f.recebido).toList();
    l.sort((a, b) {
      final c = a.vencimento.compareTo(b.vencimento);
      return c != 0 ? c : semAcento(a.clienteNome).compareTo(semAcento(b.clienteNome));
    });
    return l;
  }

  static Future<bool> recebido(int clienteId, Quinzena q) async {
    final r = await (await _d)
        .query('recebimentos', where: 'cliente_id = ? AND quinzena = ?', whereArgs: [clienteId, q.chave]);
    return r.isNotEmpty;
  }

  static Future<void> marcarRecebido(int clienteId, Quinzena q, double valor) async {
    await (await _d).insert(
        'recebimentos', {'cliente_id': clienteId, 'quinzena': q.chave, 'valor': valor, 'data': dbData(hoje())},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> desmarcarRecebido(int clienteId, Quinzena q) async {
    await (await _d)
        .delete('recebimentos', where: 'cliente_id = ? AND quinzena = ?', whereArgs: [clienteId, q.chave]);
  }

  // ---------- Config ----------
  static Future<String?> config(String chave) async {
    final r = await (await _d).query('config', where: 'chave = ?', whereArgs: [chave]);
    return r.isEmpty ? null : r.first['valor'] as String;
  }

  static Future<void> setConfig(String chave, String valor) async {
    await (await _d)
        .insert('config', {'chave': chave, 'valor': valor}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
