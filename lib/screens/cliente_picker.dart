import 'package:flutter/material.dart';

import '../db.dart';
import '../format.dart';
import '../models.dart';
import 'cliente_edit_page.dart';

Future<Cliente?> escolherCliente(BuildContext context) => showModalBottomSheet<Cliente>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ClientePicker(),
    );

class _ClientePicker extends StatefulWidget {
  const _ClientePicker();

  @override
  State<_ClientePicker> createState() => _ClientePickerState();
}

class _ClientePickerState extends State<_ClientePicker> {
  List<Cliente> todos = [];
  String filtro = '';
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    Db.clientes().then((l) => setState(() {
          todos = l;
          carregando = false;
        }));
  }

  Future<void> _novo() async {
    final c = await Navigator.push<Cliente>(context, MaterialPageRoute(builder: (_) => const ClienteEditPage()));
    if (c != null && mounted) Navigator.pop(context, c);
  }

  @override
  Widget build(BuildContext context) {
    final f = semAcento(filtro);
    final lista = f.isEmpty ? todos : todos.where((c) => semAcento(c.nome).contains(f)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar cliente'),
              onChanged: (v) => setState(() => filtro = v),
            ),
          ),
          Expanded(
            child: carregando
                ? const Center(child: CircularProgressIndicator())
                : lista.isEmpty
                    ? const Center(child: Text('Nenhum cliente encontrado.'))
                    : ListView(children: [
                        for (final c in lista)
                          ListTile(
                            leading: CircleAvatar(child: Text(c.nome.isEmpty ? '?' : c.nome[0].toUpperCase())),
                            title: Text(c.nome, style: const TextStyle(fontSize: 18)),
                            subtitle: c.obs.isEmpty ? null : Text(c.obs),
                            onTap: () => Navigator.pop(context, c),
                          ),
                      ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                  onPressed: _novo, icon: const Icon(Icons.person_add), label: const Text('Novo cliente')),
            ),
          ),
        ]),
      ),
    );
  }
}
