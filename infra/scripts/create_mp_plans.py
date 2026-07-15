import os
import json
import urllib.request
import urllib.error

MP_ACCESS_TOKEN = os.environ.get("MP_ACCESS_TOKEN", "").strip()
ONES_APP_BASE_URL = os.environ.get("ONES_APP_BASE_URL", "").strip()

if not MP_ACCESS_TOKEN:
    raise SystemExit("ERROR: MP_ACCESS_TOKEN is required (use your MercadoPago TEST-... token for sandbox).")

if not ONES_APP_BASE_URL:
    raise SystemExit("ERROR: ONES_APP_BASE_URL is required (e.g. https://appdev.ones.events).")

API_BASE = "https://api.mercadopago.com"

def create_preapproval_plan(*, reason, frequency, frequency_type, amount, currency_id, back_url, notification_url):
    url = f"{API_BASE}/preapproval_plan"
    payload = {
        "reason": reason,
        "auto_recurring": {
            "frequency": frequency,
            "frequency_type": frequency_type,
            "transaction_amount": amount,
            "currency_id": currency_id,
        },
        "back_url": back_url,
        "notification_url": notification_url,
    }

    body_bytes = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body_bytes, method="POST")
    req.add_header("Authorization", f"Bearer {MP_ACCESS_TOKEN}")
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            resp_body = resp.read().decode("utf-8", errors="replace")
            try:
                return json.loads(resp_body)
            except Exception:
                return {"raw": resp_body}
    except urllib.error.HTTPError as e:
        err_body = ""
        try:
            err_body = e.read().decode("utf-8", errors="replace")
        except Exception:
            err_body = ""
        try:
            err_json = json.loads(err_body) if err_body else {"raw": err_body}
        except Exception:
            err_json = {"raw": err_body}
        raise RuntimeError(
            f"ERROR creating plan HTTP {e.code}: {json.dumps(err_json, ensure_ascii=False)}"
        )

def main():
    # Ajusta estos valores a tus precios reales
    monthly = {
        "reason": "Monthly Ones Launch Plan",
        "frequency": 1,
        "frequency_type": "months",
        "amount": 19900,      # COP 19,900 (sin decimales en COP)
        "currency_id": "COP",
    }

    yearly = {
        "reason": "Yearly Ones Launch Plan",
        "frequency": 12,
        "frequency_type": "months",
        "amount": 179100,     # ejemplo: COP 199,000
        "currency_id": "COP",
    }

    back_url = f"{ONES_APP_BASE_URL.rstrip('/')}/plans/success"
    notification_url = f"{ONES_APP_BASE_URL.rstrip('/')}/v1/webhooks/mercadopago"

    print("Creating MercadoPago preapproval plans...")
    print(f"- back_url={back_url}")
    print(f"- notification_url={notification_url}")

    monthly_resp = create_preapproval_plan(
        reason=monthly["reason"],
        frequency=monthly["frequency"],
        frequency_type=monthly["frequency_type"],
        amount=monthly["amount"],
        currency_id=monthly["currency_id"],
        back_url=back_url,
        notification_url=notification_url,
    )

    yearly_resp = create_preapproval_plan(
        reason=yearly["reason"],
        frequency=yearly["frequency"],
        frequency_type=yearly["frequency_type"],
        amount=yearly["amount"],
        currency_id=yearly["currency_id"],
        back_url=back_url,
        notification_url=notification_url,
    )

    print("\nSUCCESS. Save these IDs:")
    print(f"MP_MONTHLY_PLAN_ID={monthly_resp.get('id')}")
    print(f"MP_YEARLY_PLAN_ID={yearly_resp.get('id')}")

    print("\nAlso returned init_points (open them to test checkout):")
    print(f"monthly init_point={monthly_resp.get('init_point')}")
    print(f"yearly init_point={yearly_resp.get('init_point')}")

if __name__ == "__main__":
    main()