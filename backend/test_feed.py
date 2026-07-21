import json
from curl_cffi import requests
from bs4 import BeautifulSoup
import re

def test_feed():
    s = requests.Session(impersonate="chrome120")
    s.headers.update({"Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"})
    s.headers["Referer"] = "https://malayalamsubtitles.org/"
    
    r = s.get("https://malayalamsubtitles.org/feed/")
    print("Status:", r.status_code)
    
    soup = BeautifulSoup(r.text, "xml")
    
    results = []
    for item in soup.find_all("item"):
        link = item.find("link")
        title_elem = item.find("title")
        if link and link.text:
            href = link.text.strip()
            title_text = title_elem.text.strip() if title_elem else ""
            cats = [c.text.strip() for c in item.find_all("category")]
            
            # extract year
            year_match = re.search(r'\((\d{4})\)', title_text)
            year = int(year_match.group(1)) if year_match else None
            
            desc_elem = item.find("description")
            if not desc_elem:
                desc_elem = item.find("encoded")
                
            desc_text = ""
            if desc_elem and desc_elem.text:
                desc_soup = BeautifulSoup(desc_elem.text, "html.parser")
                desc_text = " ".join(desc_soup.get_text().split())
                
            results.append({
                "title": title_text,
                "url": href,
                "cats": cats,
                "year": year,
                "desc_snippet": desc_text[:100] if desc_text else ""
            })
            
    print(f"Found {len(results)} items")
    if results:
        print(json.dumps(results[0], indent=2, ensure_ascii=False))

if __name__ == "__main__":
    test_feed()
