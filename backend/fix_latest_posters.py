import json
import os
from urllib.parse import quote
from curl_cffi import requests
from bs4 import BeautifulSoup

def fix_latest_msone_posters():
    try:
        with open('../data/subtitles.json', 'r', encoding='utf-8') as f:
            db = json.load(f)
    except Exception as e:
        print(f"Error loading db: {e}")
        return

    updates = 0
    session = requests.Session(impersonate='chrome120')

    for d in db:
        if d['source_site'] == 'msone' and 'telesco.pe' in d.get('thumbnail_url', ''):
            url = d.get('download_url')
            if url and 'malayalamsubtitles.org' in url:
                print(f"Fetching HQ poster for: {d['title']}")
                try:
                    # Try direct fetch first
                    direct_headers = {
                        'User-Agent': 'Mozilla/5.0 (Linux; Android 13; SM-S901B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
                        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
                        'Accept-Language': 'en-US,en;q=0.9',
                    }
                    resp = session.get(url, headers=direct_headers, timeout=15)
                    soup = BeautifulSoup(resp.text, 'lxml')
                    og_image = soup.find('meta', property='og:image')
                    
                    if not (og_image and og_image.get('content')):
                        # Fallback to proxy
                        print(f"  -> Direct fetch failed/blocked, trying proxy for: {url}")
                        proxy_url = os.getenv("MSONE_PROXY_URL")
                        if proxy_url:
                            fetch_url = f"{proxy_url.rstrip('/')}/?url={quote(url)}"
                            proxy_headers = {}
                            auth_token = os.getenv("MSONE_PROXY_AUTH_TOKEN")
                            if auth_token:
                                proxy_headers["X-Auth-Token"] = auth_token
                                
                            resp = session.get(fetch_url, headers=proxy_headers, timeout=15)
                            soup = BeautifulSoup(resp.text, 'lxml')
                            og_image = soup.find('meta', property='og:image')
                            
                    if og_image and og_image.get('content'):
                        hq_url = og_image['content']
                        if 'telesco.pe' not in hq_url:
                            d['thumbnail_url'] = hq_url
                            print(f"  -> Found HQ: {hq_url}")
                            updates += 1
                        else:
                            print(f"  -> Still got telesco.pe: {hq_url}")
                    else:
                        print(f"  -> Failed to find og:image in response")
                except Exception as e:
                    print(f"  -> Failed to fetch {url}: {e}")

    if updates > 0:
        with open('../data/subtitles.json', 'w', encoding='utf-8') as f:
            json.dump(db, f, ensure_ascii=False, indent=2)
        print(f"Successfully upgraded {updates} latest MSone posters to HQ!")
    else:
        print("No latest MSone posters needed upgrading or could be fetched.")

if __name__ == '__main__':
    fix_latest_msone_posters()
