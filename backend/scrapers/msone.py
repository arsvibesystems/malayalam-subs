"""
Scraper for malayalamsubtitles.org (MSone)
The largest Malayalam subtitle community with ~3700 releases.

Site structure (from research):
- Listing: /releases/ (paginated, ?page=N or /page/N/)
- Detail: /languages/{lang}/{slug}/
- Data points: title, language, genres, IMDB, translator, certificate, download link
"""

import re
from typing import Optional, Dict, Any, List
from bs4 import BeautifulSoup
from .base import BaseScraper


class MSoneScraper(BaseScraper):
    SITE_NAME = "MSone (malayalamsubtitles.org)"
    SITE_KEY = "msone"
    BASE_URL = "https://malayalamsubtitles.org"
    TELEGRAM_URL = "https://t.me/s/msone"

    # Malayalam to English language mapping
    LANGUAGE_MAP = {
        "ഇംഗ്ലീഷ്": "English",
        "കൊറിയൻ": "Korean",
        "ഹിന്ദി": "Hindi",
        "ജാപ്പനീസ്": "Japanese",
        "ഫ്രഞ്ച്": "French",
        "സ്പാനിഷ്": "Spanish",
        "ജർമൻ": "German",
        "ചൈനീസ്": "Chinese",
        "മാൻഡറിൻ": "Mandarin",
        "തായ്": "Thai",
        "ഇറ്റാലിയൻ": "Italian",
        "തുർക്കിഷ്": "Turkish",
        "മലയാളം": "Malayalam",
        "തമിഴ്": "Tamil",
        "തെലുഗ്": "Telugu",
        "കന്നഡ": "Kannada",
        "ബംഗാളി": "Bengali",
        "മറാത്തി": "Marathi",
        "റഷ്യൻ": "Russian",
        "പോർച്ചുഗീസ്": "Portuguese",
        "ഡാനിഷ്": "Danish",
        "സ്വീഡിഷ്": "Swedish",
        "നോർവീജിയൻ": "Norwegian",
        "ഡച്ച്": "Dutch",
        "പോളിഷ്": "Polish",
        "അറബിക്": "Arabic",
        "പേർഷ്യൻ": "Persian",
        "ഇന്തോനേഷ്യൻ": "Indonesian",
    }

    # Malayalam to English genre mapping
    GENRE_MAP = {
        "ആക്ഷൻ": "Action",
        "ക്രൈം": "Crime",
        "ത്രില്ലർ": "Thriller",
        "ഡ്രാമ": "Drama",
        "കോമഡി": "Comedy",
        "ഹൊറർ": "Horror",
        "റൊമാൻസ്": "Romance",
        "സയൻസ് ഫിക്ഷൻ": "Sci-Fi",
        "ഫാന്റസി": "Fantasy",
        "ആനിമേഷൻ": "Animation",
        "മിസ്റ്ററി": "Mystery",
        "അഡ്വഞ്ചർ": "Adventure",
        "ഹിസ്റ്ററി": "History",
        "വാർ": "War",
        "ബയോഗ്രഫി": "Biography",
        "ഡോക്യുമെന്ററി": "Documentary",
        "മ്യൂസിക്കൽ": "Musical",
        "സ്പോർട്സ്": "Sports",
        "വെസ്റ്റേൺ": "Western",
        "ഫാമിലി": "Family",
    }

    def __init__(self):
        super().__init__()
        self.rss_data: Dict[str, Dict[str, Any]] = {}

    def scrape_listing_page(self, page_num: int) -> List[str]:
        """Scrape the releases listing page or RSS feed for detail page URLs."""
        detail_urls = []
        if page_num == 1:
            # Use RSS feed for page 1 — bypasses Cloudflare challenge on GitHub Actions IPs
            feed_url = f"{self.BASE_URL}/feed/"
            soup = self._fetch_page(feed_url)
            if soup:
                for item in soup.find_all("item"):
                    link = item.find("link")
                    title_elem = item.find("title")
                    if link and link.text:
                        href = link.text.strip()
                        if href.startswith(self.BASE_URL):
                            detail_urls.append(href)
                            
                            # Build RSS fallback item in case detail page fetch gets 403
                            title_text = self._clean_text(title_elem.text) if title_elem else "Unknown"
                            title_text = re.sub(r'\s*[-–]\s*എംസോൺ\s*$', '', title_text)
                            cats = [c.text.strip() for c in item.find_all("category")]
                            
                            desc_elem = item.find("description") or item.find("encoded")
                            desc_text = ""
                            if desc_elem and desc_elem.text:
                                desc_soup = BeautifulSoup(desc_elem.text, "html.parser")
                                desc_text = self._clean_text(desc_soup.get_text())

                            self.rss_data[href] = {
                                "source_site": self.SITE_KEY,
                                "source_url": href,
                                "title": title_text,
                                "year": self._extract_year(title_text),
                                "thumbnail_url": "",
                                "movie_language": cats[0] if cats else self._detect_language_from_url(href),
                                "genres": "",
                                "imdb_rating": None,
                                "imdb_url": "",
                                "translator": cats[1] if len(cats) > 1 else "",
                                "release_type": "movie",
                                "certificate": "",
                                "download_url": href,
                                "description": desc_text[:500] if desc_text else "",
                                "release_number": None,
                                "slug": self._make_slug(title_text, href),
                            }
            if detail_urls:
                self.logger.info(f"  Found {len(detail_urls)} detail URLs on page 1 via RSS feed")
                return detail_urls

        # Fallback / Subsequent pages
        url = f"{self.BASE_URL}/releases/" if page_num == 1 else f"{self.BASE_URL}/releases/page/{page_num}/"
        soup = self._fetch_page(url)
        if not soup:
            return []

        # MSone uses links that contain /languages/ in the path for detail pages
        for link in soup.find_all("a", href=True):
            href = link["href"]
            if "/languages/" in href and href.startswith(self.BASE_URL):
                if href not in detail_urls and re.search(r'/languages/[^/]+/[^/]+/$', href):
                    detail_urls.append(href)

        # Deduplicate while preserving order
        seen = set()
        unique_urls = []
        for u in detail_urls:
            if u not in seen:
                seen.add(u)
                unique_urls.append(u)

        self.logger.info(f"  Found {len(unique_urls)} detail URLs on page {page_num}")
        return unique_urls

    def scrape_detail_page(self, url: str) -> Optional[Dict[str, Any]]:
        """Scrape a single subtitle detail page for all metadata."""
        # Fast-fail if we have fallback data (no retries) to save time when blocked
        has_fallback = url in self.rss_data
        soup = self._fetch_page(url, max_retries=0 if has_fallback else None)
        if not soup:
            if has_fallback:
                self.logger.info(f"  ✓ Using RSS fallback data for: {url}")
                return self.rss_data[url]
            return None

        try:
            data: Dict[str, Any] = {
                "source_site": self.SITE_KEY,
                "source_url": url,
            }

            # --- Title ---
            # The page title format: "The Furious / ദ ഫ്യൂരിയസ് (2025) - എംസോൺ"
            page_title = soup.find("title")
            if page_title:
                title_text = self._clean_text(page_title.get_text())
                # Remove site suffix
                title_text = re.sub(r'\s*[-–]\s*എംസോൺ\s*$', '', title_text)
                data["title"] = title_text
                data["year"] = self._extract_year(title_text)
            else:
                data["title"] = "Unknown"
                data["year"] = None

            # --- Thumbnail / Poster ---
            # Look for the main poster image - usually an og:image meta or first large image
            og_image = soup.find("meta", property="og:image")
            if og_image and og_image.get("content"):
                data["thumbnail_url"] = og_image["content"]
            else:
                data["thumbnail_url"] = ""

            # --- Languages (category links) ---
            languages = []
            for cat_link in soup.find_all("a", href=re.compile(r'/category/')):
                cat_text = self._clean_text(cat_link.get_text())
                if cat_text in self.LANGUAGE_MAP:
                    languages.append(self.LANGUAGE_MAP[cat_text])
                elif cat_text and not cat_text.startswith(("പരിഭാഷ", "റിലീസ")):
                    # Check if it's in the URL pattern for languages
                    if "/category/" in cat_link["href"]:
                        languages.append(cat_text)
            data["movie_language"] = ", ".join(languages) if languages else self._detect_language_from_url(url)

            # --- Genres ---
            genres = []
            for genre_link in soup.find_all("a", href=re.compile(r'/genres/')):
                genre_text = self._clean_text(genre_link.get_text())
                if genre_text in self.GENRE_MAP:
                    genres.append(self.GENRE_MAP[genre_text])
                elif genre_text:
                    genres.append(genre_text)
            data["genres"] = ", ".join(genres) if genres else ""

            # --- IMDB Rating ---
            imdb_rating = None
            imdb_url = ""
            # Look for IMDb link
            for link in soup.find_all("a", href=re.compile(r'imdb\.com')):
                imdb_url = link["href"]
                break
            # Look for rating text like "7.7/10"
            rating_match = re.search(r'(\d+\.?\d*)\s*/\s*10', soup.get_text())
            if rating_match:
                try:
                    imdb_rating = float(rating_match.group(1))
                except ValueError:
                    pass
            data["imdb_rating"] = imdb_rating
            data["imdb_url"] = imdb_url

            # --- Translator ---
            translator = ""
            for tag_link in soup.find_all("a", href=re.compile(r'/tag/')):
                tag_text = self._clean_text(tag_link.get_text())
                if tag_text and not any(skip in tag_text.lower() for skip in ["imdb", "movie", "series"]):
                    translator = tag_text
                    break
            data["translator"] = translator

            # --- Release Type (Movie/Series) ---
            release_type = "movie"
            for rt_link in soup.find_all("a", href=re.compile(r'/release-type/')):
                rt_text = self._clean_text(rt_link.get_text()).lower()
                if "series" in rt_text:
                    release_type = "series"
                    break
            data["release_type"] = release_type

            # --- Certificate ---
            certificate = ""
            for cert_link in soup.find_all("a", href=re.compile(r'/certificates/')):
                cert_text = self._clean_text(cert_link.get_text())
                if cert_text:
                    certificate = cert_text
                    break
            data["certificate"] = certificate

            # --- Download URL ---
            # Look for SRT download links (usually in .srt format or download buttons)
            download_url = ""
            for link in soup.find_all("a", href=True):
                href = link["href"]
                link_text = self._clean_text(link.get_text()).lower()
                if any(ext in href.lower() for ext in ['.srt', '.zip', '.rar', 'download']) and 'sub-counts' not in href:
                    download_url = href
                    break
                if ("ഡൗൺലോഡ്" in link.get_text() or "download" in link_text) and 'sub-counts' not in href:
                    download_url = href
                    break
            # Fallback: the source page itself is the download reference
            data["download_url"] = download_url if download_url else url

            # Get all paragraphs from the main content
            desc_parts = []
            main_content = soup.find("div", class_=re.compile(r'entry-content|post-content')) or soup.find("main")
            if main_content:
                for p in main_content.find_all("p"):
                    text = self._clean_text(p.get_text())
                    if len(text) > 30 and not any(kw in text.lower() for kw in ["പരിഭാഷ", "download", "ഡൗൺലോഡ്"]):
                        desc_parts.append(text)
            
            # If no paragraphs found, fallback to meta description
            if not desc_parts:
                meta_desc = soup.find("meta", attrs={"name": "description"})
                og_desc = soup.find("meta", property="og:description")
                if og_desc and og_desc.get("content"):
                    desc_parts.append(og_desc["content"])
                elif meta_desc and meta_desc.get("content"):
                    desc_parts.append(meta_desc["content"])

            data["description"] = "\n\n".join(desc_parts)

            # --- Release Number ---
            release_match = re.search(r'(?:റിലീസ്|Release)\s*[:\-–]\s*(\d+)', soup.get_text(), re.IGNORECASE)
            data["release_number"] = int(release_match.group(1)) if release_match else None

            # --- Slug ---
            data["slug"] = self._make_slug(data["title"], url)

            return data

        except Exception as e:
            self.logger.error(f"Error parsing {url}: {e}")
            return None

    def _detect_language_from_url(self, url: str) -> str:
        """Detect language from the URL path like /languages/english/..."""
        match = re.search(r'/languages/([^/]+)/', url)
        if match:
            lang = match.group(1).capitalize()
            return lang
        return "Unknown"

    def _parse_release_text(self, text: str, post_id: str, thumb_url: Optional[str], download_url: str, buttons_meta: Dict[str, Any]) -> Dict[str, Any]:
        """Parse structured release metadata from MSone Telegram post text and buttons."""
        lines = [self._clean_text(l) for l in text.split('\n') if self._clean_text(l)]

        data: Dict[str, Any] = {
            "source_site": self.SITE_KEY,
            "source_url": download_url if download_url else (f"https://t.me/{post_id}" if post_id else self.BASE_URL),
            "thumbnail_url": thumb_url or "",
            "imdb_url": buttons_meta.get("imdb_url", ""),
            "certificate": "",
        }

        # --- Release Number ---
        rn_match = re.search(r'(?:റിലീസ്|Release)[^\d]*(\d+)', text, re.IGNORECASE)
        if rn_match:
            data["release_number"] = int(rn_match.group(1))
        else:
            data["release_number"] = None

        # --- Title & Year ---
        title_candidate = "Unknown"
        year = None
        eng_title = ""
        ml_title = ""
        desc_lines = []
        seen_meta = False

        for line in lines:
            if any(w in line.lower() for w in ['#msone', 'release', '🔸', '🟥', '🦾', '🐉', '🚪', '🔥', '⭐', '🎬', '📽', '🍅', '💵', '🛑', '🧩', '⭐️', '👀', '👑', '🌐', 'അഭിപ്രായങ്ങൾ', 'download', 'പോസ്റ്റർ']):
                continue
            if any(w in line for w in ['പരിഭാഷ', 'ഭാഷ:', 'സംവിധാനം', 'നിർമ്മാണം:', 'ജോണർ:', 'IMDb', 'രചന']):
                seen_meta = True
                continue
            if not seen_meta and re.search(r'[a-zA-Zമലയാളം]', line) and len(line) > 2 and not line.isdigit():
                ym = re.search(r'\(\d{4}\)', line)
                if re.search(r'[a-zA-Z]', line):
                    if not eng_title:
                        eng_title = line
                else:
                    if not ml_title:
                        ml_title = line
            elif seen_meta and len(line) > 25 and not any(k in line for k in ['/10', '%', 'അഭിപ്രായങ്ങൾ']):
                desc_lines.append(line)

        if eng_title and ml_title:
            title_candidate = f"{eng_title} / {ml_title}"
        elif eng_title:
            title_candidate = eng_title
        elif ml_title:
            title_candidate = ml_title if not year else f"{ml_title} ({year})"

        data["title"] = title_candidate
        data["year"] = self._extract_year(title_candidate) or self._extract_year(text)

        # --- IMDb Rating ---
        imdb_match = re.search(r'(\d+(?:\.\d+)?)\s*/\s*10', text)
        data["imdb_rating"] = float(imdb_match.group(1)) if imdb_match else None

        # --- Language ---
        lang_str = buttons_meta.get("language", "")
        if not lang_str:
            lang_match = re.search(r'(?:ഭാഷ|Language)\s*[:\-–]\s*([^\n]+)', text, re.IGNORECASE)
            if lang_match:
                raw_lang = self._clean_text(lang_match.group(1)).split()[0]
                lang_str = self.LANGUAGE_MAP.get(raw_lang, raw_lang)
        data["movie_language"] = lang_str or "Malayalam"

        # --- Director ---
        dir_str = buttons_meta.get("director", "")
        if not dir_str:
            dir_match = re.search(r'(?:സംവിധാനം|Director)\s*[:\-–]\s*([^\n]+)', text, re.IGNORECASE)
            if dir_match:
                dir_str = self._clean_text(dir_match.group(1))
        data["director"] = dir_str

        # --- Translator ---
        tr_str = buttons_meta.get("translator", "")
        if not tr_str:
            tr_match = re.search(r'(?:പരിഭാഷ|Translator)\s*[:\-–]\s*([^\n]+)', text, re.IGNORECASE)
            if tr_match:
                tr_str = self._clean_text(tr_match.group(1))
        data["translator"] = tr_str

        # --- Genres ---
        genres_str = buttons_meta.get("genres", "")
        if not genres_str:
            genres_list = []
            genre_match = re.search(r'(?:ജോണർ|Genre)\s*[:\-–]\s*([^\n]+)', text, re.IGNORECASE)
            if genre_match:
                for g in re.split(r'[,/ ]+', genre_match.group(1)):
                    g_clean = self._clean_text(g)
                    if g_clean in self.GENRE_MAP:
                        genres_list.append(self.GENRE_MAP[g_clean])
                    elif g_clean:
                        genres_list.append(g_clean)
            genres_str = ", ".join(genres_list)
        data["genres"] = genres_str

        # --- Release Type ---
        if any(w in text.lower() for w in ['#series', 'സീസൺ', 'season', 'എപ്പിസോഡ്', 'episode']):
            data["release_type"] = "series"
        else:
            data["release_type"] = "movie"

        # --- Description ---
        data["description"] = "\n\n".join(desc_lines)

        # --- Download URL & Slug ---
        data["download_url"] = download_url if download_url else data["source_url"]
        data["slug"] = self._make_slug(title_candidate, data["download_url"])

        return data

    def _parse_messages(self, messages: List[Any]) -> List[Dict[str, Any]]:
        """Group and parse MSone Telegram channel messages into subtitle release objects."""
        results = []
        curr_thumb = None

        for m in messages:
            post_id = m.get("data-post", "")

            # Check for photo wrap or reply thumb
            photo_wrap = m.find("a", class_="tgme_widget_message_photo_wrap") or m.find("i", class_="tgme_widget_message_photo_image") or m.find("i", class_="tgme_widget_message_reply_thumb")
            if photo_wrap:
                style_attr = photo_wrap.get("style", "") or photo_wrap.get("data-content", "")
                url_match = re.search(r'url\([\'"]?(.*?)[\'"]?\)', style_attr)
                if url_match:
                    curr_thumb = url_match.group(1)
                elif photo_wrap.find("img") and photo_wrap.find("img").get("src"):
                    curr_thumb = photo_wrap.find("img")["src"]

            text_div = m.find("div", class_="tgme_widget_message_text")
            if text_div:
                text = text_div.get_text("\n")
                if "Release" in text and len(text) > 40:
                    # Parse buttons and links in this message
                    download_url = ""
                    buttons_meta: Dict[str, Any] = {"genres_list": [], "lang_list": []}
                    for a in m.find_all("a", href=True):
                        href = a["href"]
                        a_text = self._clean_text(a.get_text())
                        if "/languages/" in href or "Download" in a_text or "ഡൗൺലോഡ്" in a_text:
                            if "malayalamsubtitles.org" in href:
                                download_url = href
                        elif "/category/" in href:
                            if a_text in self.LANGUAGE_MAP:
                                buttons_meta["lang_list"].append(self.LANGUAGE_MAP[a_text])
                            elif a_text:
                                buttons_meta["lang_list"].append(a_text.capitalize())
                        elif "/genres/" in href:
                            if a_text in self.GENRE_MAP:
                                buttons_meta["genres_list"].append(self.GENRE_MAP[a_text])
                            elif a_text:
                                buttons_meta["genres_list"].append(a_text.capitalize())
                        elif "/tag/" in href and a_text and not buttons_meta.get("translator"):
                            buttons_meta["translator"] = a_text
                        elif "?s=dir_" in href and not buttons_meta.get("director"):
                            buttons_meta["director"] = self._clean_text(href.split("dir_")[-1].replace("+", " "))
                        elif "imdb.com" in href:
                            buttons_meta["imdb_url"] = href

                    if buttons_meta["lang_list"]:
                        buttons_meta["language"] = ", ".join(buttons_meta["lang_list"])
                    if buttons_meta["genres_list"]:
                        buttons_meta["genres"] = ", ".join(buttons_meta["genres_list"])

                    # If this URL was also found in the RSS feed, upgrade to the HIGH QUALITY WordPress poster!
                    if download_url and download_url in self.rss_data:
                        rss_item = self.rss_data[download_url]
                        if rss_item.get("thumbnail_url") and "telesco.pe" not in rss_item["thumbnail_url"]:
                            curr_thumb = rss_item["thumbnail_url"]

                    item = self._parse_release_text(text, post_id, curr_thumb, download_url, buttons_meta)
                    
                    time_tag = m.find("time", class_="time")
                    if time_tag and time_tag.get("datetime"):
                        item["created_at"] = time_tag["datetime"]
                        item["updated_at"] = time_tag["datetime"]
                        
                    if item not in results:
                        results.append(item)

        return results

    def scrape_all(self, max_pages: int = 5) -> List[Dict[str, Any]]:
        """
        Scrape MSone via official Telegram channel (@msone) web preview.
        Bypasses Cloudflare entirely while retrieving canonical malayalamsubtitles.org URLs and rich metadata.
        Each page request fetches 20 messages (~15-20 releases).
        """
        all_items = []
        seen_slugs = set()
        next_before: Optional[int] = None

        # Pre-fetch the latest 15 releases from RSS to guarantee High-Quality WordPress posters
        self.logger.info("Pre-fetching high-quality posters from MSone RSS feed...")
        self.scrape_listing_page(1)

        for page in range(1, max_pages + 1):
            if page == 1:
                url = self.TELEGRAM_URL
            else:
                if not next_before:
                    self.logger.info(f"No older messages to paginate from page {page}, stopping.")
                    break
                url = f"{self.TELEGRAM_URL}?before={next_before}"

            self.logger.info(f"Scraping MSone Telegram page {page}/{max_pages} (url: {url})...")
            soup = self._fetch_page(url)
            if not soup:
                break

            messages = soup.find_all("div", class_="tgme_widget_message")
            if not messages:
                self.logger.info("No messages found on page, stopping.")
                break

            lowest_id = None
            for m in messages:
                post_id_str = m.get("data-post", "")
                if "/" in post_id_str:
                    try:
                        msg_num = int(post_id_str.split("/")[-1])
                        if lowest_id is None or msg_num < lowest_id:
                            lowest_id = msg_num
                    except ValueError:
                        pass

            next_before = lowest_id
            page_items = self._parse_messages(messages)
            for item in page_items:
                slug = item.get("slug", "")
                if slug and slug not in seen_slugs:
                    seen_slugs.add(slug)
                    all_items.append(item)
                    self.logger.info(f"  ✓ {item.get('title', 'Unknown')} (#{item.get('release_number', 'N/A')})")

        # Add items from RSS feed that were missed by Telegram (e.g. newly published on site only)
        rss_added = 0
        for rss_url, rss_item in self.rss_data.items():
            slug = rss_item.get("slug", "")
            if slug and slug not in seen_slugs:
                seen_slugs.add(slug)
                
                # Attempt to scrape the detail page to get missing metadata (poster, IMDb, release #).
                # If it gets blocked by Cloudflare, it automatically falls back to the partial rss_item.
                full_item = self.scrape_detail_page(rss_url)
                all_items.append(full_item)
                rss_added += 1
                self.logger.info(f"  ✓ {full_item.get('title', 'Unknown')} (from RSS)")
                
        if rss_added > 0:
            self.logger.info(f"Added {rss_added} items exclusively from RSS feed.")

        self.logger.info(f"Total scraped from {self.SITE_NAME} via Telegram & RSS: {len(all_items)} items")
        return all_items


if __name__ == "__main__":
    scraper = MSoneScraper()
    # Test with just 1 page
    results = scraper.scrape_all(max_pages=1)
    import json
    print(json.dumps(results, ensure_ascii=False, indent=2))
