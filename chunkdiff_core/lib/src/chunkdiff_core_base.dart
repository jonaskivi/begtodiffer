enum SymbolKind { function, method, classType, enumType, other }

class SymbolChange {
  final String name;
  final SymbolKind kind;
  final String? beforePath;
  final String? afterPath;

  const SymbolChange({
    required this.name,
    required this.kind,
    this.beforePath,
    this.afterPath,
  });
}

List<SymbolChange> dummySymbolChanges() {
  return const <SymbolChange>[
    SymbolChange(
      name: 'ChunkDiffExample.greet',
      kind: SymbolKind.method,
      beforePath: 'lib/src/example.dart',
      afterPath: 'lib/src/example.dart',
    ),
    SymbolChange(
      name: 'ChunkDiffExample',
      kind: SymbolKind.classType,
      beforePath: 'lib/src/example.dart',
      afterPath: 'lib/src/example.dart',
    ),
    SymbolChange(
      name: 'main',
      kind: SymbolKind.function,
      beforePath: 'lib/main.dart',
      afterPath: 'lib/main.dart',
    ),
  ];
}
