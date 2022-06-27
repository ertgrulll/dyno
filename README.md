## Dyno

[![pub package](https://img.shields.io/pub/v/dyno.svg)](https://pub.dev/packages/dyno) [![GitHub issues](https://img.shields.io/github/issues/ertgrulll/dyno)](https://github.com/ertgrulll/dyno/issues) [![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://gitHub.com/ertgrulll/dyno/graphs/commit-activity)

Creates an isolation pool and manages it dynamically to run a closure isolated.

> **Tip**: running heavy computations isolated prevents lags in application. An isolate has it's own memory and event loop.

### Features

➡️ It doesn't create isolates for every process, communicates bidirectionally with isolations.

➡️ Has a load balancer, creates and kills isolates automatically according to load.

➡️ Lightweight, only 182 lines.

## Getting started
 Add dependency to `pubspec.yaml`:

 ```yaml
dyno: ^0.0.1
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

- Run a closure isolated,

```dart
final result = await dyno.run<String>(() {
    // Some complex process.
    return 'result of process';
});
```

### Maintainer
Hey, I'm Ertuğrul, please feel free to ask any questions about this tool. If you find `Dyno` useful, you can hit the like button and give a star to project on [Github](https://github.com/ertgrulll/dyno) to motivate me or treat me with [coffee](https://www.buymeacoffee.com/ertgrulll).