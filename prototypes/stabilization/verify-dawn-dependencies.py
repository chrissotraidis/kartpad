#!/usr/bin/env python3
"""Verify populated Dawn dependency checkouts against its pinned DEPS data."""
import argparse
import ast
import json
from pathlib import Path
import subprocess


def string(node):
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return node.value
    if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add):
        return string(node.left) + string(node.right)
    raise ValueError('unsupported DEPS string expression')


def verify(root):
    module = ast.parse((root / 'DEPS').read_text())
    deps = next(node.value for node in module.body if isinstance(node, ast.Assign)
                and any(isinstance(target, ast.Name) and target.id == 'deps' for target in node.targets))
    records = []
    for key, value in zip(deps.keys, deps.values):
        name = string(key)
        path = root / name
        if not (path / '.git').exists():
            continue
        url_node = (next(v for k, v in zip(value.keys, value.values) if string(k) == 'url')
                    if isinstance(value, ast.Dict) else value)
        expected = string(url_node).rsplit('@', 1)[1]
        revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=path, text=True).strip()
        changes = subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=no'],
                                          cwd=path, text=True).strip()
        if revision != expected or changes:
            raise ValueError(f'dependency revision or tracked source differs: {name}')
        records.append({'path': name, 'revision': revision})
    required = {'third_party/abseil-cpp', 'third_party/jinja2', 'third_party/markupsafe',
                'third_party/spirv-headers/src', 'third_party/spirv-tools/src',
                'third_party/vulkan-headers/src', 'third_party/vulkan-utility-libraries/src',
                'third_party/webgpu-headers/src', 'third_party/protobuf'}
    missing = required - {record['path'] for record in records}
    if missing:
        raise ValueError(f'missing populated dependencies: {sorted(missing)}')
    return records


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(args.source), indent=2))
