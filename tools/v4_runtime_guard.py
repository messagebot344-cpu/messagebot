#!/usr/bin/env python3
from pathlib import Path
import re, sys

ROOT = Path(__file__).resolve().parents[1]
errors=[]

def fail(msg): errors.append(msg)

# Runtime entry points and V4 runtime graph must not load the V3 latent model.
runtime_files = [
    ROOT/'lib/src/app.dart', ROOT/'lib/src/app_scope.dart',
    ROOT/'lib/src/services/search_service_v4.dart', ROOT/'lib/src/study/similarity_engine.dart',
]
runtime_files += list((ROOT/'lib/src/search_v4').glob('*.dart'))
runtime_files += list((ROOT/'lib/src/conversation').glob('*.dart'))
runtime_files += list((ROOT/'lib/src/study_certification').glob('*.dart'))
for p in runtime_files:
    text=p.read_text(encoding='utf-8')
    for banned in ['semantic_index.dart','SemanticIndex(', 'SemanticSearchEngine(', 'semantic_vectors.f32','semantic_components.f32']:
        if banned in text: fail(f'{p.relative_to(ROOT)} contains banned V4 runtime dependency: {banned}')
    if re.search(r"package:(http|dio|web_socket_channel|openai|google_generative_ai|anthropic)/", text):
        fail(f'{p.relative_to(ROOT)} imports a network/generative client')

# V4 sparse similar-passages implementation must not read precomputed LSA neighbors.
sim=(ROOT/'lib/src/study/similarity_engine.dart').read_text(encoding='utf-8')
if 'neighborPassages(' in sim: fail('V4 SimilarityEngine still calls legacy passage_neighbors')

# Shipped assets must not contain V3 LSA float arrays.
for name in ['semantic_vocab.json','semantic_components.f32','semantic_vectors.f32','semantic_passage_ids.i32','semantic_manifest.json']:
    if (ROOT/'assets/corpus'/name).exists(): fail(f'legacy LSA asset is still shipped: {name}')

# Public runtime branding. The 4 October 2026 reference UI makes
# "Le Grenier du Message" the authoritative public identity. Technical class
# names and package identifiers may keep their historical names.
app=(ROOT/'lib/src/app.dart').read_text(encoding='utf-8')
if 'GrenierBrand.name' not in app or 'SearchServiceV4' not in app:
    fail('app.dart is not wired to Le Grenier du Message V4')
tokens=(ROOT/'lib/src/theme/grenier_tokens.dart').read_text(encoding='utf-8')
for exact in ['Le Grenier du Message', 'V4 – IR Expert', 'Toute Sa Parole. Toujours avec vous. Hors ligne.']:
    if exact not in tokens:
        fail(f'missing authoritative Grenier public branding: {exact}')
settings=(ROOT/'lib/src/screens/settings_screen.dart').read_text(encoding='utf-8')
for exact in ['Ce logiciel est conçu par le frère Erly Rolvinst BASSOMBI','242 069101357','ebassombi@gmail.com']:
    if exact not in settings: fail(f'missing official Avant-propos text: {exact}')

# No network package dependency in pubspec.
pub=(ROOT/'pubspec.yaml').read_text(encoding='utf-8')
for dep in ['http:', 'dio:', 'web_socket_channel:', 'firebase_', 'supabase_']:
    if re.search(rf'^\s*{re.escape(dep)}', pub, flags=re.M): fail(f'network/cloud dependency in pubspec: {dep}')

# Generated release Android manifest, if present, must not request INTERNET.
for manifest in ROOT.glob('android/app/src/**/AndroidManifest.xml'):
    if 'src/debug' in str(manifest).replace('\\','/'):
        continue
    if 'android.permission.INTERNET' in manifest.read_text(encoding='utf-8'):
        fail(f'INTERNET permission in release/main manifest: {manifest.relative_to(ROOT)}')

if errors:
    print('V4_RUNTIME_GUARD: FAIL')
    for e in errors: print('-',e)
    sys.exit(1)
print('V4_RUNTIME_GUARD: OK')
print(f'Checked {len(runtime_files)} V4 runtime files; no LSA/generative/network runtime dependency detected.')
