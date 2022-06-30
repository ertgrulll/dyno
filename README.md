# Dyno

[![pub package](https://img.shields.io/pub/v/dyno.svg)](https://pub.dev/packages/dyno) [![GitHub issues](https://img.shields.io/github/issues/ertgrulll/dyno)](https://github.com/ertgrulll/dyno/issues) [![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://gitHub.com/ertgrulll/dyno/graphs/commit-activity)

Creates an isolation pool and manages it dynamically to run a closure isolated.

> **Tip**: running heavy computations isolated prevents lags in application. An isolate has it's own memory and event loop.

## Features

➡️ It doesn't create isolates for every process, communicates bidirectionally with isolations.

➡️ Has a load balancer, creates and kills isolates automatically according to load.

➡️ Allows the use of certain isolate for certain processes. 

➡️ Lightweight, only ~270 lines.

## Getting started
 Add dependency to `pubspec.yaml`:

 ```yaml
dyno: ^0.0.3
 ```

## Usage

- Import `dyno`,

```dart
import 'package:dyno/dyno.dart' as dyno;
```

- prepare isolates before use. (_This an optional step_)

**Dyno** creates isolates as needed, but preparing speeds up first run. You can prepare dyno on the splash screen or any other desired place.

```dart
dyno.prepare(single: false);
```

> `prepare` creates _two_ isolate by default, but creates _one_ isolate when `single` parameter is set to true.

- Running isolated,

    -  Closure, use with caution, may capture more then it's need and may cause exception.
    ```dart
    final result = await dyno.run<String>(() {
      // Some complex process.
      return 'result of process';
    });
    ```

    - Static, top level or parameterized function(can accept max 4 parameters).
    ```dart
    Future<MyObject> myFunc(String param1) async {
      final myResult = await doSomething(param1);

      return myResults;
    }
    ```

    ```dart
    final result = await dyno.run<MyObject>(myFunc, param1: 'myParam');
    ```
    or
    ```dart
    final result = await dyno.run<MyObject>((String param1) async {
      final myResult = await doSomething(param1);

      return myResults;
    }, param1: 'myParam');
    ```

### Isolator Reserve
 Isolator reserving useful for processes that require initialization. Isolates don't share memory, once you initialize a class or a package in the main isolate, you can't use it in another isolate without initializing it for isolation. ***Dyno*** excludes reserved isolators from automatic clean and keeps them alive until `unreserve` called.

 > An example use case may be cache supported api requests. Reserve an isolate, initialize your local database package(tested with _Hive_) and send all requests, encode/decode jsons, save it to the local database in reserved isoalator and return result.

 Reserve an isolator and initialize required classes/packages inside it,

```dart
await dyno.reserve('my_api_isolator');
dyno.run(() async => await initializeMyLocalDb(), key: 'my_api_isolator');
```
And use reserved isolator later by sending key to the `run` method,

```dart
dyno.run<Profile>((String userId) async {
  final profile = await getProfileFromMyRemoteDb(userId);
  await MyCache.add(profile);

  return profile;
}, param1: 'myUserId', key: 'my_api_isolator');
```
When you want to let dyno to clean reserved isolator, call `dyno.unreserve('my_api_isolator')`. 
 ___


## Maintainer
Hey, I'm Ertuğrul, please feel free to ask any questions about this tool. If you find `Dyno` useful, you can hit the like button and give a star to project on [Github](https://github.com/ertgrulll/dyno) to motivate me or treat me with [coffee](https://www.buymeacoffee.com/ertgrulll).