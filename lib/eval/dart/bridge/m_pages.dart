import 'package:d4rt/d4rt.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';

class MPagesBridge {
  final mPageBridgedClass = BridgedClass(
    nativeType: MPages,
    name: 'MPages',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        return MPages(
          list: (positionalArgs[0] as List).map((e) => e as MManga).toList(),
          hasNextPage: positionalArgs[1] as bool,
          total: namedArgs.get<int?>('total'),
        );
      },
    },
    getters: {
      'list': (visitor, target) => (target as MPages).list,
      'hasNextPage': (visitor, target) => (target as MPages).hasNextPage,
      'total': (visitor, target) => (target as MPages).total,
    },
    setters: {
      'list': (visitor, target, value) =>
          (target as MPages).list = (value as List).cast<MManga>(),
      'hasNextPage': (visitor, target, value) =>
          (target as MPages).hasNextPage = value as bool,
      'total': (visitor, target, value) =>
          (target as MPages).total = value as int?,
    },
  );
  void registerBridgedClasses(D4rt interpreter) {
    interpreter.registerBridgedClass(
      mPageBridgedClass,
      'package:watchtower/bridge_lib.dart',
    );
  }
}
