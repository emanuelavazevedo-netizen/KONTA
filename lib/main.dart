
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const verde = Color(0xFF087F5B);
const fundo = Color(0xFFF3F7F5);
const armazenamentoSeguro = FlutterSecureStorage();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await KontaDatabase.database;
  runApp(const KontaApp());
}

class KontaDatabase {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;

    final caminho = p.join(await getDatabasesPath(), 'konta.db');

    _db = await openDatabase(
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
            categoria TEXT NOT NULL DEFAULT 'Outros'
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE movimentos ADD COLUMN categoria TEXT NOT NULL DEFAULT 'Outros'"
          );
        }
      },
    );

    return _db!;
  }

  static Future<List<Map<String, dynamic>>> listar() async {
    final db = await database;
    return db.query('movimentos', orderBy: 'id DESC');
  }

  static Future<void> guardar({
    int? id,
    required String tipo,
    required String descricao,
    required double valor,
    required String categoria,
  }) async {
    final db = await database;

    final dados = {
      'tipo': tipo,
      'descricao': descricao,
      'valor': valor,
      'categoria': categoria,
    };

    if (id == null) {
      dados['data'] = DateTime.now().toIso8601String();
      await db.insert('movimentos', dados);
    } else {
      await db.update(
        'movimentos',
        dados,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  static Future<void> eliminar(int id) async {
    final db = await database;
    await db.delete('movimentos', where: 'id = ?', whereArgs: [id]);
  }
}

class KontaApp extends StatelessWidget {
  const KontaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KONTA',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: verde,
          primary: verde,
        ),
        scaffoldBackgroundColor: fundo,
        appBarTheme: const AppBarTheme(
          backgroundColor: verde,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: fundo,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const AcessoKonta(),
    );
  }
}

class AcessoKonta extends StatefulWidget {
  const AcessoKonta({super.key});

  @override
  State<AcessoKonta> createState() => _AcessoKontaState();
}

class _AcessoKontaState extends State<AcessoKonta> {
  final pinController = TextEditingController();
  final confirmarController = TextEditingController();

  bool carregando = true;
  bool configuracao = false;
  bool confirmar = false;
  String? pinGuardado;

  @override
  void initState() {
    super.initState();
    verificarPin();
  }

  Future<void> verificarPin() async {
    pinGuardado = await armazenamentoSeguro.read(key: 'konta_pin');

    if (!mounted) return;

    setState(() {
      configuracao = pinGuardado == null;
      carregando = false;
    });
  }

  Future<void> entrar() async {
    final pin = pinController.text;

    if (pin.length != 6) {
      mensagem('Introduza os 6 dígitos.');
      return;
    }

    if (configuracao) {
      if (!confirmar) {
        confirmarController.text = pin;
        pinController.clear();
        setState(() => confirmar = true);
        return;
      }

      if (pin != confirmarController.text) {
        mensagem('Os PIN não coincidem.');
        pinController.clear();
        return;
      }

      await armazenamentoSeguro.write(
        key: 'konta_pin',
        value: pin,
      );

      abrirPainel();
      return;
    }

    if (pin == pinGuardado) {
      abrirPainel();
    } else {
      mensagem('PIN incorrecto. Tente novamente.');
      pinController.clear();
    }
  }

  void abrirPainel() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PainelKonta()),
    );
  }

  void mensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: verde,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'KONTA',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: verde,
                  ),
                ),
                const Text(
                  'GESTÃO FINANCEIRA INTELIGENTE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 45),
                Text(
                  configuracao
                      ? confirmar
                          ? 'Confirme o seu PIN'
                          : 'Crie o seu PIN de acesso'
                      : 'Bem-vindo de volta',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  configuracao
                      ? 'Escolha um código pessoal de 6 dígitos.'
                      : 'Introduza o PIN para entrar na KONTA.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: pinController,
                    obscureText: true,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 27,
                      letterSpacing: 12,
                    ),
                    decoration: const InputDecoration(
                      hintText: '••••••',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: verde,
                    ),
                    onPressed: entrar,
                    child: Text(
                      configuracao ? 'Continuar' : 'Entrar',
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                const Text(
                  'Desenvolvido por',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const Text(
                  'Emanuel Azevedo',
                  style: TextStyle(
                    color: verde,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  '© 2026 KONTA',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PainelKonta extends StatefulWidget {
  const PainelKonta({super.key});

  @override
  State<PainelKonta> createState() => _PainelKontaState();
}

class _PainelKontaState extends State<PainelKonta> {
  List<Map<String, dynamic>> movimentos = [];
  String periodo = 'Todos';
  int pagina = 0;
  bool ocultarSaldo = false;

  final formato = NumberFormat('#,##0.00', 'pt_PT');

  String dinheiro(double valor) =>
      '${formato.format(valor)} Kz';

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    final dados = await KontaDatabase.listar();
    if (!mounted) return;
    setState(() => movimentos = dados);
  }

  List<Map<String, dynamic>> get filtrados {
    final agora = DateTime.now();

    return movimentos.where((m) {
      final data = DateTime.parse(m['data']);

      if (periodo == 'Hoje') {
        return data.year == agora.year &&
            data.month == agora.month &&
            data.day == agora.day;
      }

      if (periodo == 'Este mês') {
        return data.year == agora.year &&
            data.month == agora.month;
      }

      return true;
    }).toList();
  }

  double total(String tipo) {
    return filtrados
        .where((m) => m['tipo'] == tipo)
        .fold(0.0, (soma, m) => soma + (m['valor'] as num).toDouble());
  }

  double get receitas => total('Entrada');
  double get despesas => total('Saída');
  double get saldo => receitas - despesas;

  Future<void> novoMovimento({Map<String, dynamic>? movimento}) async {
    final descricao = TextEditingController(
      text: movimento?['descricao'] ?? '',
    );
    final valor = TextEditingController(
      text: movimento == null
          ? ''
          : (movimento['valor'] as num).toString(),
    );

    String tipo = movimento?['tipo'] ?? 'Entrada';
    String categoria = movimento?['categoria'] ?? 'Outros';

    const categorias = [
      'Vendas',
      'Serviços',
      'Investimentos',
      'Alimentação',
      'Transporte',
      'Salários',
      'Renda',
      'Compras',
      'Energia',
      'Água',
      'Outros',
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, atualizar) => AlertDialog(
          title: Text(
            movimento == null ? 'Novo movimento' : 'Editar movimento',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Entrada',
                      child: Text('Receita / Entrada'),
                    ),
                    DropdownMenuItem(
                      value: 'Saída',
                      child: Text('Despesa / Saída'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) atualizar(() => tipo = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: categoria,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: categorias.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) atualizar(() => categoria = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descricao,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Ex.: Venda de mercadoria',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valor,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor em Kz',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final numero = double.tryParse(
                  valor.text.replaceAll(',', '.'),
                );

                if (descricao.text.trim().isEmpty ||
                    numero == null ||
                    numero <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verifique a descrição e o valor.'),
                    ),
                  );
                  return;
                }

                await KontaDatabase.guardar(
                  id: movimento?['id'] as int?,
                  tipo: tipo,
                  descricao: descricao.text.trim(),
                  valor: numero,
                  categoria: categoria,
                );

                if (ctx.mounted) Navigator.pop(ctx);
                await carregar();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    descricao.dispose();
    valor.dispose();
  }

  Future<void> eliminarMovimento(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar movimento?'),
        content: const Text(
          'Esta operação não poderá ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
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

  Future<void> alterarPin() async {
    final atual = TextEditingController();
    final novo = TextEditingController();
    final confirmar = TextEditingController();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: atual,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'PIN actual'),
            ),
            TextField(
              controller: novo,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Novo PIN'),
            ),
            TextField(
              controller: confirmar,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Confirmar PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado == true) {
      final guardado = await armazenamentoSeguro.read(key: 'konta_pin');

      if (atual.text == guardado &&
          novo.text.length == 6 &&
          novo.text == confirmar.text) {
        await armazenamentoSeguro.write(
          key: 'konta_pin',
          value: novo.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN alterado com sucesso.')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados do PIN inválidos.')),
        );
      }
    }

    atual.dispose();
    novo.dispose();
    confirmar.dispose();
  }

  Widget resumo(String titulo, double valor, Color cor, IconData icone) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, color: cor, size: 24),
              const SizedBox(height: 10),
              Text(titulo, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  ocultarSaldo ? '••••••' : dinheiro(valor),
                  style: TextStyle(
                    color: cor,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
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
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => setState(() => ocultarSaldo = !ocultarSaldo),
                icon: Icon(
                  ocultarSaldo ? Icons.visibility_off : Icons.visibility,
                  color: verde,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            color: verde,
            child: Padding(
              padding: const EdgeInsets.               fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Receitas menos despesas registadas',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      cartao(
                        'Receitas',
                        receitas,
                        Colors.green,
                        Icons.trending_up,
                      ),
                      cartao(
                        'Despesas',
                        despesas,
                        Colors.red,
                        Icons.trending_down,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'MOVIMENTOS RECENTES',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (movimentos.isEmpty)
                    const Card(
                      elevation: 0,
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 42,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Ainda não existem movimentos.',
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              'Registe a primeira receita ou despesa.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ...movimentos.map((item) {
                    final entrada = item['tipo'] == 'Entrada';
                    final valor = (item['valor'] as num).toDouble();
                    final data = DateTime.parse(item['data']);

                    return Card(
                      elevation: 0,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: entrada
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          child: Icon(
                            entrada ? Icons.add : Icons.remove,
                            color: entrada ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(item['descricao']),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(data),
                        ),
                        trailing: Text(
                          '${entrada ? '+' : '-'}${dinheiro(valor)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: entrada ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 90),
                ],
              ),
            ),
    );
  }
}
