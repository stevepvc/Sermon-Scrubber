# AI Usage Tracking Overview

The Sermon Scrubber app now records detailed usage for every interaction with the OpenAI and Anthropic APIs so that monthly token consumption and estimated costs can be audited.

## What gets recorded

Each API response is inspected for the provider-reported usage section. When usage data is present the app records:

- Timestamp of the request.
- Provider (`OpenAI` or `Anthropic`).
- Model name (for example `gpt-4o` or `claude-3-7-sonnet-20250219`).
- Input and output token counts.
- An estimated dollar cost based on the current rate card.
- Contextual metadata (chunk indices, prompt identifiers, character counts, etc.).

Records are stored in `UserDefaults` as JSON so that they persist between launches. The default rate card can be updated inside `AIUsageTracker` when pricing changes.

## Accessing usage data

The `AIUsageTracker` singleton exposes a few helpers for auditing consumption:

- `usageEntries()` returns the full history of request records.
- `monthlySummary(containing:)` provides a roll-up for the month containing the supplied date.
- `monthlySummaries(limit:)` generates descending chronological summaries so you can render reports or dashboards.

A `MonthlyUsageSummary` contains total requests, token counts, estimated spend, and a provider breakdown (`ProviderUsageSummary`) so you can attribute costs to Anthropic or OpenAI.

## Using the data for financial planning

To balance subscription revenue against API spend, call `AIUsageTracker.shared.monthlySummary()` at the close of each billing cycle. The summary gives you:

- **Total token consumption** for the month.
- **Estimated dollar spend**, using the configured per-model rates.
- **Provider-level breakdowns** to highlight where optimizations may be needed.

Combine these metrics with your subscriber counts and price points to monitor gross margins, adjust rate cards, or flag heavy users who may require usage-based pricing.

> Tip: If you integrate server-side reporting, serialize the summary output and sync it with your backend analytics platform so you can join it with Stripe subscription data or other financial KPIs.
