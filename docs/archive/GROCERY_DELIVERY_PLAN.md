# CraveCircle — Grocery delivery integration (Blinkit / Zepto / Instamart / Milkbasket)

Goal the user wants: grocery list → tap "order" → items go to Blinkit/Zepto/etc. pre-filled
(quantity 1 by default) → user tweaks quantity → one tap places the order.

## The honest reality (2026)
**None of Blinkit, Zepto, Swiggy Instamart, or Milkbasket offer a public ordering API.** There is no
developer program that lets a third-party app build a cart or place an order on a user's behalf. Their
catalog, cart, and checkout are closed. So the seamless "set quantity → tap order" flow **cannot be
built through official means with these apps directly.**

Two things also block a true cart even if an API existed:
- **SKU mapping.** These apps sell specific products ("Amul Butter 100g", "Onion 1kg"), not free-text
  "butter". Turning our "1 tbsp butter" into a purchasable SKU needs their catalog — which we can't access.
- **Payment + credentials.** Placing an order means handling the user's account + payment. We never do
  that (and shouldn't) — it belongs in their own app where they're logged in.

## The three real options

### Option A — Deep-link hand-off (free, ships now) ✅ recommended MVP
We can't build their cart, but we **can** open their app pre-searched for each item. Per grocery item:
a small "Order on Blinkit / Zepto / Instamart" that opens `https://blinkit.com/s/?q=<item>` (or the app
via its universal link), where the user adds it and checks out **in their app, logged in, paying there**.
- **Cost:** ₹0. **Effort:** small.
- **UX:** not one-tap-order — it's "hand me to Blinkit with this item searched." The user still taps add
  in Blinkit. But it removes the retyping and is genuinely useful.
- **Quantity:** we default each item to qty 1 and let the user set it; the quantity travels in the
  search/label, but the actual cart quantity is set in their app.
- **Risk:** these deep-link URLs are undocumented and can change; keep them in config so they're easy to fix.

### Option B — ONDC buyer app (real ordering, strategic, has cost)
**ONDC** (Open Network for Digital Commerce — India's govt-backed open commerce network) is the *only*
legitimate way to place real grocery orders across sellers programmatically. We'd build CraveCircle as
an **ONDC Buyer App**: browse the catalog, build a cart, and place orders that route to sellers on the
network.
- **Feasibility:** real, but a significant project — register as an ONDC Network Participant (Buyer App),
  integrate the ONDC protocol (search / select / init / confirm), handle payment + order status.
- **Coverage caveat:** grocery/quick-commerce coverage on ONDC varies; Blinkit/Zepto/Instamart are **not**
  guaranteed to be sellers there (verify current coverage before committing). You'd be ordering from
  whichever grocery sellers *are* on ONDC, not necessarily those four brands.
- **Cost:** ONDC registration/compliance, integration dev time, and possible per-transaction/network fees.
  This is a strategic bet, not an MVP feature.

### Option C — Affiliate / partnership (could earn, not cost)
Zepto/Blinkit run affiliate and partnership programs at times. An **affiliate deep link** can pay us a
commission when a user orders through it — turning Option A from free into *revenue*. Worth an outreach
email to their partnerships teams. No public self-serve API, but a direct partnership might expose more.

## Recommended plan
1. **Now (Option A):** add a "Shop this list" flow — each item gets a qty stepper (default 1) and a
   hand-off button to the user's preferred app (setting: Blinkit / Zepto / Instamart / Milkbasket), plus
   a "Copy list" fallback. Keep the deep-link templates in config. Free, useful, ships this week.
2. **Explore (Option C):** email Zepto/Blinkit partnerships about affiliate/ordering access. If they
   offer affiliate links, swap Option A's links for affiliate ones — same UX, now earning.
3. **Strategic (Option B):** if grocery ordering becomes a core pillar, scope an ONDC buyer-app
   integration. Verify ONDC grocery coverage first; budget for registration + dev + fees.

## What NOT to do
- Don't automate/scrape their web checkout or store user credentials/payment — against their ToS, breaks
  constantly, and unsafe. Ordering stays in the user's own logged-in app (Option A) or via ONDC (Option B).

**Bottom line:** the exact one-tap-order-into-Blinkit flow isn't possible today (no API). The realistic
path is **Option A now** (free hand-off with per-item quantity), **Option C** to maybe monetize it, and
**Option B (ONDC)** only if grocery ordering becomes a strategic pillar.
