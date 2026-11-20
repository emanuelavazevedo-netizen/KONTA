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
