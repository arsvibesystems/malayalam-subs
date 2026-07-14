import os
import sys
import logging

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from scrapers.msone import MSoneScraper
from scrapers.teamgoat import TeamGoatScraper
from scrapers.moviemirror import MovieMirrorScraper
from run_scraper import merge_results, save_data, load_existing_data, build_stats
import json

sys.stdout.reconfigure(encoding='utf-8')
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("deep-scrape")

def save_and_stats(data):
    # Sort and save
    filepath = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "subtitles.json")
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    # Generate and save stats
    stats = build_stats(data)
    stats_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "stats.json")
    with open(stats_path, "w", encoding="utf-8") as f:
        json.dump(stats, f, ensure_ascii=False, indent=2)
    
    logger.info(f"Progress Saved! Total Items: {len(data)}")

def scrape_robust():
    logger.info("=== Starting Robust Deep Scrape ===")
    data = load_existing_data()
    
    # 1. Team GOAT
    logger.info("--- Scraping Team GOAT ---")
    goat = TeamGoatScraper()
    goat_items = goat.scrape_all(max_pages=200) # Give plenty of room
    if goat_items:
        data = merge_results(data, goat_items)
        save_and_stats(data)
    
    # 2. Movie Mirror
    logger.info("--- Scraping Movie Mirror ---")
    mirror = MovieMirrorScraper()
    mirror_items = mirror.scrape_all(max_pages=200)
    if mirror_items:
        data = merge_results(data, mirror_items)
        save_and_stats(data)
        
    # 3. MSone (Incremental Save)
    logger.info("--- Scraping MSone (Iterative) ---")
    msone = MSoneScraper()
    
    # We will do chunks of 10 pages up to page 350
    CHUNK_SIZE = 10
    MAX_PAGES = 350
    
    seen_urls = set()
    for chunk_start in range(1, MAX_PAGES + 1, CHUNK_SIZE):
        chunk_end = min(chunk_start + CHUNK_SIZE - 1, MAX_PAGES)
        logger.info(f"MSone Chunk: Pages {chunk_start} to {chunk_end}")
        
        chunk_items = []
        stop_early = False
        
        for page in range(chunk_start, chunk_end + 1):
            logger.info(f"MSone Page {page}/{MAX_PAGES}...")
            detail_urls = msone.scrape_listing_page(page)
            if not detail_urls:
                logger.info(f"No more items on MSone page {page}, stopping MSone early.")
                stop_early = True
                break
                
            for url in detail_urls:
                if url in seen_urls:
                    continue
                seen_urls.add(url)
                item = msone.scrape_detail_page(url)
                if item:
                    chunk_items.append(item)
                    logger.info(f"  ✓ {item.get('title', 'Unknown')}")
        
        if chunk_items:
            data = merge_results(data, chunk_items)
            save_and_stats(data)
            
        if stop_early:
            break

    logger.info("=== Robust Deep Scrape Finished! ===")

if __name__ == '__main__':
    scrape_robust()
