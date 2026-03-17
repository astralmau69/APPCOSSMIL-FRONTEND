import 'package:flutter/cupertino.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/mock/mock_user_data.dart';

class FamiliaScreen extends StatelessWidget {
  const FamiliaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final beneficiaries = MockUserData.user.beneficiaries;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgGrey,
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'Familia',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: CupertinoColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: beneficiaries.length,
          itemBuilder: (context, index) {
            final b = beneficiaries[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.olive.withOpacity(0.1),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      b.fullName[0],
                      style: const TextStyle(
                        color: AppColors.olive,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          b.relationship,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.subtleGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
