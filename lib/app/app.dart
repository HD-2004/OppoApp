import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class TempJobsApp extends StatelessWidget {
  const TempJobsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Oppo Temp Jobs',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: buildAppTheme(),
    );
  }
}
