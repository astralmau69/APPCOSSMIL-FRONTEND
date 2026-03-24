import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/beneficiary_model.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/theme/app_constants.dart';

class FamiliaScreen extends StatefulWidget {
  const FamiliaScreen({super.key});

  @override
  State<FamiliaScreen> createState() => _FamiliaScreenState();
}

class _FamiliaScreenState extends State<FamiliaScreen> {
  // Pre-decoded photos — avoids decoding base64 on every parent rebuild.
  late final List<Uint8List?> _decodedPhotos;

  @override
  void initState() {
    super.initState();
    _decodedPhotos = MockUserData.user.beneficiaries.map((b) {
      if (b.photoBase64.isEmpty) return null;
      try {
        return base64Decode(b.photoBase64);
      } catch (_) {
        return null;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final beneficiaries = MockUserData.user.beneficiaries;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleCount = beneficiaries.length;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(
              'Mi Grupo Familiar',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            backgroundColor: isDark
                ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
                : AppColors.white.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Text(
                      '$titleCount miembro${titleCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.white : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding:
                const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final b = beneficiaries[index];
                  final decodedPhoto =
                      index < _decodedPhotos.length ? _decodedPhotos[index] : null;

                  return FadeSlideIn(
                    delay: Duration(milliseconds: 60 + (index * 70)),
                    offsetY: 14,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BeneficiaryCard(
                        beneficiary: b,
                        decodedPhoto: decodedPhoto,
                        isDark: isDark,
                      ),
                    ),
                  );
                },
                childCount: beneficiaries.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card individual por beneficiario ────────────────────────────────────────
class _BeneficiaryCard extends StatelessWidget {
  final BeneficiaryModel beneficiary;
  final Uint8List? decodedPhoto;
  final bool isDark;

  const _BeneficiaryCard({
    required this.beneficiary,
    required this.decodedPhoto,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final b = beneficiary;
    final isTitular = b.isTitular;
    final accentColor = isTitular
        ? (isDark ? AppColors.razer : AppColors.primary)
        : AppColors.accent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isTitular
              ? accentColor.withValues(alpha: isDark ? 0.35 : 0.2)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border),
          width: isTitular ? 1.0 : 0.5,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // ── Avatar ──
          _buildAvatar(accentColor),
          const SizedBox(width: 14),
          // ── Info ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.fullName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color:
                              Theme.of(context).textTheme.bodyLarge?.color ??
                                  AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isTitular)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'TITULAR',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: accentColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isTitular ? 'Titular de la cuenta' : b.relationship,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                // ── Chips de info ──
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (b.matricula.isNotEmpty)
                      _chip(
                        icon: CupertinoIcons.number,
                        label: 'Mat. ${b.matricula}',
                        isDark: isDark,
                      ),
                    if (b.age != null)
                      _chip(
                        icon: CupertinoIcons.calendar,
                        label: '${b.age} años',
                        isDark: isDark,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            CupertinoIcons.chevron_right,
            color: AppColors.textTertiary,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Color accentColor) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [accentColor, accentColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipOval(
        child: decodedPhoto != null
            ? Image.memory(
                decodedPhoto!,
                fit: BoxFit.cover,
                width: 56,
                height: 56,
                errorBuilder: (_, __, ___) => _initial(),
              )
            : _initial(),
      ),
    );
  }

  Widget _initial() {
    return Center(
      child: Text(
        beneficiary.initial,
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : AppColors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 11,
              color: isDark
                  ? AppColors.white.withValues(alpha: 0.5)
                  : AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.white.withValues(alpha: 0.6)
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
