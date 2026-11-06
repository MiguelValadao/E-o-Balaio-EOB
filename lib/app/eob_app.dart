import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/live_tracking/presentation/live_map_page.dart';

class EOBApp extends StatelessWidget {
  const EOBApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'E o Balaio?',
        debugShowCheckedModeBanner: false,
        locale: DevicePreview.locale(context),
        builder: DevicePreview.appBuilder,
        theme: AppTheme.light,
        home: const LiveMapPage(),
      );
}
