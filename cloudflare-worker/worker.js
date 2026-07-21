/**
 * Cloudflare Worker — MSone Proxy
 *
 * Proxies requests to malayalamsubtitles.org from within Cloudflare's own
 * edge network. This bypasses bot-detection that blocks datacenter IPs
 * (like GitHub Actions runners).
 *
 * Usage:
 *   GET https://<your-worker>.workers.dev/?url=https://malayalamsubtitles.org/releases/
 *
 * Security:
 *   - Only proxies requests to malayalamsubtitles.org (no open relay)
 *   - Optional AUTH_TOKEN header for access control
 */

const ALLOWED_ORIGIN = 'malayalamsubtitles.org';

export default {
  async fetch(request, env) {
    // --- Auth check (optional, if AUTH_TOKEN is set in Worker env) ---
    if (env.AUTH_TOKEN) {
      const authHeader = request.headers.get('X-Auth-Token');
      if (authHeader !== env.AUTH_TOKEN) {
        return new Response('Unauthorized', { status: 401 });
      }
    }

    // --- Parse the target URL from query param ---
    const url = new URL(request.url);
    const targetUrl = url.searchParams.get('url');

    if (!targetUrl) {
      return new Response(
        JSON.stringify({
          error: 'Missing ?url= parameter',
          usage: 'GET /?url=https://malayalamsubtitles.org/releases/',
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // --- Security: only allow malayalamsubtitles.org ---
    let parsed;
    try {
      parsed = new URL(targetUrl);
    } catch {
      return new Response('Invalid URL', { status: 400 });
    }

    if (!parsed.hostname.endsWith(ALLOWED_ORIGIN)) {
      return new Response(
        JSON.stringify({ error: `Only ${ALLOWED_ORIGIN} is allowed` }),
        {
          status: 403,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // --- Proxy the request with browser-like headers ---
    try {
      const proxyResponse = await fetch(targetUrl, {
        method: 'GET',
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
          'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9,ml;q=0.8',
          'Accept-Encoding': 'gzip',
          'Cache-Control': 'no-cache',
        },
        // Cloudflare Workers follow redirects by default
        redirect: 'follow',
      });

      // Return the proxied response with CORS headers
      const responseHeaders = new Headers(proxyResponse.headers);
      responseHeaders.set('Access-Control-Allow-Origin', '*');
      // Remove security headers that might interfere
      responseHeaders.delete('Content-Security-Policy');
      responseHeaders.delete('X-Frame-Options');

      return new Response(proxyResponse.body, {
        status: proxyResponse.status,
        headers: responseHeaders,
      });
    } catch (err) {
      return new Response(
        JSON.stringify({ error: `Proxy fetch failed: ${err.message}` }),
        {
          status: 502,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }
  },
};
