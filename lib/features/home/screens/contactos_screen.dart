import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/animations/fade_slide_in.dart';

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
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Contactos'),
            backgroundColor: AppColors.white.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Subtitle
                const FadeSlideIn(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Líneas de atención, emergencias y contactos institucionales de COSSMIL.',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.4,
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
                  const SizedBox(height: 20),
                ],

                // ── Líneas gratuitas ────────────────────────────
                FadeSlideIn(
                  delay: const Duration(milliseconds: 160),
                  child: _sectionHeader('LÍNEAS GRATUITAS'),
                ),
                const SizedBox(height: 10),
                for (int i = 0; i < _lineasGratuitas.length; i++) ...[
                  FadeSlideIn(
                    delay: Duration(milliseconds: 200 + i * 80),
                    child: _ContactCard(
                      contact: _lineasGratuitas[i],
                      onCopy: () => _copyPhone(context, _lineasGratuitas[i].phone),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 20),

                // ── Institutional categories ────────────────────
                for (int ci = 0; ci < _contactCategories.length; ci++) ...[
                  FadeSlideIn(
                    delay: Duration(milliseconds: 360 + ci * 100),
                    child: _sectionHeader(_contactCategories[ci].title.toUpperCase()),
                  ),
                  const SizedBox(height: 10),
                  FadeSlideIn(
                    delay: Duration(milliseconds: 400 + ci * 100),
                    child: _GroupedContactList(
                      items: _contactCategories[ci].items,
                      onCopy: (phone) => _copyPhone(context, phone),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
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
}

// ── Emergency Hero Card ─────────────────────────────────────────────────────

class _EmergencyCard extends StatelessWidget {
  final _ContactItem contact;
  const _EmergencyCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
        ),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.bell_fill,
                  color: AppColors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'EMERGENCIA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Phone number — BIG
          Center(
            child: Text(
              contact.phone,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: AppColors.white,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              contact.subtitle ?? '',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Call button
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: AppColors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(12),
              onPressed: () {
                // TODO: Integrar url_launcher para llamar
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.phone_fill,
                      size: 18, color: AppColors.white),
                  SizedBox(width: 8),
                  Text(
                    'Llamar ahora',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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
    final accentColor =
        contact.isFreeCall ? AppColors.accent : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppColors.softShadow,
        border: Border.all(
          color: accentColor.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(contact.icon, size: 22, color: accentColor),
          ),
          const SizedBox(width: 14),

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
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LÍNEA GRATUITA',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                Text(
                  contact.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.phone,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
                if (contact.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    contact.subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
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
                  // TODO: Integrar url_launcher
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.phone_fill,
                      size: 16, color: accentColor),
                ),
              ),
              const SizedBox(height: 6),
              // Copy
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(36),
                onPressed: onCopy,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(CupertinoIcons.doc_on_clipboard,
                      size: 16, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Grouped Contact List (iOS Settings-style) ───────────────────────────────

class _GroupedContactList extends StatelessWidget {
  final List<_ContactItem> items;
  final void Function(String phone) onCopy;
  const _GroupedContactList({required this.items, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _GroupedRow(
              item: items[i],
              onCopy: () => onCopy(items[i].phone),
              isFirst: i == 0,
              isLast: i == items.length - 1,
            ),
            if (i < items.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 60),
                child: Container(
                  height: 0.5,
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _GroupedRow extends StatelessWidget {
  final _ContactItem item;
  final VoidCallback onCopy;
  final bool isFirst;
  final bool isLast;

  const _GroupedRow({
    required this.item,
    required this.onCopy,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onCopy,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.phone,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
