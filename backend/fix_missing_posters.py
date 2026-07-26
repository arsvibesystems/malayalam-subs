import json, urllib.request, urllib.parse, time

def fix_posters():
    try:
        with open('data/subtitles.json', 'r', encoding='utf-8') as f:
            db = json.load(f)
    except Exception as e:
        print(f"Error loading db: {e}")
        return

    updates = 0
    api_key = '15d2ea6d0dc1d476efbca3eba2b9bbfb'

    for d in db:
        if not d.get('thumbnail_url') and d.get('title') and d['title'] != 'Unknown':
            # Clean title for TMDB (remove Malayalam part and brackets)
            q = d['title'].split(' / ')[0].split('–')[0].strip()
            # Also remove parenthetical years from query string if present
            if '(' in q:
                q = q.split('(')[0].strip()
                
            url = f'https://api.themoviedb.org/3/search/movie?api_key={api_key}&query=' + urllib.parse.quote(q)
            if d.get('year'):
                url += '&primary_release_year=' + str(d['year'])
            
            try:
                req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
                resp = urllib.request.urlopen(req)
                data = json.loads(resp.read())
                
                if data.get('results') and data['results'][0].get('poster_path'):
                    d['thumbnail_url'] = 'https://image.tmdb.org/t/p/w500' + data['results'][0]['poster_path']
                    print(f"Fixed poster for: {d['title']}")
                    updates += 1
            except Exception as e:
                print(f"Failed TMDB for {q}: {e}")
            
            time.sleep(0.1) # Be nice to TMDB API

    if updates > 0:
        with open('data/subtitles.json', 'w', encoding='utf-8') as f:
            json.dump(db, f, ensure_ascii=False, indent=2)
        print(f"Successfully updated {updates} posters!")
    else:
        print("No missing posters could be found.")

if __name__ == '__main__':
    fix_posters()
