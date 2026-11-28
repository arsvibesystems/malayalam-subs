"""
Enrich and optionally sync subtitles data from the Stremio addons:
  - MSone: https://addon.malayalamsubtitles.org
  - Team GOAT + Movie Mirror: https://malayalam-subs.onrender.com

What this script does:
  1. Fetches catalog pages from both addons (concurrently, with retries).
  2. Matches addon entries to existing items in data/subtitles.json using:
     - Exact normalized source_url (from GOAT/MM addon descriptions)
     - IMDb ID (tt...) extracted from imdb_id / imdb_url
     - Normalized English title (+ year fallback) per source_site
  3. Enriches matched entries with:
     - thumbnail_url (upgrades empty, telesco.pe, or missing posters; uses addon poster)
     - backdrop_url (MSone full-res background)
     - imdb_id (tt...) and imdb_url
     - imdb_rating (when missing)
     - genres (fills empty genres, e.g. Movie Mirror, and adds K-Drama / festival tags)
     - year (when missing)
     - movie_language (extracted from Team GOAT addon footer when missing)
     - description (when missing or empty)
  4. Optionally adds genuinely new releases present in the addons (default: enabled).

Usage:
  python enrich_from_addons.py --full               # Scan all catalog pages from both addons
  python enrich_from_addons.py --pages 3            # Scan first 3 pages per catalog (fast incremental)
  python enrich_from_addons.py --no-add-new --full  # Only enrich existing items
"""

import argparse
import concurrent.futures
import json
import logging
import os
import re
import time
from datetime import datetime, timezone, timedelta
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import urlparse
from urllib.request import Request, urlopen

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("addon_enricher")

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
MSONE_ADDON_BASE = "https://addon.malayalamsubtitles.org"
GOAT_MM_ADDON_BASE = "https://malayalam-subs.onrender.com"

# Catalog definitions: (base_url, type, catalog_id, source_site, page_size, extra_genre_tag)
CATALOG_SPECS: List[Tuple[str, str, str, str, int, Optional[str]]] = [
    (MSONE_ADDON_BASE, "movie", "msone-movies", "msone", 20, None),
    (MSONE_ADDON_BASE, "series", "msone-series", "msone", 20, None),
    (MSONE_ADDON_BASE, "series", "msone-kdrama", "msone", 20, "K-Drama"),
    (GOAT_MM_ADDON_BASE, "movie", "goat-latest", "teamgoat", 24, None),
    (GOAT_MM_ADDON_BASE, "movie", "goat-movies", "teamgoat", 24, None),
    (GOAT_MM_ADDON_BASE, "series", "goat-series", "teamgoat", 24, None),
    (GOAT_MM_ADDON_BASE, "movie", "goat-festivals", "teamgoat", 24, None),
    (GOAT_MM_ADDON_BASE, "movie", "mm-latest", "moviemirror", 24, None),
    (GOAT_MM_ADDON_BASE, "movie", "mm-movies", "moviemirror", 24, None),
    (GOAT_MM_ADDON_BASE, "series", "mm-series", "moviemirror", 24, None),
]

MALAYALAM_LANG_MAP = {
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


def fetch_json(url: str, timeout: int = 25, retries: int = 2) -> Optional[Dict[str, Any]]:
    """Fetch JSON from an addon URL with retries."""
    for attempt in range(retries + 1):
        try:
            req = Request(
                url,
                headers={
                    "User-Agent": "MalayalamSubsEnricher/1.0",
                    "Accept": "application/json",
                },
            )
            with urlopen(req, timeout=timeout) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except Exception as exc:
            if attempt < retries:
                time.sleep(1.5 * (attempt + 1))
            else:
                logger.warning("Failed to fetch %s: %s", url, exc)
    return None


def extract_imdb_id(value: Optional[str]) -> str:
    """Extract canonical tt1234567 IMDb ID from an ID or IMDb URL."""
    if not value:
        return ""
    match = re.search(r"(tt\d{5,})", value)
    return match.group(1) if match else ""


def normalize_url(url: Optional[str]) -> str:
    """Normalize a site URL for reliable matching."""
    if not url:
        return ""
    parsed = urlparse(url.strip())
    if not parsed.netloc:
        return ""
    host = parsed.netloc.lower().removeprefix("www.")
    path = parsed.path.rstrip("/")
    return f"{host}{path}"


def extract_english_title(title: str) -> str:
    """Extract the English title portion without Malayalam text or year tags."""
    if not title:
        return ""
    # Split on slash or em-dash/en-dash separators commonly used for bilingual titles
    part = title.split("/")[0].split("–")[0].strip()
    # Movie Mirror often writes: "മലയാളം(English Title) 2021"
    paren_eng = re.search(r"\(([A-Za-z0-9][^()]{1,})\)", title)
    if re.search(r"[\u0D00-\u0D7F]", part) and paren_eng:
        part = paren_eng.group(1).strip()
    # Remove Malayalam script chars and trailing/embedded 4-digit years
    part = re.sub(r"[\u0D00-\u0D7F]+", " ", part)
    part = re.sub(r"\(\s*\d{4}\s*[-–]?\s*\)", " ", part)
    part = re.sub(r"\b(?:19|20)\d{2}\b\s*$", " ", part)
    part = re.sub(r"[^a-zA-Z0-9]+", " ", part).strip().lower()
    return part


def extract_year(value: Any) -> Optional[int]:
    """Parse a 4-digit year from releaseInfo or title."""
    if isinstance(value, int):
        return value
    if not value:
        return None
    match = re.search(r"\b((?:19|20)\d{2})\b", str(value))
    return int(match.group(1)) if match else None


def parse_addon_description(raw_desc: str, source_site: str) -> Tuple[str, str, str]:
    """
    Parse description, embedded source_url, and language from an addon meta description.
    Returns: (clean_description, source_url, language)
    """
    if not raw_desc:
        return "", "", ""
    lines = [line.strip() for line in raw_desc.strip().splitlines()]
    source_url = ""
    language = ""
    kept_lines: List[str] = []

    for line in lines:
        if line.startswith("http://") or line.startswith("https://"):
            if (
                (source_site == "teamgoat" and "malayalamsubtitles.in" in line)
                or (source_site == "moviemirror" and "moviemirrorsubtitles.com" in line)
            ):
                source_url = line
                continue
        if line.startswith("Malayalam subtitles from "):
            # Format: "Malayalam subtitles from Team GOAT · ഇന്തോനേഷ്യൻ"
            if "·" in line:
                raw_lang = line.split("·", 1)[1].strip()
                language = MALAYALAM_LANG_MAP.get(raw_lang, raw_lang)
            continue
        kept_lines.append(line)

    clean_desc = "\n".join(kept_lines).strip()
    return clean_desc, source_url, language


def fetch_catalog(
    base_url: str,
    media_type: str,
    catalog_id: str,
    source_site: str,
    page_size: int,
    extra_genre_tag: Optional[str],
    max_pages: int,
) -> List[Dict[str, Any]]:
    """Fetch up to max_pages of a single Stremio addon catalog."""
    items: List[Dict[str, Any]] = []
    seen_keys = set()
    consecutive_empty = 0

    for page_idx in range(max_pages):
        skip = page_idx * page_size
        if skip == 0:
            url = f"{base_url}/catalog/{media_type}/{catalog_id}.json"
        else:
            url = f"{base_url}/catalog/{media_type}/{catalog_id}/skip={skip}.json"

        data = fetch_json(url, timeout=35 if "onrender.com" in base_url else 25)
        metas = (data.get("metas") or []) if data else []
        if not metas:
            consecutive_empty += 1
            # Movie Mirror occasionally returns an empty page/timeout transiently before later pages
            max_empty = 2 if source_site == "moviemirror" else 1
            if consecutive_empty >= max_empty:
                break
            continue

        consecutive_empty = 0
        new_on_page = 0
        for meta in metas:
            meta_id = str(meta.get("id", ""))
            clean_desc, embedded_url, embedded_lang = parse_addon_description(
                meta.get("description", ""), source_site
            )
            dedup_key = (source_site, meta_id, embedded_url or meta.get("name", ""))
            if dedup_key in seen_keys:
                continue
            seen_keys.add(dedup_key)
            new_on_page += 1

            genres = list(meta.get("genres") or [])
            if extra_genre_tag and extra_genre_tag not in genres:
                genres.append(extra_genre_tag)

            imdb_id = extract_imdb_id(meta_id)
            items.append(
                {
                    "source_site": source_site,
                    "release_type": "series" if media_type == "series" else "movie",
                    "imdb_id": imdb_id,
                    "raw_id": meta_id,
                    "title": (meta.get("name") or "").strip(),
                    "poster": (meta.get("poster") or "").strip(),
                    "background": (meta.get("background") or "").strip(),
                    "description": clean_desc,
                    "source_url": embedded_url,
                    "movie_language": embedded_lang,
                    "year": extract_year(meta.get("releaseInfo")) or extract_year(meta.get("name")),
                    "imdb_rating": _safe_float(meta.get("imdbRating")),
                    "genres": genres,
                }
            )

        if len(metas) < page_size or new_on_page == 0:
            break

    logger.info("Catalog %s (%s): fetched %d entries", catalog_id, source_site, len(items))
    return items


def _safe_float(val: Any) -> Optional[float]:
    if val is None or val == "":
        return None
    try:
        return float(val)
    except (ValueError, TypeError):
        return None


def fetch_all_addon_catalogs(
    max_pages: int,
    sites: Optional[List[str]] = None,
) -> List[Dict[str, Any]]:
    """Fetch all configured catalogs in parallel and merge duplicates per site."""
    specs = [
        spec for spec in CATALOG_SPECS
        if not sites or spec[3] in sites
    ]
    all_raw: List[Dict[str, Any]] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
        futures = [
            executor.submit(fetch_catalog, *spec, max_pages)
            for spec in specs
        ]
        for fut in concurrent.futures.as_completed(futures):
            try:
                all_raw.extend(fut.result())
            except Exception as exc:
                logger.warning("Catalog fetch error: %s", exc)

    # Merge duplicate entries within the same site (e.g. goat-latest + goat-movies + goat-festivals,
    # or msone-series + msone-kdrama) so genres & metadata combine cleanly.
    merged: Dict[Tuple[str, str], Dict[str, Any]] = {}
    for entry in all_raw:
        key_id = normalize_url(entry["source_url"]) or entry["imdb_id"] or f"{extract_english_title(entry['title'])}:{entry['year'] or ''}:{entry['release_type']}"
        key = (entry["source_site"], key_id)
        if key not in merged:
            merged[key] = entry
        else:
            existing = merged[key]
            for g in entry["genres"]:
                if g not in existing["genres"]:
                    existing["genres"].append(g)
            if not existing["poster"] and entry["poster"]:
                existing["poster"] = entry["poster"]
            if not existing["background"] and entry["background"]:
                existing["background"] = entry["background"]
            if not existing["source_url"] and entry["source_url"]:
                existing["source_url"] = entry["source_url"]
            if not existing["movie_language"] and entry["movie_language"]:
                existing["movie_language"] = entry["movie_language"]
            if existing["imdb_rating"] is None and entry["imdb_rating"] is not None:
                existing["imdb_rating"] = entry["imdb_rating"]
            if len(entry["title"]) > len(existing["title"]):
                existing["title"] = entry["title"]

    result = list(merged.values())
    logger.info("Total unique addon entries collected: %d", len(result))
    return result


def _is_weak_poster(url: str) -> bool:
    return not url or "telesco.pe" in url


def _merge_genres(existing_genres: str, addon_genres: List[str]) -> str:
    if not addon_genres:
        return existing_genres
    current = [g.strip() for g in existing_genres.split(",") if g.strip()] if existing_genres else []
    lower_set = {g.lower() for g in current}
    for g in addon_genres:
        g_clean = g.strip()
        if g_clean and g_clean.lower() not in lower_set:
            current.append(g_clean)
            lower_set.add(g_clean.lower())
    return ", ".join(current)


def _make_addon_slug(entry: Dict[str, Any]) -> str:
    site = entry["source_site"]
    if entry["source_url"]:
        parts = [p for p in urlparse(entry["source_url"]).path.strip("/").split("/") if p]
        if parts:
            return f"{site}_{parts[-1]}"
    eng = extract_english_title(entry["title"])
    base = re.sub(r"[^a-z0-9]+", "-", eng).strip("-") or entry["raw_id"].replace(":", "-")
    if entry["year"] and str(entry["year"]) not in base:
        base = f"{base}-{entry['year']}"
    return f"{site}_{base}"


def enrich_dataset(
    db: List[Dict[str, Any]],
    addon_entries: List[Dict[str, Any]],
    add_new: bool = True,
) -> Tuple[List[Dict[str, Any]], Dict[str, int]]:
    """
    Match addon_entries against db, enrich missing/weak fields, and optionally append new releases.
    """
    stats = {
        "matched": 0,
        "posters_upgraded": 0,
        "backdrops_added": 0,
        "imdb_ids_added": 0,
        "ratings_added": 0,
        "genres_updated": 0,
        "years_added": 0,
        "new_added": 0,
    }

    # Build lookup indexes over existing db
    by_url: Dict[Tuple[str, str], int] = {}
    by_imdb: Dict[Tuple[str, str], int] = {}
    by_title_year: Dict[Tuple[str, str, str], int] = {}
    by_title_only: Dict[Tuple[str, str], List[int]] = {}
    existing_slugs = set()

    for idx, item in enumerate(db):
        site = item.get("source_site", "")
        existing_slugs.add(item.get("slug", ""))

        # Normalize existing imdb_id field if imdb_url already exists
        if not item.get("imdb_id") and item.get("imdb_url"):
            extracted = extract_imdb_id(item.get("imdb_url"))
            if extracted:
                item["imdb_id"] = extracted

        norm_u = normalize_url(item.get("source_url"))
        if norm_u:
            by_url[(site, norm_u)] = idx

        imdb_id = item.get("imdb_id") or extract_imdb_id(item.get("imdb_url"))
        if imdb_id:
            by_imdb[(site, imdb_id)] = idx

        eng = extract_english_title(item.get("title", ""))
        if eng:
            yr = str(item.get("year") or extract_year(item.get("title")) or "")
            if yr:
                by_title_year.setdefault((site, eng, yr), idx)
            by_title_only.setdefault((site, eng), []).append(idx)

    new_items: List[Dict[str, Any]] = []

    for entry in addon_entries:
        site = entry["source_site"]
        match_idx: Optional[int] = None

        norm_u = normalize_url(entry["source_url"])
        if norm_u and (site, norm_u) in by_url:
            match_idx = by_url[(site, norm_u)]
        elif entry["imdb_id"] and (site, entry["imdb_id"]) in by_imdb:
            match_idx = by_imdb[(site, entry["imdb_id"])]
        else:
            eng = extract_english_title(entry["title"])
            yr = str(entry["year"] or "")
            if eng and yr and (site, eng, yr) in by_title_year:
                match_idx = by_title_year[(site, eng, yr)]
            elif eng and (site, eng) in by_title_only:
                candidates = by_title_only[(site, eng)]
                if len(candidates) == 1:
                    match_idx = candidates[0]

        if match_idx is not None:
            stats["matched"] += 1
            item = db[match_idx]

            # Poster upgrade: replace empty, telesco.pe, or missing-image URLs; also prefer addon poster for MSone if currently TMDB
            cur_thumb = item.get("thumbnail_url", "")
            if entry["poster"] and (
                _is_weak_poster(cur_thumb)
                or (site == "msone" and "image.tmdb.org" in cur_thumb)
            ):
                item["thumbnail_url"] = entry["poster"]
                stats["posters_upgraded"] += 1

            # Backdrop (MSone full-res image)
            if entry["background"] and not item.get("backdrop_url"):
                item["backdrop_url"] = entry["background"]
                stats["backdrops_added"] += 1

            # IMDb ID & URL
            if entry["imdb_id"]:
                if not item.get("imdb_id"):
                    item["imdb_id"] = entry["imdb_id"]
                    stats["imdb_ids_added"] += 1
                if not item.get("imdb_url"):
                    item["imdb_url"] = f"https://www.imdb.com/title/{entry['imdb_id']}/"

            # IMDb rating
            if item.get("imdb_rating") is None and entry["imdb_rating"] is not None:
                item["imdb_rating"] = entry["imdb_rating"]
                stats["ratings_added"] += 1

            # Genres (fills 733 missing Movie Mirror genres & adds K-Drama/festival tags)
            merged_genres = _merge_genres(item.get("genres", ""), entry["genres"])
            if merged_genres != item.get("genres", ""):
                item["genres"] = merged_genres
                stats["genres_updated"] += 1

            # Year
            if not item.get("year") and entry["year"]:
                item["year"] = entry["year"]
                stats["years_added"] += 1

            # Language (from Team GOAT footer)
            if (not item.get("movie_language") or item.get("movie_language") == "Unknown") and entry["movie_language"]:
                item["movie_language"] = entry["movie_language"]

            # Description
            if not item.get("description") and entry["description"]:
                item["description"] = entry["description"]

        elif add_new:
            slug = _make_addon_slug(entry)
            if slug in existing_slugs:
                continue
            existing_slugs.add(slug)

            # Fallback source URL if addon didn't embed one (MSone)
            source_url = entry["source_url"]
            if not source_url:
                if site == "msone":
                    eng_q = extract_english_title(entry["title"]) or entry["title"]
                    source_url = f"https://malayalamsubtitles.org/?s={eng_q.replace(' ', '+')}"
                else:
                    source_url = "https://malayalamsubtitles.in/" if site == "teamgoat" else "https://moviemirrorsubtitles.com/"

            imdb_url = f"https://www.imdb.com/title/{entry['imdb_id']}/" if entry["imdb_id"] else ""
            new_item = {
                "title": entry["title"],
                "slug": slug,
                "thumbnail_url": entry["poster"],
                "backdrop_url": entry["background"] or entry["poster"],
                "movie_language": entry["movie_language"] or ("Korean" if "K-Drama" in entry["genres"] else ""),
                "genres": ", ".join(entry["genres"]),
                "imdb_rating": entry["imdb_rating"],
                "imdb_id": entry["imdb_id"],
                "imdb_url": imdb_url,
                "translator": "",
                "source_site": site,
                "source_url": source_url,
                "download_url": source_url,
                "release_type": entry["release_type"],
                "year": entry["year"],
                "certificate": "",
                "description": entry["description"],
                "release_number": None,
                "created_at": "",
                "updated_at": "",
            }
            new_items.append(new_item)
            stats["new_added"] += 1

    if new_items:
        # Place genuinely new addon items at the top with current timestamps
        base_dt = datetime.now(timezone.utc)
        for i, item in enumerate(reversed(new_items)):
            ts = (base_dt + timedelta(seconds=i)).isoformat()
            item["created_at"] = ts
            item["updated_at"] = ts
        db = new_items + db

    return db, stats


def run_enrichment(
    data_dir: str = DATA_DIR,
    max_pages: int = 3,
    add_new: bool = True,
    sites: Optional[List[str]] = None,
) -> Dict[str, int]:
    """Load subtitles.json, enrich from Stremio addons, and persist subtitles.json + stats.json."""
    subtitles_path = os.path.join(data_dir, "subtitles.json")
    with open(subtitles_path, "r", encoding="utf-8") as f:
        db = json.load(f)

    addon_entries = fetch_all_addon_catalogs(max_pages=max_pages, sites=sites)
    if not addon_entries:
        logger.warning("No addon entries fetched; skipping enrichment.")
        return {}

    updated_db, stats = enrich_dataset(db, addon_entries, add_new=add_new)

    with open(subtitles_path, "w", encoding="utf-8") as f:
        json.dump(updated_db, f, ensure_ascii=False, indent=2)

    # Rebuild stats.json using run_scraper.build_stats if available
    try:
        from run_scraper import build_stats
        stats_data = build_stats(updated_db)
        stats_path = os.path.join(data_dir, "stats.json")
        with open(stats_path, "w", encoding="utf-8") as f:
            json.dump(stats_data, f, ensure_ascii=False, indent=2)
    except Exception as exc:
        logger.warning("Could not rebuild stats.json: %s", exc)

    logger.info("Addon enrichment stats: %s", stats)
    return stats


def main():
    parser = argparse.ArgumentParser(description="Enrich subtitles.json from Stremio addons")
    parser.add_argument("--full", action="store_true", help="Fetch all catalog pages from both addons")
    parser.add_argument("--pages", type=int, default=3, help="Number of pages per catalog (default: 3)")
    parser.add_argument(
        "--sites",
        nargs="+",
        choices=["msone", "teamgoat", "moviemirror"],
        help="Optional subset of sites to enrich",
    )
    parser.add_argument("--no-add-new", action="store_true", help="Only enrich existing entries without adding new ones")
    args = parser.parse_args()

    max_pages = 250 if args.full else args.pages
    run_enrichment(max_pages=max_pages, add_new=not args.no_add_new, sites=args.sites)


if __name__ == "__main__":
    main()

