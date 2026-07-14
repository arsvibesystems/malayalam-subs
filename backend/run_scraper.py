"""
Main scraper runner — orchestrates all 3 site scrapers and outputs JSON data.
This is what GitHub Actions runs every 6 hours.

Usage:
    python run_scraper.py              # Scrape first 2 pages (incremental)
    python run_scraper.py --full       # Full scrape (all pages)
    python run_scraper.py --pages 5    # Scrape first 5 pages
"""

import json
import os
import sys
import argparse
import logging
from datetime import datetime, timezone, timedelta
from typing import List, Dict, Any

# Add parent dir to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from scrapers.msone import MSoneScraper
from scrapers.teamgoat import TeamGoatScraper
from scrapers.moviemirror import MovieMirrorScraper

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("main")

# Output directory for JSON data
DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")


def merge_results(existing: List[Dict], new_items: List[Dict]) -> List[Dict]:
    """
    Merge new scraped items into existing data.
    Uses 'slug' as unique key — updates existing items, adds new ones.
    """
    existing_map = {item["slug"]: item for item in existing}

    # We want new items to retain the order they were scraped in (newest first).
    # Since datetime.now() inside a loop gives increasing timestamps,
    # sorting by updated_at descending would reverse the order!
    # Instead, we assign a decreasing timestamp artificially for the scrape batch.
    base_time = datetime.now(timezone.utc)
    
    for i, item in enumerate(new_items):
        slug = item.get("slug", "")
        if not slug:
            continue

        # Subtract milliseconds so earlier items get NEWER timestamps
        item_time = (base_time - timedelta(milliseconds=i*10)).isoformat()

        if slug in existing_map:
            # Update existing item but keep the original created_at
            old_created = existing_map[slug].get("created_at")
            existing_map[slug].update(item)
            if old_created:
                existing_map[slug]["created_at"] = old_created
            existing_map[slug]["updated_at"] = item_time
        else:
            # New item
            item["created_at"] = item_time
            item["updated_at"] = item_time
            existing_map[slug] = item

    # Sort by updated_at descending (newest first)
    merged = sorted(
        existing_map.values(),
        key=lambda x: x.get("updated_at", ""),
        reverse=True
    )

    return merged


def load_existing_data() -> List[Dict]:
    """Load existing JSON data file if it exists."""
    filepath = os.path.join(DATA_DIR, "subtitles.json")
    if os.path.exists(filepath):
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            logger.warning(f"Could not load existing data: {e}")
    return []


def save_data(data: List[Dict]):
    """Save scraped data to JSON files."""
    os.makedirs(DATA_DIR, exist_ok=True)

    # Main data file
    filepath = os.path.join(DATA_DIR, "subtitles.json")
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    logger.info(f"Saved {len(data)} items to {filepath}")

    # Build filter/stats metadata
    stats = build_stats(data)
    stats_path = os.path.join(DATA_DIR, "stats.json")
    with open(stats_path, "w", encoding="utf-8") as f:
        json.dump(stats, f, ensure_ascii=False, indent=2)
    logger.info(f"Saved stats to {stats_path}")


def build_stats(data: List[Dict]) -> Dict[str, Any]:
    """Build stats and filter options from the data."""
    languages = set()
    genres = set()
    translators = set()
    sources = set()
    release_types = set()

    for item in data:
        # Languages
        lang = item.get("movie_language", "")
        if lang:
            for l in lang.split(","):
                l = l.strip()
                if l:
                    languages.add(l)

        # Genres
        genre = item.get("genres", "")
        if genre:
            for g in genre.split(","):
                g = g.strip()
                if g:
                    genres.add(g)

        # Translators
        translator = item.get("translator", "")
        if translator:
            translators.add(translator)

        # Sources
        source = item.get("source_site", "")
        if source:
            sources.add(source)

        # Release types
        rt = item.get("release_type", "")
        if rt:
            release_types.add(rt)

    return {
        "total_count": len(data),
        "last_updated": datetime.now(timezone.utc).isoformat(),
        "per_source": {
            source: {
                "total": len([d for d in data if d.get("source_site") == source]),
                "movies": len([d for d in data if d.get("source_site") == source and d.get("release_type", "").lower() == "movie"]),
                "series": len([d for d in data if d.get("source_site") == source and d.get("release_type", "").lower() == "series"]),
            }
            for source in sources
        },
        "filters": {
            "languages": sorted(languages),
            "genres": sorted(genres),
            "translators": sorted(translators),
            "sources": sorted(sources),
            "release_types": sorted(release_types),
        }
    }


def main():
    parser = argparse.ArgumentParser(description="Malayalam Subtitles Scraper")
    parser.add_argument("--full", action="store_true", help="Full scrape (all pages)")
    parser.add_argument("--pages", type=int, default=2, help="Number of pages to scrape (default: 2)")
    parser.add_argument("--sites", nargs="+", default=["msone", "teamgoat", "moviemirror"],
                        choices=["msone", "teamgoat", "moviemirror"],
                        help="Which sites to scrape")
    args = parser.parse_args()

    max_pages = 500 if args.full else args.pages

    logger.info(f"=== Malayalam Subtitles Scraper ===")
    logger.info(f"Pages: {'ALL' if args.full else max_pages}, Sites: {args.sites}")
    logger.info(f"Started at: {datetime.now(timezone.utc).isoformat()}")

    # Load existing data
    existing_data = load_existing_data()
    logger.info(f"Existing data: {len(existing_data)} items")

    # Run scrapers
    all_new_items: List[Dict] = []

    scrapers = {
        "msone": MSoneScraper,
        "teamgoat": TeamGoatScraper,
        "moviemirror": MovieMirrorScraper,
    }

    for site_key in args.sites:
        try:
            scraper = scrapers[site_key]()
            items = scraper.scrape_all(max_pages=max_pages)
            all_new_items.extend(items)
            logger.info(f"  {site_key}: scraped {len(items)} items")
        except Exception as e:
            logger.error(f"  {site_key}: FAILED - {e}")

    # Merge with existing data
    merged_data = merge_results(existing_data, all_new_items)

    # Save
    save_data(merged_data)

    logger.info(f"=== Done! Total items: {len(merged_data)} ===")
    logger.info(f"  New items added: {len(merged_data) - len(existing_data)}")
    logger.info(f"Finished at: {datetime.now(timezone.utc).isoformat()}")


if __name__ == "__main__":
    main()
