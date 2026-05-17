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


def retrieve_balance() -> Any:
    api_key = os.environ.get("STRIPE_SECRET_KEY")
    if not api_key:
        raise SystemExit("Missing STRIPE_SECRET_KEY environment variable.")
    if not api_key.startswith(("sk_test_", "sk_live_")):
        raise SystemExit(
            "STRIPE_SECRET_KEY does not look like a Stripe secret key. "
            "Expected a value starting with sk_test_ or sk_live_."
        )

    stripe = load_stripe()
    stripe.api_key = api_key
    try:
        return stripe.Balance.retrieve()
    except stripe.error.AuthenticationError as exc:
        raise SystemExit("Stripe authentication failed. Check STRIPE_SECRET_KEY.") from exc
    except stripe.error.StripeError as exc:
        raise SystemExit(f"Stripe request failed: {exc.user_message or str(exc)}") from exc


def main() -> int:
    parser = argparse.ArgumentParser(description="Fetch the Stripe account balance safely.")
    parser.add_argument("--json", action="store_true", help="Print raw balance payload as JSON.")
    args = parser.parse_args()

    balance = retrieve_balance()
    if args.json:
        print(json.dumps(balance, indent=2, default=str))
    else:
        print("Stripe balance:")
        for item in balance.get("available", []):
            amount = item.get("amount", 0) / 100
            currency = item.get("currency", "").upper()
            print(f" - available: {amount:.2f} {currency}")
        for item in balance.get("pending", []):
            amount = item.get("amount", 0) / 100
            currency = item.get("currency", "").upper()
            print(f" - pending: {amount:.2f} {currency}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
