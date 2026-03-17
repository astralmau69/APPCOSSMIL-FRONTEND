import 'package:flutter/cupertino.dart';
import '../../../core/constants/app_colors.dart';

class ReservasScreen extends StatelessWidget {
  const ReservasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgGrey,
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'Reservas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: CupertinoColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.calendar,
                size: 56,
                color: AppColors.subtleGrey.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No tiene reservas pendientes',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.subtleGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
