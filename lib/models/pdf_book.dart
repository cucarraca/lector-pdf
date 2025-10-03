import 'package:json_annotation/json_annotation.dart';

part 'pdf_book.g.dart';

@JsonSerializable()
class PdfBook {
  final String id;
  final String title;
  final String filePath;
  final int totalPages;
  final int currentPage;
  final double progress;
  final DateTime lastOpened;
  final List<Bookmark> bookmarks;
  final String? coverImagePath;

  PdfBook({
    required this.id,
    required this.title,
    required this.filePath,
    required this.totalPages,
    this.currentPage = 0,
    this.progress = 0.0,
    required this.lastOpened,
    this.bookmarks = const [],
    this.coverImagePath,
  });

  factory PdfBook.fromJson(Map<String, dynamic> json) =>
      _$PdfBookFromJson(json);

  Map<String, dynamic> toJson() => _$PdfBookToJson(this);

  PdfBook copyWith({
    String? id,
    String? title,
    String? filePath,
    int? totalPages,
    int? currentPage,
    double? progress,
    DateTime? lastOpened,
    List<Bookmark>? bookmarks,
    String? coverImagePath,
  }) {
    return PdfBook(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      progress: progress ?? this.progress,
      lastOpened: lastOpened ?? this.lastOpened,
      bookmarks: bookmarks ?? this.bookmarks,
      coverImagePath: coverImagePath ?? this.coverImagePath,
    );
  }
}

@JsonSerializable()
class Bookmark {
  final String id;
  final int pageNumber;
  final String title;
  final DateTime createdAt;

  Bookmark({
    required this.id,
    required this.pageNumber,
    required this.title,
    required this.createdAt,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) =>
      _$BookmarkFromJson(json);

  Map<String, dynamic> toJson() => _$BookmarkToJson(this);
}
