import json
import os
import sys
import logging
from backend.scrapers.msone import MSoneScraper
from backend.scrapers.teamgoat import TeamGoatScraper
from backend.scrapers.moviemirror import MovieMirrorScraper
from backend.run_scraper import merge_results, save_data, load_existing_data

sys.stdout.reconfigure(encoding='utf-8')
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("continue")

def scrape_range(scraper, start_page, end_page):
    all_items = []
    seen_urls = set()
    for page in range(start_page, end_page + 1):
        logger.info(f"Scraping listing page {page}/{end_page}...")
        detail_urls = scraper.scrape_listing_page(page)
        if not detail_urls:
            logger.info(f"No more items on page {page}, stopping.")
            break
        for url in detail_urls:
            if url in seen_urls:
                continue
            seen_urls.add(url)
            item = scraper.scrape_detail_page(url)
            if item:
                all_items.append(item)
                logger.info(f"  ✓ {item.get('title', 'Unknown')}")
    return all_items

if __name__ == '__main__':
    existing_data = load_existing_data()
    
    # MSone has ~303 pages
    logger.info("Continuing MSone from page 51...")
    msone_items = scrape_range(MSoneScraper(), 51, 350)
    
    # TeamGoat and MovieMirror might have more than 50 pages too
    logger.info("Continuing TeamGoat from page 51...")
    goat_items = scrape_range(TeamGoatScraper(), 51, 150)
    
    logger.info("Continuing MovieMirror from page 51...")
    mirror_items = scrape_range(MovieMirrorScraper(), 51, 150)
    
    all_new = msone_items + goat_items + mirror_items
    logger.info(f"Found {len(all_new)} additional items!")
    
    merged = merge_results(existing_data, all_new)
    save_data(merged)
