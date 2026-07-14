"""
Scraper for moviemirrorsubtitles.com (Movie Mirror)
WordPress-based subtitle site with custom theme.

Site structure (from research):
- WordPress site with WPBakery Page Builder
- Uses 'Search & Filter' plugin
- Downloads via WP Download Manager plugin
- Has REST API at /wp-json/wp/v2/posts (WordPress default)
- Categories for languages, genres
- Custom post type for subtitles

Strategy:
1. Try WordPress REST API first (cleaner data)
2. Fall back to HTML scraping if API is restricted
"""

import re
from typing import Optional, Dict, Any, List
from urllib.parse import urljoin
from .base import BaseScraper


class MovieMirrorScraper(BaseScraper):
    SITE_NAME = "Movie Mirror (moviemirrorsubtitles.com)"
    SITE_KEY = "moviemirror"
    BASE_URL = "https://moviemirrorsubtitles.com"

    # WordPress REST API endpoint
    WP_API_URL = f"{BASE_URL}/wp-json/wp/v2"

    def _try_wp_api(self, page: int = 1, per_page: int = 20) -> Optional[List[Dict]]:
        """Try to use WordPress REST API to get posts."""
        url = f"{self.WP_API_URL}/posts?page={page}&per_page={per_page}&_embed"
        try:
            self.logger.info(f"Trying WP REST API: {url}")
            response = self.session.get(url, timeout=30)
            if response.status_code == 200:
                return response.json()
        except Exception as e:
            self.logger.warning(f"WP API not available: {e}")
        return None

    def scrape_listing_page(self, page_num: int) -> List[str]:
        """Scrape the listing page for subtitle post URLs."""
        # First try: WordPress REST API
        api_data = self._try_wp_api(page=page_num)
        if api_data:
            urls = []
            for post in api_data:
                link = post.get("link", "")
                if link:
                    urls.append(link)
            self.logger.info(f"  Found {len(urls)} posts via WP API on page {page_num}")
            self._rate_limit()
            return urls

        # Fallback: HTML scraping
        if page_num == 1:
            url = f"{self.BASE_URL}/"
        else:
            url = f"{self.BASE_URL}/page/{page_num}/"

        soup = self._fetch_page(url)
        if not soup:
            return []

        detail_urls = []
        # Look for post links - Movie Mirror uses card-style layouts
        # Find links within post containers
        for article in soup.find_all(["article", "div"], class_=re.compile(r'prod-blk|post|entry|blog')):
            for link in article.find_all("a", href=True):
                href = link["href"]
                if href.startswith(self.BASE_URL) and href != self.BASE_URL + "/":
                    if href not in detail_urls:
                        detail_urls.append(href)

        # If no articles found, try broader search for post links
        if not detail_urls:
            for link in soup.find_all("a", href=True):
                href = link["href"]
                # Filter for subtitle post URLs (avoid pages, categories, etc.)
                if (href.startswith(self.BASE_URL)
                    and href != self.BASE_URL + "/"
                    and not any(skip in href for skip in [
                        "/category/", "/tag/", "/page/", "/wp-", "/author/",
                        "/about", "/contact", "/feed", "#", "?", "/archives/",
                        ".css", ".js", ".png", ".jpg"
                    ])):
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
        """Scrape a Movie Mirror subtitle detail page."""
        soup = self._fetch_page(url)
        if not soup:
            return None

        try:
            data: Dict[str, Any] = {
                "source_site": self.SITE_KEY,
                "source_url": url,
            }

            # --- Title ---
            # Try h1 first, then page title
            h1 = soup.find("h1", class_="entry-title")
            if not h1:
                h1 = soup.find("h1")
            if h1:
                data["title"] = self._clean_text(h1.get_text())
            else:
                title_tag = soup.find("title")
                if title_tag:
                    title_text = self._clean_text(title_tag.get_text())
                    title_text = re.sub(r'\s*[-–].*മൂവി\s*മിറർ.*$', '', title_text)
                    data["title"] = title_text
                else:
                    data["title"] = "Unknown"

            data["year"] = self._extract_year(data["title"])

            # --- Thumbnail ---
            og_image = soup.find("meta", property="og:image")
            if og_image and og_image.get("content"):
                data["thumbnail_url"] = og_image["content"]
            else:
                # Look for featured image
                featured = soup.find("img", class_=re.compile(r'wp-post-image|featured|prod'))
                if featured and featured.get("src"):
                    data["thumbnail_url"] = featured["src"]
                else:
                    data["thumbnail_url"] = ""

            # --- Extract metadata from page content ---
            # Movie Mirror often has structured data in tables or labeled divs
            page_text = soup.get_text()

            # Language
            data["movie_language"] = self._extract_field(soup, page_text,
                ["language", "ഭാഷ", "lang"], "Unknown")

            # Genre
            genres = []
            # Check WordPress categories
            for cat_link in soup.find_all("a", href=re.compile(r'/category/')):
                cat_text = self._clean_text(cat_link.get_text())
                if cat_text and len(cat_text) < 30:
                    genres.append(cat_text)
            data["genres"] = ", ".join(genres) if genres else ""

            # Translator
            data["translator"] = self._extract_field(soup, page_text,
                ["translator", "subtitle by", "subtitled by", "പരിഭാഷ", "sub by"], "")

            # --- IMDB ---
            imdb_rating = None
            imdb_url = ""
            for link in soup.find_all("a", href=re.compile(r'imdb\.com')):
                imdb_url = link["href"]
                break
            rating_match = re.search(r'(\d+\.?\d*)\s*/\s*10', page_text)
            if rating_match:
                try:
                    imdb_rating = float(rating_match.group(1))
                except ValueError:
                    pass
            data["imdb_rating"] = imdb_rating
            data["imdb_url"] = imdb_url

            # --- Release Type ---
            title_lower = data["title"].lower()
            if "season" in title_lower or "series" in title_lower:
                data["release_type"] = "series"
            else:
                data["release_type"] = "movie"

            # --- Certificate ---
            data["certificate"] = ""

            # --- Download URL ---
            download_url = ""
            # Look for WP Download Manager links
            for link in soup.find_all("a", href=True):
                href = link["href"]
                link_text = self._clean_text(link.get_text()).lower()
                if any(kw in href.lower() for kw in ['download', '.srt', '.zip']):
                    download_url = href
                    break
                if any(kw in link_text for kw in ['download', 'ഡൗൺലോഡ്']):
                    download_url = href
                    break
            data["download_url"] = download_url if download_url else url

            # --- Description ---
            desc_parts = []
            content_div = soup.find("div", class_=re.compile(r'entry-content|post-content')) or soup.find("main")
            if content_div:
                for p in content_div.find_all("p"):
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

    def _extract_field(self, soup, page_text: str, keywords: list, default: str) -> str:
        """Try to extract a labeled field from the page."""
        # Search in table rows
        for table in soup.find_all("table"):
            for row in table.find_all("tr"):
                header = row.find("th")
                cell = row.find("td")
                if header and cell:
                    header_text = self._clean_text(header.get_text()).lower()
                    for kw in keywords:
                        if kw in header_text:
                            # Prevent 'ഭാഷ' from matching 'പരിഭാഷ'
                            if kw == "ഭാഷ" and "പരിഭാഷ" in header_text:
                                continue
                            return self._clean_text(cell.get_text())

        # Search in labeled divs/spans
        for kw in keywords:
            # Add a negative lookbehind to prevent matching "പരിഭാഷ" when searching for "ഭാഷ"
            prefix = r'(?<!പരി)' if kw == "ഭാഷ" else ''
            pattern = re.compile(rf'{prefix}{re.escape(kw)}\s*[:\-–]\s*(.+)', re.IGNORECASE)
            match = pattern.search(page_text)
            if match:
                value = match.group(1).strip()
                # Take only the first line
                value = value.split('\n')[0].strip()
                if len(value) < 100:
                    return value

        return default


if __name__ == "__main__":
    scraper = MovieMirrorScraper()
    results = scraper.scrape_all(max_pages=1)
    import json
    print(json.dumps(results, ensure_ascii=False, indent=2))
