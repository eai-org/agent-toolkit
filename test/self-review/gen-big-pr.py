#!/usr/bin/env python3
"""Generates the big-pr fixture of SELF-REVIEW-TEST.md: a warehouse package of N entities whose
feature branch adds soft-archive with an audit trail across every entity, with planted defects,
traps and mechanical files (lockfile, minified bundle, snapshots). Deterministic per --modules
and --seed.

Usage: gen-big-pr.py <fixture-dir> [--modules 40] [--seed 7]
Writes base/, change/, intent.txt, defects.tsv and traps.tsv into <fixture-dir>, which must not
exist yet.
"""
import argparse
import hashlib
import json
import os
import random
import sys

ENTITIES = [
    "product", "supplier", "shipment", "pallet", "bin_location", "carrier", "dock", "forklift",
    "inbound_order", "outbound_order", "pick_list", "pack_station", "return_item", "cycle_count",
    "lot", "serial_unit", "hazmat_class", "temperature_zone", "wave", "label_template",
    "customer", "warehouse_site", "shift", "operator", "scanner", "conveyor", "putaway_rule",
    "replenishment_rule", "kit", "bundle_offer", "price_list", "tax_zone", "inventory_adjustment",
    "damage_report", "quality_hold", "vendor_contract", "transport_leg", "route", "tariff",
    "sla_policy",
]

# kind -> (blocking, description); one entity each, spread over the package
DEFECTS = {
    "off_by_one": ("yes", "list_archived loops to len(rows) - 1 and drops the newest archived record"),
    "none_handling": ("yes", "archive() reads item.archived_at after repo.get() without a None check; unknown ids crash with AttributeError"),
    "inverted": ("yes", "the already-archived guard is inverted (is None): archiving a live record is rejected, re-archiving passes"),
    "swallowed": ("yes", "archive() swallows any exception from save(): the caller gets an archived record that was never persisted"),
    "swapped": ("yes", "archived_at and archived_by are assigned swapped: the actor lands in the timestamp field"),
    "leftover": ("no", "debug print() left in library code; the project rule is the audit log and warehouse.log only"),
    "actor_check": ("yes", "archive() skips the blank-actor check the requirement demands and every other entity performs"),
    "tautology": ("no", "test_archive_stamps_actor_and_time asserts `... or True`, which cannot fail"),
    "omission": ("yes", "repository.py was not updated: to_row/from_row drop archived_at and archived_by, so archive() never persists and the twice-guard never fires"),
    "compat": ("yes", "from_row indexes row[\"archived_at\"]: rows dumped before this change raise KeyError on load"),
}


def camel(name):
    return "".join(p.capitalize() for p in name.split("_"))


class Tree:
    def __init__(self, root):
        self.root = root

    def write(self, rel, lines):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write("\n".join(lines) + "\n")


def models(e, archived):
    E = camel(e)
    L = [f'"""{E} records. Timestamps are timezone-aware UTC."""',
         "from dataclasses import dataclass", "from datetime import datetime",
         "from typing import Optional", "", "", "@dataclass", f"class {E}:", "    id: str",
         "    name: str", "    created_at: datetime", "    updated_at: Optional[datetime] = None",
         "    active: bool = True"]
    if archived:
        L += ["    archived_at: Optional[datetime] = None", "    archived_by: Optional[str] = None"]
    return L


def repository(e, archived, compat_bug=False):
    E = camel(e)
    marks = {}
    L = [f'"""Dict-backed {e} store. Methods never raise on a miss; they return None or False."""',
         "from datetime import datetime", "from typing import Dict, List, Optional", "",
         f"from .models import {E}", "", "", f"def to_row(item: {E}) -> dict:",
         '    """Serialize for the JSON dump."""', "    return {", '        "id": item.id,',
         '        "name": item.name,', '        "created_at": item.created_at.isoformat(),',
         '        "updated_at": item.updated_at.isoformat() if item.updated_at else None,',
         '        "active": item.active,']
    marks["to_row"] = 8
    if archived:
        L += ['        "archived_at": item.archived_at.isoformat() if item.archived_at else None,',
              '        "archived_by": item.archived_by,']
    L += ["    }", "", ""]
    marks["from_row"] = len(L) + 1
    L += [f"def from_row(row: dict) -> {E}:", '    """Rebuild from a to_row dict."""',
          f"    return {E}(", '        id=row["id"],', '        name=row["name"],',
          '        created_at=datetime.fromisoformat(row["created_at"]),',
          '        updated_at=datetime.fromisoformat(row["updated_at"]) if row.get("updated_at") else None,',
          '        active=row.get("active", True),']
    if archived:
        if compat_bug:
            L.append('        archived_at=datetime.fromisoformat(row["archived_at"]) if row["archived_at"] else None,')
            marks["compat"] = len(L)
        else:
            L.append('        archived_at=datetime.fromisoformat(row["archived_at"]) if row.get("archived_at") else None,')
        L.append('        archived_by=row.get("archived_by"),')
    L += ["    )", "", "", f"class {E}Repository:",
          '    """In-memory store; production swaps in a database."""', "",
          "    def __init__(self) -> None:", "        self._rows: Dict[str, dict] = {}", "",
          f"    def save(self, item: {E}) -> None:", '        """Insert or replace."""',
          "        self._rows[item.id] = to_row(item)", "",
          f"    def get(self, item_id: str) -> Optional[{E}]:",
          '        """Return the record, or None when unknown."""',
          "        row = self._rows.get(item_id)", "        return from_row(row) if row else None", "",
          f"    def list_all(self) -> List[{E}]:", '        """Every record, insertion order."""',
          "        return [from_row(r) for r in self._rows.values()]", "",
          "    def delete(self, item_id: str) -> bool:", '        """Remove; False when absent."""',
          "        return self._rows.pop(item_id, None) is not None"]
    return L, marks


def service(e, archived, defect=None):
    E = camel(e)
    marks = {}
    L = [f'"""{E} use cases."""', "from datetime import datetime", "from typing import List", ""]
    if archived:
        L.append("from warehouse import audit")
    doc = f'    """Create, rename, deactivate and archive {e} records."""' if archived \
        else f'    """Create, rename and deactivate {e} records."""'
    L += [f"from .models import {E}", f"from .repository import {E}Repository", "", "",
          f"class {E}Error(Exception):", '    """Raised when a use case cannot proceed."""', "", "",
          f"class {E}Service:", doc, "", f"    def __init__(self, repo: {E}Repository) -> None:",
          "        self._repo = repo", "",
          f"    def create(self, item_id: str, name: str, now: datetime) -> {E}:",
          '        """Create an active record; blank names are rejected."""',
          "        if not name.strip():", f'            raise {E}Error("name is required")',
          f"        item = {E}(id=item_id, name=name.strip(), created_at=now)",
          "        self._repo.save(item)", "        return item", "",
          f"    def rename(self, item_id: str, name: str, now: datetime) -> {E}:",
          '        """Rename an existing record."""', "        item = self._require(item_id)",
          "        if not name.strip():", f'            raise {E}Error("name is required")',
          "        item.name = name.strip()", "        item.updated_at = now",
          "        self._repo.save(item)", "        return item", "",
          f"    def deactivate(self, item_id: str, now: datetime) -> {E}:",
          '        """Hide a record from active listings without deleting it."""',
          "        item = self._require(item_id)", "        item.active = False",
          "        item.updated_at = now", "        self._repo.save(item)", "        return item", "",
          f"    def list_active(self) -> List[{E}]:", '        """Active records only."""']
    if archived:
        L.append("        return [i for i in self._repo.list_all() if i.active and i.archived_at is None]")
    else:
        L.append("        return [i for i in self._repo.list_all() if i.active]")
    if archived:
        L += ["", f"    def archive(self, item_id: str, actor: str, now: datetime) -> {E}:",
              '        """Archive for actor: blank actors and archiving twice are rejected."""']
        if defect == "actor_check":
            marks["actor_check"] = len(L) - 1
        else:
            L += ["        if not actor.strip():", f'            raise {E}Error("actor is required")']
        if defect == "none_handling":
            L.append("        item = self._repo.get(item_id)")
            marks["none_handling"] = f"{len(L)}-{len(L) + 1}"
        else:
            L.append("        item = self._require(item_id)")
        if defect == "inverted":
            L.append("        if item.archived_at is None:")
            marks["inverted"] = len(L)
        else:
            L.append("        if item.archived_at is not None:")
        L.append(f'            raise {E}Error(f"{{item_id}} is already archived")')
        if defect == "swapped":
            L.append("        item.archived_at = actor")
            L.append("        item.archived_by = now")
            marks["swapped"] = f"{len(L) - 1}-{len(L)}"
        else:
            L += ["        item.archived_at = now", "        item.archived_by = actor"]
        L.append("        item.active = False")
        if defect == "swallowed":
            L += ["        try:", "            self._repo.save(item)", "        except Exception:", "            pass"]
            marks["swallowed"] = f"{len(L) - 3}-{len(L)}"
        else:
            L.append("        self._repo.save(item)")
        if defect == "leftover":
            L.append(f'        print(f"DEBUG archive {{item_id}} by {{actor}}")')
            marks["leftover"] = len(L)
        L += [f'        audit.record("{e}.archive", item_id, actor, now)', "        return item", "",
              f"    def restore(self, item_id: str, actor: str, now: datetime) -> {E}:",
              '        """Undo an archive; restoring an active record is a no-op."""',
              "        item = self._require(item_id)", "        if item.archived_at is None:"]
        L.append("            return item")
        marks["restore_noop"] = len(L)
        L += ["        item.archived_at = None", "        item.archived_by = None",
              "        item.active = True", "        item.updated_at = now",
              "        self._repo.save(item)",
              f'        audit.record("{e}.restore", item_id, actor, now)', "        return item", "",
              f"    def list_archived(self) -> List[{E}]:",
              '        """Archived records, oldest archive first."""', "        rows = sorted(",
              "            (i for i in self._repo.list_all() if i.archived_at is not None),",
              "            key=lambda i: i.archived_at,"]
        marks["sort_trap"] = len(L)
        L.append("        )")
        if defect == "off_by_one":
            L += ["        result = []", "        for index in range(len(rows) - 1):"]
            marks["off_by_one"] = len(L)
            L += ["            result.append(rows[index])", "        return result"]
        else:
            L.append("        return rows")
    L += ["", f"    def _require(self, item_id: str) -> {E}:", "        item = self._repo.get(item_id)",
          "        if item is None:", f'            raise {E}Error(f"unknown {e} {{item_id}}")',
          "        return item"]
    return L, marks


def tests(e, archived, tautology=False):
    E = camel(e)
    marks = {}
    L = ["from datetime import datetime", "", "import pytest", "",
         f"from warehouse.{e}.repository import {E}Repository",
         f"from warehouse.{e}.service import {E}Error, {E}Service", "",
         "NOW = datetime(2026, 1, 1, 12, 0)", "", "", "def service():",
         f"    return {E}Service({E}Repository())", "", "", "def test_create_rejects_blank_name():",
         f"    with pytest.raises({E}Error):", '        service().create("x", "   ", NOW)', "", "",
         "def test_rename_updates_name_and_timestamp():", "    svc = service()",
         '    svc.create("x", "first", NOW)', '    item = svc.rename("x", "second", NOW)',
         '    assert (item.name, item.updated_at) == ("second", NOW)', "", "",
         "def test_deactivate_hides_from_active_list():", "    svc = service()",
         '    svc.create("x", "first", NOW)', '    svc.deactivate("x", NOW)',
         "    assert svc.list_active() == []"]
    if archived:
        L += ["", "", "def test_archive_stamps_actor_and_time():", "    svc = service()",
              '    svc.create("x", "first", NOW)']
        if tautology:
            L.append('    assert svc.archive("x", "ann", NOW) or True')
            marks["tautology"] = len(L)
        else:
            L += ['    item = svc.archive("x", "ann", NOW)',
                  '    assert (item.archived_at, item.archived_by, item.active) == (NOW, "ann", False)']
        L += ["", "", "def test_archive_twice_is_rejected():", "    svc = service()",
              '    svc.create("x", "first", NOW)', '    svc.archive("x", "ann", NOW)',
              f"    with pytest.raises({E}Error):", '        svc.archive("x", "bob", NOW)', "", "",
              "def test_restore_reactivates():", "    svc = service()",
              '    svc.create("x", "first", NOW)', '    svc.archive("x", "ann", NOW)',
              '    item = svc.restore("x", "ann", NOW)',
              "    assert item.active and item.archived_at is None",
              "    assert svc.list_archived() == []"]
    return L, marks


def audit_module():
    L = ['"""Append-only audit trail for archive and restore events."""',
         "from datetime import datetime", "from typing import List, NamedTuple", "", "",
         "class AuditEvent(NamedTuple):", "    action: str", "    subject_id: str", "    actor: str",
         "    at: datetime", "", "", "_EVENTS: List[AuditEvent] = []", "", "",
         "def record(action: str, subject_id: str, actor: str, at: datetime) -> AuditEvent:",
         '    """Append an event and return it."""',
         "    event = AuditEvent(action, subject_id, actor, at)", "    _EVENTS.append(event)",
         "    return event", "", ""]
    L.append("def events(subject_id: str | None = None) -> List[AuditEvent]:")
    trap_line = len(L)
    L += ['    """Events in order, optionally for one subject."""', "    if subject_id is None:",
          "        return list(_EVENTS)", "    return [e for e in _EVENTS if e.subject_id == subject_id]"]
    return L, trap_line


def lockfile(rng, bumped):
    packages = {}
    for i in range(600):
        name = f"pkg-{i:03d}"
        minor = 7 if i in bumped else 6
        version = f"1.{minor}.{i % 5}"
        digest = hashlib.sha512(f"{name}{version}{rng.random()}".encode()).hexdigest()[:88]
        packages[f"node_modules/{name}"] = {
            "version": version,
            "resolved": f"https://registry.example/{name}/-/{name}-{version}.tgz",
            "integrity": f"sha512-{digest}",
            "license": "MIT",
        }
    doc = {"name": "warehouse-ui", "version": "2.4.0", "lockfileVersion": 3, "packages": packages}
    return json.dumps(doc, indent=2).splitlines()


def bundle(entities, archived):
    verbs = ["create", "rename", "deactivate"] + (["archive", "restore"] if archived else [])
    body = "".join(f"e.{camel(x)}={{{','.join(f'{v}:function(a,b){{return s.{v}(\"{x}\",a,b)}}' for v in verbs)}}};"
                   for x in entities)
    return [f"!function(e,s){{{body}}}(window.warehouse={{}},window.warehouseClient);"]


def snapshot(e):
    return [f"# {camel(e)}Service.archive", "{", f'  "id": "x",', '  "name": "first",',
            '  "created_at": "2026-01-01T12:00:00",', '  "updated_at": null,', '  "active": false,',
            '  "archived_at": "2026-01-01T12:00:00",', '  "archived_by": "ann"', "}"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dest")
    ap.add_argument("--modules", type=int, default=40)
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()
    n = args.modules
    if not 12 <= n <= len(ENTITIES):
        sys.exit(f"--modules must be between 12 and {len(ENTITIES)} (10 defect entities plus 2 clean ones for traps)")
    if os.path.exists(args.dest):
        sys.exit(f"{args.dest} exists")
    rng = random.Random(args.seed)
    entities = ENTITIES[:n]
    base, change = Tree(os.path.join(args.dest, "base")), Tree(os.path.join(args.dest, "change"))
    step = n // len(DEFECTS)
    defect_of = {entities[(k * step + 1) % n]: kind for k, kind in enumerate(DEFECTS)}
    defects, traps = [], []

    for e in entities:
        kind = defect_of.get(e)
        base.write(f"warehouse/{e}/__init__.py", [f'"""{camel(e)} module."""'])
        base.write(f"warehouse/{e}/models.py", models(e, False))
        base.write(f"warehouse/{e}/repository.py", repository(e, False)[0])
        base.write(f"warehouse/{e}/service.py", service(e, False)[0])
        base.write(f"tests/test_{e}_service.py", tests(e, False)[0])

        change.write(f"warehouse/{e}/models.py", models(e, True))
        if kind == "omission":
            _, marks = repository(e, False)
            defects.append(("omission", f"warehouse/{e}/repository.py:{marks['to_row']}|warehouse/{e}/repository.py:{marks['from_row']}"))
        else:
            lines, marks = repository(e, True, compat_bug=(kind == "compat"))
            change.write(f"warehouse/{e}/repository.py", lines)
            if kind == "compat":
                defects.append(("compat", f"warehouse/{e}/repository.py:{marks['compat']}"))
        svc_defect = kind if kind in ("off_by_one", "none_handling", "inverted", "swallowed", "swapped", "leftover", "actor_check") else None
        lines, marks = service(e, True, svc_defect)
        change.write(f"warehouse/{e}/service.py", lines)
        if svc_defect:
            defects.append((svc_defect, f"warehouse/{e}/service.py:{marks[svc_defect]}"))
        lines, marks = tests(e, True, tautology=(kind == "tautology"))
        change.write(f"tests/test_{e}_service.py", lines)
        if kind == "tautology":
            defects.append(("tautology", f"tests/test_{e}_service.py:{marks['tautology']}"))
        change.write(f"tests/__snapshots__/test_{e}_service.snap", snapshot(e))

    # traps: correct code that looks suspicious, in defect-free entities
    clean = [e for e in entities if e not in defect_of]
    _, marks = service(clean[0], True)
    traps.append((f"warehouse/{clean[0]}/service.py:{marks['sort_trap']}",
                  "sorting by archived_at is safe: the generator filters archived_at is not None one line up"))
    _, marks = service(clean[1], True)
    traps.append((f"warehouse/{clean[1]}/service.py:{marks['restore_noop']}",
                  "restore() returning the live record unchanged is the documented no-op, not a missed save"))
    audit_lines, audit_trap = audit_module()
    change.write("warehouse/audit.py", audit_lines)
    traps.append((f"warehouse/audit.py:{audit_trap}", "str | None is valid syntax on the project's Python; not a type error"))

    base.write("warehouse/__init__.py", ['"""Warehouse domain package."""'])
    base.write("warehouse/log.py", ['"""Logger shim so library code never prints."""', "import sys", "", "",
                                     "def info(msg: str) -> None:", '    """Write an info line to stderr."""',
                                     '    sys.stderr.write(f"INFO {msg}\\n")'])
    base.write(".gitignore", [".agents/", ".claude/", "__pycache__/"])
    base.write("AGENTS.md", [
        "# Warehouse — agent guide", "",
        "- Library code never calls `print()`; use `warehouse.log` or the audit trail.",
        "- Every public function in `warehouse/` has a one-line docstring.",
        "- Repository methods never raise on a missing record: they return `None` or `False`.",
        "- Persistence stays backward compatible: `from_row` reads new fields with `row.get`.",
        "- Tests live in `tests/`, one `test_<entity>_service.py` per entity; every new public",
        "  behaviour gets a test that fails when the behaviour breaks.",
        "- `README.md` documents every user-facing rule; update it in the same change.",
    ])
    readme = ["# Warehouse", "", "Domain services behind the warehouse console.", "",
              "- Every entity can be created, renamed and deactivated.",
              "- `list_active` hides deactivated records."]
    base.write("README.md", readme)
    change.write("README.md", readme + [
        "- Archiving: `archive(id, actor, now)` needs a non-blank actor, rejects a second archive,",
        "  stamps `archived_at`/`archived_by`, deactivates the record and writes an audit event;",
        "  `restore` undoes it. `list_active` excludes archived records; `list_archived` lists them",
        "  oldest first."])
    bumped = set(range(0, 600, 10))
    base.write("package-lock.json", lockfile(random.Random(args.seed), set()))
    change.write("package-lock.json", lockfile(random.Random(args.seed), bumped))
    base.write("dist/warehouse.min.js", bundle(entities, False))
    change.write("dist/warehouse.min.js", bundle(entities, True))

    with open(os.path.join(args.dest, "intent.txt"), "w") as f:
        f.write("Add soft-archive with an audit trail to every warehouse entity: archive(id, actor, now) "
                "requires a non-blank actor, rejects archiving twice, stamps archived_at and archived_by, "
                "deactivates the record and records an audit event; restore undoes it; list_active "
                "excludes archived records and list_archived lists them oldest first. Persistence must "
                "round-trip the new fields and keep loading rows dumped before this change.\n")
    with open(os.path.join(args.dest, "defects.tsv"), "w") as f:
        f.write("id\tsites\tkind\tblocking\tdescription\n")
        for i, (kind, sites) in enumerate(defects, 1):
            blocking, desc = DEFECTS[kind]
            f.write(f"D{i}\t{sites}\t{kind}\t{blocking}\t{desc}\n")
        f.write(f"D{len(defects) + 1}\tpackage-lock.json:*\tmechanical_mismatch\tno\t"
                f"{len(bumped)} packages bumped in package-lock.json with no package.json in the repo; the change is unrelated to the PR\n")
    with open(os.path.join(args.dest, "traps.tsv"), "w") as f:
        f.write("id\tsites\tdescription\n")
        for i, (sites, desc) in enumerate(traps, 1):
            f.write(f"T{i}\t{sites}\t{desc}\n")
    print(f"generated {args.dest}: {n} entities, {len(defects) + 1} defects, {len(traps)} traps")


if __name__ == "__main__":
    main()
