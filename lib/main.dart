// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculadora de Gorjeta',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const TipCalculatorScreen(),
    );
  }
}

class TipCalculatorScreen extends StatefulWidget {
  const TipCalculatorScreen({Key? key}) : super(key: key);

  @override
  _TipCalculatorScreenState createState() => _TipCalculatorScreenState();
}

class _TipCalculatorScreenState extends State<TipCalculatorScreen> {
  final TextEditingController _billController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  double _billAmount = 0.0;
  
  final formatCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void dispose() {
    _billController.dispose();
    super.dispose();
  }

  void _calculateTip() {
    setState(() {
      _billAmount = double.tryParse(_billController.text) ?? 0.0;
    });
  }

  Future<void> _saveTipCalculation(double tipPercentage) async {
    if (_billAmount <= 0) return;
    
    final tipAmount = _billAmount * (tipPercentage / 100);
    final totalAmount = _billAmount + tipAmount;
    
    await _firestore.collection('tip_history').add({
      'billAmount': _billAmount,
      'tipPercentage': tipPercentage,
      'tipAmount': tipAmount,
      'totalAmount': totalAmount,
      'date': Timestamp.now(),
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cálculo salvo no histórico')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora de Gorjeta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _billController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Valor da Conta',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monetization_on),
                hintText: 'Digite o valor da conta',
              ),
              onChanged: (value) {
                _calculateTip();
              },
            ),
            const SizedBox(height: 32),
            if (_billAmount > 0) ...[
              Text(
                'Valor da Conta: ${formatCurrency.format(_billAmount)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Text(
                'Sugestões de Gorjeta:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _buildTipCard(10),
              const SizedBox(height: 12),
              _buildTipCard(15),
              const SizedBox(height: 12),
              _buildTipCard(20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(double percentage) {
    final tipAmount = _billAmount * (percentage / 100);
    final total = _billAmount + tipAmount;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '${percentage.toInt()}%',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gorjeta: ${formatCurrency.format(tipAmount)}'),
                    Text('Total: ${formatCurrency.format(total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => _saveTipCalculation(percentage),
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Gorjetas'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tip_history')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhum cálculo de gorjeta salvo.'));
          }

          final formatCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
          final formatDate = DateFormat('dd/MM/yyyy HH:mm');

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final double billAmount = data['billAmount'] ?? 0.0;
              final double tipPercentage = data['tipPercentage'] ?? 0.0;
              final double tipAmount = data['tipAmount'] ?? 0.0;
              final double totalAmount = data['totalAmount'] ?? 0.0;
              final Timestamp timestamp = data['date'] ?? Timestamp.now();
              final DateTime date = timestamp.toDate();
              
              return Dismissible(
                key: Key(doc.id),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  FirebaseFirestore.instance.collection('tip_history').doc(doc.id).delete();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item removido do histórico')),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatDate.format(date),
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Text(
                              '${tipPercentage.toInt()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Valor da Conta:'),
                            Text(formatCurrency.format(billAmount)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Gorjeta:'),
                            Text(formatCurrency.format(tipAmount)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total:'),
                            Text(
                              formatCurrency.format(totalAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}