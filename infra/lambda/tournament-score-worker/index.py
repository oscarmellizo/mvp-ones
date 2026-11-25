import json
import logging
import os
import time

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

log = logging.getLogger()
log.setLevel(logging.INFO)

TABLE = boto3.resource("dynamodb").Table(os.environ["TOURNAMENTS_TABLE_NAME"])
MAX_POINTS = 80
MAX_EXACT = 8
MAX_FIVES = 8
# Bump this when point rules change to re-score stored predictions on enqueue.
SCORING_REVISION = 2


def _score_value(score, key):
    value = score.get(key) if isinstance(score, dict) else None
    return int(value) if value is not None else None


def _match_points(prediction, actual_home, actual_away):
    home = _score_value(prediction, "homeGoals")
    away = _score_value(prediction, "awayGoals")
    if home is None or away is None or actual_home is None or actual_away is None:
        return 0
    if home == actual_home and away == actual_away:
        return 10
    if home == actual_home or away == actual_away:
        return 5
    return 0


def _projected_order(state, forecasts):
    teams = state.get("teams", [])
    standings = {
        team["id"]: {
            "id": team["id"], "seed": index, "points": 0,
            "gd": 0, "gf": 0, "ga": 0,
        }
        for index, team in enumerate(teams)
    }
    match_count = 0
    scores = forecasts if isinstance(forecasts, dict) else {}
    for match in state.get("matches", []):
        if match.get("phase") != "ROUND_ROBIN":
            continue
        prediction = scores.get(match["id"])
        home = _score_value(prediction, "homeGoals")
        away = _score_value(prediction, "awayGoals")
        if home is None or away is None:
            continue
        home_row = standings.get(match.get("homeTeamId"))
        away_row = standings.get(match.get("awayTeamId"))
        if home_row is None or away_row is None:
            continue
        match_count += 1
        home_row["gf"] += home
        home_row["ga"] += away
        away_row["gf"] += away
        away_row["ga"] += home
        home_row["gd"] = home_row["gf"] - home_row["ga"]
        away_row["gd"] = away_row["gf"] - away_row["ga"]
        if home > away:
            home_row["points"] += 3
        elif away > home:
            away_row["points"] += 3
        else:
            home_row["points"] += 1
            away_row["points"] += 1
    rows = sorted(
        standings.values(),
        key=lambda item: (-item["points"], -item["gd"], -item["gf"], item["seed"]),
    )
    return [row["id"] for row in rows], match_count == 6


def _calculate(state, prediction):
    points = 0
    exact = 0
    fives = 0
    group_scores = prediction.get("roundRobinScores") or {}
    projected, _ = _projected_order(state, group_scores)
    actual_matches = {
        match["id"]: match for match in state.get("matches", [])
        if match.get("status") == "FINISHED"
    }
    for match_id, match in actual_matches.items():
        phase = match.get("phase")
        if phase == "ROUND_ROBIN":
            predicted_score = group_scores.get(match_id)
        elif phase == "FINAL":
            if len(projected) < 2 or projected[0] != match.get("homeTeamId") or projected[1] != match.get("awayTeamId"):
                continue
            predicted_score = prediction.get("finalScore")
        elif phase == "THIRD_PLACE":
            if len(projected) < 4 or projected[2] != match.get("homeTeamId") or projected[3] != match.get("awayTeamId"):
                continue
            predicted_score = prediction.get("thirdPlaceScore")
        else:
            continue
        score = _match_points(predicted_score, match.get("homeGoals"), match.get("awayGoals"))
        points += score
        if score == 10:
            exact += 1
        elif score == 5:
            fives += 1
    return points, exact, fives


def _score_key(points, exact, fives, user_id):
    return "SCORE#{:05d}#{:02d}#{:02d}#{}".format(
        MAX_POINTS - points, MAX_EXACT - exact, MAX_FIVES - fives, user_id
    )


def _process_shard(event_id, shard, force=False):
    state_response = TABLE.get_item(Key={"pk": "EVENT#" + event_id, "sk": "STATE"}, ConsistentRead=True)
    state_item = state_response.get("Item")
    if not state_item:
        return 0
    state = json.loads(state_item["payload"])
    state_version = int(state.get("version", state_item.get("version", 0)))
    shard_key = "EVENT#{}#PRED#{:02d}".format(event_id, shard)
    response = TABLE.query(
        IndexName="byEventShard",
        KeyConditionExpression=Key("eventShardPk").eq(shard_key),
    )
    items = response.get("Items", [])
    while response.get("LastEvaluatedKey"):
        response = TABLE.query(
            IndexName="byEventShard",
            KeyConditionExpression=Key("eventShardPk").eq(shard_key),
            ExclusiveStartKey=response["LastEvaluatedKey"],
        )
        items.extend(response.get("Items", []))

    processed = 0
    for item in items:
        if item.get("sk") != "PREDICTION":
            continue
        prediction = json.loads(item["payload"])
        if not force and (
            int(prediction.get("scoredVersion", -1)) >= state_version
            and int(item.get("scoringRevision", 0)) >= SCORING_REVISION
            and item.get("rankKey")
        ):
            continue
        points, exact, fives = _calculate(state, prediction)
        prediction.update({
            "points": points,
            "exactCount": exact,
            "fivePointCount": fives,
            "scoredVersion": state_version,
        })
        user_id = prediction["userId"]
        rank_key = _score_key(points, exact, fives, user_id)
        rank_pk = "EVENT#{}#RANK#{:02d}".format(event_id, shard)
        rank_payload = json.dumps({
            "userId": user_id,
            "displayName": prediction.get("displayName") or user_id,
            "points": points,
            "exactCount": exact,
            "fivePointCount": fives,
            "place": 0,
        }, separators=(",", ":"))

        transact_items = []
        old_rank_key = item.get("rankKey")
        if old_rank_key and old_rank_key != rank_key:
            transact_items.append({
                "Delete": {
                    "TableName": TABLE.name,
                    "Key": {"pk": {"S": rank_pk}, "sk": {"S": old_rank_key}},
                }
            })
        transact_items.extend([
            {
                "Update": {
                    "TableName": TABLE.name,
                    "Key": {"pk": {"S": item["pk"]}, "sk": {"S": item["sk"]}},
                    "UpdateExpression": (
                        "SET #payload = :payload, scoredVersion = :version, "
                        "#scoringRevision = :revision, rankKey = :rank"
                    ),
                    "ConditionExpression": (
                        "attribute_not_exists(scoredVersion) OR scoredVersion < :version OR "
                        "(scoredVersion = :version AND "
                        "(attribute_not_exists(#scoringRevision) OR #scoringRevision <= :revision))"
                    ),
                    "ExpressionAttributeNames": {
                        "#payload": "payload",
                        "#scoringRevision": "scoringRevision",
                    },
                    "ExpressionAttributeValues": {
                        ":payload": {"S": json.dumps(prediction, separators=(",", ":"))},
                        ":version": {"N": str(state_version)},
                        ":revision": {"N": str(SCORING_REVISION)},
                        ":rank": {"S": rank_key},
                    },
                }
            },
            {
                "Put": {
                    "TableName": TABLE.name,
                    "Item": {
                        "pk": {"S": rank_pk},
                        "sk": {"S": rank_key},
                        "payload": {"S": rank_payload},
                    },
                }
            },
        ])
        try:
            boto3.client("dynamodb").transact_write_items(TransactItems=transact_items)
            processed += 1
        except ClientError as error:
            if error.response["Error"]["Code"] != "TransactionCanceledException":
                raise
    return processed


def handler(event, context):
    failures = []
    started = time.perf_counter()
    for record in event.get("Records", []):
        event_id = "unknown"
        shard = -1
        try:
            body = json.loads(record["body"])
            event_id = str(body["eventId"])
            shard = int(body["shard"])
            force = bool(body.get("force", False))
            if shard < 0 or shard > 15:
                raise ValueError("Invalid tournament score shard")
            processed = _process_shard(event_id, shard, force=force)
            log.info(json.dumps({
                "event": "tournament_score_shard_processed",
                "eventId": event_id,
                "shard": shard,
                "predictionsProcessed": processed,
                "forceRecalculation": force,
                "durationMs": round((time.perf_counter() - started) * 1000),
            }))
        except Exception:
            log.exception("Tournament score shard failed eventId=%s shard=%s", event_id, shard)
            failures.append({"itemIdentifier": record["messageId"]})
    return {"batchItemFailures": failures}
