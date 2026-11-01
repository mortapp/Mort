import { readdir, readFile } from 'node:fs/promises';
import { join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = resolve(fileURLToPath(new URL('..', import.meta.url)));
const sourceRoot = join(repoRoot, 'flutter_mort', 'lib');
const calls = { rpc: new Map(), relation: new Map() };

async function collectDartFiles(directory) {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await collectDartFiles(path));
    else if (entry.isFile() && entry.name.endsWith('.dart')) files.push(path);
  }
  return files;
}

for (const path of await collectDartFiles(sourceRoot)) {
  const source = await readFile(path, 'utf8');
  for (const [kind, expression] of [
    ['rpc', /\.rpc\(\s*(?:'([^']+)'|"([^"]+)")/g],
    // Supabase Storage also uses `.from(bucket)`. Exclude those calls so this
    // inventory reflects database relations only.
    ['relation', /(?<!storage)\.from\(\s*(?:'([^']+)'|"([^"]+)")/g],
  ]) {
    for (const match of source.matchAll(expression)) {
      const name = match[1] ?? match[2];
      if (!calls[kind].has(name)) calls[kind].set(name, new Set());
      calls[kind].get(name).add(relative(repoRoot, path).replaceAll('\\', '/'));
    }
  }
}

const serialize = (items) => Object.fromEntries(
  [...items].sort(([left], [right]) => left.localeCompare(right))
    .map(([name, paths]) => [name, [...paths].sort()]),
);

console.log(JSON.stringify({
  sourceRoot: relative(repoRoot, sourceRoot).replaceAll('\\', '/'),
  rpc: serialize(calls.rpc),
  relation: serialize(calls.relation),
}));
