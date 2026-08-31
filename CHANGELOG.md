# Changelog

## 0.2.0

- The default base URL is now `https://api.fxmacrodata.com`, the canonical host
  (`fxmacrodata.com/api` was an undocumented alias). Pass `base_url=` to override.

- **API keys are now sent as an `X-API-Key` header instead of an `api_key` query
  parameter.** A key in the query string is recorded by every proxy, CDN and
  server access log along the request path, and can leak through `Referer`
  headers. Query-parameter auth is still available via `Client(auth_mode=:query)`
  for callers behind something that cannot forward the header.
- `Client` gained an `auth_mode` keyword, validated to `:header` or `:query`.

## 0.1.0

- Initial release: `announcements`, `release_calendar`, `forex`, `cot`,
  `commodity`, `data_catalogue`, `health`, `ping`, plus the `get_json` /
  `get_data` escape hatches.
