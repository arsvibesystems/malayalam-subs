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
import time
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


def assign_interleaved_timestamps(items: List[Dict]) -> List[Dict]:
    """
    Assign updated_at timestamps that interleave items across all sites
    based on their release_number (or position for sites without it).
    
    This ensures the JSON order reflects true chronological publication
    order across all 3 subtitle sites, not just scrape-time ordering.
    """
    from collections import defaultdict

    # Group by source site
    by_site = defaultdict(list)
    for item in items:
        by_site[item.get("source_site", "unknown")].append(item)

    # Sort each site's items oldest → newest
    # MSone & TeamGoat: by release_number
    # MovieMirror: by release_number if available, else by existing updated_at
    for site, site_items in by_site.items():
        if site in ("msone", "teamgoat"):
            site_items.sort(key=lambda x: x.get("release_number") or 0)
        else:
            # MovieMirror: try release_number first, fall back to updated_at
            has_rn = any(x.get("release_number") for x in site_items)
            if has_rn:
                site_items.sort(key=lambda x: x.get("release_number") or 0)
            else:
                site_items.sort(key=lambda x: x.get("updated_at", ""))

    # Assign chronological percentage (0.0 = oldest, 1.0 = newest)
    all_items = []
    for site, site_items in by_site.items():
        for i, item in enumerate(site_items):
            item["_chrono_pct"] = i / max(1, len(site_items) - 1)
            all_items.append(item)

    # Sort all items by percentage; use year as tiebreaker
    all_items.sort(key=lambda x: (x["_chrono_pct"], x.get("year") or 0))

    # Assign new timestamps: 1 hour apart starting from 2020-01-01
    base_date = datetime(2020, 1, 1, tzinfo=timezone.utc)
    for i, item in enumerate(all_items):
        new_date = base_date + timedelta(hours=i)
        item["updated_at"] = new_date.isoformat()
        item["created_at"] = new_date.isoformat()
        del item["_chrono_pct"]

    # Reverse to newest-first
    all_items.reverse()
    return all_items


def merge_results(existing: List[Dict], new_items: List[Dict]) -> List[Dict]:
    """
    Merge new scraped items into existing data.
    Uses 'slug' as unique key — updates existing items, adds new ones.
    
    Key design decisions:
    - Re-scraped existing items: content is updated but timestamps are PRESERVED
    - Genuinely new items: added with a temporary timestamp, then the full list
      is re-interleaved using release_number-based chronological ordering
    """
    existing_map = {item["slug"]: item for item in existing}
    has_new = False

    for item in new_items:
        slug = item.get("slug", "")
        if not slug:
            continue

        if slug in existing_map:
            # EXISTING item re-scraped: update content but PRESERVE timestamps
            old_created = existing_map[slug].get("created_at")
            old_updated = existing_map[slug].get("updated_at")
            existing_map[slug].update(item)
            if old_created:
                existing_map[slug]["created_at"] = old_created
            if old_updated:
                existing_map[slug]["updated_at"] = old_updated
        else:
            # GENUINELY NEW item
            now_str = datetime.now(timezone.utc).isoformat()
            item["created_at"] = now_str
            item["updated_at"] = now_str
            existing_map[slug] = item
            has_new = True
            logger.info(f"  ★ New item: {slug}")

    merged = list(existing_map.values())

    if has_new:
        # New items were added — re-interleave everything to slot them correctly
        logger.info("Re-interleaving timestamps to incorporate new items...")
        merged = assign_interleaved_timestamps(merged)
    else:
        # No new items — just keep existing order (sorted by updated_at desc)
        merged.sort(key=lambda x: x.get("updated_at", ""), reverse=True)

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

            # Safeguard: 0 items almost certainly means a transient failure
            # (e.g. Cloudflare challenge, timeout). Retry with backoff.
            if len(items) == 0:
                MAX_RETRIES = 2
                for attempt in range(1, MAX_RETRIES + 1):
                    logger.warning(
                        f"  {site_key}: got 0 items — likely blocked/timeout. "
                        f"Retrying in 30s (attempt {attempt}/{MAX_RETRIES})..."
                    )
                    time.sleep(30)
                    scraper = scrapers[site_key]()  # fresh session
                    items = scraper.scrape_all(max_pages=max_pages)
                    if len(items) > 0:
                        logger.info(f"  {site_key}: retry succeeded with {len(items)} items")
                        break
                else:
                    logger.error(
                        f"  ⚠ {site_key}: still 0 items after {MAX_RETRIES} retries! "
                        f"Site may be blocking this IP."
                    )

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
