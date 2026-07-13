import requests
from bs4 import BeautifulSoup
import re
import io

with io.open("test_goat_output.txt", "w", encoding="utf-8") as f:
    resp = requests.get("https://malayalamsubtitles.in/")
    soup = BeautifulSoup(resp.text, 'html.parser')
    link = soup.find("a", href=re.compile(r'/release/'))["href"]
    if link.startswith('/'):
        link = "https://malayalamsubtitles.in" + link
    f.write(f"Testing URL: {link}\n")

    resp = requests.get(link)
    soup = BeautifulSoup(resp.text, 'html.parser')
    
    # Just find any numbers with /10
    text_blocks = soup.get_text().split('\n')
    for t in text_blocks:
        if '10' in t:
            f.write(f"Line with 10: {t.strip()}\n")
