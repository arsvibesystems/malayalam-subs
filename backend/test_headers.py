from curl_cffi import requests
HEADERS = {
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9,ml;q=0.8",
}
s = requests.Session(impersonate='chrome120')
s.headers.update(HEADERS)
s.headers["Referer"] = "https://malayalamsubtitles.org/"
headers = {"Referer": "https://malayalamsubtitles.org/releases/"}
r = s.get('https://httpbin.org/headers', headers=headers)
print(r.text)
