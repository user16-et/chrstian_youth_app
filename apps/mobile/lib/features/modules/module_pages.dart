import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../data/date_format.dart';
import '../../data/image_upload.dart';
import '../../data/location_service.dart';
import '../../i18n/app_i18n.dart';
import '../../theme/app_theme.dart';

import 'church_detail_page.dart';
import 'courtship_swipe.dart';
import 'bible_reader.dart';
import 'group_detail_screen.dart';
import 'likes_you.dart';
import 'matches_inbox.dart';
import 'live_chat_panel.dart';
import 'prayer_growth_pages.dart';
import 'relationship_social.dart';
import 'stories_feed.dart';
import 'user_profile_sheet.dart';
import '../home/sign_in_scope.dart';

part 'module_pages/church_directory.dart';
part 'module_pages/community_pages.dart';
part 'module_pages/bible_pages.dart';
part 'module_pages/events_pages.dart';
part 'module_pages/profile_pages.dart';
part 'module_pages/social_pages.dart';
part 'module_pages/ministries_pages.dart';
part 'module_pages/mentorship_stories.dart';
part 'module_pages/courtship_pages.dart';
part 'module_pages/marketplace_payments.dart';

String _shortDate(String value) => friendlyDate(value);

// A plain field label placed above an input — used instead of a floating
// InputDecoration label on dropdowns that always have a selected value (a
// floating label would otherwise overlap that value).
Widget _fieldLabel(String text) => Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child:
            Text(text, style: Theme.of(context).textTheme.labelLarge),
      ),
    );

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: colors.outline.withValues(alpha: .20)),
        boxShadow: [
          BoxShadow(
              color: colors.shadow.withValues(alpha: .10),
              blurRadius: 22,
              offset: const Offset(0, 8))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 8,
                  height: 28,
                  decoration: BoxDecoration(
                      color: colors.secondary,
                      borderRadius: BorderRadius.circular(99))),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge)),
            ]),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ListModuleScreen extends StatelessWidget {
  const _ListModuleScreen({
    required this.title,
    required this.subtitle,
    required this.items,
    this.header,
  });

  final String title;
  final String subtitle;
  final Widget? header;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionHeader(title: title, subtitle: subtitle),
        if (header != null) ...[
          const SizedBox(height: 16),
          header!,
        ],
        const SizedBox(height: 16),
        ...items,
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _ListTileRow extends StatelessWidget {
  const _ListTileRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.onTap,
      this.trailing});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outline.withValues(alpha: .18)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                gradient:
                    LinearGradient(colors: [colors.primary, colors.secondary]),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.white, size: 21)),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: trailing ??
            (onTap == null
                ? null
                : Icon(Icons.arrow_outward_rounded,
                    size: 19, color: colors.secondary)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        onTap: onTap,
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard(
      {required this.icon,
      required this.title,
      required this.body,
      this.trailing});

  final IconData icon;
  final String title;
  final String body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: trailing,
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField(
      {required this.controller,
      required this.labelText,
      required this.hintText,
      required this.onChanged,
      this.onClear});

  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
