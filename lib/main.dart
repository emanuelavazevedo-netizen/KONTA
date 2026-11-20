
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await KontaDatabase.database;
  runApp(const KontaApp());
}

class KontaDatabase {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;

    final path = p.join(
      await getDatabasesPath(),
      'konta.db',
    );

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE movimentos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo TEXT NOT NULL,
            descricao TEXT NOT NULL,
            valor REAL NOT NULL,
            data TEXT NOT NULL
          )
        ''');
      },
    );

    return _db!;
  }

  static Future<void> adicionar(
    String tipo,
    String descricao,
    double valor,
  ) async {
    final db = await database;

    await db.insert('movimentos', {
      'tipo': tipo,
      'descricao': descricao,
      'valor': valor,
      'data': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> listar() async {
    final db = await database;
    return db.query(
      'movimentos',
      orderBy: 'id DESC',
    );
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
        colorSchemeSeed: const Color(0xFF087F5B),
        scaffoldBackgroundColor: const Color(0xFFF4F6F5),
      ),
      home: const InicioKonta(),
    );
  }
}

class InicioKonta extends StatefulWidget {
  const InicioKonta({super.key});

  @override
  State<InicioKonta> createState() => _InicioKontaState();
}

class _InicioKontaState extends State<InicioKonta> {
  List<Map<String, dynamic>> movimentos = [];
  bool carregando = true;

  double receitas = 0;
  double despesas = 0;

  double get saldo => receitas - despesas;

  final formato = NumberFormat('#,##0.00', 'pt_PT');

  String dinheiro(double valor) {
    return '${formato.format(valor)} Kz';
  }

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    final dados = await KontaDatabase.listar();

    double entradas = 0;
    double saidas = 0;

    for (final item in dados) {
      final valor = (item['valor'] as num).toDouble();

      if (item['tipo'] == 'Entrada') {
        entradas += valor;
      } else {
        saidas += valor;
      }
    }

    if (!mounted) return;

    setState(() {
      movimentos = dados;
      receitas = entradas;
      despesas = saidas;
      carregando = false;
    });
  }

  Future<void> adicionarMovimento() async {
    final descricaoController = TextEditingController();
    final valorController = TextEditingController();

    String tipo = 'Entrada';
    final chave = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, atualizar) {
            return AlertDialog(
              title: const Text('Novo movimento'),
              content: Form(
                key: chave,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: tipo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de movimento',
                      ),
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
                      onChanged: (valor) {
                        if (valor != null) {
                          atualizar(() => tipo = valor);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descricaoController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Ex.: Venda de produtos',
                      ),
                      validator: (valor) {
                        if (valor == null || valor.trim().isEmpty) {
                          return 'Indique uma descrição';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: valorController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor em kwanzas',
                        hintText: 'Ex.: 15000',
                      ),
                      validator: (valor) {
                        final numero = double.tryParse(
                          (valor ?? '').replaceAll(',', '.'),
                        );

                        if (numero == null || numero <= 0) {
                          return 'Indique um valor válido';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!chave.currentState!.validate()) return;

                    final valor = double.parse(
                      valorController.text.replaceAll(',', '.'),
                    );

                    await KontaDatabase.adicionar(
                      tipo,
                      descricaoController.text.trim(),
                      valor,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                    }

                    await carregarDados();
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    descricaoController.dispose();
    valorController.dispose();
  }

  Widget cartao(
    String titulo,
    double valor,
    Color cor,
    IconData icone,
  ) {
    return Expanded(
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, color: cor, size: 25),
              const SizedBox(height: 12),
              Text(
                titulo,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 5),
              Text(
                dinheiro(valor),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF087F5B),
        foregroundColor: Colors.white,
        title: const Text(
          'KONTA',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: carregarDados,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: adicionarMovimento,
        backgroundColor: const Color(0xFF087F5B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo movimento'),
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: carregarDados,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'RESUMO FINANCEIRO',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF087F5B),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Saldo dos movimentos',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            dinheiro(saldo),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
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
