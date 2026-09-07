# Changelog

All notable changes to Bluetir are recorded here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.4.2] — 2026-09-07

### Fixed

- **The licence file is `LICENSE`, not `LICENSE.txt`**, which is the name the
  standard asks for and the one GitHub recognises.
- **The prose is written the way a person writes.** Nearly five thousand words
  across the README, the changelog and the guide without a single contraction,
  and two passages that talked about the tool rather than to the reader.

## [2.4.1] — 2026-09-07

Both failures on the first CI run, and the reason neither showed up locally.

### Fixed

- **The Ruby floor was 3.2 and nothing installable supports it.**
  `selenium-webdriver` and `parallel` both require 3.3, so `bundle install`
  couldn't even resolve. The floor is now 3.3 in the gemspec, the CI matrix,
  RuboCop's target and the documentation.
- **The installed command couldn't find its gems.** `bin/bluetir` required
  `watir` without setting the bundle up, so it worked only where the gems
  happened to be in the ambient gem environment — true on the machine that
  wrote it, false on a CI runner that installs into the project. It now uses
  its checkout's bundle.

### Added

- **A test that no locked dependency needs a newer Ruby than the gemspec
  claims**, and one that the CI matrix's lowest version is that floor. Reading
  the metadata rather than starting another interpreter, because the local run
  that was supposed to prove the floor had quietly executed on 3.4 —
  `bundle exec` re-execs under the bundler's own Ruby, so `ruby3.2 -S bundle
  exec` is not Ruby 3.2 at all.

## [2.4.0] — 2026-09-07

### Added

- **A run stops when the store rate-limits it.** A throttled run proves nothing
  about the store, and carrying on makes it worse for whoever else is using it.
  The report says so plainly rather than filling up with failures that belong to
  the person running the suite. This exists because a demo store was pointed at
  too many times in one afternoon and started answering `429`, and the suite
  cheerfully kept going and blamed the store.

### Fixed

- **A slow checkout was given less time than the store was configured for.** The
  bounce retry added a twenty-second first look, and a checkout that hadn't
  bounced then gave up there instead of waiting out its full timeout — so adding
  a retry made the suite less patient for everybody who never bounced.
- The gemspec repeated its homepage as `source_code_uri`, which loses a link on
  rubygems.org, and didn't ship `docs/from-nothing.md`, which the README links
  to.

## [2.3.0] — 2026-09-07

The mobile persona was never the problem.

### Fixed

- **Personas shared one browser.** The second shopper inherited the first one's
  cart and a half-filled checkout, and the storefront then behaved in a way that
  read as broken rather than as one customer wearing another's session. Every
  shopper now gets their own browser. Clearing cookies between them was tried
  first and was worse: a storefront ties its form key to the session the page
  was rendered for, so a cleared session mid-run made the next add to cart fail.
- **An add to cart that navigates away wasn't recognised.** Hyvä intercepts the
  form with Alpine and shows a message — unless Alpine hasn't bound it yet, in
  which case the browser submits the form and leaves the page, and there's no
  message to wait for. That's still an add, and it's now confirmed where the
  evidence is: the cart should mention the product.
- **A text assertion checked once, immediately.** A storefront that renders its
  cart in JavaScript puts the text there after the document is done, so the
  check failed on timing rather than on content — and intermittently, which is
  worse than failing. A string now has ten seconds to arrive. Only a string that
  is missing costs that wait.
- **`verify` checked entries that name their own page.** A shopper buying three
  products visits three product pages, and asserting the first one's name on all
  three is a failure that says nothing about the store. An entry with a `url` is
  swept; one without is checked wherever the flow is.
- **A checkout that bounces is retried once.** A storefront holding its cart in
  the browser can reach the checkout before the server has a quote. A checkout
  that's merely slow isn't retried — its timeout stays the answer.
- **A failed assertion now reports the page it was on and what the page did
  say.** A missing string and a page that never painted look identical in a
  report and are completely different problems.
- **Every failure now names the page it happened on.** "The checkout page
  loaded" failing while the browser sits on the cart is a redirect; without the
  url it's indistinguishable from a slow page.

## [2.2.1] — 2026-09-07

Four overlays and a refused option, all found by running the personas against a
live React storefront. Three of four now reach a checkout ready to place, where
none did.

### Fixed

- **A cookie notice that intercepted every add to cart on ScandiPWA.** Its
  dismissal lives in `localStorage` rather than in a cookie, so `http` gained a
  `local_storage` block and the store's config seeds it. The notice never
  opens, and nothing has to click a banner to get it out of the way.
- **A selector that matched several options always took the first.** ScandiPWA
  lists three delivery methods under one class and the first is a free-shipping
  option the cart doesn't qualify for — permanently disabled. Choosing it
  waited out the full timeout for a button the store was refusing to offer.
  A selector now picks the first match a customer could actually use, and falls
  back to the first so an unusable element still fails with its own message.

- **A click aimed under a sticky footer.** Every storefront has one on a phone,
  and a click at whatever it covers goes to the footer. Elements are scrolled
  into view before being clicked, which is only ever a problem at the widths
  nobody tests by hand.
- **ScandiPWA's `Loader` covering the page**, the same failure as Magento's
  loading mask under a different class name. Its profile now names it.

### Added

- **An optional `terms_agreement`.** ScandiPWA keeps its place-order button
  disabled until "Agree to Terms & Conditions" is ticked. A profile that
  declares none does nothing, which is deliberate: agreeing to a shop's terms is
  the operator's decision about their own shop, not something the tool assumes.
  A declared control that's **not** on the page fails rather than being
  skipped — the first version skipped it, which put a tick beside an agreement
  nobody made and hid the real failure two steps later.

## [2.2.0] — 2026-09-07

Acceptance testing, and shoppers who behave like people.

### Added

- **Personas.** A persona is an archetype — someone on a phone who buys one
  thing — and each run gives it a fresh invented identity from a seeded
  generator. It sizes the window to their device, browses and searches if that
  is how they shop, fills a basket and completes the checkout under their own
  name. **It stops at the last button**: it checks Place Order is there and
  usable and never clicks it. The seed is always printed, because a failure
  nobody can repeat isn't worth having. Identities use `example.test`, which
  RFC 6761 reserves and which can't reach a real mailbox.
- **Baselines and an `acceptance` mode.** A baseline records what actually
  resolved, where each page landed and what each was titled. An acceptance run
  compares and is **silent when nothing has moved**; a lost selector or a page
  that now answers from somewhere else is a regression, while a moved or new
  selector is reported and passes.
- **`Checkout#review`**, everything `call` does except the commitment. A second
  method rather than a flag argument, so no call site can place an order by
  getting one wrong.
- A guard that every mode in the dispatch table has an implementation.

### Fixed

- **A click that landed on Magento's loading mask.** The store covers the
  checkout while it talks to the server, and every persona run failed with
  ElementClickIntercepted. A profile that names its mask is now waited on before
  any click — the commonest single cause of a flaky Magento suite.
- **Waiting for a payment radio that a store never renders.** With one payment
  method enabled Magento selects it and draws no radio at all, so the wait could
  not finish. Reaching the payment step is now proven by the place-order button,
  and having nothing to choose isn't a failure.
- **A trailing slash reported as a redirect.** Asking for `https://shop.test`
  and landing on `https://shop.test/` is the same page.
- **A recorded page kept its fragment**, so Magento moving from `#shipping` to
  `#payment` would have been a regression on every good run.
- **A persona's email was suffixed twice.** An address that already carries a
  tag is left alone; only a fixed one from `orders.yml` needs uniqueness.
- **Two settle knobs that stacked.** The probe had its own on top of the
  navigator's, so a store's configured settle was silently doubled.
- A home-page assertion that assumed a desktop navigation bar and failed for
  every persona on a phone.

## [2.1.0] — 2026-09-07

Three storefronts instead of one, verified against live demo stores rather than
against a fixture.

### Added

- **A Hyvä profile**, verified against `demo.hyva.io` — 17 of 17 selectors. Hyvä
  keeps Magento's behavioural ids and changes everything else: no quantity field
  on a product page, one `#messages` region rather than a block per message, and
  Hyvä Checkout, which isn't Magento's Knockout checkout and puts shipping and
  payment on one screen with no button between them.
- **A ScandiPWA profile**, verified against `tech-demo.scandipwa.com` — 14 of 14.
  A React app over GraphQL, with no Magento markup at all, `street_0` where
  Magento writes `street[0]`, and a delivery option rendered as a button.
- **A `probe` mode** that reports where every selector in a profile resolves,
  which is how the other two profiles were built. It records the URL each page
  actually landed on, counts what's on screen immediately after an add, and
  reports a selector whose declared `stage` it never drives to instead of
  failing it. It never places an order.
- **`http` settings** — `user_agent`, `headers`, `cookies`, `params` and
  `delay`. A staging site behind a header, a store view chosen by a cookie or a
  currency chosen by a query parameter are all the difference between testing
  the store you meant and testing a different one.
- **A `settle` setting.** A store built in JavaScript isn't finished when the
  document is, and a click that lands before Alpine or React has bound the
  button silently does nothing — which surfaces pages later as an empty cart.
- **A `stage` on a selector**, naming the checkout step it lives on, so the
  probe can say "not visited" rather than "missing".

### Changed

- **Bluetir is polite by default**: one second between page loads, and a user
  agent that identifies the tool and links to this repository, so a storefront
  owner reading their logs can tell an automated check from a customer.
- **Text matching ignores case.** A theme that sets `text-transform: uppercase`
  makes the browser report `IN STOCK` for markup that says `In stock`, so an
  expectation written from the page source failed against the rendered page.
- **Every URL is built in one place.** Custom parameters can't now be applied
  on one code path and forgotten on another.
- `--mode pages` sweeps an assertion entry that declares a `url`; one without is
  left to whichever flow reaches that page. An entry with `url: ""` is the home
  page and is swept.
- The shipping-continue button is optional, for a one-page checkout.
- Choosing an option clicks it when it isn't a radio or a checkbox.
- The Luma profile's cart estimator declares the toggle that opens it. The
  fields don't exist in the page until it's clicked.

### Fixed

- **`Navigator` compared `document.readyState` against a Symbol when Watir
  returns a String**, so the wait was never satisfied and every page load burned
  the full ten-second timeout in silence — the settle rescues its own failure.
  The local browser suite went from 60s back to 8s. The regression test asserts
  the double returns a String, because a double that returned a Symbol is what
  hid it.
- The shipping-quote flow reported a quote it hadn't obtained when the profile
  declared estimate fields the page didn't render.

## [2.0.0] — 2026-09-07

The 2013 suite brought forward to Ruby 3, Watir 7 and Magento 2. This is a breaking release: no configuration file from 1.1.0 will load.

### Added

- Storefront profiles. Every selector, path and expected string now lives in YAML under `etc/storefronts/`, so testing a different store means writing a profile rather than editing Ruby. Magento 2 Luma and Magento 1 profiles both ship, and both drive the same flows.
- A `plan` mode (`bluetir -n`) that validates the whole configuration and reports what a run would cover without opening a browser.
- A `pages` mode that sweeps every URL in the assertions file, replacing the disabled `_test_pages_available`.
- Real exit statuses, so a deploy script or git hook can act on the outcome. `hooks/pre-receive` now refuses a push on failure with `BLUETIR_FORCE=1` as the escape hatch — the one item left in the 2013 `todo.txt`.
- A unit suite covering configuration, selectors, assertions, results and the checkout flow, plus a browser suite that drives the flows through headless Chromium against a static fixture storefront.
- A `Makefile` as the interface, and a RuboCop configuration.

### Changed

- Targets Magento 2 rather than Magento 1. The one-page-checkout selectors are preserved as the Magento 1 profile.
- Requires Ruby 3.2 or newer, Watir 7 and Selenium 4. Selenium locates its own driver, so no driver install is needed.
- Configuration collapsed from eleven files across three near-duplicate sets into one file naming three others.
- YAML is parsed with `safe_load`. The `!ruby/sym` tags the old configuration files depended on are gone; keys are plain strings.
- The suite no longer subclasses `Test::Unit::TestCase`. It's a library with a command in front of it, which is why it can now report an exit status.
- Result reporting is a tally object rather than console output, and a run that performs no checks is a failure rather than a success.

### Fixed

- Page assertions run. The one line that performed them was commented out, so `enable_assertions`, the assertion proc and all four assertion files did nothing.
- The completion email states what happened. It previously reported success unconditionally, including after a crash.
- The shipped default configuration named a file that wasn't in the repository, so a first run failed on a missing file.
- Waits are bounded and report the real elapsed time. The order-confirmation loop had no timeout and counted five seconds for every one that passed.
- `custom_wait_checkout` recursed into itself on every rescue instead of retrying with a limit.
- Screenshots are written to the configured directory. The path was built from a hardcoded `screenshots/` while the directory was created from config, so any other setting wrote into a directory that was never made.
- Nested screenshot directories are created with `mkdir_p` rather than `mkdir`.
- A failing step records a failure and the run continues. Flows no longer call `exit` from inside a test.
- Teardown no longer raises over a browser that was never opened, which used to hide the error that stopped the run.
- `close_on_error:true` and `allow_email:'true'` were missing the space after the colon, so YAML read each as a key name rather than a setting. Both settings were silently absent.

### Removed

- `lib/rb_watir.rb`, a near-duplicate of `lib/watir.rb` that redefined the same class.
- `lib/watir.rb`, whose name shadowed the `watir` gem on the load path.
- Four hardcoded email addresses that were the default notification recipients.
- `jeweler`, `rcov`, `shoulda`, `rdoc` and `watir-webdriver`, all unmaintained. The gemspec is hand-written and the Gemfile reads it.
- Eight empty placeholder files under `etc/test_cases/`, `etc/assertions_per_page/` and `etc/checkout_configuration/`.

### Known gaps

- The Magento 2 profile hasn't been run against a live Magento 2 store. It's proven against a fixture that copies Luma's markup.
- Checkout as a registered customer isn't ported. Magento 2 restructured that path, and a stub would be worse than its absence.

## [1.1.0] — 2013-04-15

Initial public release. Magento 1, Watir 4, Ruby 1.8.
