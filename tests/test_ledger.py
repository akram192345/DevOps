"""Unit tests - the base of the test pyramid (fast, isolated, ~70% of suite)."""

import pytest

from app.ledger import (
    InsufficientFunds,
    apply_transaction,
    format_balance,
    to_minor_units,
)


def test_converts_decimal_string_to_minor_units():
    assert to_minor_units("12.34") == 1234


def test_rejects_sub_penny_precision():
    with pytest.raises(ValueError):
        to_minor_units("1.005")


def test_rejects_non_numeric_amount():
    with pytest.raises(ValueError):
        to_minor_units("abc")


def test_credit_increases_balance():
    assert apply_transaction(1000, "5.50", "credit") == 1550


def test_debit_decreases_balance():
    assert apply_transaction(1000, "2.50", "debit") == 750


def test_debit_beyond_balance_is_rejected():
    with pytest.raises(InsufficientFunds):
        apply_transaction(100, "2.00", "debit")


def test_zero_amount_is_rejected():
    with pytest.raises(ValueError):
        apply_transaction(1000, "0.00", "credit")


def test_unknown_transaction_kind_is_rejected():
    with pytest.raises(ValueError):
        apply_transaction(1000, "1.00", "transfer")


def test_balance_formats_to_two_decimals():
    assert format_balance(1550) == "15.50"
