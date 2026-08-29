#!/usr/bin/env python3
"""Read-only Retail 12.1 repository boundary audit.

The scanner deliberately reports context-sensitive patterns instead of rewriting
runtime code. It separates localization/player-facing files from service docs
before reporting Cyrillic text.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
REPORT_PATH = ROOT / "artifacts" / "retail-12-1-audit.json"

RUNTIME_SUFFIXES = {".lua", ".xml", ".toc"}
SERVICE_SUFFIXES = {".md", ".txt", ".rst", ".adoc"}
CYRILLIC = re.compile(r"[А-Яа-яЁё]")
INTERFACE_RE = re.compile(r"^##\s*Interface\s*:\s*(.+?)\s*$", re.MULTILINE)
SLASH_LITERAL_RE = re.compile(r"SLASH_[A-Z0-9_]+\d*\s*=\s*([\"'])(/[^\"']+)\1")

LOCALIZATION_PARTS = {
    "locale",
    "locales",
    "localization",
    "localizations",
    "l10n",
    "i18n",
    "ruru",
}

SERVICE_NAMES = {
    "todo.md",
    "todo.txt",
    "history.md",
    "history.txt",
    "audit.md",
    "plan.md",
    "architecture.md",
    "agent_guide.md",
    "agents.md",
    "code_index.md",
    "code_graph.md",
    "current_status.md",
    "migration.md",
    "handoff.md",
}

REMOVED_OR_OBSOLETE = {
    "AddAuraFrame": "removed PTR aura prototype",
    "AddAuraFilter": "removed PTR aura prototype",
    "SecureAuraHeaderTemplate": "removed Mainline fallback",
    "UIParentLoadAddOn": "replaced load-on-demand wrapper",
    "CanAccessObject": "replaced FrameScriptObject access query",
    "InterfaceOptions_AddCategory": "deprecated Settings path",
    "InterfaceOptionsCheckButtonTemplate": "deprecated Settings template",
    "GetCVarBool": "removed/deprecated CVar helper",
    "getglobal(": "deprecated global access",
    "setglobal(": "deprecated global mutation",
}

RAW_AURA_PATTERNS = {
    "UNIT_AURA": "secret-capable event/payload",
    "C_UnitAuras": "raw aura API",
    "AuraUtil.ForEachAura": "raw aura enumeration",
    "UnitAura(": "legacy/raw aura read",
    "GetAuraDataByAuraInstanceID": "raw aura instance read",
    "GetAuraDataByIndex": "raw aura index read",
    "GetUnitAuras": "raw aura collection",
}

ACCESS_PATTERNS = {
    "canaccessvalue": "value accessibility gate",
    "canaccessallvalues": "tuple accessibility gate",
    "issecretvalue": "secret-value classification",
    "issecrettable": "secret-table classification",
    "CanBeAccessedInContext": "object access constraint query",
    "HasAccessConstraints": "object constraint query",
    "IsForbidden": "forbidden-object query",
    "C_Secrets": "domain secrecy predicate",
}

HOT_LOOP_PATTERNS = {
    "SetScript(\"OnUpdate\"": "OnUpdate owner",
    "SetScript('OnUpdate'": "OnUpdate owner",
    "C_Timer.NewTicker": "repeating ticker",
    "C_Timer.After": "deferred timer",
    "GetFramesRegisteredForEvent": "global event-frame scan",
    "EnumerateFrames": "global frame scan",
    "GetChildren(": "frame-tree scan",
    "GetNumChildren(": "frame-tree size query",
}

PERSISTENCE_PATTERNS = {
    "SavedVariables": "TOC SavedVariables declaration",
    "RothSpellTrackerDB": "addon database symbol",
    "table.insert": "potential unbounded append",
    "string.format": "formatting boundary",
    "tostring(": "stringification boundary",
}


def iter_files() -> Iterable[Path]:
    ignored_roots = {".git", "artifacts", "node_modules", "vendor"}
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT)
        if any(part in ignored_roots for part in relative.parts):
            continue
        yield path


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8-sig")
    except UnicodeDecodeError:
        return ""


def is_localization(path: Path) -> bool:
    relative = path.relative_to(ROOT)
    lowered = [part.lower() for part in relative.parts]
    name = relative.name.lower()
    if any(part in LOCALIZATION_PARTS for part in lowered):
        return True
    if "ruru" in name or name.endswith("_ru.lua") or name.endswith("-ru.lua"):
        return True
    if name.endswith(".toc"):
        return False
    return False


def is_service_doc(path: Path) -> bool:
    relative = path.relative_to(ROOT)
    name = relative.name.lower()
    if path.suffix.lower() not in SERVICE_SUFFIXES:
        return False
    if is_localization(path):
        return False
    if name in SERVICE_NAMES:
        return True
    service_tokens = ("todo", "history", "audit", "plan", "architecture", "agent", "handoff", "migration", "status", "roadmap")
    return any(token in name for token in service_tokens)


def matches(text: str, patterns: dict[str, str]) -> list[dict[str, object]]:
    found: list[dict[str, object]] = []
    lines = text.splitlines()
    for token, meaning in patterns.items():
        token_hits = [index for index, line in enumerate(lines, 1) if token in line]
        if token_hits:
            found.append({"token": token, "meaning": meaning, "lines": token_hits[:25], "count": len(token_hits)})
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true", help="return non-zero for confirmed hard blockers")
    args = parser.parse_args()

    report: dict[str, object] = {
        "schema": "roth-retail-12.1-audit.v1",
        "repository": ROOT.name,
        "target_interface": 120100,
        "toc": [],
        "slash_aliases": defaultdict(list),
        "removed_or_obsolete": [],
        "raw_aura": [],
        "access_boundaries": [],
        "hot_loops": [],
        "persistence": [],
        "russian_service_docs": [],
        "localization_files_with_cyrillic": [],
        "hard_blockers": [],
    }

    for path in iter_files():
        relative = path.relative_to(ROOT).as_posix()
        text = read_text(path)
        if not text:
            continue

        suffix = path.suffix.lower()
        if suffix == ".toc":
            match = INTERFACE_RE.search(text)
            raw = match.group(1).strip() if match else None
            interfaces: list[int] = []
            if raw:
                for part in re.split(r"[,\s]+", raw):
                    if part.isdigit():
                        interfaces.append(int(part))
            row = {"path": relative, "raw": raw, "interfaces": interfaces}
            report["toc"].append(row)
            if 120100 not in interfaces:
                report["hard_blockers"].append({
                    "path": relative,
                    "kind": "interface",
                    "message": f"TOC does not target 120100: {raw!r}",
                })

        if suffix in RUNTIME_SUFFIXES:
            for _, alias in SLASH_LITERAL_RE.findall(text):
                report["slash_aliases"][alias.lower()].append(relative)

            for category, patterns in (
                ("removed_or_obsolete", REMOVED_OR_OBSOLETE),
                ("raw_aura", RAW_AURA_PATTERNS),
                ("access_boundaries", ACCESS_PATTERNS),
                ("hot_loops", HOT_LOOP_PATTERNS),
                ("persistence", PERSISTENCE_PATTERNS),
            ):
                for hit in matches(text, patterns):
                    report[category].append({"path": relative, **hit})

        if CYRILLIC.search(text):
            if is_localization(path):
                report["localization_files_with_cyrillic"].append(relative)
            elif is_service_doc(path):
                report["russian_service_docs"].append(relative)

    aliases = dict(sorted(report["slash_aliases"].items()))
    report["slash_aliases"] = aliases

    if "/rst" in aliases:
        report["hard_blockers"].append({
            "path": aliases["/rst"],
            "kind": "slash_collision",
            "message": "/rst collides with Roth Secret Tester; ownership must be resolved explicitly",
        })

    for hit in report["removed_or_obsolete"]:
        report["hard_blockers"].append({
            "path": hit["path"],
            "kind": "obsolete_api",
            "message": f"{hit['token']}: {hit['meaning']}",
        })

    report["summary"] = {
        "toc_files": len(report["toc"]),
        "slash_alias_count": len(aliases),
        "raw_aura_hit_files": len({row["path"] for row in report["raw_aura"]}),
        "access_gate_hit_files": len({row["path"] for row in report["access_boundaries"]}),
        "hot_loop_hit_files": len({row["path"] for row in report["hot_loops"]}),
        "russian_service_doc_count": len(report["russian_service_docs"]),
        "localization_file_count": len(report["localization_files_with_cyrillic"]),
        "hard_blocker_count": len(report["hard_blockers"]),
    }

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(json.dumps(report["summary"], indent=2, ensure_ascii=False))
    if report["hard_blockers"]:
        print("Hard blockers:")
        for blocker in report["hard_blockers"]:
            print(f"- {blocker['kind']}: {blocker['path']}: {blocker['message']}")

    return 1 if args.strict and report["hard_blockers"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
