import json

def fix_sort_order():
    try:
        with open('data/subtitles.json', 'r', encoding='utf-8') as f:
            db = json.load(f)
    except Exception as e:
        print(f"Error loading db: {e}")
        return

    updates = 0

    for d in db:
        if d.get('created_at'):
            if d.get('updated_at') != d['created_at']:
                d['updated_at'] = d['created_at']
                updates += 1

    # Sort database chronologically just to be perfectly clean
    db.sort(key=lambda x: x.get('created_at', ''), reverse=True)

    if updates > 0:
        with open('data/subtitles.json', 'w', encoding='utf-8') as f:
            json.dump(db, f, ensure_ascii=False, indent=2)
        print(f"Successfully synced {updates} items to fix the app's Latest feed sorting!")
    else:
        print("No items needed fixing.")

if __name__ == '__main__':
    fix_sort_order()
