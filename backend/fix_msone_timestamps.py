import json
from datetime import datetime, timedelta, timezone

def fix_msone_timestamps():
    try:
        with open('data/subtitles.json', 'r', encoding='utf-8') as f:
            db = json.load(f)
    except Exception as e:
        print(f"Error loading db: {e}")
        return

    # Find the absolute newest timestamp across all items to use as our anchor
    newest_date = datetime(2020, 1, 1, tzinfo=timezone.utc)
    for d in db:
        if d.get('created_at'):
            try:
                dt = datetime.fromisoformat(d['created_at'].replace('Z', '+00:00'))
                if dt > newest_date and dt < datetime.now(timezone.utc) + timedelta(days=1):
                    newest_date = dt
            except:
                pass

    print(f"Anchor date for highest MSone release: {newest_date.isoformat()}")

    # Extract all MSone items that have a release number
    msone_items = [d for d in db if d.get('source_site') == 'msone' and d.get('release_number')]
    
    # Sort them perfectly by release_number descending!
    msone_items.sort(key=lambda x: x['release_number'], reverse=True)

    if not msone_items:
        print("No MSone items found with release numbers.")
        return

    current_dt = newest_date
    last_rn = msone_items[0]['release_number']

    updates = 0
    for item in msone_items:
        rn = item['release_number']
        
        # If release number drops, subtract time! 
        # 365 days / ~200 releases per year = ~1.8 days per release. Let's subtract 43 hours.
        if rn < last_rn:
            diff = last_rn - rn
            current_dt -= timedelta(hours=43 * diff)
            last_rn = rn

        # Synthesize perfect chronological timestamps!
        perfect_time = current_dt.isoformat()
        
        if item.get('created_at') != perfect_time or item.get('updated_at') != perfect_time:
            item['created_at'] = perfect_time
            item['updated_at'] = perfect_time
            updates += 1

    # Finally, sort the entire database perfectly by updated_at descending
    db.sort(key=lambda x: x.get('updated_at', ''), reverse=True)

    if updates > 0:
        with open('data/subtitles.json', 'w', encoding='utf-8') as f:
            json.dump(db, f, ensure_ascii=False, indent=2)
        print(f"Successfully synthesized perfect timestamps for {updates} MSone releases based on release_number!")
    else:
        print("No MSone timestamps needed fixing.")

if __name__ == '__main__':
    fix_msone_timestamps()
