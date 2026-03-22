import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/mock/mock_user_data.dart';

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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 120),
              child: CupertinoListSection.insetGrouped(
                backgroundColor: Colors.transparent,
                margin: const EdgeInsets.all(20),
                children: List.generate(beneficiaries.length, (index) {
                  final b = beneficiaries[index];
                  final isTitular = b.relationship == 'Titular';

                  return FadeSlideIn(
                    delay: Duration(milliseconds: 100 + (index * 80)),
                    offsetY: 15,
                    child: CupertinoListTile(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leadingSize: 56,
                      leading: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              isTitular ? AppColors.primary : AppColors.accent,
                              (isTitular ? AppColors.primary : AppColors.accent).withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                        child: ClipOval(
                          child: (isTitular && MockUserData.user.photoBase64.isNotEmpty)
                              ? Image.memory(
                                  base64Decode(MockUserData.user.photoBase64),
                                  fit: BoxFit.cover,
                                  width: 56,
                                  height: 56,
                                )
                              : Center(
                                  child: Text(
                                    b.fullName[0],
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      title: Text(
                        b.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        isTitular ? 'Titular' : 'Beneficiario: ${b.relationship}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isTitular ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        color: AppColors.textTertiary,
                        size: 20,
                      ),
                      onTap: () {
                        // TODO: Ver detalle familiar
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
