import { parse, type Node } from 'acorn';
import { transpileAcornFn } from 'tinyest-for-wgsl';
import tgpu, { d, std } from 'typegpu';
import { KNOBS, layout, resolveShader, trap, type Shape } from './raymarch';
import { sd } from './sd';
// Before anything resolves, so the CPU keeps every function's AST.
import './cpu';

// What a code block can reach: the names a TypeGPU module imports, `sd`, a
// few primitives, and `Sdf`, the shell every solid shares: a point and the
// time in, a distance out.
const SCOPE: Record<string, unknown> = {
  tgpu,
  d,
  std,
  sd,
  trap,
  Sdf: tgpu.fn([d.vec3f, d.f32], d.f32),
};

// Every solid compiled so far, by name, so a later block can call an earlier
// one, numbers as written. Kept as code until one does.
const solids = new Map<string, Shape | string>();

// A replay compiles the same code again.
const compiled = new Map<string, Extract<Compiled, { ok: true }>>();

const KNOBS_NAME = '__knobs';

/**
 * Two numbers past the block's own that ease its newest part in, one for
 * every other preview, so the shader still on screen keeps its part whole.
 */
export const GROW_SLOTS = [KNOBS - 2, KNOBS - 1] as const;

/** A number in the code that reads its own uniform slot. */
export type Knob = { start: number; end: number; value: number };

export type Compiled =
  | {
      ok: true;
      name: string;
      wgsl: string;
      ms: number;
      knobs: Knob[];
      // The slot the newest part grows in through, if it does.
      grow?: number;
      // The solid as compiled, numbers as knobs, to run on the CPU too.
      shape: Shape;
    }
  | { ok: false; error: string };

type AnyNode = Node & Record<string, any>;

/**
 * Compiles a ```typegpu block on the device. The block is TypeGPU as you
 * would write it in a module, a solid's signed distance function:
 *
 *   const sphere = Sdf((p, t) => {
 *     return std.length(p) - 1;
 *   });
 *
 * unplugin-typegpu does this at build time for the app's own shaders: acorn
 * parses the block, tinyest-for-wgsl turns the arrow function into the AST
 * TypeGPU generates WGSL from, and the function gets it as its metadata, so
 * `tgpu.fn` treats it like one the plugin saw. Its numbers become uniform
 * reads on the way, so they can change without compiling again.
 */
export function compileSolid(
  code: string,
  register = false,
  grow?: number
): Compiled {
  const started = performance.now();
  try {
    const key = `${grow ?? ''}|${code}`;
    let result = compiled.get(key);
    if (!result) {
      const built = build(code, true, grow);
      const wgsl = resolveShader(built.shape);
      result = {
        ok: true,
        name: built.name,
        wgsl,
        ms: performance.now() - started,
        knobs: built.knobs,
        grow: built.grows ? grow : undefined,
        shape: built.shape,
      };
      compiled.set(key, result);
    }
    if (register) solids.set(result.name, code);
    return result;
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

/**
 * A block still being written, cut after its last whole statement and closed
 * with a return of its first `let`, the distance it builds up line by line.
 * A `const` adds nothing to it yet, nor does its own `return`, so the cut
 * skips those. Null until there
 * is such a statement, and once the function is whole.
 */
export function closePartial(code: string) {
  const open = code.indexOf('{', code.indexOf('=>'));
  if (open === -1) return null;
  let braces = 0;
  let parens = 0;
  let cut = -1;
  let start = open + 1;
  const end = (i: number) => {
    if (!/^(const|return)\b/.test(code.slice(start, i).trimStart())) cut = i;
    start = i;
  };
  for (let i = open; i < code.length; i++) {
    const char = code[i];
    if (char === '(' || char === '[') parens++;
    else if (char === ')' || char === ']') parens--;
    else if (char === '{') braces++;
    else if (char === '}') {
      braces--;
      if (braces === 0) return null;
      if (braces === 1 && parens === 0) end(i + 1);
    } else if (char === ';' && braces === 1 && parens === 0) end(i + 1);
  }
  const running = code.slice(open, cut).match(/\n {2}let (\w+)/)?.[1];
  if (cut === -1 || !running) return null;
  return `${code.slice(0, cut)}\n  return ${running};\n});\n`;
}

function build(code: string, live: boolean, grow?: number) {
  const program = parse(code, {
    ecmaVersion: 'latest',
    sourceType: 'module',
  }) as AnyNode;
  const declaration = program.body.find(
    (node: AnyNode) => node.type === 'VariableDeclaration'
  ) as AnyNode | undefined;
  const declarator = declaration?.declarations[0];
  const call = declarator?.init;
  const impl = call?.arguments?.[0];
  if (
    call?.type !== 'CallExpression' ||
    !impl ||
    (impl.type !== 'ArrowFunctionExpression' &&
      impl.type !== 'FunctionExpression')
  ) {
    throw new Error('Expected `const name = Sdf((p, t) => { ... })`');
  }
  const name: string = declarator.id.name;
  const knobs = live ? liftNumbers(impl.body) : [];
  const grows = grow !== undefined && growNewest(impl.body, grow);
  const { params, body, externalNames } = transpileAcornFn(impl);
  const names = [...externalNames.keys()];
  const fn = () => {};
  const meta = ((globalThis as any).__TYPEGPU_META__ ??= new WeakMap());
  meta.set(fn, {
    v: 2,
    name,
    ast: { params, body, externalNames: names },
    externals: Object.fromEntries(
      names.map((path) => [path, () => lookup(path)])
    ),
  });
  // The shell is the block's own, `Sdf` or a `tgpu.fn([...], ...)`, so a
  // signature that is not (vec3f, f32) -> f32 fails here.
  const shape = evaluate(call.callee)(fn) as Shape;
  return { name, shape, knobs, grows };
}

// How far in a part starts, deeper than any is thick, so it is not there yet.
const GROW_DEPTH = 0.35;

// A preview's newest part, `s = <part>` before its `return s`, becomes
// `s = std.min(s, <part> + (1 - grow) * depth)`: the part swells out from its
// core as `grow` goes from 0 to 1, and at 1 it is the statement as written.
function growNewest(body: AnyNode, slot: number) {
  const statements: AnyNode[] = body.body;
  const result = statements[statements.length - 1];
  const newest = statements[statements.length - 2];
  const name =
    result?.type === 'ReturnStatement' && result.argument?.type === 'Identifier'
      ? result.argument.name
      : null;
  const assign =
    newest?.type === 'ExpressionStatement' ? newest.expression : null;
  if (
    !name ||
    assign?.type !== 'AssignmentExpression' ||
    assign.operator !== '=' ||
    assign.left.type !== 'Identifier' ||
    assign.left.name !== name
  ) {
    return false;
  }
  const number = (value: number) => ({
    type: 'Literal',
    value,
    raw: String(value),
  });
  const binary = (operator: string, left: AnyNode, right: AnyNode) => ({
    type: 'BinaryExpression',
    operator,
    left,
    right,
  });
  assign.right = {
    type: 'CallExpression',
    callee: {
      type: 'MemberExpression',
      computed: false,
      object: { type: 'Identifier', name: 'std' },
      property: { type: 'Identifier', name: 'min' },
    },
    arguments: [
      { type: 'Identifier', name },
      binary(
        '+',
        assign.right,
        binary(
          '*',
          binary('-', number(1), knobRead(slot) as AnyNode),
          number(GROW_DEPTH)
        ) as AnyNode
      ),
    ],
  };
  return true;
}

function knobRead(slot: number) {
  return {
    type: 'MemberExpression',
    computed: false,
    object: {
      type: 'MemberExpression',
      computed: true,
      object: { type: 'Identifier', name: KNOBS_NAME },
      property: { type: 'Literal', value: slot >> 2, raw: String(slot >> 2) },
    },
    property: { type: 'Identifier', name: 'xyzw'[slot & 3] },
  };
}

// Turns the body's numbers into reads of the knobs uniform, in place, all but
// a loop's own: its counter stays an integer.
function liftNumbers(body: AnyNode) {
  const literals: AnyNode[] = [];
  const visit = (node: AnyNode, inLoopHead: boolean) => {
    if (!node || typeof node.type !== 'string') return;
    if (
      node.type === 'Literal' &&
      typeof node.value === 'number' &&
      !inLoopHead
    ) {
      literals.push(node);
      return;
    }
    for (const [key, child] of Object.entries(node)) {
      const head =
        inLoopHead ||
        (node.type === 'ForStatement' &&
          (key === 'init' || key === 'test' || key === 'update')) ||
        (node.type === 'MemberExpression' &&
          node.computed &&
          key === 'property');
      if (Array.isArray(child)) child.forEach((item) => visit(item, head));
      else if (child && typeof child === 'object')
        visit(child as AnyNode, head);
    }
  };
  visit(body, false);
  return literals.slice(0, GROW_SLOTS[0]).map((node, i): Knob => {
    const knob = {
      start: node.start,
      end: node.end,
      value: node.value as number,
    };
    for (const key of Object.keys(node)) {
      if (key !== 'start' && key !== 'end') delete node[key];
    }
    Object.assign(node, knobRead(i));
    return knob;
  });
}

function lookup(path: string) {
  if (path === KNOBS_NAME) return layout.$.knobs;
  const [first, ...rest] = path.split('.');
  let value: any = first! in SCOPE ? SCOPE[first!] : solid(first!);
  if (value === undefined) throw new Error(`${first} is not defined`);
  for (const key of rest) {
    if (value == null || !(key in Object(value)))
      throw new Error(`${path} is not defined`);
    value = value[key];
  }
  return value;
}

function solid(name: string) {
  const entry = solids.get(name);
  if (typeof entry !== 'string') return entry;
  const { shape } = build(entry, false);
  solids.set(name, shape);
  return shape;
}

// Just enough JavaScript for a function shell: `Sdf`, `tgpu.fn([d.vec3f, d.f32], d.f32)`.
function evaluate(node: AnyNode): any {
  switch (node.type) {
    case 'Identifier':
      return lookup(node.name);
    case 'MemberExpression':
      return evaluate(node.object)[
        node.computed ? evaluate(node.property) : node.property.name
      ];
    case 'CallExpression': {
      const args = node.arguments.map(evaluate);
      if (node.callee.type === 'MemberExpression') {
        const target = evaluate(node.callee.object);
        return target[node.callee.property.name](...args);
      }
      return evaluate(node.callee)(...args);
    }
    case 'ArrayExpression':
      return node.elements.map(evaluate);
    case 'Literal':
      return node.value;
    default:
      throw new Error(`Unsupported ${node.type} in the function shell`);
  }
}
