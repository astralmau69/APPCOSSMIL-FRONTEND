import 'package:flutter/cupertino.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/models/user_model.dart';
import '../../../shell/tab_shell.dart';

class HomeScreen extends StatefulWidget {
  final TabShellState tabShell;

  const HomeScreen({super.key, required this.tabShell});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = MockUserData.user;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgGrey,
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 16),
              // Saludo + título
              Text(
                'Bienvenido,',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.subtleGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.displayName,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              _buildProfileCard(user),
              const SizedBox(height: 32),
              // Sección asegurados
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'SELECCIONE UN ASEGURADO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.subtleGrey,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildBeneficiaryList(user),
              const SizedBox(height: 24),
              // Quick action
              _buildQuickActions(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7A7640),
            Color(0xFF5C5928),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.olive.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white.withOpacity(0.2),
                  border: Border.all(
                    color: AppColors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  user.fullName[0],
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user.rank} ${user.fullName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${user.role} • Mat. ${user.matricula}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 0.5,
            color: AppColors.white.withOpacity(0.15),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _infoBadge(
                icon: CupertinoIcons.drop_fill,
                label: 'GRUPO SANG.',
                value: user.bloodType,
              ),
              Container(
                width: 0.5,
                height: 36,
                color: AppColors.white.withOpacity(0.15),
              ),
              _infoBadge(
                icon: CupertinoIcons.person_fill,
                label: 'EDAD',
                value: '${user.age} años',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBadge({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AppColors.white.withOpacity(0.7)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white.withOpacity(0.55),
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBeneficiaryList(UserModel user) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          for (int i = 0; i < user.beneficiaries.length; i++) ...[
            _beneficiaryTile(user.beneficiaries[i], i == 0),
            if (i < user.beneficiaries.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 0.5, color: AppColors.cardBorder),
              ),
          ],
        ],
      ),
    );
  }

  Widget _beneficiaryTile(final beneficiary, bool isSelf) {
    final label = isSelf
        ? 'Para mí (${beneficiary.relationship})'
        : '${beneficiary.fullName} (${beneficiary.relationship})';

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        widget.tabShell.startBooking(
          isSelf ? 'Para mí' : beneficiary.fullName,
          beneficiary,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.olive.withOpacity(0.12),
                    AppColors.olive.withOpacity(0.06),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                beneficiary.fullName[0],
                style: const TextStyle(
                  color: AppColors.olive,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    beneficiary.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isSelf ? 'Titular' : beneficiary.relationship,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.subtleGrey,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.olive.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: AppColors.olive,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionCard(
            icon: CupertinoIcons.calendar_badge_plus,
            label: 'Nueva\nReserva',
            onTap: () => widget.tabShell.startBooking('Para mí',
                MockUserData.user.beneficiaries[0]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard(
            icon: CupertinoIcons.clock,
            label: 'Mis\nReservas',
            onTap: () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard(
            icon: CupertinoIcons.phone,
            label: 'Línea\nDirecta',
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.olive.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.olive),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
