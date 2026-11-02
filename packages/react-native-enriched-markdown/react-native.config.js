/**
 * @type {import('@react-native-community/cli-types').UserDependencyConfig}
 */
module.exports = {
  dependency: {
    platforms: {
      android: {
        cmakeListsPath: 'src/main/jni/CMakeLists.txt',
        componentDescriptors: [
          'EnrichedMarkdownTextComponentDescriptor',
          'EnrichedMarkdownComponentDescriptor',
          'EnrichedMarkdownTextInputComponentDescriptor',
          'EnrichedMarkdownBlockSlotComponentDescriptor',
        ],
        // Pure C++ TurboModule (EnrichedMarkdownParser). The class is compiled into
        // the codegen library above; this CMakeLists only exposes it to autolinking.
        cxxModuleCMakeListsModuleName: 'EnrichedMarkdownParser',
        cxxModuleCMakeListsPath: 'src/main/jni/parser-module/CMakeLists.txt',
        cxxModuleHeaderName: 'EnrichedMarkdownParser',
      },
    },
  },
};
