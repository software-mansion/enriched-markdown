// Type declarations for the Emscripten-generated md4c WASM module.
// The actual md4c.js file is produced by cpp/wasm/build.sh and committed to git.

interface Md4cModule {
  cwrap(
    name: string,
    returnType: string,
    argTypes: string[]
  ): (...args: unknown[]) => unknown;
  ccall(
    name: string,
    returnType: string,
    argTypes: string[],
    args: unknown[]
  ): unknown;
  UTF8ToString(ptr: number): string;
}

// The object passed to the factory, which Emscripten fills in as the module.
// Built with WASM_ASYNC_COMPILATION=0, it is filled in and
// `onRuntimeInitialized` has run by the time the factory returns.
export type Md4cModuleArg = Partial<Md4cModule> & {
  onRuntimeInitialized?: () => void;
};

declare function createMd4cModule(options?: Md4cModuleArg): Promise<Md4cModule>;

export default createMd4cModule;
