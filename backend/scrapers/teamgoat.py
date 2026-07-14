"""
Scraper for malayalamsubtitles.in (Team GOAT)
Community-driven subtitle team with well-structured detail pages.

Site structure (from research):
- Listing: / (homepage), /1/, /2/, etc. (paginated)
- Detail: /release/{slug}
- Data points: title, language, director, translator, genre, IMDB, download link
- Download: wp.malayalamsubtitles.in/download/{id} (Cloudflare protected)
- Note: HTML is server-rendered, all data visible in page source
"""

import re
from typing import Optional, Dict, Any, List
from .base import BaseScraper


class TeamGoatScraper(BaseScraper):
    SITE_NAME = "Team GOAT (malayalamsubtitles.in)"
    SITE_KEY = "teamgoat"
    BASE_URL = "https://malayalamsubtitles.in"

    def scrape_listing_page(self, page_num: int) -> List[str]:
        """Scrape the homepage/paginated listing for detail page URLs."""
        if page_num == 1:
            url = f"{self.BASE_URL}/"
        else:
            url = f"{self.BASE_URL}/{page_num - 1}/"

        soup = self._fetch_page(url)
        if not soup:
            return []

        detail_urls = []
        # Find all links to /release/ pages
        for link in soup.find_all("a", href=re.compile(r'/release/')):
            href = link["href"]
            # Normalize URL
            if href.startswith("/"):
                href = f"{self.BASE_URL}{href}"
            if href not in detail_urls:
                detail_urls.append(href)

        # Deduplicate
        seen = set()
        unique_urls = []
        for u in detail_urls:
            if u not in seen:
                seen.add(u)
                unique_urls.append(u)

        self.logger.info(f"  Found {len(unique_urls)} detail URLs on page {page_num}")
        return unique_urls

    def scrape_detail_page(self, url: str) -> Optional[Dict[str, Any]]:
        """Scrape a Team GOAT detail page for subtitle metadata."""
        soup = self._fetch_page(url)
        if not soup:
            return None

        try:
            data: Dict[str, Any] = {
                "source_site": self.SITE_KEY,
                "source_url": url,
            }

            # --- Title ---
            h1 = soup.find("h1")
            if h1:
                data["title"] = self._clean_text(h1.get_text())
            else:
                # Fallback to <title>
                title_tag = soup.find("title")
                if title_tag:
                    title_text = self._clean_text(title_tag.get_text())
                    title_text = re.sub(r'\s*[-–]\s*Team GOAT.*$', '', title_text)
                    data["title"] = title_text
                else:
                    data["title"] = "Unknown"

            data["year"] = self._extract_year(data["title"])

            # --- Thumbnail / Poster ---
            # The main poster image is in the detail page with class 'card-image'
            poster_img = soup.find("img", class_="card-image")
            if poster_img and poster_img.get("src"):
                src = poster_img["src"]
                if src.startswith("/"):
                    src = f"{self.BASE_URL}{src}"
                data["thumbnail_url"] = src
            else:
                og_image = soup.find("meta", property="og:image")
                data["thumbnail_url"] = og_image["content"] if og_image else ""

            # --- Table data (Language, Director, Translator, Genre) ---
            language = ""
            director = ""
            translator = ""
            genre = ""

            table = soup.find("table", id="movie-posttable")
            if not table:
                # Fallback: find any table
                table = soup.find("table", class_="table")

            if table:
                for row in table.find_all("tr"):
                    header = row.find("th")
                    cell = row.find("td")
                    if header and cell:
                        header_text = self._clean_text(header.get_text()).lower()
                        cell_text = self._clean_text(cell.get_text())

                        if "പരിഭാഷ" in header_text or "translat" in header_text:
                            # Check if there's a link (translator profile)
                            translator_link = cell.find("a")
                            if translator_link:
                                translator = self._clean_text(translator_link.get_text())
                            else:
                                translator = cell_text
                        elif "ഭാഷ" in header_text or "language" in header_text:
                            language = cell_text
                        elif "സംവിധാനം" in header_text or "director" in header_text:
                            director = cell_text
                        elif "genre" in header_text:
                            genre = cell_text

            # Map Malayalam language names to English
            language_map = {
                "ഇംഗ്ലീഷ്": "English",
                "കൊറിയൻ": "Korean",
                "ഹിന്ദി": "Hindi",
                "ജാപ്പനീസ്": "Japanese",
                "ഫ്രഞ്ച്": "French",
                "സ്പാനിഷ്": "Spanish",
                "മലയാളം": "Malayalam",
                "തമിഴ്": "Tamil",
                "തെലുഗ്": "Telugu",
                "മാൻഡറിൻ": "Mandarin",
                "തായ്": "Thai",
            }
            data["movie_language"] = language_map.get(language, language)
            data["genres"] = genre
            data["translator"] = translator

            # --- IMDB Rating ---
            imdb_rating = None
            imdb_url = ""
            for link in soup.find_all("a", href=re.compile(r'imdb\.com')):
                imdb_url = link["href"]
                # Look for rating text near the IMDB link
                parent = link.parent
                if parent:
                    rating_match = re.search(r'(\d+\.?\d*)\s*/\s*10', parent.get_text())
                    if rating_match:
                        try:
                            imdb_rating = float(rating_match.group(1))
                        except ValueError:
                            pass
                break

            # Also search for rating in the broader page
            if imdb_rating is None:
                match = re.search(r'★\s*(\d+(?:\.\d+)?)/10', soup.get_text())
                if not match:
                    # sometimes the star is separated by newlines
                    match = re.search(r'(\d+(?:\.\d+)?)/10', soup.get_text())
                if match:
                    try:
                        imdb_rating = float(match.group(1))
                    except ValueError:
                        pass

            data["imdb_rating"] = imdb_rating
            data["imdb_url"] = imdb_url

            # --- Release Type ---
            title_lower = data["title"].lower()
            if "season" in title_lower or "സീസൺ" in data["title"]:
                data["release_type"] = "series"
            else:
                data["release_type"] = "movie"

            # --- Certificate ---
            data["certificate"] = ""

            # --- Download URL ---
            # Team GOAT uses wp.malayalamsubtitles.in/download/{id}
            # These are Cloudflare protected, so we'll store the URL
            # but redirect to the detail page in-app if direct download fails
            download_btn = soup.find("a", class_="download-button")
            if download_btn and download_btn.get("href"):
                data["download_url"] = download_btn["href"]
            else:
                # Fallback: look for any download link
                for link in soup.find_all("a", href=re.compile(r'download')):
                    data["download_url"] = link["href"]
                    break
                else:
                    # Last resort: use the source page URL
                    data["download_url"] = url

            # --- Description ---
            description = ""
            main_content = soup.find("main", id="post") or soup.find("main")
            if main_content:
                # Get paragraphs that contain the description (after the table)
                paragraphs = main_content.find_all("p")
                desc_parts = []
                for p in paragraphs:
                    text = self._clean_text(p.get_text())
                    # Filter out short texts, links, buttons
                    if len(text) > 50 and "ടീം" not in text[:10]:
                        desc_parts.append(text)
                if desc_parts:
                    description = "\n\n".join(desc_parts)  # Keep all paragraphs
            data["description"] = description

            # --- Release Number ---
            release_match = re.search(r'(?:റിലീസ്|Release)\s*[:\-–]\s*(\d+)', soup.get_text(), re.IGNORECASE)
            data["release_number"] = int(release_match.group(1)) if release_match else None

            # --- Slug ---
            data["slug"] = self._make_slug(data["title"], url)

            return data

        except Exception as e:
            self.logger.error(f"Error parsing {url}: {e}")
            return None


if __name__ == "__main__":
    scraper = TeamGoatScraper()
    results = scraper.scrape_all(max_pages=1)
    import json
    print(json.dumps(results, ensure_ascii=False, indent=2))
