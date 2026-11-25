import importlib.util
import json
import os
import pathlib
import unittest
from unittest.mock import Mock, patch

os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")
os.environ.setdefault("TOURNAMENTS_TABLE_NAME", "tournaments-test")

MODULE_PATH = pathlib.Path(__file__).with_name("index.py")
SPEC = importlib.util.spec_from_file_location("tournament_score_worker", MODULE_PATH)
worker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(worker)


class TournamentScoreWorkerTests(unittest.TestCase):
    def test_awards_points_only_for_exact_or_one_goal_hit(self):
        self.assertEqual(
            worker._match_points({"homeGoals": 2, "awayGoals": 1}, 2, 1),
            10,
        )
        self.assertEqual(
            worker._match_points({"homeGoals": 2, "awayGoals": 0}, 2, 1),
            5,
        )
        self.assertEqual(
            worker._match_points({"homeGoals": 3, "awayGoals": 3}, 1, 1),
            0,
        )
        self.assertEqual(
            worker._match_points({"homeGoals": 2, "awayGoals": 1}, 1, 0),
            0,
        )

    def test_new_scoring_revision_recalculates_same_state_version(self):
        state = {
            "version": 7,
            "teams": [],
            "matches": [
                {
                    "id": "rr-1",
                    "phase": "ROUND_ROBIN",
                    "status": "FINISHED",
                    "homeTeamId": "a",
                    "awayTeamId": "b",
                    "homeGoals": 1,
                    "awayGoals": 1,
                }
            ],
        }
        prediction = {
            "userId": "user-1",
            "displayName": "User",
            "roundRobinScores": {
                "rr-1": {"homeGoals": 3, "awayGoals": 3},
            },
            "finalScore": None,
            "thirdPlaceScore": None,
            "points": 3,
            "exactCount": 0,
            "fivePointCount": 0,
            "scoredVersion": 7,
            "version": 1,
        }
        item = {
            "pk": "EVENT#event-1#PRED#04",
            "sk": "PREDICTION",
            "payload": json.dumps(prediction),
            "scoredVersion": 7,
            "rankKey": "old-rank-key",
        }
        table = Mock()
        table.get_item.return_value = {"Item": {"payload": json.dumps(state)}}
        table.query.return_value = {"Items": [item]}
        dynamodb = Mock()

        with (
            patch.object(worker, "TABLE", table),
            patch.object(worker.boto3, "client", return_value=dynamodb),
        ):
            processed = worker._process_shard("event-1", 4)

        self.assertEqual(processed, 1)
        transaction = dynamodb.transact_write_items.call_args.kwargs["TransactItems"]
        self.assertTrue(any("Delete" in operation for operation in transaction))
        update = next(
            operation["Update"]
            for operation in transaction
            if "Update" in operation
        )
        updated_prediction = json.loads(
            update["ExpressionAttributeValues"][":payload"]["S"]
        )
        self.assertEqual(updated_prediction["points"], 0)
        self.assertEqual(
            update["ExpressionAttributeValues"][":revision"]["N"],
            str(worker.SCORING_REVISION),
        )

    def test_current_revision_and_state_version_are_skipped(self):
        state = {"version": 7, "teams": [], "matches": []}
        item = {
            "pk": "EVENT#event-1#PRED#04",
            "sk": "PREDICTION",
            "payload": json.dumps({"userId": "user-1", "scoredVersion": 7}),
            "scoredVersion": 7,
            "scoringRevision": worker.SCORING_REVISION,
            "rankKey": "current-rank-key",
        }
        table = Mock()
        table.get_item.return_value = {"Item": {"payload": json.dumps(state)}}
        table.query.return_value = {"Items": [item]}

        with patch.object(worker, "TABLE", table):
            processed = worker._process_shard("event-1", 4)

        self.assertEqual(processed, 0)
        dynamodb = Mock()
        with (
            patch.object(worker, "TABLE", table),
            patch.object(worker.boto3, "client", return_value=dynamodb),
        ):
            forced = worker._process_shard("event-1", 4, force=True)

        self.assertEqual(forced, 1)
        self.assertTrue(dynamodb.transact_write_items.called)


if __name__ == "__main__":
    unittest.main()
