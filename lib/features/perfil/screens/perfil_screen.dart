import 'package:flutter/cupertino.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/storage/token_storage.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = MockUserData.user;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgGrey,
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'Perfil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: CupertinoColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 10),
            // Avatar
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.olive.withOpacity(0.12),
                ),
                alignment: Alignment.center,
                child: Text(
                  user.fullName[0],
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.olive,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                user.displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
            ),
            Center(
              child: Text(
                '${user.role} • Mat. ${user.matricula}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.olive,
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Info card
            _infoRow('Grupo Sanguíneo', user.bloodType),
            _infoRow('Edad', '${user.age} años'),
            _infoRow('Matrícula', user.matricula),
            const SizedBox(height: 30),
            // Logout
            CupertinoButton(
              color: AppColors.errorRed,
              borderRadius: BorderRadius.circular(14),
              onPressed: () async {
                await TokenStorage.deleteToken();
                if (!context.mounted) return;
                Navigator.of(context, rootNavigator: true)
                    .pushReplacementNamed('/login');
              },
              child: const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 15, color: AppColors.subtleGrey),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
        ],
      ),
    );
  }
}
