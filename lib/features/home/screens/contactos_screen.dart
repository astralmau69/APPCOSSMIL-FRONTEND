import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Data Model ──────────────────────────────────────────────────────────────

class _ContactCategory {
  final String title;
  final List<_ContactItem> items;
  const _ContactCategory({required this.title, required this.items});
}

class _ContactItem {
  final String title;
  final String phone;
  final IconData icon;
  final String? subtitle;
  final bool isEmergency;
  final bool isFreeCall;

  const _ContactItem({
    required this.title,
    required this.phone,
    required this.icon,
    this.subtitle,
    this.isEmergency = false,
    this.isFreeCall = false,
  });
}

// ── Contact Data ────────────────────────────────────────────────────────────

const _emergencyContacts = [
  _ContactItem(
    title: 'Emergencias Hospital Militar Central',
    phone: '164',
    icon: CupertinoIcons.phone_fill,
    subtitle: 'Línea Gratuita — disponible 24/7',
    isEmergency: true,
    isFreeCall: true,
  ),
];

const _lineasGratuitas = [
  _ContactItem(
    title: 'Atención al Asegurado',
    phone: '800-11-6465',
    icon: CupertinoIcons.headphones,
    subtitle: 'Encargado: Lic. Rubén Alfredo García Peñaloza',
    isFreeCall: true,
  ),
  _ContactItem(
    title: 'Transparencia',
    phone: '800-11-6464',
    icon: CupertinoIcons.shield_lefthalf_fill,
    subtitle: 'Línea Gratuita de denuncias y reclamos',
    isFreeCall: true,
  ),
];

const _contactCategories = [
  _ContactCategory(
    title: 'Contactos Gerencias',
    items: [
      _ContactItem(
        title: 'Junta Superior de Decisiones',
        phone: '2434455',
        icon: CupertinoIcons.building_2_fill,
      ),
      _ContactItem(
        title: 'Gerencia General',
        phone: '2315060 - 2314236',
        icon: CupertinoIcons.briefcase_fill,
      ),
      _ContactItem(
        title: 'Gerencia de Finanzas',
        phone: '2373044',
        icon: CupertinoIcons.money_dollar_circle_fill,
      ),
      _ContactItem(
        title: 'Gerencia de Seguros',
        phone: '2310570',
        icon: CupertinoIcons.shield_fill,
      ),
      _ContactItem(
        title: 'Gerencia de Vivienda',
        phone: '2906229',
        icon: CupertinoIcons.house_fill,
      ),
      _ContactItem(
        title: 'Gerencia de Empresas',
        phone: '2204176',
        icon: CupertinoIcons.bag_fill,
      ),
      _ContactItem(
        title: 'Gerencia de Salud',
        phone: '2229106',
        icon: CupertinoIcons.heart_fill,
      ),
    ],
  ),
  _ContactCategory(
    title: 'Contactos H.M.C.',
    items: [
      _ContactItem(
        title: 'Hospital Militar Central',
        phone: '2223049',
        icon: CupertinoIcons.plus_rectangle_fill,
      ),
      _ContactItem(
        title: 'Citas Médicas H.M.C.',
        phone: '2242058',
        icon: CupertinoIcons.calendar,
      ),
      _ContactItem(
        title: 'WIN Corp. Citas Médicas',
        phone: '72027824',
        icon: CupertinoIcons.phone_circle_fill,
      ),
      _ContactItem(
        title: 'WIN Corp. Citas Médicas',
        phone: '72022794',
        icon: CupertinoIcons.phone_circle_fill,
      ),
    ],
  ),
];

// ── Screen ──────────────────────────────────────────────────────────────────

class ContactosScreen extends StatelessWidget {
  const ContactosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Contactos', style: TextStyle(color: AppColors.textPrimaryC(isDark))),
            backgroundColor: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.92)
                : AppColors.white.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(
                color: AppColors.cardBorder(isDark).withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(context.r.paddingH, 12, context.r.paddingH, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Subtitle
                FadeSlideIn(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: context.r.spaceLg),
                    child: Text(
                      'Líneas de atención, emergencias y contactos institucionales de COSSMIL.',
                      style: TextStyle(
                        color: AppColors.textSecondaryC(isDark),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                // ── Emergency hero card ─────────────────────────
                for (final c in _emergencyContacts) ...[
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 80),
                    child: _EmergencyCard(contact: c),
                  ),
                  SizedBox(height: context.r.spaceLg),
                ],

                // ── Líneas gratuitas ────────────────────────────
                FadeSlideIn(
                  delay: const Duration(milliseconds: 160),
                  child: _sectionHeader(context, 'LÍNEAS GRATUITAS'),
                ),
                SizedBox(height: context.r.spaceSm),
                for (int i = 0; i < _lineasGratuitas.length; i++) ...[
                  FadeSlideIn(
                    delay: Duration(milliseconds: 200 + i * 80),
                    child: _ContactCard(
                      contact: _lineasGratuitas[i],
                      onCopy: () => _copyPhone(context, _lineasGratuitas[i].phone),
                    ),
                  ),
                  SizedBox(height: context.r.spaceSm),
                ],

                SizedBox(height: context.r.spaceLg),

                // ── Institutional categories ────────────────────
                for (int ci = 0; ci < _contactCategories.length; ci++) ...[
                  FadeSlideIn(
                    delay: Duration(milliseconds: 360 + ci * 100),
                    child: _sectionHeader(context, _contactCategories[ci].title.toUpperCase()),
                  ),
                  SizedBox(height: context.r.spaceSm),
                  for (int j = 0; j < _contactCategories[ci].items.length; j++) ...[
                    FadeSlideIn(
                      delay: Duration(milliseconds: 400 + ci * 100 + j * 50),
                      child: _ContactCard(
                        contact: _contactCategories[ci].items[j],
                        onCopy: () => _copyPhone(context, _contactCategories[ci].items[j].phone),
                      ),
                    ),
                    SizedBox(height: context.r.spaceSm),
                  ],
                  SizedBox(height: context.r.spaceLg),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: isDark ? AppColors.white : AppColors.primary,
              borderRadius: BorderRadius.circular(context.r.spaceXs),
            ),
          ),
          SizedBox(width: context.r.spaceSm),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondaryC(isDark),
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _copyPhone(BuildContext context, String phone) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    Clipboard.setData(ClipboardData(text: clean));
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Número copiado'),
        content: Text(phone),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  static Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanFormat = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: cleanFormat,
    );
    if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $launchUri');
    }
  }
}

// ── Emergency Hero Card ─────────────────────────────────────────────────────

class _EmergencyCard extends StatelessWidget {
  final _ContactItem contact;
  const _EmergencyCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.r.cardPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row — icon + badge
          Row(
            children: [
              Container(
                width: context.r.avatarMd,
                height: context.r.avatarMd,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(context.r.radiusMd),
                ),
                child: const Icon(
                  CupertinoIcons.bell_fill,
                  color: AppColors.white,
                  size: 30,
                ),
              ),
              SizedBox(width: context.r.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(context.r.badgeRadius),
                      ),
                      child: const Text(
                        'EMERGENCIA',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    SizedBox(height: context.r.spaceXs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        contact.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.r.spaceLg),

          // Phone number — BIG
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                contact.phone,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.white,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
          SizedBox(height: context.r.spaceSm),
          Center(
            child: Text(
              contact.subtitle ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Call button
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: context.r.spaceMd),
              color: AppColors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(context.r.radiusMd),
              onPressed: () {
                ContactosScreen._makePhoneCall(contact.phone);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.phone_fill,
                      size: 24, color: AppColors.white),
                  SizedBox(width: 8),
                  Text(
                    'Llamar ahora',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Standard Contact Card ───────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final _ContactItem contact;
  final VoidCallback? onCopy;
  const _ContactCard({required this.contact, this.onCopy});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        contact.isFreeCall ? AppColors.accent : (isDark ? AppColors.white : AppColors.primary);

    return Container(
      padding: EdgeInsets.all(context.r.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppColors.cardShadowFor(isDark),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: context.r.listAvatarSize,
            height: context.r.listAvatarSize,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(contact.icon, size: 30, color: accentColor),
          ),
          SizedBox(width: context.r.spaceMd),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (contact.isFreeCall)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(context.r.spaceXs),
                      ),
                      child: const Text(
                        'LÍNEA GRATUITA',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.accentDark,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    contact.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryC(isDark),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                SizedBox(height: context.r.spaceXs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    contact.phone,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                if (contact.subtitle != null) ...[
                  SizedBox(height: context.r.spaceXs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      contact.subtitle!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryC(isDark),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Actions column
          Column(
            children: [
              // Call
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(36),
                onPressed: () {
                  ContactosScreen._makePhoneCall(contact.phone);
                },
                child: Container(
                  width: context.r.avatarMd,
                  height: context.r.avatarMd,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(context.r.radiusMd),
                  ),
                  child: Icon(CupertinoIcons.phone_fill,
                      size: 24, color: accentColor),
                ),
              ),
              SizedBox(height: context.r.spaceSm),
              // Copy
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(36),
                onPressed: onCopy,
                child: Container(
                  width: context.r.avatarMd,
                  height: context.r.avatarMd,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(context.r.radiusMd),
                  ),
                  child: Icon(CupertinoIcons.doc_on_clipboard,
                      size: 24, color: AppColors.textSecondaryC(isDark)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

