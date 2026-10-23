#!/usr/bin/env python3
"""Skip malformed MDL0 texture metadata links in the light-map lookup.

Apply to both standalone functions and the aggregate sources actually compiled:
the shard emitter may use an older cached source bundle.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

SIGNATURE = 'extern "C" void func_802289DC(CpuContext* MKW_RESTRICT ctx)\n{'
ENTRY = '[[maybe_unused]] loc_80228A44:\n{\n    r0 = MemoryInline::FlatRead32(r3);'
MARKER = '// KartPad: ignore a texture metadata link outside its owning MDL0.'
GUARD = '''[[maybe_unused]] loc_80228A44:
{
    // KartPad: ignore a texture metadata link outside its owning MDL0.
    // Some custom models contain stale relative links. ResTexPlttInfo is a
    // 0x34-byte material record inside MDL0; its name may live in a separate
    // string pool. Skip only this invalid link, preserving the remaining
    // links, name filtering, output capacity, and the generated epilogue.
    const uint32_t model = MemoryInline::FlatRead32(r23);
    const uint64_t model_end = uint64_t{model} + MemoryInline::FlatRead32(model + 4u);
    if (model_end > (uint64_t{1} << 32) || r3 < model ||
        uint64_t{r3} + 0x34u > model_end) {
        goto loc_80228AD8;
    }
    r0 = MemoryInline::FlatRead32(r3);'''
NEXT_LINK = '[[maybe_unused]] loc_80228AD8:\n{\n    r28 = (r28 + 1);'


def function_span(source: str, path: Path) -> tuple[int, int]:
    if source.count(SIGNATURE) != 1:
        raise SystemExit(f"expected one texture-link function in {path}; regenerate translation")
    start = source.index(SIGNATURE)
    end = source.find('\n// RECOMP_GUEST_ABI ', start)
    if end < 0 or not source[start:end].rstrip().endswith('}'):
        raise SystemExit(f"unexpected texture-link function boundary in {path}")
    return start, end


def verify_body(body: str, path: Path) -> None:
    if body.count(GUARD) != 1 or body.count(MARKER) != 1 or body.count(NEXT_LINK) != 1:
        raise SystemExit(f"missing complete texture-link guard in {path}; regenerate translation")
    if body.index(GUARD) >= body.index(NEXT_LINK):
        raise SystemExit(f"unexpected texture-link loop in {path}; regenerate translation")


def inject(path: Path) -> bool:
    source = path.read_text()
    start, end = function_span(source, path)
    body = source[start:end]
    if MARKER in body or 'const uint64_t model_end' in body:
        verify_body(body, path)
        return False
    if body.count(ENTRY) != 1 or body.count(NEXT_LINK) != 1:
        raise SystemExit(f"unexpected texture-link source in {path}; regenerate translation")
    guarded = body.replace(ENTRY, GUARD, 1)
    verify_body(guarded, path)
    path.write_text(source[:start] + guarded + source[end:])
    return True


def verify(path: Path) -> None:
    source = path.read_text()
    start, end = function_span(source, path)
    verify_body(source[start:end], path)


def shard_definition(root: Path) -> Path:
    root = root.resolve()
    graph = (root / 'shards.cmake').read_text()
    entries = re.findall(r'^\s*"([^"\n]+\.cpp)"\s*$', graph, re.M)
    if not entries:
        raise SystemExit(f"missing compiled source list in {root}/shards.cmake")
    definitions = []
    for entry in sorted(set(entries)):
        path = Path(entry).resolve()
        if SIGNATURE in path.read_text():
            if not path.is_relative_to(root):
                raise SystemExit(f"compiled texture-link function outside shard root: {path}")
            definitions.append(path)
    if len(definitions) != 1:
        raise SystemExit(f"expected one compiled texture-link function under {root}")
    return definitions[0]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--verify', action='store_true')
    modes.add_argument('--inject-shards', type=Path)
    modes.add_argument('--verify-shards', type=Path)
    parser.add_argument('function', type=Path, nargs='?')
    args = parser.parse_args()
    shards = args.inject_shards or args.verify_shards
    if bool(shards) == bool(args.function):
        parser.error('provide a function path or a shard mode/root')
    try:
        path = shard_definition(shards) if shards else args.function
        if args.verify or args.verify_shards:
            verify(path)
        else:
            inject(path)
    except OSError as error:
        parser.exit(1, f'texture-link guard: {error}\n')
    print(f'verified texture-link guard: {path}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
