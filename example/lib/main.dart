import 'package:fl_env/fl_env.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlEnvService.instance.init();

  runApp(const FlEnvExampleApp());
}

class FlEnvExampleApp extends StatelessWidget {
  const FlEnvExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fl_env Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const EnvValuesPage(),
    );
  }
}

class EnvValuesPage extends StatefulWidget {
  const EnvValuesPage({super.key});

  @override
  State<EnvValuesPage> createState() => _EnvValuesPageState();
}

class _EnvValuesPageState extends State<EnvValuesPage> {
  final _service = FlEnvService.instance;

  @override
  Widget build(BuildContext context) {
    final apiUrl = _service.get('API_URL') ?? '(not set)';
    final timeout = _service.getInt('TIMEOUT');
    final debug = _service.getBool('DEBUG');
    final tier = _service.activeEnvironment;

    return Scaffold(
      appBar: AppBar(
        title: const Text('fl_env Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EnvTile(label: 'Active tier', value: tier),
          _EnvTile(label: 'API_URL', value: apiUrl),
          _EnvTile(label: 'TIMEOUT', value: timeout?.toString() ?? '(not set)'),
          _EnvTile(label: 'DEBUG', value: debug?.toString() ?? '(not set)'),
        ],
      ),
    );
  }
}

class _EnvTile extends StatelessWidget {
  const _EnvTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(value),
    );
  }
}
