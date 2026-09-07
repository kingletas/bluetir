# Bluetir

[![CI](https://github.com/kingletas/bluetir/actions/workflows/ci.yml/badge.svg)](https://github.com/kingletas/bluetir/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.3-CC342D.svg)](https://www.ruby-lang.org)

Bluetir drives a real browser through a Magento storefront to prove a deployment works. It adds products to the cart, places an order, and checks that every page along the way says what it should. When something is wrong it exits non-zero, so a deploy script or a git hook can stop.

It was written in 2013 against Magento 1. This version runs on Ruby 3.3+, Watir 7 and Selenium 4, and targets Magento 2.

## What makes it different from a normal test suite

The storefront is described in YAML, not in Ruby. Every selector Bluetir clicks or fills lives in a profile file. Testing a different store means writing another profile, not editing code.

That's why four profiles ship. They drive the same flows through markup that has almost nothing in common:

| Profile | Frontend | Verified against |
|---|---|---|
| `magento2.yml` | Luma, Magento's own theme | `magento.demo.magecom.net` — 19/19 selectors |
| `hyva.yml` | Hyvä — Tailwind and Alpine, with Hyvä Checkout | `demo.hyva.io` — 17/17 |
| `scandipwa.yml` | ScandiPWA — a React app over GraphQL | `tech-demo.scandipwa.com` — 14/14 |
| `magento1.yml` | Magento 1 one-page checkout | nothing; Magento 1 is gone |

Each has a ready-made config under `etc/stores/`. The differences the profile format has to absorb turn out to be large: Hyvä has no quantity field on a product page and puts shipping and payment on one screen with no button between them, and ScandiPWA renders a delivery option as a **button** rather than a radio.

## Getting started

You need Ruby 3.3 or newer and Chrome or Chromium. Selenium finds the driver on its own, so there's nothing else to install.

```bash
make setup
```

Copy the sample config and point it at your store:

```bash
make config
```

Open `etc/bluetir.yml` and change `base_url`. Then check that everything resolves before you open a browser:

```bash
make plan
```

You'll see what a run would do — which store, which profile, how many products, how many assertions — and it touches nothing. If a file is missing or a selector is malformed, it tells you here instead of halfway through a checkout.

When the plan looks right:

```bash
make run
```

## The four files

Everything lives under `etc/`, and paths inside the config are relative to the config itself.

| File | What it holds |
|---|---|
| `bluetir.yml` | The store to test, and which of the other three files to use |
| `storefronts/*.yml` | Every selector, path and expected string for one kind of store |
| `orders/*.yml` | What to buy and who is buying it |
| `assertions/*.yml` | Text that has to appear on each page |

### Writing a selector

A selector says what kind of element it is and how to find it:

```yaml
add_to_cart_button: { type: button, id: product-addtocart-button }
address_city:       { type: text_field, css: "#shipping-new-address-form input[name='city']" }
shipping_method:    { type: radio, css: "input[value='flatrate_flatrate']" }
```

`type` is a Watir element type — `button`, `text_field`, `select_list`, `radio`, `checkbox`, `div`, `link`, or `element` for anything else. Everything after it is how Watir should locate it.

If a flow needs a selector your profile doesn't have, Bluetir says which profile and which selector, rather than failing somewhere inside Selenium.

### Writing an assertion

```yaml
cart:
  - expect:
      - "Shopping Cart"
      - "Estimate Shipping and Tax"
```

A section listed here gets checked. A section you leave out runs nothing, which is fine. An assertions file that defines no expectations at all is refused, because a file that can never fail looks exactly like a file that always passes.

**Matching ignores case**, and that isn't laziness. A theme that sets `text-transform: uppercase` makes the browser report `IN STOCK` for markup that says `In stock`, so an expectation written by reading the page source fails against the rendered page — for a reason nobody can see.

## Finding out what a profile gets wrong

Writing selectors from a theme's documentation and discovering during a checkout which ones were wrong is the slow way round. `probe` loads each page once and reports where every selector in the profile actually resolves:

```bash
bluetir --mode probe -c etc/stores/hyva.yml
```

```text
  home       https://demo.hyva.io/default
  product    https://demo.hyva.io/default/atlas-pouf.html
  cart       https://demo.hyva.io/default/checkout/cart/
  checkout   https://demo.hyva.io/default/checkout/

  add_to_cart_button         product, after-add
  add_to_cart_confirmation   after-add
  checkout_email             checkout
  payment_method             not visited (stage: payment)
```

Three things in that output are the point.

**It says where each page landed.** A store redirects an empty cart away from the checkout, so a failed add-to-cart shows up three pages later as "nothing found on the checkout". Without the landing line that's a mystery; with it, `<- REDIRECTED` tells you immediately.

**`after-add` is a page.** A confirmation message is gone by the next page load, so what's on screen right after the add has to be counted there and then.

**A selector can name the `stage` it lives on.** Luma's payment method only exists once the shipping step is done, and the probe doesn't drive that far. It reports those rather than failing them — a column that cries wolf is a column you stop reading.

It adds one product to the cart, because a cart page with nothing in it can't tell you whether its selectors are right. **It never places an order.**

## Being a good guest

Bluetir drives somebody else's shop. By default it waits **one second between page loads** and identifies itself in the user agent as `Bluetir/<version>` with a link to this repository, so a storefront owner reading their logs can tell an automated check from a customer.

Raise the delay for a store you don't own:

```yaml
http:
  delay: 2.0
```

## Sending what the store needs

A staging site behind a header, a store view chosen by a cookie, a currency chosen by a query parameter, a bot filter that wants a real browser's user agent — without these the suite tests a different site and tells you nothing about the one you meant.

```yaml
http:
  user_agent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/140.0 Safari/537.36"
  delay: 2.0
  headers:
    X-Staging-Auth: "let-me-in"
  cookies:
    - { name: "store", value: "default", domain: ".example.test" }
  params:
    ___store: "default"
```

`params` are appended to **every** URL the suite visits, which is why navigation goes through one place rather than being spelled out on each code path. Headers are set over CDP, so a browser that can't do that gets a warning rather than a crash. Cookies need a page on the domain first, so the session loads the store's front page and throws it away before adding them.

## When a store paints late

A React storefront has nothing on screen when the document is complete, and Alpine hasn't yet wired Hyvä's add-to-cart button. A click that lands before it does **silently does nothing** — and shows up much later as an empty cart. `settle` waits after each page load:

```yaml
settle: 4     # Hyvä
settle: 10    # ScandiPWA
```

Luma needs none.

## Acceptance testing: baseline, then compare

An assertions file only knows what somebody thought to write down. A **baseline** knows what was actually there, so it catches the selector nobody remembered to assert on.

```bash
bluetir --mode baseline -c etc/stores/magecom-luma.yml
```

That records every selector that resolved, where each page landed, and each page's title. Afterwards, on any deploy:

```bash
bluetir --mode acceptance -c etc/stores/magecom-luma.yml
```

```text
  nothing has changed since 2026-09-07T15:46:30Z
```

**It's silent when the store hasn't moved.** Everything it prints is a difference, and only some differences fail the run:

| Change | Verdict |
|---|---|
| A selector that resolved and now doesn't | **REGRESSION** |
| A page that now answers from somewhere else | **REGRESSION** |
| A selector that moved to a different page | reported |
| A selector that's new | reported |
| A page title that changed | reported |

Baselines aren't committed — a baseline belongs to one store at one moment, and yours isn't mine.

## Personas: a real person, all the way to the button

A persona is an archetype — *someone on a phone who buys one thing* — and each run gives it a fresh invented identity from a seeded generator.

```bash
bluetir --mode persona -c etc/stores/magecom-luma.yml
```

```text
  Deliberate researcher — 3 product(s), browses a category, searches, desktop — Blythe Grimaldi of Savannah
    reached a checkout ready to place
  Phone impulse buyer — 1 product(s), mobile — Fenna Nakamura of Boise
    reached a checkout ready to place
  personas ran with seed 20260907
```

Each shopper sizes the window to their device, lands on the home page, browses a category and searches if that's how they shop, fills a basket, and completes the checkout with their own name and address.

**It stops at the last button.** It checks that Place Order is there and usable, and doesn't click it. That's a separate method rather than a flag, so no call site can place an order by getting an argument wrong.

The seed is always printed, because a persona failure is worth nothing if it can't be repeated:

```bash
bluetir --mode persona --seed 20260907 -c etc/stores/magecom-luma.yml
```

Personas live in `etc/personas.yml`. Their identities are generated: names come from a fixed pool, city, region and postcode are kept together so a store's address validation accepts them, and every email is at `example.test`, which RFC 6761 reserves and which can never reach a real mailbox.

## The modes

`order` is the default: add the products, get a shipping quote, check out, place the order. It's the only mode that places one.

`pages` visits every URL named in the assertions file and checks the text on each. Use it when you want a fast sweep after a deploy without placing an order. An assertion entry with a `url` is swept; one without is checked in place by whichever flow reaches that page, which is how the cart and the order confirmation are covered.

```bash
bluetir --mode pages
```

## Stopping a bad deploy

`hooks/pre-receive` refuses a push when Bluetir can't place an order. Copy it into a bare repository's `hooks/` directory and set `BLUETIR_CONFIG` to the config for the store that repository deploys to.

Push with `BLUETIR_FORCE=1` to deploy anyway.

## Running the checks

```bash
make check
```

That's RuboCop plus the unit suite, and it needs no browser. It's what a commit has to pass.

```bash
make test-browser
```

That drives the real flows through headless Chromium against a small static storefront built in a temp directory. It proves the selectors resolve and the flows work without needing a Magento anywhere. It's kept out of `make check` so a commit never waits on a browser.

## What isn't verified

**No order has been placed through any of these profiles.** Every step up to the final button is verified against a live store; the button itself isn't, because pressing it puts a real order on somebody else's system. Run `--mode order` yourself against a store you own.

The Magento 1 profile can't be verified at all. Magento 1 reached end of life in June 2020 and the demo stores Bluetir originally pointed at are gone. It's kept because it's the same suite described by different data, which is the whole point of the format.

## Email

If you set `smtp_server` and `recipients`, Bluetir emails the outcome when a run finishes. The subject says what actually happened — passed, failed with a count, or nothing was proven. There's no default recipient, and with nothing configured it sends nothing.

## Where to go next

- [docs/from-nothing.md](docs/from-nothing.md) — from a clone to a persona run in five minutes
- [CONTRIBUTING.md](CONTRIBUTING.md) — the gate, and the shape a change should arrive in
- [SECURITY.md](SECURITY.md) — how to report something privately

## Known issues

**A Hyvä cart assertion failed on about half of runs, and the cause was us.** The page had no text at all when the check ran, and the diagnostic that reports what the page *did* say answered it: `429 Too Many Requests / nginx`. The demo store was rate-limiting a suite that had been pointed at it too many times in one afternoon.

Bluetir now stops when a store says that, rather than filling a report with failures that belong to the person running it. If you see it, raise `http.delay` and come back later.

**Nothing else is outstanding**, and this is worth keeping in mind generally: **the default one-second delay is polite for one run, not for ten.** A store you don't own deserves more room than a store you do.

## Licence

MIT. See `LICENSE`.
