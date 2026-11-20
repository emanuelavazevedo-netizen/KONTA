import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const Color verde = Color(0xFF087F5B);
const Color fundo = Color(0xFFF3F7F5);
const FlutterSecureStorage armazenamentoSeguro = FlutterSecureStorage();

final NumberFormat formatoMoeda = NumberFormat('#,##0.00', 'pt_PT');
final DateFormat formatoData = DateFormat('dd/MM/yyyy');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await KontaDatabase.database;
  runApp(const KontaApp());
}

// ======================================================
// BASE DE DADOS
// ======================================================

class KontaDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;

    final caminho = p.join(await getDatabasesPath(), 'konta.db');

    _database = await openDatabase(
      caminho,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE movimentos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo TEXT NOT NULL,
            descricao TEXT NOT NULL,
            valor REAL NOT NULL,
            data TEXT NOT NULL,
            categoria TEXT
          )
        ''');
      },
    );

    return _database!;
  }

  static Future<List<Map<String, dynamic>>> listar() async {
    final db = await database;
    return db.query('movimentos', orderBy: 'id DESC');
  }

  static Future<int> inserir(Map<String, dynamic> movimento) async {
    final db = await database;
    return db.insert('movimentos', movimento);
  }

  static Future<int> atualizar(
    int id,
    Map<String, dynamic> movimento,
  ) async {
    final db = await database;
    return db.update(
      'movimentos',
      movimento,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> eliminar(int id) async {
    final db = await database;
    return db.delete(
      'movimentos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// ======================================================
// APLICAÇÃO
// ======================================================

class KontaApp extends StatelessWidget {
  const KontaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KONTA 2.0',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: fundo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: verde,
          primary: verde,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: verde,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const AcessoKonta(),
    );
  }
}

// ======================================================
// ACESSO E CONFIGURAÇÃO DO PIN
// ======================================================

class AcessoKonta extends StatefulWidget {
  const AcessoKonta({super.key});

  @override
  State<AcessoKonta> createState() => _AcessoKontaState();
}

class _AcessoKontaState extends State<AcessoKonta> {
  final TextEditingController pinController = TextEditingController();
  final TextEditingController confirmarController =
      TextEditingController();

  String? pinGuardado;
  bool aCarregar = true;
  bool criarPin = false;
  bool confirmarPin = false;
  String mensagem = '';

  @override
  void initState() {
    super.initState();
    verificarPin();
  }

  Future<void> verificarPin() async {
    final pin = await armazenamentoSeguro.read(key: 'konta_pin');

    if (!mounted) return;

    setState(() {
      pinGuardado = pin;
      criarPin = pin == null;
      aCarregar = false;
    });
  }

  Future<void> entrarOuCriar() async {
    final pin = pinController.text.trim();

    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => mensagem = 'Introduza um PIN de 4 números.');
      return;
    }

    if (criarPin) {
      if (!confirmarPin) {
        setState(() {
          confirmarPin = true;
          mensagem = 'Confirme o seu PIN.';
        });
        return;
      }

      if (pin != confirmarController.text.trim()) {
        setState(() => mensagem = 'Os PINs não coincidem.');
        return;
      }

      await armazenamentoSeguro.write(
        key: 'konta_pin',
        value: pin,
      );

      abrirAplicacao();
      return;
    }

    if (pin == pinGuardado) {
      abrirAplicacao();
    } else {
      setState(() => mensagem = 'PIN incorrecto. Tente novamente.');
      pinController.clear();
    }
  }

  void abrirAplicacao() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const PainelKonta(),
      ),
    );
  }

  @override
  void dispose() {
    pinController.dispose();
    confirmarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (aCarregar) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: verde,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'KONTA 2.0',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: verde,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    criarPin
                        ? 'Crie um PIN de segurança'
                        : 'Introduza o seu PIN para entrar',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'PIN de 4 dígitos',
                      prefixIcon: Icon(Icons.lock_outline),
                      counterText: '',
                    ),
                  ),
                  if (criarPin && confirmarPin) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmarController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar PIN',
                        prefixIcon: Icon(Icons.lock_reset),
                        counterText: '',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (mensagem.isNotEmpty)
                    Text(
                      mensagem,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: entrarOuCriar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verde,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        criarPin ? 'Continuar' : 'Entrar',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),
                  const Text(
                    'Desenvolvido por Emanuel Azevedo',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ======================================================
// PAINEL PRINCIPAL
// ======================================================

class PainelKonta extends StatefulWidget {
  const PainelKonta({super.key});

  @override
  State<PainelKonta> createState() => _PainelKontaState();
}

class _PainelKontaState extends State<PainelKonta> {
  int pagina = 0;
  List<Map<String, dynamic>> movimentos = [];
  bool aCarregar = true;
  bool ocultarSaldo = false;
  String filtro = 'Todos';

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    final dados = await KontaDatabase.listar();

    if (!mounted) return;

    setState(() {
      movimentos = dados;
      aCarregar = false;
    });
  }

  double get totalEntradas {
    return movimentos
        .where((m) => m['tipo'] == 'Entrada')
        .fold(0.0, (soma, m) => soma + (m['valor'] as num).toDouble());
  }

  double get totalSaidas {
    return movimentos
        .where((m) => m['tipo'] == 'Saída')
        .fold(0.0, (soma, m) => soma + (m['valor'] as num).toDouble());
  }

  double get saldo => totalEntradas - totalSaidas;

  String moeda(double valor) {
    return '${formatoMoeda.format(valor)} Kz';
  }

  Future<void> abrirFormulario({Map<String, dynamic>? movimento}) async {
    await showDialog(
      context: context,
      builder: (_) => DialogoMovimento(movimento: movimento),
    );
    await carregar();
  }

  Future<void> eliminarMovimento(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar movimento?'),
        content: const Text(
          'Tem a certeza de que pretende eliminar este registo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await KontaDatabase.eliminar(id);
      await carregar();
    }
  }

  Widget cartaoResumo(
    String titulo,
    double valor,
    IconData icone,
    Color cor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: cor, size: 25),
            const SizedBox(height: 10),
            Text(
              titulo,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              ocultarSaldo ? '••••••' : moeda(valor),
              style: TextStyle(
                color: cor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget painelInicio() {
    return RefreshIndicator(
      onRefresh: carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Olá, bem-vindo!',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    'Resumo financeiro',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: ocultarSaldo ? 'Mostrar saldo' : 'Ocultar saldo',
                onPressed: () {
                  setState(() => ocultarSaldo = !ocultarSaldo);
                },
                icon: Icon(
                  ocultarSaldo ? Icons.visibility_off : Icons.visibility,
                  color: verde,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: verde,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SALDO DISPONÍVEL',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  ocultarSaldo ? '••••••••' : moeda(saldo),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Controlo simples das suas finanças',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              cartaoResumo(
                'Entradas',
                totalEntradas,
                Icons.arrow_downward,
                Colors.green,
              ),
              const SizedBox(width: 12),
              cartaoResumo(
                'Saídas',
                totalSaidas,
                Icons.arrow_upward,
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Text(
            'Movimentos recentes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (movimentos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(25),
              child: Center(
                child: Text(
                  'Ainda não existem movimentos registados.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...movimentos.take(5).map((m) => cartaoMovimento(m)),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => abrirFormulario(),
              icon: const Icon(Icons.add),
              label: const Text('Novo movimento'),
              style: ElevatedButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Desenvolvido por Emanuel Azevedo',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget cartaoMovimento(Map<String, dynamic> m) {
    final entrada = m['tipo'] == 'Entrada';
    final cor = entrada ? Colors.green : Colors.red;
    final id = (m['id'] as num).toInt();

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cor.withValues(alpha: 0.12),
          child: Icon(
            entrada ? Icons.arrow_downward : Icons.arrow_upward,
            color: cor,
          ),
        ),
        title: Text(
          m['descricao']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${m['categoria'] ?? 'Geral'} • ${m['data'] ?? ''}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (opcao) {
            if (opcao == 'editar') {
              abrirFormulario(movimento: m);
            } else if (opcao == 'eliminar') {
              eliminarMovimento(id);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'editar',
              child: Text('Editar'),
            ),
            PopupMenuItem(
              value: 'eliminar',
              child: Text('Eliminar'),
            ),
          ],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entrada ? '+' : '-'}${moeda((m['valor'] as num).toDouble())}',
                style: TextStyle(
                  color: cor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Icon(Icons.more_horiz, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget paginaMovimentos() {
    final lista = movimentos.where((m) {
      if (filtro == 'Todos') return true;
      return m['tipo'] == filtro;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Histórico de movimentos',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DropdownButton<String>(
                value: filtro,
                items: const [
                  DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                  DropdownMenuItem(value: 'Entrada', child: Text('Entradas')),
                  DropdownMenuItem(value: 'Saída', child: Text('Saídas')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => filtro = v);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: lista.isEmpty
              ? const Center(
                  child: Text('Não existem movimentos nesta categoria.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: lista.length,
                  itemBuilder: (context, index) {
                    return cartaoMovimento(lista[index]);
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => abrirFormulario(),
              icon: const Icon(Icons.add),
              label: const Text('Registar movimento'),
              style: ElevatedButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget paginaDefinicoes() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Definições',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 18),
        Card(
          color: Colors.white,
          child: ListTile(
            leading: const Icon(Icons.lock_outline, color: verde),
            title: const Text('Alterar PIN de segurança'),
            subtitle: const Text('Actualizar o código de acesso'),
            trailing: const Icon(Icons.chevron_right),
            onTap: alterarPin,
          ),
        ),
        Card(
          color: Colors.white,
          child: ListTile(
            leading: const Icon(Icons.info_outline, color: verde),
            title: const Text('Sobre a KONTA'),
            subtitle: const Text('Versão 2.0'),
          ),
        ),
        const SizedBox(height: 30),
        const Center(
          child: Text(
            'KONTA 2.0',
            style: TextStyle(
              color: verde,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Desenvolvido por Emanuel Azevedo',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Future<void> alterarPin() async {
    final atual = TextEditingController();
    final novo = TextEditingController();
    final confirmar = TextEditingController();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterar PIN'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: atual,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'PIN actual'),
              ),
              TextField(
                controller: novo,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'Novo PIN'),
              ),
              TextField(
                controller: confirmar,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Confirmar novo PIN',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final guardado =
                  await armazenamentoSeguro.read(key: 'konta_pin');

              if (atual.text.trim() != guardado) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN actual incorrecto.')),
                );
                return;
              }

              if (novo.text.length != 4 ||
                  int.tryParse(novo.text) == null ||
                  novo.text != confirmar.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Verifique o novo PIN de 4 dígitos.'),
                  ),
                );
                return;
              }

              await armazenamentoSeguro.write(
                key: 'konta_pin',
                value: novo.text,
              );

              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    atual.dispose();
    novo.dispose();
    confirmar.dispose();

    if (resultado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN alterado com sucesso.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (aCarregar) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final paginas = [
      painelInicio(),
      paginaMovimentos(),
      paginaDefinicoes(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'KONTA 2.0',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: IndexedStack(
        index: pagina,
        children: paginas,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: pagina,
        onDestinationSelected: (index) {
          setState(() => pagina = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Movimentos',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Definições',
          ),
        ],
      ),
    );
  }
}
// ======================================================
// FORMULÁRIO DE REGISTO E EDIÇÃO
// ======================================================

class DialogoMovimento extends StatefulWidget {
  final Map<String, dynamic>? movimento;

  const DialogoMovimento({
    super.key,
    this.movimento,
  });

  @override
  State<DialogoMovimento> createState() => _DialogoMovimentoState();
}

class _DialogoMovimentoState extends State<DialogoMovimento> {
  final descricaoController = TextEditingController();
  final valorController = TextEditingController();

  String tipo = 'Entrada';
  String categoria = 'Geral';
  bool aGuardar = false;

  final List<String> categorias = [
    'Geral',
    'Salário',
    'Vendas',
    'Alimentação',
    'Transporte',
    'Habitação',
    'Saúde',
    'Educação',
    'Serviços',
    'Outros',
  ];

  @override
  void initState() {
    super.initState();

    final m = widget.movimento;

    if (m != null) {
      tipo = m['tipo']?.toString() ?? 'Entrada';
      categoria = m['categoria']?.toString() ?? 'Geral';
      descricaoController.text = m['descricao']?.toString() ?? '';
      valorController.text = m['valor']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    descricaoController.dispose();
    valorController.dispose();
    super.dispose();
  }

  Future<void> guardar() async {
    final descricao = descricaoController.text.trim();
    final valorTexto = valorController.text.trim().replaceAll(',', '.');
    final valor = double.tryParse(valorTexto);

    if (descricao.isEmpty || valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha a descrição e um valor válido.'),
        ),
      );
      return;
    }

    setState(() => aGuardar = true);

    final dados = <String, dynamic>{
      'tipo': tipo,
      'descricao': descricao,
      'valor': valor,
      'categoria': categoria,
      'data': widget.movimento?['data'] ??
          formatoData.format(DateTime.now()),
    };

    try {
      if (widget.movimento == null) {
        await KontaDatabase.inserir(dados);
      } else {
        await KontaDatabase.atualizar(
          (widget.movimento!['id'] as num).toInt(),
          dados,
        );
      }

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.movimento == null
                ? 'Movimento registado com sucesso!'
                : 'Movimento actualizado com sucesso!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => aGuardar = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao guardar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.movimento != null;

    return AlertDialog(
      title: Text(
        editando ? 'Editar movimento' : 'Novo movimento',
        style: const TextStyle(
          color: verde,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de movimento',
                  prefixIcon: Icon(Icons.swap_vert),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Entrada',
                    child: Text('Entrada'),
                  ),
                  DropdownMenuItem(
                    value: 'Saída',
                    child: Text('Saída'),
                  ),
                ],
                onChanged: (valor) {
                  if (valor != null) {
                    setState(() => tipo = valor);
                  }
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: valorController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor em Kz',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: categorias.contains(categoria) ? categoria : 'Geral',
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: categorias.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(c),
                  );
                }).toList(),
                onChanged: (valor) {
                  if (valor != null) {
                    setState(() => categoria = valor);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: aGuardar ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: aGuardar ? null : guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: verde,
            foregroundColor: Colors.white,
          ),
          child: aGuardar
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
