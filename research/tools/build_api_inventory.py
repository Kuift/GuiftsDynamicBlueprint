#!/usr/bin/env python3
"""Build a deterministic, clean-room inventory of KAG APIs used by this mod.

The installed KAG manual publishes the AngelScript declarations. This tool
cross-references those declarations against call-like tokens in mod sources.
Member ownership is necessarily approximate without full AngelScript type
inference; ambiguous names are reported rather than guessed.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


PRIORITY_TYPES = [
    "CBrain",
    "CBlob",
    "CMap",
    "CInventory",
    "CRules",
    "CShape",
    "CNet",
    "CBitStream",
    "CPlayer",
    "CCamera",
    "CSprite",
    "CControls",
    "Driver",
    "SMesh",
    "SMaterial",
]

DECL_NAME_RE = re.compile(r"([A-Za-z_]\w*(?:::[A-Za-z_]\w*)*|<constructor>)\s*\(")
MEMBER_CALL_RE = re.compile(r"\.\s*([A-Za-z_]\w*)\s*\(")
STRING_RE = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')
BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.S)
LINE_COMMENT_RE = re.compile(r"//[^\r\n]*")


def sanitize_source(text: str) -> str:
    text = BLOCK_COMMENT_RE.sub(lambda m: "\n" * m.group(0).count("\n"), text)
    text = LINE_COMMENT_RE.sub("", text)
    return STRING_RE.sub('""', text)


def declaration_name(signature: str) -> str | None:
    match = DECL_NAME_RE.search(signature)
    if not match:
        return None
    name = match.group(1)
    return None if name == "<constructor>" else name


def read_object_interfaces(objects_dir: Path) -> dict[str, list[dict[str, str]]]:
    result: dict[str, list[dict[str, str]]] = {}
    for path in sorted(objects_dir.glob("*.txt"), key=lambda p: p.name.lower()):
        text = path.read_text(encoding="utf-8", errors="replace")
        header = re.search(r"-- CLASS '([^']+)' --", text)
        if not header:
            continue
        owner = header.group(1)
        declarations: list[dict[str, str]] = []
        for raw in text.splitlines():
            signature = raw.strip()
            if not signature or signature.startswith("---") or signature.startswith("-- CLASS"):
                continue
            name = declaration_name(signature)
            if name:
                declarations.append({"name": name, "signature": signature})
        result[owner] = declarations
    return result


def read_global_interfaces(functions_file: Path) -> list[dict[str, str]]:
    declarations: list[dict[str, str]] = []
    for raw in functions_file.read_text(encoding="utf-8", errors="replace").splitlines():
        signature = raw.strip()
        if not signature or signature.startswith("---"):
            continue
        name = declaration_name(signature)
        if name:
            declarations.append({"name": name, "signature": signature})
    return declarations


def source_files(mod_root: Path) -> list[Path]:
    ignored_parts = {".git", ".agents", ".codex", "Artifacts", "research"}
    files = []
    for path in mod_root.rglob("*.as"):
        try:
            relative = path.relative_to(mod_root)
        except ValueError:
            continue
        if any(part in ignored_parts for part in relative.parts):
            continue
        files.append(path)
    return sorted(files, key=lambda p: p.as_posix().lower())


def count_pattern(pattern: re.Pattern[str], sources: dict[str, str]) -> tuple[int, list[str]]:
    count = 0
    files: list[str] = []
    for name, text in sources.items():
        found = len(pattern.findall(text))
        if found:
            count += found
            files.append(name)
    return count, files


def markdown_report(data: dict) -> str:
    lines = [
        "# KAG Engine API Usage Inventory",
        "",
        f"Installed interface build: **{data['engine_interface_build']}**",
        f"Scanned AngelScript files: **{data['source_file_count']}**",
        "",
        "> Counts are lexical call-like matches. A member name shared by several",
        "> engine types is intentionally shown under each possible owner; this is",
        "> a prioritization map, not full AngelScript type inference.",
        "",
        "## Priority surface",
        "",
        "| Engine type | Call-like references | Used methods | Published methods |",
        "|---|---:|---:|---:|",
    ]
    for item in data["priority_summary"]:
        lines.append(
            f"| `{item['type']}` | {item['call_references']} | "
            f"{item['used_method_count']} | {item['published_method_count']} |"
        )

    for owner in PRIORITY_TYPES:
        methods = data["types"].get(owner, {}).get("used_methods", [])
        if not methods:
            continue
        lines.extend(
            [
                "",
                f"## {owner}",
                "",
                "| Method | References | Files | Published signatures |",
                "|---|---:|---:|---|",
            ]
        )
        for method in methods:
            signatures = "<br>".join(f"`{s}`" for s in method["signatures"])
            lines.append(
                f"| `{method['name']}` | {method['count']} | "
                f"{len(method['files'])} | {signatures} |"
            )

    lines.extend(
        [
            "",
            "## Most-used published global functions",
            "",
            "| Function | References | Files |",
            "|---|---:|---:|",
        ]
    )
    for item in data["used_globals"][:60]:
        lines.append(f"| `{item['name']}` | {item['count']} | {len(item['files'])} |")

    lines.extend(
        [
            "",
            "## Unresolved member-call names",
            "",
            "These are usually mod-defined methods or calls on script-library types.",
            "They are retained so a missing engine declaration is visible.",
            "",
            "| Name | References |",
            "|---|---:|",
        ]
    )
    for name, count in data["unresolved_member_calls"][:80]:
        lines.append(f"| `{name}` | {count} |")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mod-root", type=Path)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()

    default_mod_root = Path(__file__).resolve().parents[2]
    mod_root = (args.mod_root or default_mod_root).resolve()
    kag_root = mod_root.parent.parent
    interface_root = kag_root / "Manual" / "interface"
    objects_dir = interface_root / "Objects"
    functions_file = interface_root / "Functions.txt"
    if not objects_dir.is_dir() or not functions_file.is_file():
        raise SystemExit(f"Installed KAG interface manual not found under {interface_root}")

    object_interfaces = read_object_interfaces(objects_dir)
    global_interfaces = read_global_interfaces(functions_file)
    paths = source_files(mod_root)
    sources = {
        path.relative_to(mod_root).as_posix(): sanitize_source(
            path.read_text(encoding="utf-8", errors="replace")
        )
        for path in paths
    }

    method_owners: dict[str, set[str]] = defaultdict(set)
    for owner, declarations in object_interfaces.items():
        for decl in declarations:
            method_owners[decl["name"]].add(owner)

    member_counts: Counter[str] = Counter()
    member_files: dict[str, set[str]] = defaultdict(set)
    for filename, text in sources.items():
        for name in MEMBER_CALL_RE.findall(text):
            member_counts[name] += 1
            member_files[name].add(filename)

    types: dict[str, dict] = {}
    for owner, declarations in sorted(object_interfaces.items()):
        by_name: dict[str, list[str]] = defaultdict(list)
        for decl in declarations:
            by_name[decl["name"]].append(decl["signature"])
        used = []
        for name, signatures in sorted(by_name.items()):
            count = member_counts[name]
            if count:
                used.append(
                    {
                        "name": name,
                        "count": count,
                        "files": sorted(member_files[name]),
                        "signatures": sorted(set(signatures)),
                        "ambiguous_owners": sorted(method_owners[name]),
                    }
                )
        used.sort(key=lambda item: (-item["count"], item["name"]))
        types[owner] = {
            "published_method_count": len(by_name),
            "used_methods": used,
        }

    used_globals = []
    globals_by_name: dict[str, list[str]] = defaultdict(list)
    for decl in global_interfaces:
        globals_by_name[decl["name"]].append(decl["signature"])
    for name, signatures in sorted(globals_by_name.items()):
        token = re.escape(name)
        pattern = re.compile(rf"(?<![A-Za-z0-9_]){token}\s*\(")
        count, files = count_pattern(pattern, sources)
        if count:
            used_globals.append(
                {
                    "name": name,
                    "count": count,
                    "files": files,
                    "signatures": sorted(set(signatures)),
                }
            )
    used_globals.sort(key=lambda item: (-item["count"], item["name"]))

    priority_summary = []
    for owner in PRIORITY_TYPES:
        info = types.get(owner, {"published_method_count": 0, "used_methods": []})
        priority_summary.append(
            {
                "type": owner,
                "call_references": sum(item["count"] for item in info["used_methods"]),
                "used_method_count": len(info["used_methods"]),
                "published_method_count": info["published_method_count"],
            }
        )

    published_method_names = set(method_owners)
    unresolved = sorted(
        ((name, count) for name, count in member_counts.items() if name not in published_method_names),
        key=lambda item: (-item[1], item[0]),
    )
    build_match = re.search(
        r"SCRIPT INTERFACE FOR BUILD\s+(\d+)",
        (objects_dir / "CBrain.txt").read_text(encoding="utf-8", errors="replace"),
    )
    data = {
        "schema": 1,
        "engine_interface_build": int(build_match.group(1)) if build_match else None,
        "source_file_count": len(paths),
        "priority_types": PRIORITY_TYPES,
        "priority_summary": priority_summary,
        "types": types,
        "used_globals": used_globals,
        "unresolved_member_calls": unresolved,
    }

    output_dir = (args.output_dir or mod_root / "research" / "generated").resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / "engine_api_inventory.json"
    md_path = output_dir / "engine_api_inventory.md"
    json_path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    md_path.write_text(markdown_report(data), encoding="utf-8")
    print(f"Wrote {md_path}")
    print(f"Wrote {json_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
