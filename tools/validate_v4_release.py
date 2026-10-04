#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, sqlite3, sys, tempfile

ROOT=Path(__file__).resolve().parents[1]
manifest=json.loads((ROOT/'assets/corpus/manifest.json').read_text(encoding='utf-8'))
errors=[]
def check(ok,msg):
    if not ok: errors.append(msg)

check(manifest.get('schema_version') == 4, 'manifest schema_version must be 4')
check(manifest.get('search_v4',{}).get('lsa_runtime') is False, 'manifest must disable LSA runtime')
check(manifest.get('search_v4',{}).get('generative_ai') is False, 'manifest must disable generative AI')
parts=manifest.get('parts',[])
check(bool(parts), 'database parts missing')

h=hashlib.sha256(); total=0
with tempfile.NamedTemporaryFile(suffix='.db') as tmp:
    for part in parts:
        p=ROOT/'assets/corpus/db_parts'/part['name']
        check(p.exists(), f'missing part {part["name"]}')
        if not p.exists(): continue
        data=p.read_bytes(); total += len(data); h.update(data); tmp.write(data)
        check(len(data)==part['bytes'], f'wrong byte count for {part["name"]}')
        check(hashlib.sha256(data).hexdigest()==part['sha256'], f'wrong sha256 for {part["name"]}')
    tmp.flush()
    check(total==manifest.get('database_bytes'), 'database byte count mismatch')
    check(h.hexdigest()==manifest.get('database_sha256'), 'database sha256 mismatch')
    if not errors:
        con=sqlite3.connect(tmp.name)
        try:
            quick=con.execute('PRAGMA quick_check').fetchone()[0]
            check(str(quick).lower()=='ok', f'PRAGMA quick_check={quick}')
            meta=dict(con.execute('SELECT key,value FROM corpus_meta'))
            check(meta.get('schema_version')=='4','corpus_meta schema_version must be 4')
            check(meta.get('search_model_version')=='deterministic-ir-v4','search_model_version mismatch')
            count=con.execute('SELECT COUNT(*) FROM passages').fetchone()[0]
            check(count==39679, f'unexpected passage count: {count}')
            # Canonical-content hash is independent of SQLite physical bytes.
            ch=hashlib.sha256()
            for pid,text in con.execute('SELECT id,text_display FROM passages ORDER BY id'):
                b=(text or '').encode('utf-8')
                ch.update(str(pid).encode('ascii')); ch.update(b'\0'); ch.update(len(b).to_bytes(8,'big')); ch.update(b)
            canonical=ch.hexdigest()
            check(canonical==manifest.get('canonical_text_sha256'), 'canonical passage text hash mismatch')
            check(canonical==meta.get('canonical_text_sha256'), 'corpus_meta canonical passage text hash mismatch')
            for table in ['v4_search_metadata','v4_safe_aliases']:
                check(con.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",(table,)).fetchone() is not None, f'missing V4 table {table}')

            curated_manifest_path=ROOT/'assets/curated/manifest.json'
            check(curated_manifest_path.exists(), 'curated reference manifest missing')
            if curated_manifest_path.exists():
                curated_manifest=json.loads(curated_manifest_path.read_text(encoding='utf-8'))
                check(curated_manifest.get('schema_version')==1, 'curated manifest schema_version must be 1')
                curated_files=curated_manifest.get('files') or []
                check(bool(curated_files), 'curated manifest files missing')
                seen_refs=set()
                for rel in curated_files:
                    index_path=ROOT/rel
                    check(index_path.exists(), f'missing curated reference index: {rel}')
                    if not index_path.exists():
                        continue
                    payload=json.loads(index_path.read_text(encoding='utf-8'))
                    check(payload.get('schema_version')==1, f'{rel}: schema_version must be 1')
                    refs=payload.get('references') or []
                    topics=payload.get('topics') or []
                    check(bool(refs), f'{rel}: references missing')
                    check(bool(topics), f'{rel}: topics missing')
                    local_ids=set()
                    for ref in refs:
                        ref_id=str(ref.get('id') or '').strip()
                        code=str(ref.get('sermon_code') or '').strip()
                        anchors=[str(v).strip() for v in (ref.get('anchor_terms') or []) if str(v).strip()]
                        check(bool(ref_id), f'{rel}: reference id missing')
                        check(ref_id not in seen_refs, f'{rel}: duplicate reference id {ref_id}')
                        seen_refs.add(ref_id)
                        local_ids.add(ref_id)
                        check(bool(code), f'{rel}:{ref_id}: sermon_code missing')
                        check(bool(anchors), f'{rel}:{ref_id}: anchor_terms missing')
                        sermon=con.execute('SELECT id FROM sermons WHERE code=? LIMIT 1',(code,)).fetchone()
                        if sermon is None:
                            title=str(ref.get('sermon_title') or '').strip()
                            needle=title.split(' / ')[0].strip()
                            candidates=con.execute(
                                'SELECT code,title FROM sermons WHERE lower(title) LIKE ? ORDER BY code LIMIT 8',
                                (f'%{needle.lower()}%',),
                            ).fetchall() if needle else []
                            hint=', '.join(f'{row[0]} — {row[1]}' for row in candidates) or 'aucun titre proche'
                            check(False, f'{rel}:{ref_id}: unknown sermon code {code}; corpus candidates: {hint}')
                        if sermon is not None and anchors:
                            terms=[]
                            for value in anchors:
                                for token in value.lower().replace('’',"'").split():
                                    token=''.join(ch for ch in token if ch.isalnum() or ch in "-'")
                                    if len(token)>=3 and token not in terms:
                                        terms.append(token)
                            fts=' OR '.join(f'"{term.replace(chr(34), chr(34)*2)}"' for term in terms[:12])
                            if fts:
                                try:
                                    hit=con.execute(
                                        'SELECT 1 FROM passages_fts '
                                        'JOIN passages p ON p.id=passages_fts.rowid '
                                        'JOIN editions e ON e.id=p.edition_id '
                                        'JOIN sermons s ON s.id=p.sermon_id '
                                        'WHERE passages_fts MATCH ? AND e.is_primary=1 AND s.code=? LIMIT 1',
                                        (fts,code),
                                    ).fetchone()
                                except sqlite3.Error:
                                    hit=None
                                check(hit is not None, f'{rel}:{ref_id}: anchor terms do not resolve in canonical sermon {code}')
                    for topic in topics:
                        topic_id=str(topic.get('id') or '').strip()
                        aliases=topic.get('aliases') or []
                        ref_ids=topic.get('reference_ids') or []
                        check(bool(topic_id), f'{rel}: topic id missing')
                        check(bool(aliases), f'{rel}:{topic_id}: aliases missing')
                        check(bool(ref_ids), f'{rel}:{topic_id}: reference_ids missing')
                        for ref_id in ref_ids:
                            check(ref_id in local_ids, f'{rel}:{topic_id}: unknown reference {ref_id}')
        finally: con.close()

for old in ['semantic_vocab.json','semantic_components.f32','semantic_vectors.f32','semantic_passage_ids.i32','semantic_manifest.json']:
    check(not (ROOT/'assets/corpus'/old).exists(), f'legacy LSA asset shipped: {old}')

if errors:
    print('V4_RELEASE_VALIDATION: FAIL')
    for e in errors: print('-',e)
    sys.exit(1)
print('V4_RELEASE_VALIDATION: OK')
print(json.dumps({
    'schema_version':4,
    'passages':39679,
    'database_bytes':manifest['database_bytes'],
    'database_sha256':manifest['database_sha256'],
    'canonical_text_sha256':manifest['canonical_text_sha256'],
    'lsa_assets_packaged':False,
}, ensure_ascii=False, indent=2))
