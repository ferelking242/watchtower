import 'dart:async';
import 'dart:math';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/collections/riverpod_compat.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/common.dart';
import 'package:watchtower/modules/music/services/logger/logger.dart';

abstract class FamilyPaginatedAsyncNotifier<K, A>
    extends FamilyAsyncNotifier<SpotubePaginationResponseObject<K>, A>
    with MetadataPluginMixin<K> {
  Future<SpotubePaginationResponseObject<K>> fetch(int offset, int limit);

  Future<void> fetchMore() async {
    if (state.value == null || !state.value!.hasMore) return;

    final oldState = state.value!;

    try {
      final newState = await fetch(
        oldState.nextOffset!,
        oldState.limit,
      );

      final oldItems =
          oldState.items.isEmpty ? <K>[] : oldState.items.cast<K>();
      final items = newState.items.isEmpty ? <K>[] : newState.items.cast<K>();

      state = AsyncData(newState.copyWith(items: <K>[...oldItems, ...items]));
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      state = AsyncData(oldState);
    }
  }

  Future<List<K>> fetchAll() async {
    if (state.value == null) return [];
    if (!state.value!.hasMore) return state.value!.items.cast<K>();

    bool hasMore = true;
    while (hasMore) {
      final newState = await fetch(
        state.value!.nextOffset!,
        max(state.value!.limit, 100),
      )
          .catchError(
            (e) => fetch(state.value!.nextOffset!, max(state.value!.limit, 50)),
          )
          .catchError(
            (e) => fetch(state.value!.nextOffset!, state.value!.limit),
          )
          .catchError(
        (e) async {
          await Future.delayed(const Duration(milliseconds: 500));
          return fetch(state.value!.nextOffset!, state.value!.limit);
        },
      );

      hasMore = newState.hasMore;

      final oldItems =
          state.value!.items.isEmpty ? <K>[] : state.value!.items.cast<K>();
      final items = newState.items.isEmpty ? <K>[] : newState.items.cast<K>();

      state = AsyncData(
        newState.copyWith(items: [...oldItems, ...items]),
      );
    }

    return state.value!.items.cast<K>();
  }
}

abstract class AutoDisposeFamilyPaginatedAsyncNotifier<K, A>
    extends AutoDisposeFamilyAsyncNotifier<SpotubePaginationResponseObject<K>,
        A> with MetadataPluginMixin<K> {
  Future<SpotubePaginationResponseObject<K>> fetch(int offset, int limit);

  Future<void> fetchMore() async {
    if (state.value == null || !state.value!.hasMore) return;
    final oldState = state.value!;

    try {
      final newState = await fetch(
        oldState.nextOffset!,
        oldState.limit,
      );

      state = AsyncData(
        newState.copyWith(items: [
          ...oldState.items.cast<K>(),
          ...newState.items.cast<K>(),
        ]),
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      state = AsyncData(oldState);
    }
  }

  Future<List<K>> fetchAll() async {
    if (state.value == null) return [];
    if (!state.value!.hasMore) return state.value!.items.cast<K>();

    bool hasMore = true;
    while (hasMore) {
      final newState = await fetch(
        state.value!.nextOffset!,
        max(state.value!.limit, 100),
      )
          .catchError(
            (e) => fetch(state.value!.nextOffset!, max(state.value!.limit, 50)),
          )
          .catchError(
            (e) => fetch(state.value!.nextOffset!, state.value!.limit),
          )
          .catchError(
        (e) async {
          await Future.delayed(const Duration(milliseconds: 500));
          return fetch(state.value!.nextOffset!, state.value!.limit);
        },
      );

      hasMore = newState.hasMore;

      final oldItems =
          state.value!.items.isEmpty ? <K>[] : state.value!.items.cast<K>();
      final items = newState.items.isEmpty ? <K>[] : newState.items.cast<K>();

      state = AsyncData(
        newState.copyWith(items: [...oldItems, ...items]),
      );
    }

    return state.value!.items.cast<K>();
  }
}
