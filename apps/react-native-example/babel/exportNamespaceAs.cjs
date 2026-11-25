// `export * as 'name' from '...'` with a string name (TypeGPU's '~unstable')
// comes out of the CommonJS transform as `exports.~unstable = ...`, which
// Hermes rejects. Through a local binding it comes out as `exports["~unstable"]`.
module.exports = ({ types: t }) => ({
  visitor: {
    ExportNamedDeclaration(path) {
      const { node } = path;
      const specifier = node.specifiers.find(
        (s) => t.isExportNamespaceSpecifier(s) && t.isStringLiteral(s.exported)
      );
      if (!specifier || !node.source) return;
      const imported = path.scope.generateUidIdentifier('ns');
      const local = path.scope.generateUidIdentifier('namespace');
      path.replaceWithMultiple([
        t.importDeclaration([t.importNamespaceSpecifier(imported)], node.source),
        t.variableDeclaration('const', [t.variableDeclarator(local, imported)]),
        t.exportNamedDeclaration(null, [t.exportSpecifier(local, specifier.exported)]),
      ]);
    },
  },
});
