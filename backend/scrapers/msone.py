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
from .base import BaseScraper


class MSoneScraper(BaseScraper):
    SITE_NAME = "MSone (malayalamsubtitles.org)"
    SITE_KEY = "msone"
    BASE_URL = "https://malayalamsubtitles.org"

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

    def scrape_listing_page(self, page_num: int) -> List[str]:
        """Scrape the releases listing page for detail page URLs."""
        if page_num == 1:
            url = f"{self.BASE_URL}/releases/"
        else:
            url = f"{self.BASE_URL}/releases/page/{page_num}/"

        soup = self._fetch_page(url)
        if not soup:
            return []

        detail_urls = []
        # MSone uses links that contain /languages/ in the path for detail pages
        for link in soup.find_all("a", href=True):
            href = link["href"]
            if "/languages/" in href and href.startswith(self.BASE_URL):
                # Avoid duplicates and non-detail pages
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
        soup = self._fetch_page(url)
        if not soup:
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


if __name__ == "__main__":
    scraper = MSoneScraper()
    # Test with just 1 page
    results = scraper.scrape_all(max_pages=1)
    import json
    print(json.dumps(results, ensure_ascii=False, indent=2))
