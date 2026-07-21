# MSone Proxy — Cloudflare Worker Setup

This Worker proxies requests to `malayalamsubtitles.org` through Cloudflare's own edge network, bypassing the bot detection that blocks GitHub Actions' datacenter IPs.

## Quick Setup (5 minutes)

### 1. Install Wrangler CLI

```bash
npm install -g wrangler
```

### 2. Login to Cloudflare

```bash
wrangler login
```

This opens a browser window. Log in with your Cloudflare account (free tier is fine).

### 3. Deploy the Worker

```bash
cd cloudflare-worker
npx wrangler deploy
```

After deployment, you'll get a URL like:
```
https://msone-proxy.<your-subdomain>.workers.dev
```

### 4. (Optional) Set an Auth Token

For security, set an auth token so only your scraper can use the proxy:

```bash
npx wrangler secret put AUTH_TOKEN
# Enter a random string when prompted, e.g.: msone_scrape_2026_secret
```

### 5. Add the URL to GitHub Secrets

Go to your repo → Settings → Secrets and variables → Actions → New repository secret:

| Secret Name | Value |
|---|---|
| `MSONE_PROXY_URL` | `https://msone-proxy.<your-subdomain>.workers.dev` |
| `MSONE_PROXY_AUTH_TOKEN` | *(same token you set in step 4, or leave empty)* |

### 6. Test It

Open in browser:
```
https://msone-proxy.<your-subdomain>.workers.dev/?url=https://malayalamsubtitles.org/releases/
```

You should see the MSone releases page HTML.

## How It Works

```
GitHub Actions → Cloudflare Worker (edge network) → malayalamsubtitles.org
                 ↑ Trusted IP, not blocked          ↑ Sees Cloudflare IP, allows
```

## Costs

Cloudflare Workers free tier: **100,000 requests/day**. The scraper uses ~50-100 requests per run, so this is effectively unlimited for our use case.
