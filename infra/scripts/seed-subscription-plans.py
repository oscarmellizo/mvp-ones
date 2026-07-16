#!/usr/bin/env python3
"""Seed subscription plans into DynamoDB for an environment.

Expects AWS credentials in the environment (same as aws-cli).
Optionally uses MP_MONTHLY_PLAN_ID and MP_YEARLY_PLAN_ID env vars for the
Mercado Pago preapproval_plan ids. If they are not set, the script inserts
placeholder values and prints a warning.

Usage:
    python seed-subscription-plans.py --env dev --region us-east-1
"""

import argparse
import os
from datetime import datetime, timezone

import boto3


def _plan_item(
    plan_id: str,
    name: str,
    short_description: str,
    tier: str,
    price_cents: int,
    currency: str,
    billing_interval: str | None,
    mercado_pago_plan_id: str | None,
    features: dict,
    sort_order: int,
    active: bool = True,
):
    now = datetime.now(timezone.utc).isoformat()

    # Defensive: ensure priceCents is an integer. Accidental floats (e.g. 19.900)
    # will get stored in DynamoDB as decimals and can break backend parsing.
    if isinstance(price_cents, float):
        if price_cents.is_integer():
            price_cents = int(price_cents)
        else:
            price_cents = int(round(price_cents))

    return {
        "planId": {"S": plan_id},
        "name": {"S": name},
        "shortDescription": {"S": short_description},
        "tier": {"S": tier},
        "priceCents": {"N": str(price_cents)},
        "currency": {"S": currency},
        "billingInterval": {"S": billing_interval or ""},
        "mercadoPagoPlanId": {"S": mercado_pago_plan_id or ""},
        "active": {"BOOL": active},
        "sortOrder": {"N": str(sort_order)},
        "createdAt": {"S": now},
        "updatedAt": {"S": now},
        "features": {"M": _features(features)},
    }


def _features(features: dict) -> dict:
    result = {}
    for key, feature in features.items():
        value = feature["value"]
        item = {
            "type": {"S": feature.get("type", "")},
            "label": {"S": feature.get("label", "")},
        }
        if isinstance(value, bool):
            item["value"] = {"BOOL": value}
        elif isinstance(value, (int, float)):
            item["value"] = {"N": str(value)}
        else:
            item["value"] = {"S": str(value)}
        result[key] = {"M": item}
    return result


def main():
    parser = argparse.ArgumentParser(description="Seed subscription plans")
    parser.add_argument("--env", default="dev", help="Environment (dev, stage, prod)")
    parser.add_argument("--region", default="us-east-1", help="AWS region")
    parser.add_argument("--stack-prefix", default="ones", help="CloudFormation stack prefix")
    args = parser.parse_args()

    table_name = f"{args.stack_prefix}-{args.env}-plans"

    monthly_mp_plan_id = os.environ.get("MP_MONTHLY_PLAN_ID")
    yearly_mp_plan_id = os.environ.get("MP_YEARLY_PLAN_ID")

    if not monthly_mp_plan_id or not yearly_mp_plan_id:
        print(
            "WARNING: MP_MONTHLY_PLAN_ID and/or MP_YEARLY_PLAN_ID not set.\n"
            "Paid plans will reference placeholder ids and subscriptions will fail\n"
            "until you update the Mercado Pago plan ids in the DynamoDB items.\n"
        )

    plans = [
        _plan_item(
            plan_id="free",
            name="Free",
            short_description="Explora Ones sin costo. Crea hasta 2 eventos y comparte hasta 30 fotos en total para experimentar una nueva forma de conservar recuerdos compartidos.",
            tier="free",
            price_cents=0,
            currency="COP",
            billing_interval=None,
            mercado_pago_plan_id=None,
            features={
                "maxEvents": {"value": 2, "type": "number", "label": "Eventos propios"},
                "maxPhotos": {"value": 30, "type": "number", "label": "Fotos total"},
            },
            sort_order=1,
        ),
        _plan_item(
            plan_id="ones-plus-monthly",
            name="Ones Plus Mensual",
            short_description="Eventos y fotos sin límites. Facturado mensualmente.",
            tier="paid",
            price_cents=19900,
            currency="COP",
            billing_interval="month",
            mercado_pago_plan_id=monthly_mp_plan_id or "ONES_LAUNCHE_MONTHLY",
            features={
                "maxEvents": {"value": True, "type": "boolean", "label": "Eventos propios ilimitados"},
                "maxPhotos": {"value": True, "type": "boolean", "label": "Fotos propias ilimitadas"},
            },
            sort_order=2,
        ),
        _plan_item(
            plan_id="ones-plus-yearly",
            name="Ones Plus Anual",
            short_description="Todo lo de Ones Plus con 3 meses de descuento.",
            tier="paid",
            price_cents=179100,
            currency="COP",
            billing_interval="year",
            mercado_pago_plan_id=yearly_mp_plan_id or "ONES_LAUNCHE_YEARLY",
            features={
                "maxEvents": {"value": True, "type": "boolean", "label": "Eventos propios ilimitados"},
                "maxPhotos": {"value": True, "type": "boolean", "label": "Fotos propias ilimitadas"},
            },
            sort_order=3,
        ),
    ]

    client = boto3.client("dynamodb", region_name=args.region)
    print(f"Seeding plans into {table_name}...")

    for plan in plans:
        client.put_item(TableName=table_name, Item=plan)
        print(f"  - {plan['planId']['S']}")

    print("Done.")
    if monthly_mp_plan_id and yearly_mp_plan_id:
        print(
            "\nNext: configure the webhook URL in Mercado Pago:\n"
            f"  https://<ALB_URL>/v1/payments/mercadopago/webhook"
        )


if __name__ == "__main__":
    main()
