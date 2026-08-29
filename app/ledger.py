"""Minimal ledger domain logic for the Fintech demo application.

Deliberately trivial: the assessment marks the DevOps artefacts around this
code, not the code itself. It exists so the pipeline has something real to
build, lint, test and containerise.
"""

from decimal import Decimal, InvalidOperation


class InsufficientFunds(Exception):
    """Raised when a debit would take an account below zero."""


def to_minor_units(amount):
    """Convert a decimal currency amount to integer minor units (pence).

    Money is never held as a float; fintech balances must be exact.
    """
    try:
        value = Decimal(str(amount))
    except (InvalidOperation, ValueError):
        raise ValueError("amount is not a valid decimal")
    if value != value.quantize(Decimal("0.01")):
        raise ValueError("amount has more than two decimal places")
    return int(value * 100)


def apply_transaction(balance_minor, amount, kind):
    """Apply a credit or debit to a balance expressed in minor units."""
    delta = to_minor_units(amount)
    if delta <= 0:
        raise ValueError("amount must be positive")
    if kind == "credit":
        return balance_minor + delta
    if kind == "debit":
        if delta > balance_minor:
            raise InsufficientFunds("balance would go negative")
        return balance_minor - delta
    raise ValueError("kind must be 'credit' or 'debit'")


def format_balance(balance_minor):
    """Render minor units back to a two-decimal string."""
    return f"{Decimal(balance_minor) / 100:.2f}"


def is_duplicate(seen_keys, idempotency_key):
    """Return True when a payment request has already been processed.

    Retries are normal on mobile networks; without this check a customer could
    be debited twice for one tap.
    """
    if not idempotency_key:
        raise ValueError("idempotency key is required")
    return idempotency_key in seen_keys
