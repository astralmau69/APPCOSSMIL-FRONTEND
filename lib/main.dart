import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  // Initialize Spanish locale for date formatting
  await initializeDateFormatting('es');
  // Initialize notification channels + timezone before app launch
  await NotificationService.initialize();
  runApp(const CossmilApp());
}
