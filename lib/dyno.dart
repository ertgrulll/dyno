/// A dynamic isolation pool with load balance for Flutter.
library dyno;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

/// Keeps bidirectional isolators.
final _isolators = <_Isolator>[];

/// Isolate count limit.
final _limit =
    Platform.numberOfProcessors == 1 ? 2 : Platform.numberOfProcessors;

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
    final instance = _Isolator();
    await instance.init();
    _isolators.add(instance);
  }
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
      _isolators[i].dispose();
      _isolators.removeAt(i);
    }
  }

  if (_isolators[0].load != 0 && _isolators.length - 1 != _limit) {
    final isolator = _Isolator();
    await isolator.init();

    _isolators.insert(0, isolator);
  }

  return _isolators.first;
}

/// Runs given closure isolated and returns result.
FutureOr<R> run<R>(FutureOr<R> Function() func) async {
  final completer = Completer<R>();
  final isolator = await _getFree();

  // Create a key to pass isolation, isolation sends back this key.
  // Key is used to ensure returned result is for the func.
  final key = Capability();
  late final StreamSubscription<dynamic> subs;
  subs = isolator.listen((message) {
    final mes = message as _IsolationResponse;

    if (mes.key == key) {
      isolator.load--;
      completer.complete(mes.result as R);
      subs.cancel();
    }
  });

  isolator.load++;
  isolator.port.send(_IsolationRequest<R>(key, func));

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

class _Isolator {
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

/// Params to send to isolate.
class _IsolationRequest<R> {
  const _IsolationRequest(this.key, this.closure);

  /// Key to match response.
  final Capability key;

  /// Closure to run in isolate.
  final FutureOr<R> Function() closure;
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
      final res = await Future.value(message.closure());

      sendPort.send(_IsolationResponse(message.key, res));
    }
  });
}
