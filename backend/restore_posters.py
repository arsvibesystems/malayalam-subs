import json

with open('data/subtitles_old.json', 'r', encoding='utf-16') as f:
    old_db = json.load(f)

with open('data/subtitles.json', 'r', encoding='utf-8') as f:
    current_db = json.load(f)

old_map = {d['slug']: d for d in old_db}

restored = 0
for d in current_db:
    if d['source_site'] == 'msone' and 'telesco.pe' in d.get('thumbnail_url', ''):
        slug = d['slug']
        if slug in old_map:
            old_thumb = old_map[slug].get('thumbnail_url', '')
            # If the old thumb was high quality (not a telegram link)
            if old_thumb and 'telesco.pe' not in old_thumb:
                d['thumbnail_url'] = old_thumb
                restored += 1

if restored > 0:
    with open('data/subtitles.json', 'w', encoding='utf-8') as f:
        json.dump(current_db, f, ensure_ascii=False, indent=2)
    print(f"Successfully restored {restored} high-quality MSone posters!")
else:
    print("No posters needed restoring.")
