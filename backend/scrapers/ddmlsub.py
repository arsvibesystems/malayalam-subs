"""
Scraper for DDs Malayalam Subtitles (@ddmlsub Telegram Channel)
Uses public web preview at https://t.me/s/ddmlsub (no API key or auth required).

Site structure:
- Listing/Preview: https://t.me/s/ddmlsub?before={id} (paginated, 20 messages per page)
- Sequential pattern: Photo (poster) -> Text (metadata) -> Document (.srt file)
"""

import re
from typing import Optional, Dict, Any, List
from bs4 import BeautifulSoup
from .base import BaseScraper


class DdmlSubScraper(BaseScraper):
    SITE_NAME = "DDs Malayalam Subtitles (Telegram)"
    SITE_KEY = "ddmlsub"
    BASE_URL = "https://t.me/s/ddmlsub"

    # Respectful rate limiting for Telegram web preview
    MIN_DELAY = 3.0
    MAX_DELAY = 5.0

    def __init__(self):
        super().__init__()

    def _make_slug(self, title: str, source_url: str) -> str:
        """Generate a unique slug combining title and telegram message ID."""
        post_id = source_url.split('/')[-1] if '/' in source_url else ''
        slug_part = re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')
        if post_id and post_id.isdigit():
            return f"{self.SITE_KEY}_{slug_part}_{post_id}"
        return f"{self.SITE_KEY}_{slug_part}"

    def scrape_listing_page(self, page_num: int) -> List[str]:
        """Not used when scrape_all is overridden, but implemented for interface compatibility."""
        return []

    def scrape_detail_page(self, url: str) -> Optional[Dict[str, Any]]:
        """Not used when scrape_all is overridden."""
        return None

    def _parse_release_text(self, text: str, post_id: str, thumb_url: Optional[str]) -> Dict[str, Any]:
        """Parse structured release metadata from Telegram post text."""
        lines = [self._clean_text(l) for l in text.split('\n') if self._clean_text(l) and l.strip() != '▪️']

        data: Dict[str, Any] = {
            "source_site": self.SITE_KEY,
            "source_url": f"https://t.me/{post_id}" if post_id else "",
            "thumbnail_url": thumb_url or "",
            "imdb_url": "",
            "certificate": "",
        }

        # --- Release Number ---
        rn_match = re.search(r'(?:റിലീസ്|റീലിസ്|Release)\s*[-–: ]*\s*(\d+)', text, re.IGNORECASE)
        if rn_match:
            data["release_number"] = int(rn_match.group(1))
        else:
            data["release_number"] = None

        # --- Title & Year ---
        title_candidate = "Unknown"
        year = None
        eng_title = ""
        ml_title = ""

        for line in lines[:6]:  # Look in the first few lines of text
            if any(w in line.lower() for w in ['റിലീസ്', 'റീലിസ്', 'release', 'imdb', 'rating', 'ഭാഷ', 'സംവിധാനം', 'പരിഭാഷ', 'ജോണർ']):
                continue
            ym = re.search(r'\((\d{4})\)', line)
            if ym:
                year = int(ym.group(1))
                line_clean = re.sub(r'\s*\(\d{4}\)', '', line).strip()
                if re.search(r'[a-zA-Z]', line_clean):
                    eng_title = f"{line_clean} ({year})"
                else:
                    ml_title = line_clean
            elif len(line) > 2 and not eng_title and not ml_title:
                if re.search(r'[a-zA-Z]', line):
                    eng_title = line
                else:
                    ml_title = line

        if eng_title and ml_title:
            title_candidate = f"{eng_title} / {ml_title}"
        elif eng_title:
            title_candidate = eng_title
        elif ml_title:
            title_candidate = ml_title if not year else f"{ml_title} ({year})"

        data["title"] = title_candidate
        data["year"] = year or self._extract_year(title_candidate)

        # --- IMDb Rating ---
        imdb_match = re.search(r'(\d+(?:\.\d+)?)\s*/\s*10', text)
        data["imdb_rating"] = float(imdb_match.group(1)) if imdb_match else None

        # --- Language ---
        lang_match = re.search(r'(?:ഭാഷ|Language)\s*[:\-–]\s*([^\n]+)', text, re.IGNORECASE)
        if lang_match:
            raw_lang = self._clean_text(lang_match.group(1)).replace('▪️', '').strip()
            lang_map = {
                "ഇംഗ്ലീഷ്": "English", "കൊറിയൻ": "Korean", "ഹിന്ദി": "Hindi",
                "ജാപ്പനീസ്": "Japanese", "ഫ്രഞ്ച്": "French", "സ്പാനിഷ്": "Spanish",
                "മലയാളം": "Malayalam", "തമിഴ്": "Tamil", "തെലുഗ്": "Telugu",
                "മാൻഡറിൻ": "Mandarin", "തായ്": "Thai", "Turkish": "Turkish",
                "ടർക്കിഷ്": "Turkish", "ജർമൻ": "German", "റഷ്യൻ": "Russian"
            }
            data["movie_language"] = lang_map.get(raw_lang, raw_lang)
        else:
            data["movie_language"] = ""

        # --- Director ---
        dir_match = re.search(r'(?:സംവിധാനം|Director)\s*[:\-–]\s*([^\n]+)', text, re.IGNORECASE)
        data["director"] = self._clean_text(dir_match.group(1)).replace('▪️', '').strip() if dir_match else ""

        # --- Translator ---
        tr_match = re.search(r'(?:പരിഭാഷ|Translator)\s*[:\-–]\s*([^\n]+)', text, re.IGNORECASE)
        data["translator"] = self._clean_text(tr_match.group(1)).replace('▪️', '').strip() if tr_match else ""

        # --- Genre ---
        genres = []
        genre_match = re.search(r'(?:ജോണർ|Genre)\s*[:\-–]\s*([^\n]+)', text, re.IGNORECASE)
        if genre_match:
            g_text = genre_match.group(1)
            genres.extend([self._clean_text(g).replace('#', '') for g in re.split(r'[,/ ]+', g_text) if self._clean_text(g) and g != '▪️'])
        # Also include hashtags found in text
        for tag in re.findall(r'#(\w+)', text):
            if tag.lower() not in [g.lower() for g in genres]:
                genres.append(tag)
        data["genres"] = ", ".join(genres)

        # --- Release Type ---
        if any(w in text.lower() for w in ['#series', 'സീസൺ', 'season', 'എപ്പിസോഡ്', 'episode', 'ongoing']):
            data["release_type"] = "series"
        else:
            data["release_type"] = "movie"

        # --- Description ---
        desc_lines = []
        capture_desc = False
        for line in lines:
            if any(w in line for w in ['കഥാവിവരണം', '👇', 'പോസ്റ്റർ', 'ജോണർ', '#']):
                capture_desc = True
                continue
            if any(w in line for w in ['ഡി.ഡി മലയാളത്തിന്റെ', '@ddmlsub', 'അറിവിലേക്കായി', '👉🏻']):
                continue
            if capture_desc and len(line) > 15:
                desc_lines.append(line)
        if not desc_lines:
            for line in lines:
                if len(line) > 40 and not any(w in line for w in ['റിലീസ്', 'ഭാഷ', 'സംവിധാനം', 'പരിഭാഷ', 'ജോണർ', 'ഡി.ഡി മലയാളത്തിന്റെ']):
                    desc_lines.append(line)
        data["description"] = "\n\n".join(desc_lines)

        # --- Slug ---
        data["slug"] = self._make_slug(title_candidate, data["source_url"])

        return data

    def _parse_messages(self, messages: List[Any]) -> List[Dict[str, Any]]:
        """Group and parse Telegram HTML message divs into subtitle release objects."""
        results = []
        curr_thumb = None
        curr_item = None

        for m in messages:
            post_id = m.get("data-post", "")

            # Check for photo poster
            photo_wrap = m.find("a", class_="tgme_widget_message_photo_wrap") or m.find("i", class_="tgme_widget_message_photo_image")
            if photo_wrap:
                style_attr = photo_wrap.get("style", "") or photo_wrap.get("data-content", "")
                url_match = re.search(r'url\([\'"]?(.*?)[\'"]?\)', style_attr)
                if not url_match and photo_wrap.find("img"):
                    img_tag = photo_wrap.find("img")
                    if img_tag and img_tag.get("src"):
                        curr_thumb = img_tag["src"]
                elif url_match:
                    curr_thumb = url_match.group(1)

            # Check for metadata text post
            text_div = m.find("div", class_="tgme_widget_message_text")
            if text_div:
                text = text_div.get_text("\n")
                if any(k in text for k in ['റിലീസ്', 'റീലിസ്', 'Release', 'IMDb', 'IMDB']) and len(text) > 40:
                    curr_item = self._parse_release_text(text, post_id, curr_thumb)
                    curr_item["download_url"] = f"https://t.me/{post_id}" if post_id else self.BASE_URL

            # Check for attached document (.srt / .zip file)
            doc_wrap = m.find("a", class_="tgme_widget_message_document_wrap")
            if doc_wrap and curr_item:
                doc_link = doc_wrap.get("href", "")
                if doc_link:
                    curr_item["download_url"] = doc_link
                if curr_item not in results:
                    results.append(curr_item)
            elif curr_item and curr_item not in results:
                # If no doc attached immediately, still record the release with post url as download
                results.append(curr_item)

        return results

    def scrape_all(self, max_pages: int = 5) -> List[Dict[str, Any]]:
        """
        Scrape Telegram channel web preview pages chronologically backwards.
        Each page request fetches 20 messages (~6 releases), minimizing HTTP requests.
        """
        all_items = []
        seen_slugs = set()
        next_before: Optional[int] = None

        for page in range(1, max_pages + 1):
            if page == 1:
                url = self.BASE_URL
            else:
                if not next_before:
                    self.logger.info(f"No older messages to paginate from page {page}, stopping.")
                    break
                url = f"{self.BASE_URL}?before={next_before}"

            self.logger.info(f"Scraping Telegram page {page}/{max_pages} (url: {url})...")
            soup = self._fetch_page(url)
            if not soup:
                break

            messages = soup.find_all("div", class_="tgme_widget_message")
            if not messages:
                self.logger.info("No messages found on page, stopping.")
                break

            # Find lowest message ID on this page for reverse pagination
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

            # Group and parse messages on this page
            page_items = self._parse_messages(messages)
            for item in page_items:
                slug = item.get("slug", "")
                if slug and slug not in seen_slugs:
                    seen_slugs.add(slug)
                    all_items.append(item)
                    self.logger.info(f"  ✓ {item.get('title', 'Unknown')} (#{item.get('release_number', 'N/A')})")

        self.logger.info(f"Total scraped from {self.SITE_NAME}: {len(all_items)} items")
        return all_items


if __name__ == "__main__":
    scraper = DdmlSubScraper()
    results = scraper.scrape_all(max_pages=1)
    import json
    print(json.dumps(results, ensure_ascii=True, indent=2))
