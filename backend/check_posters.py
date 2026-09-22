import json

with open('data/subtitles.json', 'r', encoding='utf-8') as f:
    db = json.load(f)

for d in db:
    if d['source_site'] == 'ddmlsub':
        t = d['title'].lower()
        if 'incantation' in t or 'brutal' in t or 'charlie' in t:
            print(f"{d['title']} | Thumb: {d.get('thumbnail_url', '')} | Slug: {d.get('slug')}")
