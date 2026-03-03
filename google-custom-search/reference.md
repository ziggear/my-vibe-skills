# Google Custom Search API – Reference

## API status (as of 2025)

The Custom Search JSON API is **closed to new customers**. Existing customers can continue using it until **January 1, 2027**. After that, an alternative must be used.

- [Official overview](https://developers.google.com/custom-search/v1/overview)
- Google recommends **Vertex AI Search** for searching up to 50 domains; for full web search they suggest contacting Google to express interest.

## Endpoint and method

- **URL:** `https://www.googleapis.com/custom-search/v1` (or `https://customsearch.googleapis.com/customsearch/v1` per newer reference)
- **Method:** GET (query parameters only; request body empty)

## Query parameters (summary)

### Required

| Parameter | Description |
|-----------|-------------|
| `key` | API key (from Google Cloud Console) |
| `cx` | Programmable Search Engine ID |
| `q` | Search query string (URL-encoded) |

### Optional (common)

| Parameter | Description | Notes |
|-----------|-------------|--------|
| `num` | Results per page | Integer 1–10, default 10 |
| `start` | 1-based index of first result | For pagination; API returns at most 100 results total |
| `hl` | Interface language | e.g. `en`, `zh-CN`; see [interface languages](https://developers.google.com/custom-search/docs/json_api_reference#interfaceLanguages) |
| `lr` | Restrict results to language | e.g. `lang_en`, `lang_zh-CN` |
| `gl` | Country boost (two-letter code) | Boosts results from that country |
| `safe` | SafeSearch | `active` or `off` (default) |
| `searchType` | Type of search | `image` for image search; omit for web |

### Optional (advanced)

- `dateRestrict` – restrict by date (e.g. `d7`, `w2`, `m1`, `y1`)
- `exactTerms`, `excludeTerms`, `fileType`, `siteSearch`, `siteSearchFilter`, `sort`, etc.  
Full list: [cse.list reference](https://developers.google.com/custom-search/v1/reference/rest/v1/cse/list).

## Response structure

- **items** – array of search results; each item typically has `title`, `link`, `snippet`; may have `pagemap` and other fields.
- **queries** – metadata (current request, `nextPage`, `previousPage` for pagination).
- **context** – search engine metadata.

If there are no results, `items` may be absent or an empty array.

## Pricing and quotas (existing customers only)

- **Free:** 100 search queries per day.
- **Paid:** Additional queries (e.g. $5 per 1,000 queries, up to 10,000 queries/day; confirm in [API Console](https://console.cloud.google.com/apis/dashboard) and billing docs).
- Monitoring: [Cloud Console API Dashboard](https://console.cloud.google.com/apis/dashboard); for advanced metrics, Google Cloud Operations (filter by `service = 'customsearch.googleapis.com'`).

## Alternatives (when API is unavailable or after 2027)

1. **Vertex AI Search** – For searching up to 50 domains; see [Vertex AI Search](https://cloud.google.com/generative-ai-app-builder/docs/introduction).
2. **Full web search** – Contact Google to express interest in a full web search product.
3. **Other search APIs** – Third-party or other providers (e.g. Bing Search API, SerpApi, etc.) if the use case allows; integration pattern (env-based key, GET request, parse JSON) is similar.

## Prerequisites (for existing API users)

1. **Programmable Search Engine** – Create and configure at [Programmable Search Engine control panel](https://programmablesearchengine.google.com/controlpanel/all); copy the Search engine ID (cx).
2. **API key** – In [Google Cloud Console](https://console.cloud.google.com/apis/credentials), enable “Custom Search API” and create an API key.
