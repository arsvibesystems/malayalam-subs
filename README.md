# 🎬 മലയാളം Subs — Malayalam Subtitles Aggregator

An Android app that aggregates Malayalam subtitles from multiple community-driven subtitle websites into one searchable, filterable, premium interface.

## 📱 Features

- **Unified Browse**: Subtitles from 3 major sites in one place
  - [MSone](https://malayalamsubtitles.org/) — ~3700+ releases
  - [Team GOAT](https://malayalamsubtitles.in/) — Community translations
  - [Movie Mirror](https://moviemirrorsubtitles.com/) — Quality subtitles
- **Smart Search**: Search by title, translator, language, genre
- **Advanced Filters**: Filter by language, genre, IMDB rating, translator, source site, movie/series
- **Auto-Sync**: GitHub Actions scrapes new subtitles every 6 hours
- **Direct Download**: Tap to download SRT files or open in browser
- **Premium Dark UI**: Netflix-style grid with IMDB badges, source badges, hero animations

## 🏗️ Architecture

```
├── backend/                    # Python scrapers
│   ├── scrapers/
│   │   ├── base.py            # Base scraper with rate limiting
│   │   ├── msone.py           # malayalamsubtitles.org scraper
│   │   ├── teamgoat.py        # malayalamsubtitles.in scraper
│   │   └── moviemirror.py     # moviemirrorsubtitles.com scraper
│   ├── run_scraper.py         # Main runner
│   └── requirements.txt
├── app/                       # Flutter Android app
│   └── lib/
│       ├── main.dart
│       ├── models/            # Data models
│       ├── providers/         # State management
│       ├── screens/           # UI screens
│       ├── services/          # API service
│       ├── theme/             # Design system
│       └── widgets/           # Reusable widgets
├── data/                      # Scraped JSON data (auto-updated)
│   ├── subtitles.json
│   └── stats.json
└── .github/workflows/         # GitHub Actions (auto-scrape)
    └── scrape.yml
```

## 🚀 Getting Started

### 1. Set up the Backend (Scraper)

```bash
cd backend
pip install -r requirements.txt
python run_scraper.py --pages 3         # Scrape first 3 pages
python run_scraper.py --full            # Full scrape (all pages)
python run_scraper.py --sites msone     # Scrape only MSone
```

### 2. Push to GitHub for Auto-Sync

1. Create a GitHub repo
2. Push this project
3. Enable GitHub Actions
4. The scraper will run every 6 hours automatically
5. Update the `_baseUrl` in `app/lib/services/api_service.dart` with your GitHub raw URL:
   ```
   https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/data
   ```

### 3. Build the Flutter App

```bash
cd app
flutter pub get
flutter run            # Run on connected device/emulator
flutter build apk      # Build release APK
```

## ⚙️ Configuration

### Data URL
Update `app/lib/services/api_service.dart`:
```dart
static const String _baseUrl = 'https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/data';
```

### Scraper Rate Limiting
The scrapers wait 2-4 seconds between requests to be respectful. This is configurable in `backend/scrapers/base.py`.

## 📋 Disclaimer

This app is for **personal use only**. The subtitle data belongs to the respective community teams (MSone, Team GOAT, Movie Mirror). NOC will be obtained from the websites before any public release.
