from __future__ import annotations

import argparse
import json
import os
from typing import Any


def load_stripe() -> Any:
    try:
        import stripe
    except ImportError as exc:
        raise SystemExit(
            "Stripe package is not installed. Install it with: python -m pip install stripe"
        ) from exc
    return stripe


def create_test_checkout_session() -> Any:
    api_key = os.environ.get("STRIPE_SECRET_KEY", "")
    price_id = os.environ.get("STRIPE_TEST_PRICE_ID", "")
    success_url = os.environ.get("STRIPE_SUCCESS_URL", "http://127.0.0.1:8080/checkout/success")
    cancel_url = os.environ.get("STRIPE_CANCEL_URL", "http://127.0.0.1:8080/checkout/cancel")

    if not api_key:
        raise SystemExit("Missing STRIPE_SECRET_KEY environment variable.")
    if not api_key.startswith("sk_test_"):
        raise SystemExit("Stripe checkout test requires a test-mode key starting with sk_test_.")
    if not price_id.startswith("price_"):
        raise SystemExit("Missing STRIPE_TEST_PRICE_ID environment variable with a price_ value.")

    stripe = load_stripe()
    stripe.api_key = api_key
    try:
        return stripe.checkout.Session.create(
            mode="payment",
            line_items=[{"price": price_id, "quantity": 1}],
            success_url=success_url,
            cancel_url=cancel_url,
        )
    except stripe.error.AuthenticationError as exc:
        raise SystemExit("Stripe authentication failed. Check STRIPE_SECRET_KEY.") from exc
    except stripe.error.StripeError as exc:
        raise SystemExit(f"Stripe checkout test failed: {exc.user_message or str(exc)}") from exc


def main() -> int:
    parser = argparse.ArgumentParser(description="Create a Stripe test checkout session safely.")
    parser.add_argument("--json", action="store_true", help="Print the checkout session payload as JSON.")
    args = parser.parse_args()

    session = create_test_checkout_session()
    if args.json:
        print(json.dumps(session, indent=2, default=str))
    else:
        print("Stripe test checkout session created:")
        print(f" - id: {session.get('id')}")
        print(f" - url: {session.get('url')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
