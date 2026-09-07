# From nothing to a working bluetir

By the end of this you'll have driven a real browser through a real Magento
store and got a verdict out of it. It takes about five minutes, and it doesn't
place an order.

## Contents

- [What this is](#what-this-is)
- [Step 1: install it](#step-1-install-it)
- [Step 2: point it at a store](#step-2-point-it-at-a-store)
- [Step 3: see what would happen](#step-3-see-what-would-happen)
- [Step 4: run it](#step-4-run-it)
- [Step 5: shop as a person](#step-5-shop-as-a-person)
- [What you get for free](#what-you-get-for-free)
- [Where to go next](#where-to-go-next)

## What this is

Bluetir drives a browser through a shop and tells you whether a customer could
have bought something.

Unit tests tell you a class works. A staging smoke test tells you the site
returns 200. Neither tells you that the Add to Cart button is covered by a
cookie banner, or that the checkout redirects to an empty cart, or that a theme
update renamed the field the shipping form needs. Those are the failures that
cost money, and they only show up in a real browser.

You describe your shop in YAML. Bluetir does the clicking.

## Step 1: install it

You need Ruby 3.3 or newer and Chrome or Chromium. Selenium finds its own
driver, so there's nothing else to install.

```bash
git clone https://github.com/kingletas/bluetir
```

```bash
cd bluetir && make setup && make install
```

`make install` puts a `bluetir` command on your PATH that points back at this
checkout, so leave the checkout where it is.

## Step 2: point it at a store

```bash
make config
```

You'll get an `etc/bluetir.yml`. Open it and change one line:

```yaml
base_url: https://your-store.test
```

If your shop runs Magento's own Luma theme, you're done. If it runs Hyvä or
ScandiPWA, change `storefront:` to point at that profile instead — all three
ship in `etc/storefronts/`.

## Step 3: see what would happen

Never start with a run. Start with the plan:

```bash
bluetir -n
```

```text
Bluetir would run:
  store:      https://your-store.test
  storefront: Magento 2 Luma (magento2), 21 selectors
  mode:       order
  runs:       1
  products:   1
  assertions: 20 expectations over 8 sections
  http:       user agent Bluetir/2.2.0, delay 2.0s
```

This opens no browser and touches nothing. If a file is missing or a selector is
malformed, you find out here rather than halfway through a checkout.

## Step 4: run it

The safest real mode visits the pages your assertions name and checks the text
on each. It buys nothing:

```bash
bluetir --mode pages
```

```text
[run 1/1] pages
12 of 12 checks passed in 21.2s
```

If your theme isn't Luma, some of those will fail — and that's the tool
working. Find out which selectors your shop actually has:

```bash
bluetir --mode probe
```

```text
  home       https://your-store.test/
  checkout   https://your-store.test/checkout/cart/   <- REDIRECTED

  add_to_cart_button         product, after-add
  checkout_email             NOT FOUND
```

`<- REDIRECTED` is the line to read first. A checkout that answers from the cart
means the cart was empty, which means the add to cart never worked — and that
shows up three pages later as "nothing found on the checkout" unless something
tells you where the browser actually landed.

Edit the selectors in your storefront profile until the probe is quiet.

## Step 5: shop as a person

Now the interesting one:

```bash
bluetir --mode persona
```

```text
  Deliberate researcher — 3 product(s), browses a category, searches, desktop — Blythe Grimaldi of Savannah
    reached a checkout ready to place
  Phone impulse buyer — 1 product(s), mobile — Fenna Nakamura of Boise
    reached a checkout ready to place
  personas ran with seed 20260907
```

Each persona sizes the window to their device, browses the way that kind of
shopper browses, fills a basket and completes the whole checkout under their own
invented name and address.

**It stops at the Place Order button.** It checks the button is there and
usable, and doesn't click it. So you can run this against production.

The seed is printed every time. When one fails, pass it back and you get the
same shoppers, the same addresses and the same failure:

```bash
bluetir --mode persona --seed 20260907
```

## What you get for free

**A baseline.** Record the shop while it works:

```bash
bluetir --mode baseline
```

Then after any deploy:

```bash
bluetir --mode acceptance
```

```text
  nothing has changed since 2026-09-07T15:46:30Z
```

It's silent when nothing moved. A selector that used to resolve and no longer
does is a regression — including the one nobody thought to write an assertion
for, which is the whole reason a baseline beats a checklist.

**An exit status**, so a deploy script or a git hook can stop. `hooks/pre-receive`
refuses a push when the shop can't take an order.

**Politeness.** One second between page loads, and a user agent that says what
it is, so whoever reads the shop's logs can tell your check from a customer.

## Where to go next

- [README](../README.md) — every mode, the four config files, and how to write a selector
- [CONTRIBUTING.md](../CONTRIBUTING.md) — the gate, and what a change should look like
- `etc/storefronts/` — three working profiles to copy from
