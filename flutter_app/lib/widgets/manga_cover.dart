import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/manga.dart';
import '../theme/app_theme.dart';

class MangaCover extends StatelessWidget {
  final Manga manga;
  final int? unreadCount;
  final VoidCallback? onTap;

  const MangaCover({
    super.key,
    required this.manga,
    this.unreadCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: manga.coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: manga.coverUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => _buildPlaceholder(context),
                          errorWidget: (context, url, error) => _buildPlaceholder(context, showIcon: true),
                        )
                      : _buildPlaceholder(context, showIcon: true),
                ),
                if (unreadCount != null && unreadCount! > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unreadCount! > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            manga.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.glassTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, {bool showIcon = false}) {
    if (showIcon) {
      return Container(
        color: context.isDark ? const Color(0xFF262626) : const Color(0xFFE5E5E5),
        child: Center(
          child: Icon(
            Icons.book_rounded,
            size: 32,
            color: context.secondaryTextColor,
          ),
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: context.isDark ? const Color(0xFF262626) : const Color(0xFFE5E5E5),
      highlightColor: context.isDark ? const Color(0xFF363636) : const Color(0xFFF5F5F5),
      child: Container(color: Colors.white),
    );
  }
}

class MangaCoverRow extends StatelessWidget {
  final Manga manga;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const MangaCoverRow({
    super.key,
    required this.manga,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 96,
                child: manga.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: manga.coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: context.isDark ? const Color(0xFF262626) : const Color(0xFFE5E5E5),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: context.isDark ? const Color(0xFF262626) : const Color(0xFFE5E5E5),
                          child: Icon(Icons.book_rounded, color: context.secondaryTextColor),
                        ),
                      )
                    : Container(
                        color: context.isDark ? const Color(0xFF262626) : const Color(0xFFE5E5E5),
                        child: Icon(Icons.book_rounded, color: context.secondaryTextColor),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manga.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.glassTextColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.secondaryTextColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
