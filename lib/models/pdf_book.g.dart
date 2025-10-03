// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pdf_book.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PdfBook _$PdfBookFromJson(Map<String, dynamic> json) => PdfBook(
      id: json['id'] as String,
      title: json['title'] as String,
      filePath: json['filePath'] as String,
      totalPages: (json['totalPages'] as num).toInt(),
      currentPage: (json['currentPage'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      lastOpened: DateTime.parse(json['lastOpened'] as String),
      bookmarks: (json['bookmarks'] as List<dynamic>?)
              ?.map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      coverImagePath: json['coverImagePath'] as String?,
    );

Map<String, dynamic> _$PdfBookToJson(PdfBook instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'filePath': instance.filePath,
      'totalPages': instance.totalPages,
      'currentPage': instance.currentPage,
      'progress': instance.progress,
      'lastOpened': instance.lastOpened.toIso8601String(),
      'bookmarks': instance.bookmarks.map((e) => e.toJson()).toList(),
      'coverImagePath': instance.coverImagePath,
    };

Bookmark _$BookmarkFromJson(Map<String, dynamic> json) => Bookmark(
      id: json['id'] as String,
      pageNumber: (json['pageNumber'] as num).toInt(),
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$BookmarkToJson(Bookmark instance) => <String, dynamic>{
      'id': instance.id,
      'pageNumber': instance.pageNumber,
      'title': instance.title,
      'createdAt': instance.createdAt.toIso8601String(),
    };
