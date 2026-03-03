import 'package:flutter/material.dart';
import 'package:rtls_flutter/rtls_flutter.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RTLS Flutter Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const RTLScreen(),
    );
  }
}

class RTLScreen extends StatefulWidget {
  const RTLScreen({super.key});

  @override
  State<RTLScreen> createState() => _RTLScreenState();
}

class _RTLScreenState extends State<RTLScreen> {
  final _baseUrl = TextEditingController(text: 'http://localhost:3000');
  final _userId = TextEditingController(text: 'flutter-user-1');
  final _deviceId = TextEditingController(text: 'flutter-device-1');
  final _token = TextEditingController(text: 'demo-token');
  bool _configured = false;
  String _lastEvent = '—';
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    RTLSync.events.listen((e) {
      if (mounted) {
        setState(() {
          _lastEvent = '${e['type']}: ${e['point'] ?? e['message'] ?? e['event'] ?? ''}';
        });
        _refreshStats();
      }
    });
  }

  Future<void> _refreshStats() async {
    final stats = await RTLSync.getStats();
    if (mounted) setState(() => _pendingCount = stats.pendingCount);
  }

  Future<void> _configure() async {
    try {
      await RTLSync.configure(RTLSyncConfig(
        baseUrl: _baseUrl.text.trim(),
        userId: _userId.text.trim(),
        deviceId: _deviceId.text.trim(),
        accessToken: _token.text.trim(),
      ));
      if (mounted) setState(() => _configured = true);
      await _refreshStats();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _start() async {
    try {
      await RTLSync.startTracking();
      await _refreshStats();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _stop() async {
    await RTLSync.stopTracking();
    await _refreshStats();
  }

  Future<void> _flush() async {
    try {
      await RTLSync.flushNow();
      await _refreshStats();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RTLS Flutter Example')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _baseUrl, decoration: const InputDecoration(labelText: 'Base URL'), enabled: !_configured),
            const SizedBox(height: 8),
            TextField(controller: _userId, decoration: const InputDecoration(labelText: 'User ID'), enabled: !_configured),
            const SizedBox(height: 8),
            TextField(controller: _deviceId, decoration: const InputDecoration(labelText: 'Device ID'), enabled: !_configured),
            const SizedBox(height: 8),
            TextField(controller: _token, decoration: const InputDecoration(labelText: 'Access token'), obscureText: true, enabled: !_configured),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _configured ? null : _configure, child: const Text('Configure')),
            const SizedBox(height: 16),
            Text('Pending: $_pendingCount', style: Theme.of(context).textTheme.titleMedium),
            Text('Last event: $_lastEvent', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (_configured) ...[
              Row(
                children: [
                  Expanded(child: ElevatedButton(onPressed: _start, child: const Text('Start'))),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton(onPressed: _stop, child: const Text('Stop'))),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _flush, child: const Text('Flush now')),
            ],
          ],
        ),
      ),
    );
  }
}
