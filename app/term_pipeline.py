"""Deterministic observation-first terminology pipeline, with local evidence only."""
from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re

from term_hygiene import is_standalone_placeholder, term_keys
from term_recovery import key

from project_paths import ROOT, SQL
TABLES = ("term_saved_sections", "term_reference_rows", "term_lookup_evaluations",
          "term_code_candidates", "term_review_decisions", "term_pipeline_migrations")
VERSION = "deterministic-2"
EDITIONS = ("ICD-O-3.2", "ICD-O-4")
LEGACY_MIGRATION = "entity_term_provenance-to-observations-v1"
MENTION_COLUMNS = {
    "observation_key": "TEXT", "source_locator": "TEXT", "term_origin": "TEXT",
    "context_class": "TEXT", "evidence_hash": "TEXT",
    "extraction_tier": "TEXT", "is_current": "INTEGER",
}


def stamp():
    return datetime.now(timezone.utc).isoformat()


def mapping_target(term, edition, code):
    return key("term-edition-code", term_keys(term)[1].casefold(), edition, code)


def global_extraction_target(term):
    return key("global-extraction", term_keys(term)[1].casefold())


def migrate(con):
    cols = {r[1] for r in con.execute("PRAGMA table_info(page_term_mentions)")}
    for name, typ in MENTION_COLUMNS.items():
        if name not in cols:
            con.execute(f"ALTER TABLE page_term_mentions ADD COLUMN {name} {typ}")
    con.commit()
    con.executescript((SQL / "schema_term_pipeline.sql").read_text(encoding="utf-8"))
    con.execute("CREATE UNIQUE INDEX IF NOT EXISTS ux_term_observation ON page_term_mentions(observation_key)")
    con.execute("CREATE INDEX IF NOT EXISTS ix_term_observation_page_norm ON page_term_mentions(page_id,TermNormUS)")
    # Old lexicon matches were code-first. They remain audit evidence, not the
    # discovery set, and cannot be confused with source-backed title observations.
    con.execute("UPDATE page_term_mentions SET observation_key='prior-mention-'||mention_id,"
                "source_locator='prior-mention-'||mention_id,term_origin='prior_lexicon',"
                "context_class='legacy',is_current=0 WHERE observation_key IS NULL")
    con.execute("UPDATE page_term_mentions SET extraction_method='legacy_import' "
                "WHERE term_origin='legacy_import' AND extraction_method<>'legacy_import'")
    con.execute("UPDATE term_lookup_evaluations SET is_current=0 "
                "WHERE matcher_version='legacy-import' AND is_current<>0")
    # Older SQLite builds created these tables before CHECK constraints were
    # added. These guards keep their constraints equivalent without rebuilding
    # history-bearing tables.
    guards = {
        "term_reference_rows": (
            "NEW.edition NOT IN ('ICD-O-3.2','ICD-O-4') OR NEW.reference_row<=0 "
            "OR length(NEW.reference_sha256)<>64",
        ),
        "term_lookup_evaluations": (
            "NEW.edition NOT IN ('ICD-O-3.2','ICD-O-4') OR NEW.reference_sha256 IS NULL "
            "OR length(NEW.reference_sha256)<>64 OR length(NEW.evidence_hash)<>64 "
            "OR NEW.outcome NOT IN ('matched','ambiguous','no_match','not_applicable',"
            "'needs_review','not_evaluated') OR NEW.is_current NOT IN (0,1)",
        ),
        "term_code_candidates": (
            "NEW.match_type NOT IN ('exact','synonym','normalized','broader','narrower',"
            "'conditional','legacy_curated') OR NEW.evidence_tier NOT IN "
            "('structured','supported_span','interpretation','curated_review') "
            "OR NEW.candidate_order<=0 OR NEW.review_status NOT IN "
            "('proposed','approved','rejected','needs_review')",
        ),
        "term_review_decisions": (
            "NEW.scope NOT IN ('observation','page_context','candidate','term_edition_code',"
            "'global_extraction') OR NEW.outcome NOT IN "
            "('approved','rejected','needs_review','proposed') OR length(NEW.evidence_hash)<>64",
        ),
        "term_pipeline_migrations": ("NEW.imported_rows<0",),
    }
    for table, (condition,) in guards.items():
        for operation in ("INSERT", "UPDATE"):
            trigger = f"tr_{table}_check_{operation.lower()}"
            con.execute(f"DROP TRIGGER IF EXISTS {trigger}")
            con.execute(
                f"CREATE TRIGGER {trigger} BEFORE {operation} ON {table} "
                f"WHEN {condition} BEGIN SELECT RAISE(ABORT,'Invalid {table} value'); END"
            )


def read_references():
    """Actual official workbook row identities, never compilation crosswalks."""
    import openpyxl
    inputs = (
        (EDITIONS[0], ROOT.parent / "CancerPathCHART" / "ICDO" / "ICD-O-3.2"
         / "ICD-O-3.2_final_update09102020.xlsx", "ICD-O-3.2 Morphology"),
        (EDITIONS[1], ROOT.parent / "BBNotebook" / "Library" / "CPC_ICDO4"
         / "Updates_2026_09" / "ICD-O-4.xlsx", "Morphology"),
    )
    rows, hashes = [], {}
    for edition, path, sheet in inputs:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        hashes[str(path)] = digest
        wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
        try:
            for number, row in enumerate(wb[sheet].iter_rows(min_row=3, values_only=True), 3):
                code, level, term = row[:3]
                pattern = r"\d{4}/[013269]" if edition == EDITIONS[0] else r"\d{4}[0-9A-Z]/[013269]"
                if not term or not re.fullmatch(pattern, str(code or "").strip()):
                    continue
                us, norm = term_keys(str(term))
                if not us or not norm or is_standalone_placeholder(us):
                    continue
                conditions = str(row[4]) if len(row) > 4 and row[4] else None
                rows.append((key(edition, digest, sheet, number), edition, str(path),
                             digest, sheet, number, str(code).strip(), str(term),
                             us, norm, str(level or ""), conditions))
        finally:
            wb.close()
    if not all(any(r[1] == edition for r in rows) for edition in EDITIONS):
        raise ValueError("Both official morphology references must have usable rows")
    return rows, hashes


def context(text, start=0, end=None, heading=""):
    """Sentence-local scope; a reference relationship is not a page diagnosis."""
    end = len(text) if end is None else end
    left = max(text.rfind(".", 0, start), text.rfind("\n", 0, start)) + 1
    right = re.search(r"[.\n]", text[end:])
    sentence = text[left:end + right.start() if right else len(text)].strip()
    before = text[left:start].casefold()
    h = heading.casefold()
    if re.search(r"\b(?:no|not|without|absence of|negative for|exclude[ds]?)\b", before[-100:]):
        kind = "negated"
    elif "differential" in h or re.search(r"\b(?:differential|distinguish|versus|rule out)\b", sentence, re.I):
        kind = "differential"
    elif re.search(r"\b(?:historically|formerly|previously|obsolete)\b", sentence, re.I):
        kind = "historical"
    elif re.search(r"\b(?:incidental|incidentally)\b", sentence, re.I):
        kind = "incidental"
    else:
        kind = "affirmative"
    return kind, sentence


class PhraseIndex:
    """First-token index, longest non-overlapping boundary-aware official spans."""
    def __init__(self, references):
        self.first = defaultdict(list)
        labels = {label for r in references for label in (r[7], r[8])}
        labels.update(label.replace("tumor", "tumour") for label in tuple(labels))
        for label in sorted(labels, key=lambda s: (-len(s), s)):
            words = re.findall(r"\w+", label.casefold())
            if len(words) < 2 and len(label) < 7:
                continue
            pattern = re.compile(r"(?<!\w)" + re.escape(label).replace(r"\ ", r"\s+") + r"(?!\w)", re.I)
            if words:
                self.first[words[0]].append(pattern)

    def spans(self, text):
        matches = []
        for token in re.finditer(r"\b\w+\b", text):
            for pattern in self.first.get(token.group().casefold(), ()):
                match = pattern.match(text, token.start())
                if match:
                    matches.append((match.start(), match.end(), match.group()))
        cursor = 0
        for start, end, label in sorted(set(matches), key=lambda m: (m[0], -(m[1]-m[0]), m[2])):
            if start >= cursor:
                yield start, end, label
                cursor = end


def observe(con, page, term, source, locator, *, heading="", snippet=None,
            context_class="affirmative", role="mention", code=None, origin="source",
            tier="structured"):
    if is_standalone_placeholder(term):
        return None
    us, norm = term_keys(term)
    if not us or not norm:
        return None
    observation = key(page, source, locator, us.casefold())
    evidence = key(term, snippet, heading, context_class, code)
    values = {
        "page_id": page, "url": con.execute("SELECT url FROM pages WHERE page_id=?", (page,)).fetchone()[0],
        "icdo_code": code, "term_original": term, "term_original_norm": norm,
        "term_text": term, "term_clean": norm, "TermUS": us, "TermNormUS": norm,
        "term_source": source, "source_kind": source, "source_heading": heading,
        "section_flag": context_class, "section_location": heading or locator,
        "source_locator": locator, "observation_key": observation,
        "term_origin": origin, "context_class": context_class, "evidence_hash": evidence,
        "extraction_tier": tier, "extraction_method": (
            "legacy_import" if origin == "legacy_import" else
            "lexicon_match" if tier == "supported_span" else "html_parse"),
        "term_role": role, "code_origin": "printed_with_term" if code else "none",
        "evidence_policy": context_class, "is_positive_evidence": int(context_class == "affirmative"),
        "confidence_score": 1.0 if tier == "structured" else 0.9,
        "snippet": snippet or term, "review_status": "accepted", "reviewed_by": "rule",
        "is_current": 1,
    }
    values["review_status"] = review_status(con, "", observation, evidence, "accepted")
    global_decision = con.execute(
        "SELECT outcome FROM term_review_decisions WHERE target_key=? "
        "AND scope='global_extraction' ORDER BY decision_id DESC LIMIT 1",
        (global_extraction_target(us),)).fetchone()
    if global_decision:
        values["review_status"] = global_decision[0]
    old = con.execute("SELECT mention_id FROM page_term_mentions WHERE observation_key=?", (observation,)).fetchone()
    names = list(values)
    if old:
        con.execute("UPDATE page_term_mentions SET " + ",".join(f"{c}=?" for c in names) +
                    " WHERE mention_id=?", (*values.values(), old[0]))
        return old[0]
    return con.execute("INSERT INTO page_term_mentions(" + ",".join(names) + ") VALUES(" +
                       ",".join("?" for _ in names) + ")", tuple(values.values())).lastrowid


def decide(con, target, scope, outcome, reason, evidence_hash, reviewer="human", when=None):
    if scope not in {"observation", "page_context", "candidate", "term_edition_code", "global_extraction"}:
        raise ValueError("Unsupported decision scope")
    if outcome not in {"approved", "rejected", "needs_review", "proposed"}:
        raise ValueError("Unsupported review outcome")
    when = when or stamp()
    decision = key(target, scope, outcome, reason, evidence_hash, reviewer, when)
    con.execute("INSERT OR IGNORE INTO term_review_decisions "
                "(decision_key,target_key,scope,outcome,reason,evidence_hash,reviewer,decided_at)"
                " VALUES(?,?,?,?,?,?,?,?)",
                (decision, target, scope, outcome, reason, evidence_hash, reviewer, when))
    if scope in {"candidate", "term_edition_code"}:
        con.execute("UPDATE term_code_candidates SET review_status=? WHERE candidate_key=?",
                    (outcome, target))
    elif scope in {"observation", "page_context"}:
        con.execute("UPDATE page_term_mentions SET review_status=? WHERE observation_key=?",
                    (outcome, target))
    return decision


def review_status(con, candidate, observation, evidence, default):
    decision = con.execute(
        "SELECT outcome,evidence_hash FROM term_review_decisions "
        "WHERE (target_key=? AND scope IN ('candidate','term_edition_code')) "
        "OR (target_key=? AND scope IN ('observation','page_context')) "
        "ORDER BY decision_id DESC LIMIT 1", (candidate, observation)).fetchone()
    if not decision:
        return default
    return decision[0] if decision[1] == evidence else "needs_review"


def cleanup(con):
    removed = {}
    for table, ident, column, provenance_column in (
        ("entity_codes", "entity_code_id", "term", "entity_code_id"),
        ("entity_related_terms", "related_term_id", "term", "related_term_id"),
    ):
        invalid = [r[0] for r in con.execute(f"SELECT {ident},{column} FROM {table}")
                   if is_standalone_placeholder(r[1])]
        for row_id in invalid:
            provenance = con.execute(
                f"SELECT provenance_id FROM entity_term_provenance WHERE {provenance_column}=?",
                (row_id,),
            ).fetchall()
            for (provenance_id,) in provenance:
                con.execute("DELETE FROM entity_term_code_matches WHERE provenance_id=?",
                            (provenance_id,))
                con.execute("DELETE FROM entity_term_provenance WHERE provenance_id=?",
                            (provenance_id,))
            con.execute(f"DELETE FROM {table} WHERE {ident}=?", (row_id,))
        removed[table] = len(invalid)
    invalid = [r[0] for r in con.execute(
        "SELECT code_id,term_in_coding_section FROM page_icdo_codes "
        "WHERE term_in_coding_section IS NOT NULL") if is_standalone_placeholder(r[1])]
    for row_id in invalid:
        con.execute("DELETE FROM page_icdo_codes WHERE code_id=?", (row_id,))
    removed["page_icdo_codes"] = len(invalid)

    invalid = [r[0] for r in con.execute(
        "SELECT provenance_id,recovered_term FROM entity_term_provenance")
        if is_standalone_placeholder(r[1])]
    for provenance_id in invalid:
        con.execute("DELETE FROM entity_term_code_matches WHERE provenance_id=?",
                    (provenance_id,))
        con.execute("DELETE FROM entity_term_provenance WHERE provenance_id=?",
                    (provenance_id,))
    removed["entity_term_provenance"] = len(invalid)
    invalid = [r[0] for r in con.execute(
        "SELECT match_id,official_term FROM entity_term_code_matches")
        if is_standalone_placeholder(r[1])]
    for match_id in invalid:
        con.execute("DELETE FROM entity_term_code_matches WHERE match_id=?", (match_id,))
    removed["entity_term_code_matches"] = len(invalid)
    invalid = [r[0] for r in con.execute(
        "SELECT reference_key,official_term FROM term_reference_rows")
        if is_standalone_placeholder(r[1])]
    for reference_key in invalid:
        con.execute("DELETE FROM term_reference_rows WHERE reference_key=?", (reference_key,))
    removed["term_reference_rows"] = len(invalid)
    invalid = [r[0] for r in con.execute(
        "SELECT candidate_id,candidateTermUS FROM term_code_candidates")
        if is_standalone_placeholder(r[1])]
    for candidate_id in invalid:
        con.execute("DELETE FROM term_code_candidates WHERE candidate_id=?", (candidate_id,))
    removed["term_code_candidates"] = len(invalid)
    invalid = [r[0] for r in con.execute(
        "SELECT mention_id,term_original FROM page_term_mentions")
        if is_standalone_placeholder(r[1])]
    for mention_id in invalid:
        evaluation_ids = [r[0] for r in con.execute(
            "SELECT evaluation_id FROM term_lookup_evaluations WHERE mention_id=?",
            (mention_id,),
        )]
        for evaluation_id in evaluation_ids:
            con.execute("DELETE FROM term_code_candidates WHERE evaluation_id=?",
                        (evaluation_id,))
        con.execute("DELETE FROM term_lookup_evaluations WHERE mention_id=?", (mention_id,))
        con.execute("DELETE FROM page_term_mentions WHERE mention_id=?", (mention_id,))
    removed["page_term_mentions"] = len(invalid)
    invalid = [r[0] for r in con.execute(
        "SELECT evidence_id,term_clean FROM page_entity_evidence")
        if is_standalone_placeholder(r[1])]
    for evidence_id in invalid:
        con.execute("DELETE FROM page_entity_evidence WHERE evidence_id=?", (evidence_id,))
    removed["page_entity_evidence"] = len(invalid)
    return removed


def server_checks():
    """SQL Server equivalents of the generic-pipeline SQLite CHECK constraints."""
    return {
        "term_reference_rows": {
            "edition": "[edition] IN ('ICD-O-3.2','ICD-O-4')",
            "reference_row": "[reference_row]>0",
            "reference_sha256": "LEN([reference_sha256])=64",
        },
        "term_lookup_evaluations": {
            "edition": "[edition] IN ('ICD-O-3.2','ICD-O-4')",
            "outcome": "[outcome] IN ('matched','ambiguous','no_match','not_applicable','needs_review','not_evaluated')",
            "current": "[is_current] IN (0,1)",
            "hashes": "LEN([reference_sha256])=64 AND LEN([evidence_hash])=64",
        },
        "term_code_candidates": {
            "match_type": "[match_type] IN ('exact','synonym','normalized','broader','narrower','conditional','legacy_curated')",
            "evidence_tier": "[evidence_tier] IN ('structured','supported_span','interpretation','curated_review')",
            "candidate_order": "[candidate_order]>0",
            "review_status": "[review_status] IN ('proposed','approved','rejected','needs_review')",
        },
        "term_review_decisions": {
            "scope": "[scope] IN ('observation','page_context','candidate','term_edition_code','global_extraction')",
            "outcome": "[outcome] IN ('approved','rejected','needs_review','proposed')",
            "evidence_hash": "LEN([evidence_hash])=64",
        },
        "term_pipeline_migrations": {"imported_rows": "[imported_rows]>=0"},
    }


def import_legacy(con):
    """One-time adaptation of persisted curated evidence, not manifest replay."""
    if con.execute(
        "SELECT 1 FROM term_pipeline_migrations WHERE migration_key=?",
        (LEGACY_MIGRATION,),
    ).fetchone():
        return 0
    rows = con.execute("SELECT provenance_key,page_id,recovered_term,original_text,"
                       "suggested_qualifier,review_status,note,provenance_id,terminology_status "
                       "FROM entity_term_provenance ORDER BY provenance_id").fetchall()
    imported = 0
    for provenance, page, term, text, role, status, note, pid, currency in rows:
        if is_standalone_placeholder(term):
            continue
        locator = "curated:" + provenance
        obskey = key(page, "legacy_import", locator, term_keys(term)[0].casefold())
        if con.execute("SELECT 1 FROM page_term_mentions WHERE observation_key=?", (obskey,)).fetchone():
            continue
        mention = observe(con, page, term, "legacy_import", locator, snippet=text,
                          role=role, origin="legacy_import", tier="interpretation",
                          context_class="historical" if currency == "historical" else "affirmative")
        if mention is None:
            continue
        imported += 1
        evidence = con.execute("SELECT evidence_hash FROM page_term_mentions WHERE mention_id=?", (mention,)).fetchone()[0]
        if status != "proposed":
            decide(con, obskey, "observation", status, note or "Imported curated review",
                   evidence, "legacy")
        matches = con.execute(
            "SELECT match_key,edition,code,official_term,official_termUS,official_termNormUS,"
            "match_type,candidate_order,conditions,reference_file,reference_sha256,"
            "reference_sheet,reference_row,code_term_evidence,review_status "
            "FROM entity_term_code_matches WHERE provenance_id=?", (pid,)).fetchall()
        for match in matches:
            mk, edition, code, label, us, norm, typ, order, cond, file, sha, sheet, row, support, review = match
            ek = key(obskey, edition, sha, "legacy-import", evidence)
            con.execute("INSERT OR IGNORE INTO term_lookup_evaluations "
                        "(evaluation_key,mention_id,edition,reference_sha256,matcher_version,"
                        "evidence_hash,outcome,detail,evaluated_at,is_current) VALUES(?,?,?,?,?,?,?,?,?,0)",
                        (ek, mention, edition, sha, "legacy-import", evidence, "needs_review",
                         "Preserved curated mapping; not automatically discovered", stamp()))
            eid = con.execute("SELECT evaluation_id FROM term_lookup_evaluations WHERE evaluation_key=?", (ek,)).fetchone()[0]
            ck = key(obskey, edition, code, (us or label).casefold())
            refs = json.dumps({"file": file, "sha256": sha, "sheet": sheet,
                               "row": row, "support": json.loads(support)})
            con.execute("INSERT OR IGNORE INTO term_code_candidates "
                        "(candidate_key,evaluation_id,code,official_term,candidateTermUS,candidateTermNormUS,"
                        "match_type,evidence_tier,candidate_order,conditions,reference_evidence,review_status,legacy_match_key)"
                        " VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
                        (ck, eid, code, label, us or term_keys(label)[0], norm or term_keys(label)[1],
                         typ, "curated_review", order, cond, refs, review, mk))
            if review != "proposed":
                decide(con, ck, "candidate", review, cond or "Imported mapping review",
                       evidence, "legacy")
    con.execute(
        "INSERT INTO term_pipeline_migrations(migration_key,applied_at,imported_rows) "
        "VALUES(?,?,?)",
        (LEGACY_MIGRATION, stamp(), imported),
    )
    return imported


def extract(con, references):
    con.execute("UPDATE page_term_mentions SET is_current=0 WHERE term_origin='source'")
    for page, title in con.execute("SELECT page_id,title FROM entity_pages ORDER BY page_id").fetchall():
        observe(con, page, title, "page_title", "title", role="entity_name")
    for table, pk, source in (("entity_codes", "entity_code_id", "coding_section"),
                               ("entity_related_terms", "related_term_id", "related_terminology")):
        fields = "code,is_subtype" if table == "entity_codes" else "NULL,0"
        for page, term, code, subtype, role in con.execute(
            f"SELECT page_id,term,{fields},term_role FROM {table} WHERE NOT EXISTS "
            "(SELECT 1 FROM entity_term_provenance p WHERE p.is_added_term=1 AND p." +
            ("entity_code_id" if table == "entity_codes" else "related_term_id") + f"={table}.{pk})").fetchall():
            observe(con, page, term, source, key(term, code, subtype), role=role or "mention",
                    code=code or None, heading="Subtype(s)" if subtype else source)
    for page, term, code, heading, role in con.execute(
        "SELECT page_id,term_in_coding_section,icdo_code_raw,section_heading,term_role "
        "FROM page_icdo_codes WHERE term_in_coding_section IS NOT NULL").fetchall():
        observe(con, page, term, "coding_page", key(term, code, heading),
                code=code, role=role or "mention", heading=heading or "")
    phrases = PhraseIndex(references)
    for page, heading, text, anchor, ordinal in con.execute(
        "SELECT s.page_id,s.heading,s.body_text,s.source_anchor,s.ord FROM sections s "
        "JOIN entity_pages e ON e.page_id=s.page_id ORDER BY s.page_id,s.ord,s.section_id").fetchall():
        text = text or ""
        for start, end, term in phrases.spans(text):
            kind, sentence = context(text, start, end, heading or "")
            observe(con, page, term, "section_body", key(anchor, heading, ordinal, start, end),
                    heading=heading or "", snippet=sentence, context_class=kind,
                    tier="supported_span")


def evaluate(con, references):
    # Older in-flight candidate rows may have values that no longer satisfy the
    # current CHECK semantics. Remove them before upserting, otherwise the
    # conflict UPDATE path will fire validation triggers on stale rows.
    con.execute(
        "DELETE FROM term_code_candidates WHERE "
        "match_type NOT IN ('exact','synonym','normalized','broader','narrower','conditional','legacy_curated') "
        "OR evidence_tier NOT IN ('structured','supported_span','interpretation','curated_review') "
        "OR candidate_order<=0 "
        "OR review_status NOT IN ('proposed','approved','rejected','needs_review')"
    )
    con.execute(
        "DELETE FROM term_lookup_evaluations WHERE evaluation_id NOT IN "
        "(SELECT DISTINCT evaluation_id FROM term_code_candidates) "
        "AND matcher_version<>'legacy-import'"
    )
    lexicon = defaultdict(list)
    revision = {}
    phrases = PhraseIndex(references)
    for row in references:
        lexicon[row[1], row[9].casefold()].append(row)
        revision[row[1]] = row[3]
    con.execute("UPDATE term_lookup_evaluations SET is_current=0 WHERE matcher_version<>'legacy-import'")
    for mention, observation, us, norm, evidence, ctx, tier in con.execute(
        "SELECT mention_id,observation_key,TermUS,TermNormUS,evidence_hash,context_class,"
        "extraction_tier FROM page_term_mentions WHERE is_current=1").fetchall():
        for edition in EDITIONS:
            sha = revision[edition]
            ek = key(observation, edition, sha, VERSION, evidence)
            refs = lexicon.get((edition, norm.casefold()), [])
            broader = False
            if not refs and tier == "structured":
                parents = {
                    term_keys(label)[1].casefold()
                    for _, _, label in phrases.spans(us)
                    if len(label.split()) >= 2 and label.casefold() != us.casefold()
                }
                refs = [r for parent in sorted(parents) for r in lexicon.get((edition, parent), [])]
                broader = bool(refs)
            codes = {r[6] for r in refs}
            outcome = "ambiguous" if len(codes) > 1 else "matched" if refs else "no_match"
            if not refs and re.search(r"\bsyndrome\b", us, re.I):
                outcome = "not_applicable"
            if ctx != "affirmative" and refs:
                outcome = "needs_review"
            if broader:
                outcome = "needs_review"
            detail = json.dumps({"context": ctx, "extraction_tier": tier,
                                 "reason": "official_normalized_lookup" if refs else "no_official_label",
                                 "coverage": "known official phrases only; unknown prose not inferred"})
            con.execute("INSERT INTO term_lookup_evaluations "
                        "(evaluation_key,mention_id,edition,reference_sha256,matcher_version,evidence_hash,"
                        "outcome,detail,evaluated_at,is_current) VALUES(?,?,?,?,?,?,?,?,?,1) "
                        "ON CONFLICT(evaluation_key) DO UPDATE SET is_current=1",
                        (ek, mention, edition, sha, VERSION, evidence, outcome, detail, stamp()))
            eid = con.execute("SELECT evaluation_id FROM term_lookup_evaluations WHERE evaluation_key=?", (ek,)).fetchone()[0]
            grouped = defaultdict(list)
            for r in refs:
                grouped[r[6], r[8]].append(r)
            for order, ((code, label), support) in enumerate(sorted(grouped.items()), 1):
                exact = us.casefold() == label.casefold()
                synonym = any("synonym" in r[10].casefold() for r in support)
                typ = "synonym" if exact and synonym else "exact" if exact else "normalized"
                reason = "official_synonym" if synonym and exact else "exact_official_label" if exact else "normalization_removed_qualifiers"
                if broader:
                    typ, reason = "broader", "contained_official_phrase_review_only"
                default = "proposed" if exact and outcome == "matched" and tier != "interpretation" else "needs_review"
                # Candidate identity includes the evidence revision: old candidates
                # and their decisions remain queryable when references change.
                ck = key(observation, edition, code, label.casefold(), sha, evidence, VERSION)
                status = review_status(con, ck, observation, evidence, default)
                mapping_decision = con.execute(
                    "SELECT outcome,evidence_hash FROM term_review_decisions WHERE target_key=? "
                    "AND scope='term_edition_code' ORDER BY decision_id DESC LIMIT 1",
                    (mapping_target(us, edition, code),)).fetchone()
                if mapping_decision:
                    status = mapping_decision[0] if mapping_decision[1] == sha else "needs_review"
                old = con.execute(
                    "SELECT d.outcome,e.reference_sha256,e.evidence_hash,c.conditions "
                    "FROM term_review_decisions d JOIN term_code_candidates c "
                    "ON c.candidate_key=d.target_key JOIN term_lookup_evaluations e "
                    "ON e.evaluation_id=c.evaluation_id WHERE e.mention_id=? AND e.edition=? "
                    "AND c.code=? AND c.candidateTermUS=? AND c.candidate_key<>? "
                    "ORDER BY d.decision_id DESC LIMIT 1", (mention, edition, code, label, ck)).fetchone()
                direct = con.execute("SELECT 1 FROM term_review_decisions WHERE target_key=?", (ck,)).fetchone()
                same_prior_evidence = bool(old and old[1] == sha and old[2] == evidence)
                if old and not direct:
                    status = old[0] if same_prior_evidence else "needs_review"
                conditions = "; ".join(sorted({r[11] for r in support if r[11]})) or None
                if same_prior_evidence and old[3]:
                    conditions = "; ".join(filter(None, (conditions, old[3])))
                if broader:
                    conditions = "; ".join(filter(None, (conditions,
                        "Contained broader official label; page qualifiers are not established by this relationship.")))
                if conditions:
                    default = "needs_review"
                    if status == "proposed":
                        status = default
                con.execute("INSERT INTO term_code_candidates "
                            "(candidate_key,evaluation_id,code,official_term,candidateTermUS,candidateTermNormUS,"
                            "match_type,evidence_tier,candidate_order,conditions,reference_evidence,review_status)"
                            " VALUES(?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(candidate_key) DO UPDATE SET "
                            "evaluation_id=excluded.evaluation_id,review_status=excluded.review_status",
                            (ck, eid, code, support[0][7], label, support[0][9], typ,
                             tier, order, conditions, json.dumps([
                                 {"file": r[2], "sha256": r[3], "sheet": r[4], "row": r[5],
                                  "code": r[6], "term": r[7], "level": r[10]} for r in support]), status))


def site_hints(con):
    """Only a unique positive 3.2 relationship can supply site-specific hints."""
    con.execute("DELETE FROM page_site_hints WHERE provenance='term_site_match'")
    con.execute(
        "INSERT INTO page_site_hints(page_id,c_code,provenance,confidence_score) "
        "SELECT DISTINCT m.page_id,s.c_code,'term_site_match',0.9 "
        "FROM page_term_mentions m JOIN term_lookup_evaluations e ON e.mention_id=m.mention_id "
        "AND e.edition='ICD-O-3.2' AND e.is_current=1 AND e.outcome='matched' "
        "JOIN term_code_candidates c ON c.evaluation_id=e.evaluation_id "
        "JOIN icdo_site_specific_terms t ON t.icdo_code=c.code AND TermNormValue(t.icdo_term)=m.TermNormUS "
        "JOIN icdo_site_specific_term_sites s ON s.term_id=t.term_id "
        "WHERE m.is_current=1 AND m.is_positive_evidence=1 "
        "AND m.extraction_tier IN ('structured','supported_span') AND m.review_status<>'rejected' "
        "AND c.review_status IN ('proposed','approved') AND c.conditions IS NULL "
        "AND NOT EXISTS(SELECT 1 FROM term_code_candidates c2 WHERE c2.evaluation_id=e.evaluation_id AND c2.code<>c.code)")


def run(con, references):
    imported = import_legacy(con)
    cleanup_counts = cleanup(con)
    con.executemany("INSERT OR IGNORE INTO term_reference_rows VALUES(?,?,?,?,?,?,?,?,?,?,?,?)", references)
    extract(con, references)
    evaluate(con, references)
    site_hints(con)
    con.execute("DELETE FROM page_entity_evidence")
    con.execute(
        "INSERT INTO page_entity_evidence(page_id,icdo_code,term_clean,positive_mentions,"
        "excluded_mentions,source_kinds,has_code_on_page,site_hints,confidence_score) "
        "SELECT page_id,icdo_code,TermNormUS,SUM(is_positive_evidence),"
        "COUNT(*)-SUM(is_positive_evidence),GROUP_CONCAT(DISTINCT source_kind),"
        "CASE WHEN icdo_code IS NULL THEN 0 ELSE 1 END,NULL,"
        "SUM(is_positive_evidence)-0.5*(COUNT(*)-SUM(is_positive_evidence)) "
        "FROM page_term_mentions WHERE is_current=1 "
        "GROUP BY page_id,icdo_code,TermNormUS")
    return {"cleanup": cleanup_counts, "legacy_provenance_preserved": imported,
            "current_observations": con.execute("SELECT COUNT(*) FROM page_term_mentions WHERE is_current=1").fetchone()[0]}


def view_sql(sqlserver=False):
    import term_recovery
    prefix = "dbo." if sqlserver else ""
    create = "CREATE OR ALTER VIEW" if sqlserver else "CREATE VIEW"
    batch = "\nGO\n" if sqlserver else ";\n"
    exact = " COLLATE Latin1_General_100_BIN2" if sqlserver else " COLLATE BINARY"
    text_collate = " COLLATE Latin1_General_100_BIN2" if sqlserver else " COLLATE BINARY"
    site_aggregate = (
        "STRING_AGG(CAST(c_code AS NVARCHAR(MAX)),N'; ') WITHIN GROUP (ORDER BY c_code)"
        if sqlserver else "GROUP_CONCAT(c_code,'; ' ORDER BY c_code)"
    )
    float_cast = "CAST({} AS FLOAT)" if sqlserver else "CAST({} AS REAL)"
    site_min_expr = float_cast.format("sites.site_confidence_min")
    site_max_expr = float_cast.format("sites.site_confidence_max")
    json_value = "JSON_VALUE" if sqlserver else "json_extract"
    reference_file = (
        f"COALESCE({json_value}(c.reference_evidence,'$[0].file'),"
        f"{json_value}(c.reference_evidence,'$.file'),"
        f"{json_value}(c.reference_evidence,'$.support[0].file'))"
    )
    reference_sheet = (
        f"COALESCE({json_value}(c.reference_evidence,'$[0].sheet'),"
        f"{json_value}(c.reference_evidence,'$.sheet'),"
        f"{json_value}(c.reference_evidence,'$.support[0].sheet'))"
    )
    reference_row = (
        f"COALESCE({json_value}(c.reference_evidence,'$[0].row'),"
        f"{json_value}(c.reference_evidence,'$.row'),"
        f"{json_value}(c.reference_evidence,'$.support[0].row'))"
    )
    reference_row = f"TRY_CONVERT(INT,{reference_row})" if sqlserver else f"CAST({reference_row} AS INTEGER)"
    paired_text_fields = (
        "term_role", "term_source", "source_tables", "page_sections",
        "terminology_kind", "lookup_outcome", "match_type", "conditions",
        "review_status", "source_kind",
    )
    paired_int_fields = (
        "is_proposed_code", "is_proposed_term", "is_subtype", "has_source",
        "has_candidate", "has_source_observation", "has_legacy_observation",
    )
    paired_projection = ",\n ".join(
        f"CASE WHEN a.{field} IS NULL THEN z.{field} "
        f"WHEN z.{field} IS NULL OR a.{field}{exact}=z.{field}{exact} THEN a.{field} "
        f"WHEN a.{field}{exact}<z.{field}{exact} THEN "
        + (f"CONCAT(a.{field},N'; ',z.{field})" if sqlserver
           else f"a.{field}||'; '||z.{field}")
        + " ELSE "
        + (f"CONCAT(z.{field},N'; ',a.{field})" if sqlserver
           else f"z.{field}||'; '||a.{field}")
        + f" END AS {field}"
        for field in paired_text_fields
    )
    paired_projection += ",\n " + ",\n ".join(
        f"CASE WHEN COALESCE(a.{field},0)>COALESCE(z.{field},0) "
        f"THEN COALESCE(a.{field},0) ELSE COALESCE(z.{field},0) END AS {field}"
        for field in paired_int_fields
    )
    edition_fields = (
        "candidateTermUS", "is_proposed_code", "is_proposed_term",
        "lookup_outcome", "match_type", "conditions", "review_status",
    )
    edition_projection = ",\n ".join(
        f"{alias}.{field} AS {field}{suffix}"
        for suffix, alias in (("32", "a"), ("4", "z"))
        for field in edition_fields
    )
    edition_output = ",".join(
        f"g.{field}{suffix}" for suffix in ("32", "4") for field in edition_fields
    )
    pair_select = f"""SELECT KEY.page_id,KEY.TermUS,KEY.TermNormUS,
 a.code AS ICDO32,z.code AS ICDO4,
 COALESCE(z.candidateTermUS,a.candidateTermUS) AS candidateTermUS,
 {paired_projection},
 {edition_projection}"""
    # Source rows and candidate rows share a display grain. Multiple observations
    # do not multiply rows; evidence stays on the linked audit view.
    legacy = term_recovery.view_sql(sqlserver=sqlserver).split(batch)[:3]
    legacy_sql = batch.join(legacy)
    for name in ("v_entity_terms", "v_entity_term_provenance", "v_entity_term_code_matches"):
        legacy_sql = legacy_sql.replace(name, name.replace("v_", "v_legacy_", 1))
    return legacy_sql + batch + f"""{create} {prefix}v_entity_terms AS
SELECT * FROM {prefix}v_legacy_entity_terms
UNION ALL
SELECT 'page_term_mentions',m.mention_id,m.page_id,m.term_original,m.TermUS,m.TermNormUS,
 m.icdo_code,CASE WHEN m.term_role LIKE '%subtype%' THEN 1 ELSE 0 END,
 m.term_role,m.term_source FROM {prefix}page_term_mentions m WHERE m.is_current=1
 AND NOT EXISTS(SELECT 1 FROM {prefix}v_legacy_entity_terms t WHERE t.page_id=m.page_id AND t.TermUS{exact}=m.TermUS{exact})
{batch}
{create} {prefix}v_entity_term_provenance AS
SELECT m.page_id,m.mention_id AS term_id,m.term_original AS term,m.TermUS,m.TermNormUS,
 m.icdo_code AS source_code,m.observation_key,m.source_locator,m.term_origin AS source_kind,
 m.term_source,m.source_heading,m.snippet AS original_text,m.context_class,
 m.extraction_tier,m.review_status,m.is_current
FROM {prefix}page_term_mentions m
{batch}
{create} {prefix}v_entity_term_code_matches AS
SELECT 'page_term_mentions' AS term_table,m.mention_id AS term_id,m.page_id,
 m.term_original AS term,m.TermUS,m.TermNormUS,m.icdo_code AS source_code,
 CASE WHEN m.term_role LIKE '%subtype%' THEN 1 ELSE 0 END AS is_subtype,
 m.term_role,m.term_source AS terminology_kind,m.term_origin AS source_kind,
 m.term_role AS suggested_qualifier,CASE WHEN m.term_origin='legacy_import' THEN 1 ELSE 0 END AS is_added_term,
 CAST(NULL AS VARCHAR(60)) AS proposal_batch,c.candidate_id AS match_id,
 e.edition,c.code AS suggested_code,c.candidateTermUS AS official_term,
 c.candidateTermUS,c.candidateTermNormUS,c.official_term AS official_term_source,
 c.match_type,c.candidate_order,c.conditions,c.review_status,
 {reference_file} AS reference_file,{reference_sheet} AS reference_sheet,
 {reference_row} AS reference_row,e.reference_sha256,c.reference_evidence AS code_term_evidence,
 e.outcome,e.is_current,m.observation_key,c.candidate_key
FROM {prefix}page_term_mentions m
JOIN {prefix}term_lookup_evaluations e ON e.mention_id=m.mention_id
LEFT JOIN {prefix}term_code_candidates c ON c.evaluation_id=e.evaluation_id
{batch}
{create} {prefix}v_term_candidate_evidence AS
SELECT m.page_id,m.observation_key,m.source_locator,m.term_origin,m.term_source,
 m.context_class,m.extraction_tier,m.snippet,m.TermUS{exact} AS TermUS,m.TermNormUS,
 e.edition,e.outcome,e.reference_sha256,e.matcher_version,e.is_current,e.evidence_hash,e.detail,
 c.candidate_key,c.code,c.candidateTermUS,c.match_type,c.evidence_tier,
 c.conditions,c.reference_evidence,c.review_status
FROM {prefix}page_term_mentions m
JOIN {prefix}term_lookup_evaluations e ON e.mention_id=m.mention_id
LEFT JOIN {prefix}term_code_candidates c ON c.evaluation_id=e.evaluation_id
{batch}
{create} {prefix}v_page_code_terms AS
WITH evaluation_outcomes AS (
 SELECT m.page_id,m.TermUS{exact} AS TermUS,e.edition,
 MAX(e.outcome{text_collate}) AS outcome
 FROM {prefix}page_term_mentions m
 JOIN {prefix}term_lookup_evaluations e ON e.mention_id=m.mention_id AND e.is_current=1
 GROUP BY m.page_id,m.TermUS{exact},e.edition
),
candidate_keys AS (
 SELECT DISTINCT m.page_id,m.TermUS{exact} AS TermUS,c.code
 FROM {prefix}page_term_mentions m
 JOIN {prefix}term_lookup_evaluations e ON e.mention_id=m.mention_id AND e.is_current=1
 JOIN {prefix}term_code_candidates c ON c.evaluation_id=e.evaluation_id
 WHERE c.review_status<>'rejected'
),
source_keys AS (
 SELECT page_id,TermUS{exact} AS TermUS,code FROM {prefix}entity_codes
 UNION
 SELECT page_id,TermUS{exact},COALESCE(icdo_code_raw,icdo_code) FROM {prefix}page_icdo_codes
),
raw AS (
 SELECT c.page_id,c.TermUS{exact} AS TermUS,c.TermNormUS,
 CASE WHEN LENFN(c.code)=6 THEN 'ICD-O-3.2' ELSE 'ICD-O-4' END AS code_edition,
 c.code,NULL AS candidateTermUS,0 AS is_proposed_code,0 AS is_proposed_term,
 'source_assignment' AS code_kind,'source' AS source_kind,
 c.term_role,CAST(c.is_subtype AS INT) AS is_subtype,
 'coding_section' AS term_source,'entity_codes' AS source_tables,
 'ICD-O coding' AS page_sections,'coding' AS terminology_kind,
 COALESCE(o.outcome,'not_evaluated') AS lookup_outcome,
 NULL AS match_type,NULL AS conditions,NULL AS review_status
 FROM {prefix}entity_codes c
 LEFT JOIN evaluation_outcomes o ON o.page_id=c.page_id AND o.TermUS=c.TermUS{exact}
 AND o.edition=CASE WHEN LENFN(c.code)=6 THEN 'ICD-O-3.2' ELSE 'ICD-O-4' END
 LEFT JOIN candidate_keys k ON k.page_id=c.page_id AND k.TermUS=c.TermUS{exact} AND k.code=c.code
 WHERE c.code IS NOT NULL AND TRIM(c.code)<>'' AND k.code IS NULL
 UNION ALL
 SELECT p.page_id,p.TermUS,p.TermNormUS,
 CASE WHEN LENFN(COALESCE(p.icdo_code_raw,p.icdo_code))=6 THEN 'ICD-O-3.2' ELSE 'ICD-O-4' END,
 COALESCE(p.icdo_code_raw,p.icdo_code),NULL,0,0,'contextual_code','source',
 p.term_role,CASE WHEN p.term_role LIKE '%subtype%' THEN 1 ELSE 0 END,
 p.term_source,'page_icdo_codes',p.section_heading,'coding',
 COALESCE(o.outcome,'not_evaluated'),NULL,NULL,NULL
 FROM {prefix}page_icdo_codes p
 LEFT JOIN evaluation_outcomes o ON o.page_id=p.page_id AND o.TermUS=p.TermUS{exact}
 AND o.edition=CASE WHEN LENFN(COALESCE(p.icdo_code_raw,p.icdo_code))=6 THEN 'ICD-O-3.2' ELSE 'ICD-O-4' END
 LEFT JOIN candidate_keys k ON k.page_id=p.page_id AND k.TermUS=p.TermUS{exact}
 AND k.code=COALESCE(p.icdo_code_raw,p.icdo_code)
 WHERE COALESCE(p.icdo_code_raw,p.icdo_code) IS NOT NULL
 AND p.TermUS IS NOT NULL
 AND k.code IS NULL
 UNION ALL
 SELECT m.page_id,m.TermUS,m.TermNormUS,e.edition,c.code,c.candidateTermUS{exact},
 CASE WHEN c.code IS NOT NULL AND s.code IS NULL THEN 1 ELSE 0 END,
 CASE WHEN c.candidateTermUS IS NOT NULL AND c.candidateTermUS{exact}<>m.TermUS{exact} THEN 1 ELSE 0 END,
 CASE WHEN c.code IS NULL THEN 'uncoded_term' ELSE 'candidate' END,m.term_origin,
 m.term_role,CASE WHEN m.term_role LIKE '%subtype%' THEN 1 ELSE 0 END,
 m.term_source,'page_term_mentions',m.source_heading,
 CASE WHEN m.term_source='related_terminology' THEN
 CASE m.term_role WHEN 'synonym' THEN 'acceptable' WHEN 'not_recommended' THEN 'not_recommended' ELSE 'other' END
 WHEN m.term_source IN ('coding_section','coding_page') THEN 'coding'
 WHEN m.term_source='page_title' THEN 'title' ELSE 'contextual' END,
 e.outcome,c.match_type,c.conditions,c.review_status
 FROM {prefix}page_term_mentions m JOIN {prefix}term_lookup_evaluations e
 ON e.mention_id=m.mention_id AND e.is_current=1
 LEFT JOIN {prefix}term_code_candidates c ON c.evaluation_id=e.evaluation_id AND c.review_status<>'rejected'
 LEFT JOIN source_keys s ON s.page_id=m.page_id AND s.TermUS=m.TermUS{exact} AND s.code=c.code
 WHERE m.is_current=1 AND m.review_status<>'rejected'
),
grain AS (
 SELECT page_id,TermUS,TermNormUS,code_edition,code,candidateTermUS,
 MAX(is_proposed_code) AS is_proposed_code,MAX(is_proposed_term) AS is_proposed_term,
 MAX(term_role{text_collate}) AS term_role,MAX(is_subtype) AS is_subtype,
 MAX(term_source{text_collate}) AS term_source,MAX(source_tables{text_collate}) AS source_tables,
 MAX(page_sections{text_collate}) AS page_sections,MAX(terminology_kind{text_collate}) AS terminology_kind,
 MAX(lookup_outcome{text_collate}) AS lookup_outcome,MAX(match_type{text_collate}) AS match_type,
 MAX(conditions{text_collate}) AS conditions,MAX(review_status{text_collate}) AS review_status,
 MAX(CASE WHEN code_kind IN ('source_assignment','contextual_code')
 OR (code IS NOT NULL AND is_proposed_code=0) THEN 1 ELSE 0 END) AS has_source,
 MAX(CASE WHEN code_kind='candidate' THEN 1 ELSE 0 END) AS has_candidate,
 MAX(source_kind{text_collate}) AS source_kind,
 MAX(CASE WHEN source_kind='source' THEN 1 ELSE 0 END) AS has_source_observation,
 MAX(CASE WHEN source_kind='legacy_import' THEN 1 ELSE 0 END) AS has_legacy_observation
 FROM raw GROUP BY page_id,TermUS,TermNormUS,code_edition,code,candidateTermUS
),
ranked AS (
 SELECT grain.*,MAX(CASE WHEN code IS NOT NULL THEN 1 ELSE 0 END)
 OVER (PARTITION BY page_id,TermUS,TermNormUS,code_edition) AS has_code
 FROM grain
),
edition32 AS (
 SELECT * FROM ranked WHERE code_edition='ICD-O-3.2' AND (code IS NOT NULL OR has_code=0)
),
edition4 AS (
 SELECT * FROM ranked WHERE code_edition='ICD-O-4' AND (code IS NOT NULL OR has_code=0)
),
paired AS (
 {pair_select.replace("KEY.", "a.")}
 FROM edition32 a LEFT JOIN edition4 z
 ON z.page_id=a.page_id AND z.TermUS=a.TermUS
 UNION ALL
 {pair_select.replace("KEY.", "z.")}
 FROM edition4 z LEFT JOIN edition32 a
 ON z.page_id=a.page_id AND z.TermUS=a.TermUS
 WHERE a.page_id IS NULL
),
site_rows AS (
 SELECT page_id,c_code,MAX(confidence_score) AS confidence_score
 FROM {prefix}page_site_hints WHERE confidence_score>=0.9 GROUP BY page_id,c_code
),
site_text AS (
 SELECT page_id,{site_aggregate} AS candidate_topography_codes,
 MIN(confidence_score) AS site_confidence_min,MAX(confidence_score) AS site_confidence_max
 FROM site_rows GROUP BY page_id
)
SELECT b.alias,b.title AS book_name,b.book_id,b.edition,g.page_id,
 COALESCE(ch.title,ep.chapter) AS chapter,ch.ord AS ch_order,p.title AS page_title,p.url AS page_url,
 CASE
 WHEN g.term_source IN ('coding_section','coding_page') THEN 'ICD-O coding'
 WHEN g.term_role LIKE '%subtype%' THEN 'Subtype(s)'
 WHEN g.term_source='related_terminology' THEN 'Related terminology'
 WHEN g.term_source='page_title' THEN 'Page title'
 ELSE g.page_sections
 END AS page_sections,
 g.TermUS,g.TermNormUS,g.candidateTermUS,g.ICDO32,g.ICDO4,
 COALESCE(g.ICDO4,g.ICDO32) AS morphology_code,g.is_subtype,g.term_role,g.term_source,
 CASE WHEN g.has_source=1 AND g.has_candidate=1 THEN 'source_assignment; candidate'
 WHEN g.has_source=1 THEN 'source_assignment' WHEN g.has_candidate=1 THEN 'candidate'
 ELSE 'uncoded_term' END AS code_kind,
 CASE WHEN g.has_source_observation=1 AND g.has_legacy_observation=1 THEN 'source; legacy_import'
 ELSE g.source_kind END AS source_kind,
 NULL AS suggested_qualifier,g.match_type,g.terminology_kind,g.conditions,g.review_status,
 g.source_tables,g.is_proposed_code,g.is_proposed_term,g.lookup_outcome,
 sites.candidate_topography_codes,
 {site_min_expr} AS site_confidence_min,
 {site_max_expr} AS site_confidence_max,
 {edition_output}
FROM paired g JOIN {prefix}pages p ON p.page_id=g.page_id
JOIN {prefix}books b ON b.book_id=p.book_id
LEFT JOIN {prefix}chapters ch ON ch.chapter_id=p.chapter_id
LEFT JOIN {prefix}entity_pages ep ON ep.page_id=g.page_id
LEFT JOIN site_text sites ON sites.page_id=g.page_id
""".replace("LENFN", "LEN" if sqlserver else "LENGTH")


def ensure_views(con):
    for view in ("v_term_candidate_evidence", "v_page_code_terms", "v_entity_terms",
                 "v_entity_term_provenance", "v_entity_term_code_matches",
                 "v_legacy_entity_terms", "v_legacy_entity_term_provenance",
                 "v_legacy_entity_term_code_matches"):
        con.execute(f"DROP VIEW IF EXISTS {view}")
    con.executescript(view_sql())
