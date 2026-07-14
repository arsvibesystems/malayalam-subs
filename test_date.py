import requests, re
url = 'https://malayalamsubtitles.org/languages/korean/alienoid-return-to-the-future-2024/'
html = requests.get(url).text
match2 = re.search(r'property="article:published_time" content="(.*?)"', html)
if match2: print('article:published_time:', match2.group(1))
