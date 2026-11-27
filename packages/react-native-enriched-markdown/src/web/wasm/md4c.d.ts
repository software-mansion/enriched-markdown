// Type declarations for the Emscripten-generated md4c WASM module.
// The actual md4c.js file is produced by cpp/wasm/build.sh and committed to git.

export interface Md4cModule {
  _malloc(size: number): number;
  _free(pointer: number): void;
  // Input markdown import and export (cpp/wasm/md4c_wasm.cpp): each returns a
  // pointer to an int32 header describing its result in the heap.
  _parseInput(markdown: number, length: number): number;
  _serializeInput(
    text: number,
    textLength: number,
    formatting: number,
    formattingCount: number,
    urls: number,
    urlsLength: number,
    blocks: number,
    blockCount: number
  ): number;
  // Re-created when the heap grows: read them after every call into the module.
  HEAPU16: Uint16Array;
  HEAP32: Int32Array;
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

declare function createMd4cModule(options?: object): Promise<Md4cModule>;

export default createMd4cModule;
