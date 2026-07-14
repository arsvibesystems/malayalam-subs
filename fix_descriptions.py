import json
import logging
from backend.scrapers.msone import MSoneScraper
from backend.scrapers.teamgoat import TeamGoatScraper
from backend.scrapers.moviemirror import MovieMirrorScraper
import sys

sys.stdout.reconfigure(encoding='utf-8')
logging.getLogger().setLevel(logging.WARNING) # suppress info logs

scrapers = {
    'msone': MSoneScraper(),
    'teamgoat': TeamGoatScraper(),
    'moviemirror': MovieMirrorScraper()
}

data = json.load(open('data/subtitles.json', encoding='utf-8'))
print(f'Updating descriptions for {len(data)} items...')

updated_count = 0
for i, item in enumerate(data):
    site = item.get('source_site')
    url = item.get('source_url')
    if site in scrapers and url:
        print(f"Fetching [{i+1}/{len(data)}] {item.get('title')}...")
        try:
            fresh_data = scrapers[site].scrape_detail_page(url)
            if fresh_data and fresh_data.get('description'):
                if item.get('description') != fresh_data['description']:
                    item['description'] = fresh_data['description']
                    updated_count += 1
        except Exception as e:
            print(f"Error fetching {url}: {e}")

if updated_count > 0:
    json.dump(data, open('data/subtitles.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    print(f'Updated {updated_count} descriptions and saved to subtitles.json')
else:
    print('No descriptions needed updating.')
