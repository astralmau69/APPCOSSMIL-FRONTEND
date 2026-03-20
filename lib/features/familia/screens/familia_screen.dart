import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/animations/fade_slide_in.dart';

class FamiliaScreen extends StatelessWidget {
  const FamiliaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final beneficiaries = MockUserData.user.beneficiaries;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Mi Grupo Familiar'),
            backgroundColor: AppColors.white.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final b = beneficiaries[index];
                  final isTitular = b.relationship == 'Titular';

                  return FadeSlideIn(
                    delay: Duration(milliseconds: 100 + (index * 80)),
                    offsetY: 15,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusXl),
                        boxShadow: AppColors.softShadow,
                        border: Border.all(
                          color: isTitular
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : Colors.transparent,
                          width: isTitular ? 1.5 : 0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  isTitular
                                      ? AppColors.primary
                                      : AppColors.accent,
                                  (isTitular
                                          ? AppColors.primary
                                          : AppColors.accent)
                                      .withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                            child: ClipOval(
                          child: (isTitular && MockUserData.user.photoBase64.isNotEmpty)
                              ? Image.memory(
                                  base64Decode(MockUserData.user.photoBase64),
                                  fit: BoxFit.cover,
                                  width: 64,
                                  height: 64,
                                )
                              : Center(
                                  child: Text(
                                    b.fullName[0],
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24,
                                    ),
                                  ),
                                ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.fullName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isTitular
                                        ? AppColors.primary
                                            .withValues(alpha: 0.1)
                                        : AppColors.accent
                                            .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isTitular
                                        ? 'Titular'
                                        : 'Beneficiario: ${b.relationship}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isTitular
                                          ? AppColors.primary
                                          : AppColors.accentDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              CupertinoIcons.chart_bar,
                              size: 24,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
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
