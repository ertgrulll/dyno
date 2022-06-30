import 'package:flutter/material.dart';
import 'package:dyno/dyno.dart' as dyno;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const MaterialApp(home: Demo());
}

class Demo extends StatefulWidget {
  const Demo({Key? key}) : super(key: key);

  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  int _executionTime = 0;

  Future<void> measureRun() async {
    final stopwatch = Stopwatch()..start();

    // Calculate the 10000th Fibonacci number isolated.
    await dyno.run<int>(() async {
      int n1 = 0, n2 = 1;
      late int n3;

      for (int i = 2; i <= 10000; i++) {
        n3 = n1 + n2;
        n1 = n2;
        n2 = n3;
      }

      return n3;
    });

    setState(() => _executionTime = stopwatch.elapsed.inMilliseconds);
    stopwatch.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(child: Text('Execution time in ms: $_executionTime')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: measureRun,
        child: const Text('Start'),
      ),
    );
  }
}
