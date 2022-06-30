/// A dynamic isolation pool with load balance for Flutter.
library dyno;

import 'dart:async';
import 'dart:isolate';

/// Keeps bidirectional isolators.
final _isolators = <_Isolator>[];

/// Prepares max two isolate before using [run].
///
/// Isolates creating and disposing dynamically according to isolators load.
/// No need to prepare more then 2 isolate, [run] function automatically
/// disposes unnecessary isolates everytime it's called.
///
/// When [single] set to true creates one isolator.
Future<void> prepare({bool single = false}) async {
  if (_isolators.isNotEmpty) return;

  int isolationCount = single ? 1 : 2;

  for (int i = 0; i < isolationCount; i++) {
    await _createIsolator();
  }
}

/// Reserves an isolator.
///
/// Isolator is still available for other processes, but is not automatically
/// killed when it's not in use.
///
/// Isolates don't share same memory, so when you initialized something in main
/// isolate, you need to re-initialize it in another isolate to use in an
/// isolation.
/// Reserving an isolation prevents re-initialize every time.
Future<void> reserve({required String key}) async {
  final unreservedIsolators = _isolators.where((i) => i.identifier == null);
  final isolator = unreservedIsolators.length == 1
      ? await _createIsolator()
      : unreservedIsolators.first;

  isolator.identifier = key;
}

void unreserve(String key) {
  _isolators.firstWhere((element) => element.identifier == key).identifier =
      null;
}

/// Returns free isolator if there are or creates new one.
///
/// Also, disposes unnecessary isolators.
Future<_Isolator> _getFree() async {
  // Create first isolator if prepare not called before using run function.
  await prepare(single: true);

  _isolators.sort((a, b) => a.load - b.load);

  // Find the first isolator index where the load is not 0.
  int loadPos = _isolators.indexWhere((element) => element.load > 0);
  loadPos = loadPos == -1 ? _isolators.length : loadPos;

  // Dispose and remove unnecessary isolators, keep 2 free isolators live.
  if (loadPos > 2) {
    for (int i = loadPos - 1; i > 1; i--) {
      final isolator = _isolators[i];
      // Prevent reserved isolator from disposed.
      if (isolator.identifier != null) continue;

      isolator.dispose();
      _isolators.removeAt(i);
    }
  }

  if (_isolators[0].load != 0) {
    final isolator = _Isolator();
    await isolator.init();

    _isolators.insert(0, isolator);
  }

  return _isolators.first;
}

/// Runs a function isolated and returns result.
///
/// [func] is a function reference which can accept max four
/// positional parameters. Only send desired parameters to [run].
/// [key] is the reserved isolation key. When provided, given function is
/// executed in reserved isolation without controlling its load.
FutureOr<R> run<R>(
  Function func, {
  dynamic param1,
  dynamic param2,
  dynamic param3,
  dynamic param4,
  String? key,
}) async {
  final completer = Completer<R>();
  late final _Isolator isolator;

  if (key != null) {
    isolator = _isolators.firstWhere((element) => element.identifier == key);
  } else {
    isolator = await _getFree();
  }

  // Create a key to pass isolation, isolation sends back this key.
  // Key is used to ensure returned result is for the func.
  final processCap = Capability();
  late final StreamSubscription<dynamic> subs;
  subs = isolator.listen((message) {
    final mes = message as _IsolationResponse;

    if (mes.key == processCap) {
      isolator.load--;
      completer.complete(mes.result as R);
      subs.cancel();
    }
  });

  isolator.load++;
  isolator.port.send(
    _IsolationRequest(processCap, func, param1, param2, param3, param4),
  );

  return completer.future;
}

/// Kills and clears all isolators.
///
/// Any running operation in an isolator stops and [run] won't return a result
/// when this function called.
void dispose() {
  for (int i = 0; i < _isolators.length; i++) {
    _isolators[i].dispose();
  }
  _isolators.clear();
}

/// Creates an isolator and adds it to the isolators.
Future<_Isolator> _createIsolator() async {
  final instance = _Isolator();
  await instance.init();
  _isolators.add(instance);

  return instance;
}

class _Isolator {
  /// Identifier of isolator.
  ///
  /// If not null, the isolate won't be killed automatically when not in use.
  String? identifier;

  /// Isolate to use for this instance.
  late final Isolate _isolate;

  /// Port to receive messages from isolate.
  /// Isolation sends messages to this port.
  late ReceivePort _receiver;

  /// Send results to the listeners.
  final _streamController = StreamController.broadcast();

  /// Port to send messages to isolate.
  late SendPort port;

  /// Number of pending processes.
  int load = 0;

  /// Adds listener to isolate for responses.
  StreamSubscription<dynamic> listen(void Function(dynamic message) listener) =>
      _streamController.stream.listen(listener);

  /// Kills isolate and controller.
  void dispose() {
    _isolate.kill();
    _streamController.close();
  }

  /// Initializes isolator.
  Future<void> init() async {
    _receiver = ReceivePort();
    final completer = Completer<void>();

    _receiver.listen((message) {
      if (!completer.isCompleted) {
        port = message;
        completer.complete();
      } else {
        _streamController.add(message);
      }
    });

    _isolate = await Isolate.spawn(_isolated, _receiver.sendPort);

    return completer.future;
  }
}

/// Request parameters for top level or static functions.
class _IsolationRequest<R> {
  _IsolationRequest(
    this.key,
    this.function,
    this.param1,
    this.param2,
    this.param3,
    this.param4,
  );

  /// Key to match response.
  final Capability key;

  /// Function to call
  final Function function;

  /// Function parameter one
  final dynamic param1;

  /// Function parameter two
  final dynamic param2;

  /// Function parameter three
  final dynamic param3;

  /// Function parameter 4
  final dynamic param4;
}

/// Response from isolate.
class _IsolationResponse {
  const _IsolationResponse(this.key, this.result);

  /// Key to match request.
  final Capability key;

  /// Result of closure.
  final dynamic result;
}

/// Isolate entry point.
void _isolated(SendPort sendPort) {
  ReceivePort receivePort = ReceivePort();

  sendPort.send(receivePort.sendPort);
  receivePort.listen((message) async {
    if (message is _IsolationRequest) {
      final p1 = message.param1,
          p2 = message.param2,
          p3 = message.param3,
          p4 = message.param4;
      final f = message.function;

      late final dynamic res;

      if (p4 != null) {
        res = await Future.value(f(p1, p2, p3, p4));
      } else if (p3 != null) {
        res = await Future.value(f(p1, p2, p3));
      } else if (p2 != null) {
        res = await Future.value(f(p1, p2));
      } else if (p1 != null) {
        res = await Future.value(f(p1));
      } else if (p1 == null) {
        res = await Future.value(f());
      }

      sendPort.send(_IsolationResponse(message.key, res));
    }
  });
}
