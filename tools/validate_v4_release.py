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
