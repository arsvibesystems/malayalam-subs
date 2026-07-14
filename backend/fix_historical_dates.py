import json
from datetime import datetime, timezone, timedelta

def fix_dates():
    with open('data/subtitles.json', 'r', encoding='utf-8') as f:
        data = json.load(f)

    msone = [d for d in data if d['source_site'] == 'msone']
    goat = [d for d in data if d['source_site'] == 'teamgoat']
    mirror = [d for d in data if d['source_site'] == 'moviemirror']

    # Sort each list oldest to newest
    # MSone: sort by release_number
    msone.sort(key=lambda x: x.get('release_number') or 0)
    
    # Team GOAT: sort by release_number
    goat.sort(key=lambda x: x.get('release_number') or 0)
    
    # Movie Mirror: sort by current updated_at (which was assigned base_time - milliseconds, so smallest = oldest)
    mirror.sort(key=lambda x: x.get('updated_at', ''))

    # Assign chronological percentage
    all_items = []
    
    for i, item in enumerate(msone):
        item['_chrono_pct'] = i / max(1, len(msone) - 1)
        all_items.append(item)
        
    for i, item in enumerate(goat):
        item['_chrono_pct'] = i / max(1, len(goat) - 1)
        all_items.append(item)
        
    for i, item in enumerate(mirror):
        item['_chrono_pct'] = i / max(1, len(mirror) - 1)
        all_items.append(item)

    # Sort all items by the percentage (0.0 to 1.0)
    # If percentages are equal, we can use year as a tiebreaker
    all_items.sort(key=lambda x: (x['_chrono_pct'], x.get('year') or 0))

    # Assign new updated_at dates starting from 2020-01-01
    base_date = datetime(2020, 1, 1, tzinfo=timezone.utc)
    
    for i, item in enumerate(all_items):
        # Each item is separated by 1 hour
        new_date = base_date + timedelta(hours=i)
        item['updated_at'] = new_date.isoformat()
        item['created_at'] = new_date.isoformat()
        # Clean up temporary field
        del item['_chrono_pct']

    # Because we sorted oldest to newest, if we want the JSON file to have newest first, we reverse it
    all_items.reverse()

    with open('data/subtitles.json', 'w', encoding='utf-8') as f:
        json.dump(all_items, f, ensure_ascii=False, indent=2)

    print(f"Fixed timestamps for {len(all_items)} items!")

if __name__ == '__main__':
    fix_dates()
