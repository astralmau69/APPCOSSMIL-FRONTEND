import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Data Model ──────────────────────────────────────────────────────────────

class _ContactGroup {
  final String key;
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<_ContactItem> items;
  const _ContactGroup({
    required this.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.items,
  });
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

const _emergencyContact = _ContactItem(
  title: 'Emergencias Hospital Militar Central',
  phone: '164',
  icon: CupertinoIcons.phone_fill,
  subtitle: 'Línea Gratuita — disponible 24/7',
  isEmergency: true,
  isFreeCall: true,
);

const _contactGroups = [
  _ContactGroup(
    key: 'lineas',
    title: 'Líneas Gratuitas',
    icon: CupertinoIcons.phone_circle_fill,
    accentColor: Color(0xFF059669),
    items: [
      _ContactItem(
        title: 'Atención al Asegurado',
        phone: '800-11-6465',
        icon: CupertinoIcons.headphones,
        subtitle: 'Lic. Rubén Alfredo García Peñaloza',
        isFreeCall: true,
      ),
      _ContactItem(
        title: 'Transparencia',
        phone: '800-11-6464',
        icon: CupertinoIcons.shield_lefthalf_fill,
        subtitle: 'Denuncias y reclamos',
        isFreeCall: true,
      ),
    ],
  ),
  _ContactGroup(
    key: 'gerencias',
    title: 'Gerencias',
    icon: CupertinoIcons.building_2_fill,
    accentColor: Color(0xFF2563EB),
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
  _ContactGroup(
    key: 'hospital',
    title: 'Hospital Militar Central',
    icon: CupertinoIcons.plus_rectangle_fill,
    accentColor: Color(0xFF7C3AED),
    items: [
      _ContactItem(
        title: 'Hospital Militar Central',
        phone: '2223049',
        icon: CupertinoIcons.plus_rectangle_fill,
      ),
      _ContactItem(
        title: 'Citas Médicas HMC',
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

class ContactosScreen extends StatefulWidget {
  const ContactosScreen({super.key});

  @override
  State<ContactosScreen> createState() => _ContactosScreenState();
}

class _ContactosScreenState extends State<ContactosScreen> {
  final Set<String> _expanded = {};

  void _toggle(String key) {
    setState(() {
      if (_expanded.contains(key)) {
        _expanded.remove(key);
      } else {
        _expanded.add(key);
      }
    });
  }

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
            largeTitle: Text(
              'Contactos COSSMIL',
              style: TextStyle(color: AppColors.textPrimaryC(isDark)),
            ),
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
            padding: EdgeInsets.fromLTRB(
                context.r.paddingH, 12, context.r.paddingH, context.r.navBarBottomSpace),
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

                // ── Emergency hero card — always visible ───────────
                FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: _EmergencyCard(contact: _emergencyContact),
                ),
                SizedBox(height: context.r.spaceLg),

                // ── Collapsible groups ─────────────────────────────
                for (int i = 0; i < _contactGroups.length; i++) ...[
                  FadeSlideIn(
                    delay: Duration(milliseconds: 160 + i * 60),
                    child: _CollapsibleGroup(
                      group: _contactGroups[i],
                      isExpanded: _expanded.contains(_contactGroups[i].key),
                      onToggle: () => _toggle(_contactGroups[i].key),
                    ),
                  ),
                  SizedBox(height: context.r.spaceSm),
                ],
              ]),
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
    final cleanFormat = phoneNumber.split(' ').first.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanFormat);
    if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $launchUri');
    }
  }
}

// ── Collapsible Group ───────────────────────────────────────────────────────

class _CollapsibleGroup extends StatelessWidget {
  final _ContactGroup group;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _CollapsibleGroup({
    required this.group,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppColors.cardShadowFor(isDark),
        border: Border.all(
          color: isExpanded
              ? group.accentColor.withValues(alpha: 0.30)
              : AppColors.cardBorder(isDark),
          width: isExpanded ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        children: [
          // ── Header row — always visible ──────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: r.cardPadding, vertical: r.spaceMd),
              child: Row(
                children: [
                  // Icon container
                  Container(
                    width: r.listAvatarSize,
                    height: r.listAvatarSize,
                    decoration: BoxDecoration(
                      color: group.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(r.radiusMd),
                    ),
                    child: Icon(group.icon, size: r.iconMd, color: group.accentColor),
                  ),
                  SizedBox(width: r.spaceMd),

                  // Title + count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.title,
                          style: context.texts.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryC(isDark),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          isExpanded
                              ? 'Toca para cerrar'
                              : '${group.items.length} contacto${group.items.length != 1 ? 's' : ''}',
                          style: context.texts.bodySmall.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiaryC(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Count badge (collapsed only)
                  if (!isExpanded)
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.chipPaddingH, vertical: r.chipPaddingV),
                      decoration: BoxDecoration(
                        color: group.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(r.chipRadius),
                      ),
                      child: Text(
                        '${group.items.length}',
                        style: context.texts.bodyMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: group.accentColor,
                        ),
                      ),
                    ),
                  SizedBox(width: r.spaceSm),

                  // Chevron
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Icon(
                      CupertinoIcons.chevron_down,
                      size: 16,
                      color: isExpanded
                          ? group.accentColor
                          : AppColors.textTertiaryC(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable content ───────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _GroupContent(group: group),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 280),
            sizeCurve: Curves.easeInOut,
            firstCurve: Curves.easeIn,
            secondCurve: Curves.easeOut,
          ),
        ],
      ),
    );
  }
}

// ── Group Content (items list) ───────────────────────────────────────────────

class _GroupContent extends StatelessWidget {
  final _ContactGroup group;
  const _GroupContent({required this.group});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return Column(
      children: [
        // Divider
        Container(
          height: 0.5,
          color: group.accentColor.withValues(alpha: 0.20),
        ),
        // Items
        for (int i = 0; i < group.items.length; i++) ...[
          _ContactRow(
            item: group.items[i],
            accentColor: group.accentColor,
            isDark: isDark,
            showDivider: i < group.items.length - 1,
          ),
        ],
        SizedBox(height: r.spaceXs),
      ],
    );
  }
}

// ── Contact Row (inside expanded group) ─────────────────────────────────────

class _ContactRow extends StatelessWidget {
  final _ContactItem item;
  final Color accentColor;
  final bool isDark;
  final bool showDivider;

  const _ContactRow({
    required this.item,
    required this.accentColor,
    required this.isDark,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: r.cardPadding, vertical: r.spaceMd),
          child: Row(
            children: [
              // Icon
              Container(
                width: r.contactRowIconSize,
                height: r.contactRowIconSize,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(r.radiusMd),
                ),
                child: Icon(item.icon, size: r.iconSm, color: accentColor),
              ),
              SizedBox(width: r.spaceMd),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.isFreeCall)
                      Container(
                        margin: const EdgeInsets.only(bottom: 3),
                        padding: EdgeInsets.symmetric(
                            horizontal: r.spaceSm, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(r.radiusSm),
                        ),
                        child: Text(
                          'LÍNEA GRATUITA',
                          style: context.texts.labelSmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF059669),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    Text(
                      item.title,
                      style: context.texts.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryC(isDark),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      item.phone,
                      style: context.texts.bodyLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        style: context.texts.bodySmall.copyWith(
                          color: AppColors.textTertiaryC(isDark),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action buttons
              Column(
                children: [
                  _ActionButton(
                    icon: CupertinoIcons.phone_fill,
                    color: accentColor,
                    onTap: () => _ContactosScreenState._makePhoneCall(item.phone),
                  ),
                  SizedBox(height: r.spaceXs),
                  _ActionButton(
                    icon: CupertinoIcons.doc_on_clipboard,
                    color: AppColors.textSecondaryC(isDark),
                    onTap: () => _ContactosScreenState._copyPhone(context, item.phone),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.cardPadding),
            child: Container(
              height: 0.5,
              color: AppColors.cardBorder(isDark),
            ),
          ),
      ],
    );
  }
}

// ── Small action button ──────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: r.avatarSm + 4,
        height: r.avatarSm + 4,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(r.radiusMd),
        ),
        child: Icon(icon, size: r.iconSm, color: color),
      ),
    );
  }
}

// ── Emergency Hero Card ─────────────────────────────────────────────────────

class _EmergencyCard extends StatelessWidget {
  final _ContactItem contact;
  const _EmergencyCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.all(r.cardPadding),
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
          Row(
            children: [
              Container(
                width: r.avatarMd,
                height: r.avatarMd,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(r.radiusMd),
                ),
                child: Icon(CupertinoIcons.bell_fill,
                    color: AppColors.white, size: r.iconLg * 0.75),
              ),
              SizedBox(width: r.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(r.badgeRadius),
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
                    SizedBox(height: r.spaceXs),
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
          SizedBox(height: r.spaceLg),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                contact.phone,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.white,
                  fontSize: r.displayXl,
                  letterSpacing: 8,
                ),
              ),
            ),
          ),
          SizedBox(height: r.spaceSm),
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
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: r.spaceMd),
              color: AppColors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(r.radiusMd),
              onPressed: () => _ContactosScreenState._makePhoneCall(contact.phone),
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
