// lib/models/post_search_filters.dart
import 'tuition_post.dart';

/// Structured search criteria applied on top of the free-text search box.
/// `minFee`/`maxFee` only make sense for tutor listings (students filtering
/// tutors by tuition fee) — leave them null when searching student posts.
class PostSearchFilters {
  final String className;
  final String subject;
  final String area;
  final double? minFee;
  final double? maxFee;

  const PostSearchFilters({
    this.className = '',
    this.subject = '',
    this.area = '',
    this.minFee,
    this.maxFee,
  });

  bool get isEmpty =>
      className.isEmpty &&
          subject.isEmpty &&
          area.isEmpty &&
          minFee == null &&
          maxFee == null;

  /// Whether [post] satisfies every non-empty criterion. Text fields match
  /// as a case-insensitive "contains", the same way the existing search box
  /// already behaves.
  bool matches(TuitionPost post) {
    if (className.isNotEmpty &&
        !post.className.toLowerCase().contains(className.toLowerCase())) {
      return false;
    }
    if (subject.isNotEmpty &&
        !post.subject.toLowerCase().contains(subject.toLowerCase())) {
      return false;
    }
    if (area.isNotEmpty &&
        !post.area.toLowerCase().contains(area.toLowerCase())) {
      return false;
    }
    if (minFee != null && post.fee < minFee!) return false;
    if (maxFee != null && post.fee > maxFee!) return false;
    return true;
  }

  PostSearchFilters copyWith({
    String? className,
    String? subject,
    String? area,
    double? minFee,
    double? maxFee,
    bool clearMinFee = false,
    bool clearMaxFee = false,
  }) {
    return PostSearchFilters(
      className: className ?? this.className,
      subject: subject ?? this.subject,
      area: area ?? this.area,
      minFee: clearMinFee ? null : (minFee ?? this.minFee),
      maxFee: clearMaxFee ? null : (maxFee ?? this.maxFee),
    );
  }
}
