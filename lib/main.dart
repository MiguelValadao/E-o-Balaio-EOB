import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app/eob_app.dart';

export 'app/eob_app.dart';

void main() => runApp(
      DevicePreview(
        enabled: !kReleaseMode,
        builder: (_) => const EOBApp(),
      ),
    );

// Code developed by Miguel Valadão. All rights reserved.
