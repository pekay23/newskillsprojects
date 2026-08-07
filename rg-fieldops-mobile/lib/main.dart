import 'package:flutter/material.dart';
import 'services/database_helper.dart';
import 'services/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FieldOpsApp());
}

class FieldOpsApp extends StatelessWidget {
  const FieldOpsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raymond Gray FieldOps',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _apiClient = ApiClient();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FieldOps Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing data to Cloud...')),
              );
              await _apiClient.syncLocalChanges();
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Offline-First Work Order Management'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await DatabaseHelper.instance.insertWorkOrder({
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'title': 'Fix HVAC in Lobby',
                  'status': 'open',
                  'priority': 'high',
                  'sync_status': 0
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved locally to queue!')),
                );
              },
              child: const Text('Create Offline Work Order'),
            ),
          ],
        ),
      ),
    );
  }
}
