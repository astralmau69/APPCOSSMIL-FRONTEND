import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/beneficiary_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/session/user_session.dart';
import '../../../core/theme/app_constants.dart';

class FamiliaScreen extends StatefulWidget {
  const FamiliaScreen({super.key});

  @override
  State<FamiliaScreen> createState() => _FamiliaScreenState();
}

class _FamiliaScreenState extends State<FamiliaScreen> {
  final _service = ProgramacionService();
  List<BeneficiaryModel> _beneficiaries = [];
  List<Uint8List?> _decodedPhotos = [];
  bool _isLoading = true;
  String? _error;

  bool get _isTitular => UserSession.currentUser.isTitular;

  @override
  void initState() {
    super.initState();
    _fetchGrupoFamiliar();
  }

  Future<void> _fetchGrupoFamiliar() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isTitular) {
        // Titular: fetch full group from API
        final idper = int.tryParse(UserSession.currentUser.id) ?? 0;
        final members = await _service.getGrupoFamiliar(idper);

        if (!mounted) return;

        if (members.isNotEmpty) {
          // Ensure titular is in the list
          if (!members.any((b) => b.isTitular)) {
            final selfBeneficiary = _selfAsBeneficiary();
            members.insert(0, selfBeneficiary);
          }
          // Update UserSession so booking flow sees fresh data
          UserSession.currentUser = UserSession.currentUser.copyWith(
            beneficiaries: members,
          );
          _setMembers(members);
        } else {
          // API returned empty — use cached from login
          _useCachedOrSelf();
        }
      } else {
        // Beneficiario: only show themselves, no API call for group
        if (!mounted) return;
        _setMembers([_selfAsBeneficiary()]);
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('❌ Error fetching grupo familiar: $e');
      _useCachedOrSelf();
    }
  }

  /// Fallback: use cached beneficiaries from login session, or self only.
  void _useCachedOrSelf() {
    final cached = UserSession.currentUser.beneficiaries;
    if (cached.isNotEmpty) {
      if (_isTitular) {
        _setMembers(cached);
      } else {
        // Non-titular: only show self from cached list
        final self = cached.firstWhere(
          (b) => b.id == UserSession.currentUser.id,
          orElse: () => _selfAsBeneficiary(),
        );
        _setMembers([self]);
      }
    } else {
      _setMembers([_selfAsBeneficiary()]);
    }
  }

  /// Create a BeneficiaryModel from the current logged-in user.
  BeneficiaryModel _selfAsBeneficiary() {
    final user = UserSession.currentUser;
    // Try to find self in the beneficiaries list first (to get photo)
    final existing = user.beneficiaries.where((b) => b.id == user.id);
    if (existing.isNotEmpty) return existing.first;

    return BeneficiaryModel(
      id: user.id,
      fullName: user.fullName,
      relationship: user.isTitular ? 'Titular' : 'Beneficiario',
      age: user.age,
      gender: user.gender,
      matricula: user.matricula,
      photoBase64: user.photoBase64,
    );
  }

  void _setMembers(List<BeneficiaryModel> members) {
    final photos = members.map((b) {
      if (b.photoBase64.isEmpty) return null;
      try {
        return base64Decode(b.photoBase64);
      } catch (_) {
        return null;
      }
    }).toList();

    setState(() {
      _beneficiaries = members;
      _decodedPhotos = photos;
      _isLoading = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleCount = _beneficiaries.length;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(
              _isTitular ? 'Mi Grupo Familiar' : 'Mi Perfil',
              style: TextStyle(
                color: AppColors.textPrimaryC(isDark),
              ),
            ),
            backgroundColor: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.92)
                : AppColors.white.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(
                color: AppColors.dividerC(isDark),
                width: 0.5,
              ),
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: _fetchGrupoFamiliar,
          ),

          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator(radius: 14)),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.wifi_slash,
                          size: 40, color: AppColors.textTertiaryC(isDark)),
                      const SizedBox(height: 16),
                      Text(
                        'No se pudo cargar la información',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryC(isDark),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Verifica tu conexión y desliza hacia abajo para reintentar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryC(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            // Info header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentBg(isDark),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(
                              color: AppColors.accentForTheme(isDark)
                                  .withValues(alpha: 0.25),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            _isTitular
                                ? '$titleCount miembro${titleCount != 1 ? 's' : ''}'
                                : 'Beneficiario',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentForTheme(isDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!_isTitular) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.info.withValues(alpha: 0.1)
                              : const Color(0xFFEFF6FF),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.info_circle,
                                size: 18, color: AppColors.info),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Como beneficiario solo puedes ver tu propia información. '
                                'El titular del grupo puede gestionar reservas para todos los miembros.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryC(isDark),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(
                  top: 12, left: 20, right: 20, bottom: 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final b = _beneficiaries[index];
                    final decodedPhoto = index < _decodedPhotos.length
                        ? _decodedPhotos[index]
                        : null;

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
                  childCount: _beneficiaries.length,
                ),
              ),
            ),
          ],
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
        ? AppColors.accentForTheme(isDark)
        : AppColors.accent;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isTitular
              ? accentColor.withValues(alpha: isDark ? 0.35 : 0.2)
              : AppColors.cardBorder(isDark),
          width: isTitular ? 1.0 : 0.5,
        ),
        boxShadow: AppColors.cardShadowFor(isDark),
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
                          color: AppColors.textPrimaryC(isDark),
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
                          color: AppColors.accentForTheme(isDark)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'TITULAR',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.accentForTheme(isDark),
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
                    color: AppColors.textSecondaryC(isDark),
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
                    if (b.effectiveGender.isNotEmpty)
                      _chip(
                        icon: b.effectiveGender == 'FEMENINO'
                            ? Icons.female
                            : Icons.male,
                        label: b.effectiveGender == 'FEMENINO' ? 'F' : 'M',
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
            color: AppColors.textTertiaryC(isDark),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Color accentColor) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor,
      ),
      child: ClipOval(
        child: decodedPhoto != null
            ? Image.memory(
                decodedPhoto!,
                fit: BoxFit.cover,
                width: 60,
                height: 60,
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
          fontSize: 22,
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
        color: isDark ? AppColors.darkElevated : AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.cardBorder(isDark).withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 11,
              color: AppColors.textSecondaryC(isDark)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryC(isDark),
            ),
          ),
        ],
      ),
    );
  }
}
