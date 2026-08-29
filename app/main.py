"""HTTP surface for the demo ledger service."""

import os

from flask import Flask, jsonify, request

from app.ledger import InsufficientFunds, apply_transaction, format_balance

APP_VERSION = os.environ.get("APP_VERSION", "0.0.0-dev")

_ACCOUNTS = {"ACC-1001": 250_00, "ACC-1002": 0}


def create_app():
    app = Flask(__name__)

    @app.get("/healthz")
    def healthz():
        """Liveness probe used by Kubernetes and by pipeline smoke tests."""
        return jsonify(status="ok", version=APP_VERSION)

    @app.get("/accounts/<account_id>/balance")
    def balance(account_id):
        if account_id not in _ACCOUNTS:
            return jsonify(error="account not found"), 404
        return jsonify(
            account_id=account_id, balance=format_balance(_ACCOUNTS[account_id])
        )

    @app.post("/accounts/<account_id>/transactions")
    def transact(account_id):
        if account_id not in _ACCOUNTS:
            return jsonify(error="account not found"), 404
        payload = request.get_json(silent=True) or {}
        try:
            _ACCOUNTS[account_id] = apply_transaction(
                _ACCOUNTS[account_id], payload.get("amount"), payload.get("kind")
            )
        except InsufficientFunds as exc:
            return jsonify(error=str(exc)), 409
        except ValueError as exc:
            return jsonify(error=str(exc)), 400
        return jsonify(
            account_id=account_id, balance=format_balance(_ACCOUNTS[account_id])
        ), 201

    return app


if __name__ == "__main__":
    create_app().run(host="0.0.0.0", port=8000)
