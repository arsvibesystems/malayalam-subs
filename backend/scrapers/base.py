"""
Base scraper class with rate-limiting, retry logic, and common utilities.
All site-specific scrapers inherit from this.
"""

import time
import random
import logging
import requests
from bs4 import BeautifulSoup
from typing import Optional, Dict, Any, List

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)


class BaseScraper:
    """Base class for all subtitle site scrapers."""

    # Subclasses must set these
    SITE_NAME: str = ""
    SITE_KEY: str = ""
    BASE_URL: str = ""

    # Rate limiting: wait 2-4 seconds between requests to be respectful
    MIN_DELAY: float = 2.0
    MAX_DELAY: float = 4.0
    MAX_RETRIES: int = 3

    HEADERS = {
        "User-Agent": (
            "Mozilla/5.0 (Linux; Android 14; Pixel 8) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/126.0.0.0 Mobile Safari/537.36"
        ),
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9,ml;q=0.8",
    }

    def __init__(self):
        try:
            import cloudscraper
            self.session = cloudscraper.create_scraper(browser={'browser': 'chrome', 'platform': 'android', 'desktop': False})
        except ImportError:
            self.session = requests.Session()
            self.session.headers.update(self.HEADERS)
        self.logger = logging.getLogger(self.SITE_KEY or self.__class__.__name__)

    def _rate_limit(self):
        """Sleep a random interval between requests to avoid hammering the server."""
        delay = random.uniform(self.MIN_DELAY, self.MAX_DELAY)
        time.sleep(delay)

    def _fetch_page(self, url: str, retry: int = 0) -> Optional[BeautifulSoup]:
        """Fetch a URL and return parsed BeautifulSoup, with retry on failure."""
        try:
            self.logger.info(f"Fetching: {url}")
            response = self.session.get(url, timeout=30)
            response.raise_for_status()
            self._rate_limit()
            return BeautifulSoup(response.text, "lxml")
        except requests.RequestException as e:
            if retry < self.MAX_RETRIES:
                wait = (retry + 1) * 5
                self.logger.warning(f"Request failed ({e}), retrying in {wait}s... (attempt {retry + 1})")
                time.sleep(wait)
                return self._fetch_page(url, retry + 1)
            else:
                self.logger.error(f"Failed to fetch {url} after {self.MAX_RETRIES} retries: {e}")
                return None

    def _clean_text(self, text: Optional[str]) -> str:
        """Strip whitespace and normalize text."""
        if not text:
            return ""
        return " ".join(text.strip().split())

    def _extract_year(self, title: str) -> Optional[int]:
        """Try to extract a 4-digit year from a title string like 'Movie Name (2025)'."""
        import re
        match = re.search(r'\((\d{4})\)', title)
        if match:
            return int(match.group(1))
        return None

    def _make_slug(self, title: str, source_url: str) -> str:
        """Generate a unique slug from the source URL or title."""
        import re
        # Use the URL path as slug basis for uniqueness
        from urllib.parse import urlparse
        path = urlparse(source_url).path.strip("/")
        # Take the last meaningful segment
        parts = [p for p in path.split("/") if p]
        if parts:
            slug = f"{self.SITE_KEY}_{parts[-1]}"
        else:
            slug = re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')
            slug = f"{self.SITE_KEY}_{slug}"
        return slug

    def scrape_listing_page(self, page_num: int) -> List[str]:
        """
        Scrape a listing page and return detail page URLs.
        Must be implemented by subclasses.
        """
        raise NotImplementedError

    def scrape_detail_page(self, url: str) -> Optional[Dict[str, Any]]:
        """
        Scrape a detail page and return structured subtitle data.
        Must be implemented by subclasses.
        """
        raise NotImplementedError

    def scrape_all(self, max_pages: int = 5) -> List[Dict[str, Any]]:
        """
        Full scrape: iterate listing pages, then scrape each detail page.
        Default: first 5 pages (for incremental sync, set max_pages=1).
        """
        all_items = []
        seen_urls = set()

        for page in range(1, max_pages + 1):
            self.logger.info(f"Scraping listing page {page}/{max_pages}...")
            detail_urls = self.scrape_listing_page(page)

            if not detail_urls:
                self.logger.info(f"No more items on page {page}, stopping.")
                break

            for url in detail_urls:
                if url in seen_urls:
                    continue
                seen_urls.add(url)

                item = self.scrape_detail_page(url)
                if item:
                    all_items.append(item)
                    self.logger.info(f"  ✓ {item.get('title', 'Unknown')}")

        self.logger.info(f"Total scraped from {self.SITE_NAME}: {len(all_items)} items")
        return all_items
