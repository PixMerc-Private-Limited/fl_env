import 'package:fl_env/fl_env.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? initError;
  try {
    await FlEnvService.instance.init();
  } catch (e) {
    initError = e;
  }

  runApp(FlEnvExampleApp(initError: initError));
}

class FlEnvExampleApp extends StatelessWidget {
  const FlEnvExampleApp({super.key, this.initError});

  final Object? initError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fl_env Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
      ),
      home: EnvShowcasePage(initError: initError),
    );
  }
}

class EnvShowcasePage extends StatelessWidget {
  const EnvShowcasePage({super.key, this.initError});

  final Object? initError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: theme.colorScheme.surface,
            title: const Text('fl_env'),
            actions: [
              if (initError == null)
                _TierChip(tier: FlEnvService.instance.activeEnvironment),
              const SizedBox(width: 12),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: initError != null
                  ? [_ErrorCard(error: initError!)]
                  : [
                      _SectionHeader('Environment values'),
                      const SizedBox(height: 8),
                      _EnvCard(
                        accessor: 'get()',
                        dartType: 'String?',
                        envKey: 'API_URL',
                        value: FlEnvService.instance.get('API_URL'),
                      ),
                      _EnvCard(
                        accessor: 'get()',
                        dartType: 'String?',
                        envKey: 'API_KEY',
                        value: FlEnvService.instance.get('API_KEY'),
                        redact: true,
                      ),
                      _EnvCard(
                        accessor: 'getInt()',
                        dartType: 'int?',
                        envKey: 'TIMEOUT',
                        value: FlEnvService.instance
                            .getInt('TIMEOUT')
                            ?.toString(),
                      ),
                      _EnvCard(
                        accessor: 'getBool()',
                        dartType: 'bool?',
                        envKey: 'DEBUG',
                        value: FlEnvService.instance
                            .getBool('DEBUG')
                            ?.toString(),
                      ),
                      _EnvCard(
                        accessor: 'getList()',
                        dartType: 'List<String>?',
                        envKey: 'TAGS',
                        value: FlEnvService.instance
                            .getList('TAGS')
                            ?.join(' · '),
                      ),
                      _EnvCard(
                        accessor: 'get()',
                        dartType: 'String?',
                        envKey: 'BACKEND_URL',
                        value: FlEnvService.instance.get('BACKEND_URL'),
                      ),
                      const SizedBox(height: 24),
                      _SectionHeader('How it works'),
                      const SizedBox(height: 8),
                      const _SetupCard(),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tier chip
// ---------------------------------------------------------------------------

class _TierChip extends StatelessWidget {
  const _TierChip({required this.tier});

  final String tier;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (tier) {
      'production' => (Colors.red.shade700, Icons.rocket_launch_outlined),
      'staging' => (Colors.amber.shade700, Icons.science_outlined),
      _ => (Colors.indigo.shade600, Icons.laptop_mac_outlined),
    };

    return Chip(
      avatar: Icon(icon, size: 14, color: Colors.white),
      label: Text(
        tier,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      side: BorderSide.none,
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Env value card
// ---------------------------------------------------------------------------

class _EnvCard extends StatelessWidget {
  const _EnvCard({
    required this.accessor,
    required this.dartType,
    required this.envKey,
    required this.value,
    this.redact = false,
  });

  final String accessor;
  final String dartType;
  final String envKey;
  final String? value;
  final bool redact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSet = value != null;
    final display = !isSet
        ? '(not set)'
        : redact
        ? '${value!.substring(0, value!.length.clamp(0, 8))}••••••••'
        : value!;
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        envKey,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          dartType,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    display,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSet
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.outline,
                      fontStyle: isSet ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              accessor,
              style: theme.textTheme.labelSmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error card — shown when FlEnvService.init() throws
// ---------------------------------------------------------------------------

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  'Initialisation failed',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Run fl_env build to generate the encrypted registry and key files:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'cd example\n'
                'cp .env.example .env\n'
                'cp .env.staging.example .env.staging\n'
                'cp .env.production.example .env.production\n'
                'FL_ENV_MASTER_KEY=<64-hex> dart run fl_env build',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Setup instructions card (collapsible)
// ---------------------------------------------------------------------------

class _SetupCard extends StatefulWidget {
  const _SetupCard();

  @override
  State<_SetupCard> createState() => _SetupCardState();
}

class _SetupCardState extends State<_SetupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.build_outlined),
            title: const Text('Quick-start'),
            subtitle: const Text(
              'How fl_env encrypts and loads your .env files',
            ),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  _Step(
                    n: '1',
                    title: 'Copy example env files',
                    code:
                        'cp .env.example .env\n'
                        'cp .env.staging.example .env.staging\n'
                        'cp .env.production.example .env.production',
                  ),
                  _Step(
                    n: '2',
                    title: 'Set your master key (never commit this)',
                    code: 'export FL_ENV_MASTER_KEY=\$(dart run fl_env keygen)',
                  ),
                  _Step(
                    n: '3',
                    title: 'Build the encrypted registry',
                    code: 'dart run fl_env build',
                  ),
                  const _Step(
                    n: '4',
                    title: 'Run the app',
                    code: 'flutter run',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The registry (FlEnvRegistry.bin) and key file '
                    '(FlEnvKey.swift / .kt) are gitignored and regenerated '
                    'from your .env files on each build.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.title, required this.code});

  final String n;
  final String title;
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              n,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    code,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
