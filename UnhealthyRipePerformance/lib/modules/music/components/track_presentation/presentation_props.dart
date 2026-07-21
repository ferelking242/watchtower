import 'dart:async';

import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';

class PaginationProps {
  final bool hasNextPage;
  final bool isLoading;
  final VoidCallback onFetchMore;
  final Future<void> Function() onRefresh;
  final Future<List<SpotubeFullTrackObject>> Function() onFetchAll;

  const PaginationProps({
    required this.hasNextPage,
    required this.isLoading,
    required this.onFetchMore,
    required this.onFetchAll,
    required this.onRefresh,
  });

  @override
  operator ==(Object other) {
    return other is PaginationProps &&
        other.hasNextPage == hasNextPage &&
        other.isLoading == isLoading &&
        other.onFetchMore == onFetchMore &&
        other.onFetchAll == onFetchAll &&
        other.onRefresh == onRefresh;
  }

  @override
  int get hashCode =>
      super.hashCode ^
      hasNextPage.hashCode ^
      isLoading.hashCode ^
      onFetchMore.hashCode ^
      onFetchAll.hashCode ^
      onRefresh.hashCode;
}

class TrackPresentationOptionsScope extends InheritedWidget {
  final TrackPresentationOptions data;

  const TrackPresentationOptionsScope({
    super.key,
    required this.data,
    required super.child,
  });

  static TrackPresentationOptions of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<TrackPresentationOptionsScope>();
    assert(scope != null,
        'No TrackPresentationOptionsScope found in widget tree');
    return scope!.data;
  }

  @override
  bool updateShouldNotify(TrackPresentationOptionsScope oldWidget) {
    return data != oldWidget.data;
  }
}

class TrackPresentationOptions {
  final Object collection;
  final String title;
  final String? description;
  final String? owner;
  final String? ownerImage;
  final String image;
  final String routePath;
  final List<SpotubeFullTrackObject> tracks;
  final PaginationProps pagination;
  final bool isLiked;
  final String? shareUrl;
  final Object? error;

  // events
  final FutureOr<bool?> Function()? onHeart; // if null heart button will hidden

  const TrackPresentationOptions({
    required this.collection,
    required this.title,
    this.description,
    this.owner,
    this.ownerImage,
    required this.image,
    required this.tracks,
    required this.pagination,
    required this.routePath,
    this.shareUrl,
    this.isLiked = false,
    this.onHeart,
    this.error,
  }) : assert(collection is SpotubeSimpleAlbumObject ||
            collection is SpotubeSimplePlaylistObject);

  String get collectionId => collection is SpotubeSimpleAlbumObject
      ? (collection as SpotubeSimpleAlbumObject).id
      : (collection as SpotubeSimplePlaylistObject).id;

  static TrackPresentationOptions of(BuildContext context) {
    return TrackPresentationOptionsScope.of(context);
  }

  @override
  operator ==(Object other) {
    return other is TrackPresentationOptions &&
        other.collection == collection &&
        other.title == title &&
        other.description == description &&
        other.image == image &&
        other.routePath == routePath &&
        other.tracks == tracks &&
        other.pagination == pagination &&
        other.isLiked == isLiked &&
        other.shareUrl == shareUrl &&
        other.onHeart == onHeart &&
        other.error == error;
  }

  @override
  int get hashCode =>
      super.hashCode ^
      collection.hashCode ^
      title.hashCode ^
      description.hashCode ^
      image.hashCode ^
      routePath.hashCode ^
      tracks.hashCode ^
      pagination.hashCode ^
      isLiked.hashCode ^
      shareUrl.hashCode ^
      onHeart.hashCode ^
      error.hashCode;
}
