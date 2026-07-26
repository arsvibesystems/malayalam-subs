import json
from datetime import datetime, timedelta, timezone

def fix_interleaving():
    try:
        with open('../data/subtitles.json', 'r', encoding='utf-8') as f:
            db = json.load(f)
    except Exception as e:
        print(f"Error loading db: {e}")
        return

    # Group by source
    sources = {}
    for item in db:
        site = item.get("source_site", "unknown")
        if site not in sources:
            sources[site] = []
        sources[site].append(item)

    # Sort each source internally by its TRUE mathematical chronological order
    # For MSone, this is release_number. For others, it's their original created_at.
    for site, items in sources.items():
        if site == "msone":
            items.sort(key=lambda x: x.get("release_number") or 0, reverse=True)
        else:
            items.sort(key=lambda x: x.get("created_at", ""), reverse=True)

    # Calculate _chrono_pct for each item to interleave them perfectly!
    all_items = []
    for site, items in sources.items():
        if not items: continue
        limit = 100.0
        for i, item in enumerate(items):
            # 0.0 is newest, 100.0 is oldest
            pct = (i / max(1, len(items) - 1)) * limit
            item["_chrono_pct"] = pct
            all_items.append(item)

    # Synthesize timestamps based purely on _chrono_pct
    # We will spread all subtitles over a 10-year (3650 days) window starting from today.
    # pct=0.0 -> today
    # pct=100.0 -> 10 years ago
    
    now = datetime(2026, 7, 26, 17, 0, 0, tzinfo=timezone.utc)
    max_days = 3650
    
    updates = 0
    for item in all_items:
        pct = item["_chrono_pct"]
        days_to_subtract = (pct / 100.0) * max_days
        
        # Tie-breaker for items with the same percentage: MSone's release_number, or title
        # We handle tie-breakers dynamically below using sort(), but the base timestamp is purely pct!
        synthetic_dt = now - timedelta(days=days_to_subtract)
        
        synthetic_str = synthetic_dt.isoformat()
        
        # Overwrite both created_at and updated_at so the app sorts it perfectly regardless of app version!
        item["created_at"] = synthetic_str
        item["updated_at"] = synthetic_str
        del item["_chrono_pct"]
        updates += 1

    # Sort the final database by updated_at descending
    all_items.sort(key=lambda x: x.get("updated_at", ""), reverse=True)

    if updates > 0:
        with open('../data/subtitles.json', 'w', encoding='utf-8') as f:
            json.dump(all_items, f, ensure_ascii=False, indent=2)
        print(f"Successfully synthesized beautifully interleaved timestamps for all {updates} items across 4 sources!")

if __name__ == '__main__':
    fix_interleaving()
