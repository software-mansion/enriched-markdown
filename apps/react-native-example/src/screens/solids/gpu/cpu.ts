import { std } from 'typegpu';

// Runs a TypeGPU function on the CPU, from the same TinyEst AST its WGSL is
// generated from. A function's JavaScript body can't do vector maths with
// `+` or `*`, so this walks the AST instead and does them with `std`, and
// calls into other TypeGPU functions, `sd.*` included, the same way.

type Meta = {
  ast: { params: { type: string; name: string }[]; body: unknown };
  externals: Record<string, unknown> | (() => Record<string, unknown>);
};

const BINARY: Record<string, (a: any, b: any) => any> = {
  '+': (a, b) => std.add(a, b),
  '-': (a, b) => std.sub(a, b),
  '*': (a, b) => std.mul(a, b),
  '/': (a, b) => std.div(a, b),
  '%': (a, b) => a % b,
  '<': (a, b) => a < b,
  '<=': (a, b) => a <= b,
  '>': (a, b) => a > b,
  '>=': (a, b) => a >= b,
  '==': (a, b) => a === b,
  '===': (a, b) => a === b,
  '!=': (a, b) => a !== b,
  '!==': (a, b) => a !== b,
};

const Break = Symbol('break');
const Continue = Symbol('continue');
class Return {
  constructor(readonly value: unknown) {}
}

// TypeGPU reads a function's metadata once, when it first resolves it, and
// deletes it; a copy is kept here so the CPU can still walk its AST.
const registry: WeakMap<object, Meta> = ((
  globalThis as any
).__TYPEGPU_META__ ??= new WeakMap());
const kept = new WeakMap<object, Meta>();
const forget = registry.delete.bind(registry);
registry.delete = (key: object) => {
  const meta = registry.get(key);
  if (meta) kept.set(key, meta);
  return forget(key);
};
const metaFor = (key: object) => registry.get(key) ?? kept.get(key);

function metaOf(fn: any): Meta | undefined {
  if (fn == null || (typeof fn !== 'object' && typeof fn !== 'function')) {
    return undefined;
  }
  const direct = metaFor(fn);
  if (direct) return direct;
  const internal = Object.getOwnPropertySymbols(fn).find((s) =>
    String(s).includes('$internal')
  );
  const impl = internal ? fn[internal]?.implementation : undefined;
  return impl ? metaFor(impl) : undefined;
}

// Private variables, `trap.$`, live here on the CPU, one value each.
const vars = new WeakMap<object, unknown>();

/**
 * A TypeGPU function, or its implementation, as a function the CPU can call.
 * `overrides` stand in for externals that only exist on the GPU, such as a
 * uniform's current value.
 */
export function onCpu(
  fn: unknown,
  overrides: Record<string, unknown> = {}
): (...args: unknown[]) => any {
  const meta = metaOf(fn);
  if (!meta) return fn as (...args: unknown[]) => any;
  const own =
    typeof meta.externals === 'function' ? meta.externals() : meta.externals;
  const externals = { ...own, ...overrides };
  return (...args) => {
    const scope = new Map<string, unknown>();
    meta.ast.params.forEach((param, i) => scope.set(param.name, args[i]));
    try {
      run(meta.ast.body, [scope], externals);
    } catch (thrown) {
      if (thrown instanceof Return) return thrown.value;
      throw thrown;
    }
    return undefined;
  };
}

type Scopes = Map<string, unknown>[];

function lookup(name: string, scopes: Scopes, externals: any) {
  for (let i = scopes.length - 1; i >= 0; i--) {
    if (scopes[i]!.has(name)) return scopes[i]!.get(name);
  }
  if (name in externals) {
    const value = externals[name];
    // Externals compiled at runtime are thunks; the plugin's are values.
    return typeof value === 'function' && !metaOf(value) && value.length === 0
      ? value()
      : value;
  }
  throw new Error(`${name} is not defined on the CPU`);
}

function assign(name: string, value: unknown, scopes: Scopes) {
  for (let i = scopes.length - 1; i >= 0; i--) {
    if (scopes[i]!.has(name)) {
      scopes[i]!.set(name, value);
      return;
    }
  }
  throw new Error(`${name} is not declared`);
}

function run(node: any, scopes: Scopes, externals: any): unknown {
  if (!Array.isArray(node)) return evaluate(node, scopes, externals);
  switch (node[0]) {
    case 0: {
      const inner = [...scopes, new Map()];
      for (const statement of node[1]) run(statement, inner, externals);
      return;
    }
    case 10:
      throw new Return(
        node.length > 1 ? evaluate(node[1], scopes, externals) : undefined
      );
    case 11:
      if (evaluate(node[1], scopes, externals)) run(node[2], scopes, externals);
      else if (node.length > 3) run(node[3], scopes, externals);
      return;
    case 12:
    case 13: {
      const name = typeof node[1] === 'string' ? node[1] : node[1][1];
      scopes[scopes.length - 1]!.set(
        name,
        node.length > 2 ? evaluate(node[2], scopes, externals) : undefined
      );
      return;
    }
    case 14: {
      const loop = [...scopes, new Map()];
      if (node[1]) run(node[1], loop, externals);
      while (!node[2] || evaluate(node[2], loop, externals)) {
        try {
          run(node[4], loop, externals);
        } catch (thrown) {
          if (thrown === Break) break;
          if (thrown !== Continue) throw thrown;
        }
        if (node[3]) run(node[3], loop, externals);
      }
      return;
    }
    case 15:
      while (evaluate(node[1], scopes, externals)) {
        try {
          run(node[2], scopes, externals);
        } catch (thrown) {
          if (thrown === Break) break;
          if (thrown !== Continue) throw thrown;
        }
      }
      return;
    case 16:
      throw Continue;
    case 17:
      throw Break;
    default:
      evaluate(node, scopes, externals);
  }
}

function evaluate(node: any, scopes: Scopes, externals: any): any {
  if (typeof node === 'string') return lookup(node, scopes, externals);
  if (typeof node === 'boolean') return node;
  switch (node[0]) {
    case 1:
      return BINARY[node[2]]!(
        evaluate(node[1], scopes, externals),
        evaluate(node[3], scopes, externals)
      );
    case 2: {
      const [, target, op, expr] = node;
      const value = evaluate(expr, scopes, externals);
      const next =
        op === '='
          ? value
          : BINARY[op.slice(0, -1)]!(
              evaluate(target, scopes, externals),
              value
            );
      if (typeof target === 'string') assign(target, next, scopes);
      else if (target[0] === 7 && target[2] === '$') {
        vars.set(evaluate(target[1], scopes, externals), next);
      } else if (target[0] === 7) {
        evaluate(target[1], scopes, externals)[target[2]] = next;
      }
      return next;
    }
    case 3: {
      const left = evaluate(node[1], scopes, externals);
      if (node[2] === '&&') return left && evaluate(node[3], scopes, externals);
      if (node[2] === '||') return left || evaluate(node[3], scopes, externals);
      return left ?? evaluate(node[3], scopes, externals);
    }
    case 4: {
      const inner = evaluate(node[2], scopes, externals);
      if (node[1] === '-') return std.neg(inner);
      if (node[1] === '!') return !inner;
      return inner;
    }
    case 5:
      return Number(node[1]);
    case 6: {
      const callee = evaluate(node[1], scopes, externals);
      const args = node[2].map((arg: any) => evaluate(arg, scopes, externals));
      return metaOf(callee) ? onCpu(callee)(...args) : callee(...args);
    }
    case 7: {
      const object = evaluate(node[1], scopes, externals);
      return node[2] === '$' ? (vars.get(object) ?? 1) : object[node[2]];
    }
    case 8:
      return evaluate(node[1], scopes, externals)[
        evaluate(node[2], scopes, externals)
      ];
    case 9:
      return lookup(node[1], scopes, externals);
    case 101:
    case 102: {
      const name = node[2] as string;
      const before = lookup(name, scopes, externals) as number;
      const after = node[1] === '++' ? before + 1 : before - 1;
      assign(name, after, scopes);
      return node[0] === 101 ? after : before;
    }
    case 105:
      return evaluate(node[1], scopes, externals)
        ? evaluate(node[2], scopes, externals)
        : evaluate(node[3], scopes, externals);
    case 107:
      return node[1];
    default:
      throw new Error(`Unsupported node ${node[0]} on the CPU`);
  }
}
