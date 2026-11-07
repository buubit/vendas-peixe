import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'atualizacao.dart';
import 'config.dart';
import 'screens/a_receber_screen.dart';
import 'screens/cadastros_screen.dart';
import 'screens/fechamento_screen.dart';
import 'screens/mais_screen.dart';
import 'screens/pedido_form.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.carregar();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vendas de Peixe',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF00796B),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int aba = 0;
  int visita = 0;
  final formKey = GlobalKey<PedidoFormState>();

  @override
  void initState() {
    super.initState();
    // Verifica atualização em segundo plano ao abrir o app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) verificarAtualizacao(context);
    });
  }

  void _trocar(int i) {
    setState(() {
      aba = i;
      visita++;
    });
    if (i == 0) formKey.currentState?.recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: aba,
        children: [
          Scaffold(appBar: AppBar(title: const Text('Lançar pedido')), body: PedidoForm(key: formKey)),
          aba == 1 ? FechamentoScreen(key: ValueKey('f$visita')) : const SizedBox(),
          aba == 2 ? AReceberScreen(key: ValueKey('r$visita')) : const SizedBox(),
          aba == 3 ? CadastrosScreen(key: ValueKey('c$visita')) : const SizedBox(),
          aba == 4 ? const MaisScreen() : const SizedBox(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: aba,
        onDestinationSelected: _trocar,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_shopping_cart), label: 'Pedido'),
          NavigationDestination(icon: Icon(Icons.event_note), label: 'Fechamento'),
          NavigationDestination(icon: Icon(Icons.payments), label: 'A receber'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Cadastros'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Mais'),
        ],
      ),
    );
  }
}
