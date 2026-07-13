import requests
from bs4 import BeautifulSoup
import re
import io

with io.open("test_goat2_out.txt", "w", encoding="utf-8") as f:
    resp = requests.get("https://malayalamsubtitles.in/")
    soup = BeautifulSoup(resp.text, 'html.parser')
    link = soup.find("a", href=re.compile(r'/release/'))["href"]
    if link.startswith('/'):
        link = "https://malayalamsubtitles.in" + link
    
    resp = requests.get(link)
    soup = BeautifulSoup(resp.text, 'html.parser')
    
    for text in soup.find_all(string=re.compile(r'★')):
        f.write(f"Star string node: '{text}'\n")

    for text in soup.find_all(string=re.compile(r'/10')):
        f.write(f"/10 string node: '{text}'\n")
