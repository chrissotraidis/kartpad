import datetime as dt
import importlib.util
from pathlib import Path
import unittest
import copy
import io
import json
import tempfile
from contextlib import redirect_stdout, redirect_stderr
from unittest.mock import patch


SCRIPT = Path(__file__).parents[1] / "scripts" / "maintenance-loop.py"
SPEC = importlib.util.spec_from_file_location("maintenance_loop", SCRIPT)
MAINTENANCE_LOOP = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MAINTENANCE_LOOP)


NOW = dt.datetime(2026, 9, 11, tzinfo=dt.timezone.utc)


def issue(number, title, body="", comments=None):
    return {
        "number": number,
        "title": title,
        "body": body,
        "labels": [{"name": "bug"}],
        "updatedAt": "2026-09-11T00:00:00Z",
        "createdAt": "2026-09-11T00:00:00Z",
        "author": {"login": "reporter"},
        "comments": comments or [],
    }


class MaintenanceLoopTests(unittest.TestCase):
    def test_migrated_scopes_follow_source_edits(self):
        paths = {
            123: "vendor/runtimes/android/runtime/src/hle/net/network_socket.cpp",
            200: "vendor/runtimes/android/runtime/src/hle/net/network_ssl.cpp",
            193: "vendor/runtimes/android/aurora-main/lib/gx/command_processor.cpp",
        }
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with patch.object(MAINTENANCE_LOOP, "REPO", root), patch.object(MAINTENANCE_LOOP, "command", return_value="same-head"):
                for number, relative in paths.items():
                    before = MAINTENANCE_LOOP.test_fingerprint(number)
                    source = root / relative
                    source.parent.mkdir(parents=True, exist_ok=True)
                    source.write_text("first source edit")
                    first = MAINTENANCE_LOOP.test_fingerprint(number)
                    source.write_text("second source edit")
                    second = MAINTENANCE_LOOP.test_fingerprint(number)
                    self.assertEqual(len({before, first, second}), 3)

    def test_maintenance_wide_reuses_recursive_source_fingerprint(self):
        with patch.object(MAINTENANCE_LOOP, "command", return_value="same-head"), patch.object(MAINTENANCE_LOOP, "source_fingerprint", side_effect=["first-dirty-content", "second-dirty-content"]) as fingerprint:
            first = MAINTENANCE_LOOP.test_fingerprint()
            second = MAINTENANCE_LOOP.test_fingerprint()
        self.assertNotEqual(first, second)
        self.assertEqual(fingerprint.call_args_list, [unittest.mock.call(MAINTENANCE_LOOP.REPO)] * 2)

    def test_intake_reads_more_than_100_issues_and_comment_pages(self):
        def page(nodes, more=False, cursor=None):
            return {"nodes": nodes, "pageInfo": {"hasNextPage": more, "endCursor": cursor}}

        def report(number):
            item = issue(number, "reported failure")
            item["labels"] = {"nodes": item["labels"]}
            item["comments"] = page([], more=number == 101, cursor="comments-first")
            return item

        first = [report(number) for number in range(1, 101)]
        second = [report(101)]
        comment1 = {"id": "older", "body": "edited old evidence", "author": None}
        comment2 = {"id": "newer", "body": "still fails", "author": {"login": "reporter"}}
        replies = [
            {"data": {"repository": {"issues": page(first, True, "issues-next")}}},
            {"data": {"repository": {"issues": page(second)}}},
            {"data": {"repository": {"issue": {"comments": page([comment1], True, "comments-next")}}}},
            {"data": {"repository": {"issue": {"comments": page([comment2])}}}},
        ]
        with patch.object(MAINTENANCE_LOOP, "command", side_effect=[json.dumps(r) for r in replies]) as command:
            reports = MAINTENANCE_LOOP.load_open_issues()
        self.assertEqual(len(reports), 101)
        self.assertEqual([c["id"] for c in reports[-1]["comments"]], ["older", "newer"])
        self.assertEqual(reports[-1]["comments"][0]["author"], {})
        self.assertIn("cursor=issues-next", command.call_args_list[1].args)
        self.assertIn("number=101", command.call_args_list[2].args)
        self.assertNotIn("cursor=issues-next", command.call_args_list[2].args)
        self.assertIn("cursor=comments-next", command.call_args_list[3].args)

    def test_incomplete_github_response_does_not_return_partial_intake(self):
        with patch.object(MAINTENANCE_LOOP, "command", return_value=json.dumps({"errors": [{"message": "query failed"}]})):
            with self.assertRaisesRegex(RuntimeError, "incomplete"):
                MAINTENANCE_LOOP.load_open_issues()

    def test_stuck_pagination_does_not_spin_or_accept_partial_intake(self):
        response = {"data": {"repository": {"issues": {"nodes": [], "pageInfo": {"hasNextPage": True, "endCursor": "stuck"}}}}}
        with patch.object(MAINTENANCE_LOOP, "command", return_value=json.dumps(response)) as command:
            with self.assertRaisesRegex(RuntimeError, "pagination did not advance"):
                MAINTENANCE_LOOP.load_open_issues()
        self.assertEqual(command.call_count, 2)

    def test_answered_blocker_does_not_starve_ready_renderer_work(self):
        answered_crash = issue(
            196,
            "My game keeps on crashing on iOS 27",
            "iPhone 17 Pro Max launch crash",
            comments=[
                {
                    "createdAt": "2026-09-11T01:59:38Z",
                    "author": {"login": "reporter"},
                },
                {
                    "createdAt": "2026-09-11T02:04:24Z",
                    "author": {"login": "chrissotraidis"},
                },
            ],
        )
        renderer = issue(
            166,
            "Texture and glitches messed up",
            "Android device build Original and Retro",
        )

        ranked = MAINTENANCE_LOOP.rank_issues([answered_crash, renderer], NOW)

        self.assertEqual(ranked[0]["issue"]["number"], 166)
        self.assertFalse(ranked[0]["externally_blocked"])
        self.assertEqual(ranked[1]["issue"]["number"], 196)
        self.assertTrue(ranked[1]["externally_blocked"])
        self.assertIn("retest failed", ranked[1]["purpose"])

    def test_unanswered_reporter_question_remains_ready(self):
        unanswered = issue(
            197,
            "Menu not working",
            "Android gameplay works but menu input does not",
            comments=[
                {
                    "createdAt": "2026-09-11T02:00:00Z",
                    "author": {"login": "reporter"},
                }
            ],
        )

        row = MAINTENANCE_LOOP.rank_issues([unanswered], NOW)[0]

        self.assertFalse(row["externally_blocked"])
        self.assertTrue(row["needs_response"])

    def test_new_issue_body_is_an_unanswered_reporter_message(self):
        new_issue = issue(
            200,
            "The app keeps crashing",
            "vivo V2436 Android 16; crash during gameplay",
        )

        row = MAINTENANCE_LOOP.rank_issues([new_issue], NOW)[0]

        self.assertTrue(row["needs_response"])
        self.assertFalse(row["externally_blocked"])
        self.assertIn(".9 is source-dirty exploratory", row["purpose"])

    def test_bare_acknowledgement_does_not_reopen_answered_issue(self):
        answered = issue(
            192,
            "The pack isn't downloading in the mod",
            "Android online-only Retro Rewind download",
            comments=[
                {
                    "createdAt": "2026-09-11T01:00:00Z",
                    "author": {"login": "chrissotraidis"},
                },
                {
                    "createdAt": "2026-09-11T02:00:00Z",
                    "author": {"login": "xevent38"},
                    "body": "thanks",
                },
            ],
        )

        row = MAINTENANCE_LOOP.rank_issues([answered], NOW)[0]

        self.assertFalse(row["needs_response"])
        self.assertTrue(row["externally_blocked"])

    def test_praise_only_reply_does_not_reopen_answered_issue(self):
        answered = issue(
            184,
            "Controller D-pad Re-mapping Support",
            "Android physical controller mapping request",
            comments=[
                {
                    "createdAt": "2026-09-11T01:00:00Z",
                    "author": {"login": "chrissotraidis"},
                },
                {
                    "createdAt": "2026-09-12T00:37:18Z",
                    "author": {"login": "reporter"},
                    "body": "You rock, having a blast playing this on my handheld.",
                },
            ],
        )

        row = MAINTENANCE_LOOP.rank_issues([answered], NOW)[0]

        self.assertFalse(row["needs_response"])
        self.assertFalse(any("fresh reporter evidence" in reason for reason in row["reasons"]))

    def test_private_handoff_wait_does_not_reopen_answered_issue(self):
        answered = issue(
            198,
            "Poor performance on MediaTek Helio G85",
            "TECNO KJ5 Android device performance report",
            comments=[
                {
                    "createdAt": "2026-09-11T01:00:00Z",
                    "author": {"login": "chrissotraidis"},
                },
                {
                    "createdAt": "2026-09-11T02:00:00Z",
                    "author": {"login": "pdvsita2-netizen"},
                    "body": (
                        "Understood! I will wait for you to establish the private "
                        "channel before installing anything, and I won't share an APK. "
                        "Standing by!"
                    ),
                },
            ],
        )

        row = MAINTENANCE_LOOP.rank_issues([answered], NOW)[0]

        self.assertFalse(row["needs_response"])
        self.assertTrue(row["externally_blocked"])

    def test_private_handoff_reply_with_result_remains_actionable(self):
        comment = {
            "createdAt": "2026-09-11T02:00:00Z",
            "author": {"login": "reporter"},
            "body": "I installed the APK and it still crashes at 25 FPS.",
        }

        self.assertFalse(MAINTENANCE_LOOP.is_non_actionable_acknowledgement(comment))

    def test_issue_family_groups_related_android_renderer_reports(self):
        self.assertEqual(
            MAINTENANCE_LOOP.issue_family(193),
            "android-renderer-geometry",
        )
        self.assertEqual(
            MAINTENANCE_LOOP.issue_family(166),
            "android-renderer-geometry",
        )

    def test_family_result_blocks_duplicate_contract_without_new_evidence(self):
        renderer = issue(
            193,
            "Characters don't render properly",
            "Android device build Original and Retro",
            comments=[
                {
                    "createdAt": "2026-09-11T00:01:00Z",
                    "author": {"login": "chrissotraidis"},
                }
            ],
        )
        ranked = MAINTENANCE_LOOP.rank_issues([renderer], NOW)
        MAINTENANCE_LOOP.apply_repeat_guard(
            ranked,
            {
                "_family_results": {
                    "android-renderer-geometry": {
                        "fingerprint": "renderer-scope-at-last-pass",
                        "result": "pass",
                        "command": ranked[0]["plan"],
                    }
                }
            },
            {193: "renderer-scope-at-last-pass"},
        )

        self.assertTrue(ranked[0]["repeat_blocked"])
        self.assertIn("family android-renderer-geometry", " ".join(ranked[0]["reasons"]))

    def test_family_guard_retains_results_for_multiple_commands(self):
        state = {}
        renderer_plan, _ = MAINTENANCE_LOOP.test_plan(193)
        vertex_plan, _ = MAINTENANCE_LOOP.test_plan(137)
        assert renderer_plan and vertex_plan
        MAINTENANCE_LOOP.record_family_result(
            state,
            "android-renderer-geometry",
            {"fingerprint": "same", "result": "pass", "issue": 193, "command": renderer_plan},
        )
        MAINTENANCE_LOOP.record_family_result(
            state,
            "android-renderer-geometry",
            {"fingerprint": "same", "result": "pass", "issue": 137, "command": vertex_plan},
        )

        for number, plan in ((193, renderer_plan), (137, vertex_plan)):
            row = MAINTENANCE_LOOP.rank_issues(
                [
                    issue(
                        number,
                        "Renderer report",
                        "Android device build Original and Retro",
                        comments=[
                            {
                                "createdAt": "2026-09-11T00:01:00Z",
                                "author": {"login": "chrissotraidis"},
                            }
                        ],
                    )
                ],
                NOW,
            )
            MAINTENANCE_LOOP.apply_repeat_guard(row, state, {number: "same"})
            self.assertTrue(row[0]["repeat_blocked"], plan)

        records = state["_family_results"]["android-renderer-geometry"]["results"]
        self.assertEqual(len(records), 2)

    def test_checkpoint_keeps_low_ranked_repeat_guarded_issue(self):
        ranked = [
            {
                "issue": {"number": number, "updatedAt": "2026-09-11T00:00:00Z"},
                "externally_blocked": False,
                "repeat_blocked": number == 184,
                "latest_external": None,
                "purpose": "physical controller acceptance",
            }
            for number in range(100, 110)
        ]
        ranked.append(
            {
                "issue": {"number": 184, "updatedAt": "2026-09-11T00:00:00Z"},
                "externally_blocked": False,
                "repeat_blocked": True,
                "latest_external": None,
                "purpose": "physical controller acceptance",
            }
        )
        state = {}
        MAINTENANCE_LOOP.record_queue_checkpoint(
            state,
            ranked,
            "fingerprint",
            NOW,
        )

        self.assertIn(184, {row["issue"] for row in state["_meta"]["dependencies"]})

    def test_delayed_android_crash_selects_runtime_ab_checks(self):
        plan, purpose = MAINTENANCE_LOOP.test_plan(200)

        self.assertIn("tests.test_android_network_stall", plan)
        self.assertIn("tests.test_active_network_calls", plan)
        self.assertIn(".9 is source-dirty exploratory", purpose)
        self.assertIn("imported-game device exit evidence", purpose)

    def test_ios_crash_dependency_preserves_failed_device_retest(self):
        plan, purpose = MAINTENANCE_LOOP.test_plan(196)

        self.assertIsNone(plan)
        self.assertIn("new crash analytics or in-app report", purpose)
        self.assertIn("retest failed", purpose)
        self.assertEqual(
            MAINTENANCE_LOOP.DEPENDENCY_STATES[196],
            "matching-build39-device-retest-failed; new-report-external",
        )

    def test_same_passing_contract_waits_for_new_evidence_or_source(self):
        renderer = issue(
            166,
            "Texture and glitches messed up",
            "Android device build Original and Retro",
            comments=[
                {
                    "createdAt": "2026-09-11T00:01:00Z",
                    "author": {"login": "chrissotraidis"},
                }
            ],
        )
        ranked = MAINTENANCE_LOOP.rank_issues([renderer], NOW)
        fingerprint = "source-and-test-state"
        state = {
            "166": {
                "fingerprint": fingerprint,
                "issue_updated_at": renderer["updatedAt"],
                "latest_external": ranked[0]["latest_external"],
                "result": "pass",
                "command": MAINTENANCE_LOOP.test_plan(166)[0],
            }
        }

        MAINTENANCE_LOOP.apply_repeat_guard(ranked, state, fingerprint)

        self.assertTrue(ranked[0]["repeat_blocked"])
        self.assertIn("same local result", " ".join(ranked[0]["reasons"]))

    def test_unrelated_scope_does_not_reopen_passing_contract(self):
        renderer = issue(
            193,
            "Characters don't render properly",
            "Android device build Original and Retro",
            comments=[
                {
                    "createdAt": "2026-09-11T00:01:00Z",
                    "author": {"login": "chrissotraidis"},
                }
            ],
        )
        ranked = MAINTENANCE_LOOP.rank_issues([renderer], NOW)
        state = {
            "193": {
                "fingerprint": "renderer-scope-at-last-pass",
                "latest_external": ranked[0]["latest_external"],
                "result": "pass",
                "command": MAINTENANCE_LOOP.test_plan(193)[0],
            }
        }

        MAINTENANCE_LOOP.apply_repeat_guard(
            ranked,
            state,
            {193: "renderer-scope-at-last-pass"},
        )

        self.assertTrue(ranked[0]["repeat_blocked"])

    def test_relevant_scope_change_reopens_passing_contract(self):
        renderer = issue(
            193,
            "Characters don't render properly",
            "Android device build Original and Retro",
            comments=[
                {
                    "createdAt": "2026-09-11T00:01:00Z",
                    "author": {"login": "chrissotraidis"},
                }
            ],
        )
        ranked = MAINTENANCE_LOOP.rank_issues([renderer], NOW)
        state = {
            "193": {
                "fingerprint": "renderer-scope-at-last-pass",
                "latest_external": ranked[0]["latest_external"],
                "result": "pass",
                "command": MAINTENANCE_LOOP.test_plan(193)[0],
            }
        }

        MAINTENANCE_LOOP.apply_repeat_guard(
            ranked,
            state,
            {193: "renderer-scope-after-source-change"},
        )

        self.assertFalse(ranked[0]["repeat_blocked"])

    def test_legacy_migration_does_not_overwrite_scoped_source_fingerprint(self):
        state = {
            "193": {
                "fingerprint": "before-source-change",
                "fingerprint_scope": "android-renderer-pnmtx",
                "result": "pass",
            }
        }

        MAINTENANCE_LOOP.migrate_legacy_state(
            state, {193: "after-source-change"}
        )

        self.assertEqual(
            state["193"]["fingerprint"],
            "before-source-change",
        )

    def test_legacy_migration_preserves_unknown_provenance(self):
        state = {
            "193": {
                "fingerprint": "legacy-broad-fingerprint",
                "result": "pass",
            }
        }

        MAINTENANCE_LOOP.migrate_legacy_state(
            state, {193: "current-renderer-fingerprint"}
        )

        self.assertEqual(
            state["193"]["fingerprint"],
            "legacy-broad-fingerprint",
        )
        self.assertEqual(state["193"]["provenance"], "legacy-unverified")
        self.assertNotIn("fingerprint_scope", state["193"])

    def test_maintainer_reply_does_not_reopen_passing_row(self):
        renderer = issue(
            120,
            "KartPad problem",
            "Android device build Original and Retro",
            comments=[
                {
                    "createdAt": "2026-09-11T03:01:00Z",
                    "author": {"login": "chrissotraidis"},
                }
            ],
        )
        # GitHub advances issue.updatedAt for the maintainer reply, but that is
        # not new reporter evidence and must not rerun the same local contract.
        renderer["updatedAt"] = "2026-09-11T03:01:00Z"
        ranked = MAINTENANCE_LOOP.rank_issues([renderer], NOW)
        state = {
            "120": {
                "fingerprint": "source-and-test-state",
                "issue_updated_at": "2026-09-11T00:00:00Z",
                "latest_external": ranked[0]["latest_external"],
                "result": "pass",
                "command": MAINTENANCE_LOOP.test_plan(120)[0],
            }
        }

        MAINTENANCE_LOOP.apply_repeat_guard(
            ranked, state, "source-and-test-state"
        )

        self.assertTrue(ranked[0]["repeat_blocked"])

    def test_exhausted_rows_produce_no_ready_work(self):
        renderer = issue(
            166,
            "Texture and glitches messed up",
            "Android device build Original and Retro",
            comments=[
                {
                    "createdAt": "2026-09-11T00:01:00Z",
                    "author": {"login": "chrissotraidis"},
                }
            ],
        )
        ranked = MAINTENANCE_LOOP.rank_issues([renderer], NOW)
        MAINTENANCE_LOOP.apply_repeat_guard(
            ranked,
            {
                "166": {
                    "fingerprint": "source-and-test-state",
                    "issue_updated_at": renderer["updatedAt"],
                    "latest_external": ranked[0]["latest_external"],
                    "result": "pass",
                    "command": MAINTENANCE_LOOP.test_plan(166)[0],
                }
            },
            "source-and-test-state",
        )

        self.assertEqual(MAINTENANCE_LOOP.ready_rows(ranked), [])

    def test_wait_checkpoint_persists_continuation_dependencies(self):
        renderer = issue(
            166,
            "Texture and glitches messed up",
            "Android device build Original and Retro",
            comments=[
                {
                    "createdAt": "2026-09-11T00:01:00Z",
                    "author": {"login": "chrissotraidis"},
                }
            ],
        )
        ranked = MAINTENANCE_LOOP.rank_issues([renderer], NOW)
        MAINTENANCE_LOOP.apply_repeat_guard(
            ranked,
            {
                "166": {
                    "fingerprint": "source-and-test-state",
                    "issue_updated_at": renderer["updatedAt"],
                    "latest_external": ranked[0]["latest_external"],
                    "result": "pass",
                    "command": MAINTENANCE_LOOP.test_plan(166)[0],
                }
            },
            "source-and-test-state",
        )

        state = {}
        MAINTENANCE_LOOP.record_wait_checkpoint(
            state, ranked, "source-and-test-state", NOW
        )

        self.assertEqual(state["_meta"]["last_continuation"], "dependency-checkpoint")
        self.assertEqual(state["_meta"]["open_issue_count"], 1)
        self.assertEqual(state["_meta"]["dependencies"][0]["issue"], 166)
        self.assertEqual(state["_meta"]["dependencies"][0]["state"], "awaiting-change")

    def test_queue_checkpoint_replaces_stale_dependency_metadata(self):
        renderer = issue(
            193,
            "Characters don't render properly",
            "Android device build Original and Retro",
            comments=[
                {
                    "createdAt": "2026-09-11T00:01:00Z",
                    "author": {"login": "chrissotraidis"},
                }
            ],
        )
        ranked = MAINTENANCE_LOOP.rank_issues([renderer], NOW)
        MAINTENANCE_LOOP.apply_repeat_guard(
            ranked,
            {
                "193": {
                    "fingerprint": "renderer-scope",
                    "latest_external": ranked[0]["latest_external"],
                    "result": "pass",
                    "command": MAINTENANCE_LOOP.test_plan(193)[0],
                }
            },
            {193: "renderer-scope"},
        )
        state = {
            "_meta": {
                "dependencies": [
                    {"issue": 200, "next": "obsolete action"},
                ]
            }
        }

        MAINTENANCE_LOOP.record_queue_checkpoint(
            state, ranked, "queue-fingerprint", NOW, "queue-reviewed"
        )

        self.assertEqual(state["_meta"]["last_continuation"], "queue-reviewed")
        self.assertNotIn(200, [row["issue"] for row in state["_meta"]["dependencies"]])

    def test_wait_checkpoint_keeps_external_blockers_beyond_display_slice(self):
        ready_rows = [
            issue(
                number,
                "Texture and glitches messed up",
                "Android device build Original and Retro",
                comments=[
                    {
                        "createdAt": "2026-09-11T00:01:00Z",
                        "author": {"login": "chrissotraidis"},
                    }
                ],
            )
            for number in (166, 193, 104, 120, 137, 102, 188, 119)
        ]
        answered_crash = issue(
            196,
            "My game keeps on crashing on iOS 27",
            "iPhone 17 Pro Max launch crash",
            comments=[
                {
                    "createdAt": "2026-09-11T01:59:38Z",
                    "author": {"login": "reporter"},
                },
                {
                    "createdAt": "2026-09-11T02:04:24Z",
                    "author": {"login": "chrissotraidis"},
                },
            ],
        )
        ranked = MAINTENANCE_LOOP.rank_issues(ready_rows + [answered_crash], NOW)
        fingerprint = "source-and-test-state"
        state = {
            str(row["issue"]["number"]): {
                "fingerprint": fingerprint,
                "issue_updated_at": row["issue"]["updatedAt"],
                "latest_external": row.get("latest_external"),
                "result": "pass",
            }
            for row in ranked
            if row["plan"]
        }
        MAINTENANCE_LOOP.apply_repeat_guard(ranked, state, fingerprint)

        checkpoint = {}
        MAINTENANCE_LOOP.record_wait_checkpoint(
            checkpoint, ranked, fingerprint, NOW
        )

        dependencies = checkpoint["_meta"]["dependencies"]
        self.assertIn(196, [row["issue"] for row in dependencies])
        crash = next(row for row in dependencies if row["issue"] == 196)
        self.assertEqual(
            crash["state"],
            "matching-build39-device-retest-failed; new-report-external",
        )

    def test_long_gratitude_reply_does_not_reopen_answered_issue(self):
        answered = issue(
            198,
            "Poor performance on MediaTek Helio G85",
            "Android Helio G85 build FPS report",
            comments=[
                {
                    "createdAt": "2026-09-11T19:09:45Z",
                    "author": {"login": "pdvsita2-netizen"},
                    "body": "Attached is the new diagnostic file.",
                },
                {
                    "createdAt": "2026-09-11T19:42:19Z",
                    "author": {"login": "chrissotraidis"},
                    "body": "Reviewed and requested the next profile gate.",
                },
                {
                    "createdAt": "2026-09-11T20:10:36Z",
                    "author": {"login": "pdvsita2-netizen"},
                    "body": "Thank you so much for the detailed update! I really love this game, so I'm more than happy to help. I'll be ready whenever you have that special build to test. Thanks again for your time and dedication!",
                },
            ],
        )

        needs_response, latest_external = MAINTENANCE_LOOP.external_activity(answered)

        self.assertFalse(needs_response)
        self.assertEqual(latest_external, "2026-09-11T19:09:45+00:00")

    def test_controller_mapping_feature_has_a_narrow_local_contract(self):
        plan, purpose = MAINTENANCE_LOOP.test_plan(184)

        self.assertIsNotNone(plan)
        self.assertIn(
            "test_controller_mapping_is_persisted_swapped_and_applied_natively",
            plan[-1],
        )
        self.assertIn("physical Thor", purpose)

    def test_primary_adreno_rows_include_the_pnmtx_hypothesis_contract(self):
        plan, purpose = MAINTENANCE_LOOP.test_plan(166)

        self.assertIn("tests.test_draw_input_diagnostics", plan)
        self.assertIn("tests.test_aurora_const_pnmtx_contract", plan)
        self.assertIn("affected-device gameplay", purpose)

    def test_renderer_scope_excludes_unrelated_packaging_wrapper_changes(self):
        self.assertNotIn(
            "scripts/build-android-game-app.sh",
            MAINTENANCE_LOOP.FINGERPRINT_SCOPE_PATHS["android-renderer-pnmtx"],
        )


class PriorityExecutionTests(unittest.TestCase):
    def test_issue123_does_not_repeat_obsolete_receive_window_plan(self):
        plan, purpose = MAINTENANCE_LOOP.test_plan(123)

        self.assertIsNone(plan)
        self.assertIn("fresh-source", purpose)
        self.assertIn("physical Retro VS disconnect", purpose)

    def test_committed_priority_queue_has_resolvable_checkpoints(self):
        work = MAINTENANCE_LOOP.load_priorities(MAINTENANCE_LOOP.DEFAULT_PRIORITIES)
        self.assertTrue(work)

    def test_closed_online_reports_are_not_active_priority_work(self):
        work = MAINTENANCE_LOOP.load_priorities(MAINTENANCE_LOOP.DEFAULT_PRIORITIES)
        online = next(item for item in work if item["id"] == "android-online")
        self.assertEqual(online["issues"], [405])
        self.assertTrue({123, 206}.isdisjoint(online["issues"]))
        self.assertEqual(online["state"], "deferred")
        # A retained VPN workaround is not a new reporter request or ready fix.
        self.assertIsNone(MAINTENANCE_LOOP.select_work([online], [{"number": 405}], {}))

    def work(self, identity, priority, number, state="ready-local"):
        return {"id": identity, "priority": priority, "issues": [number], "state": state,
                "next_action": "Deliver the retained candidate", "acceptance": "Matched affected-device result",
                "checkpoint": "README.md", "dependency": {"owner": "reporter", "needs": "matching device result"}}

    def test_unanswered_issue_cannot_displace_candidate_delivery(self):
        work = [self.work("ios", 1, 196), self.work("renderer", 3, 193)]
        issues = [issue(196, "crash"), issue(193, "new comment"), issue(211, "faces")]
        self.assertEqual(MAINTENANCE_LOOP.select_work(work, issues, {})["id"], "ios")

    def test_active_family_continues_until_gate_changes(self):
        work = [self.work("renderer", 3, 193), self.work("network", 4, 123)]
        state = {"_active_work": {"id": "network"}}
        self.assertEqual(MAINTENANCE_LOOP.select_work(work, [issue(193, "x"), issue(123, "x")], state)["id"], "network")

    def test_newly_actionable_save_loss_preempts_lower_priority_work(self):
        work = [self.work("renderer", 3, 193), self.work("save", 0, 169)]
        self.assertEqual(MAINTENANCE_LOOP.select_work(work, [issue(193, "x"), issue(169, "x")], {"_active_work": {"id": "renderer"}})["id"], "save")

    def test_external_and_closed_items_do_not_spin(self):
        work = [self.work("ios", 1, 196, "awaiting-device"), self.work("renderer", 3, 193)]
        self.assertIsNone(MAINTENANCE_LOOP.select_work(work, [issue(196, "x")], {"_active_work": None}))

    def test_stalled_gate_requires_decision_instead_of_another_audit(self):
        state = {}; work = self.work("ios", 1, 196)
        for hour in range(3): MAINTENANCE_LOOP.record_work_selection(state, work, NOW + dt.timedelta(hours=hour))
        self.assertTrue(state["_active_work"]["requires_decision"])
        work["next_action"] = "Matching device acceptance after delivered candidate"
        MAINTENANCE_LOOP.record_work_selection(state, work, NOW)
        self.assertEqual(state["_active_work"]["cycles_at_gate"], 1)

    def test_context_reloads_do_not_count_as_failed_wakes(self):
        state = {}; work = self.work("online", 2, 123)
        for minute in range(10):
            MAINTENANCE_LOOP.record_work_selection(state, work, NOW + dt.timedelta(minutes=minute))
        self.assertEqual(state["_active_work"]["cycles_at_gate"], 1)
        self.assertFalse(state["_active_work"]["requires_decision"])

    def test_evidence_counts_deduplicate_reports_and_exclude_maintainer(self):
        work = self.work("exits", 1, 208); work["issues"] = [208, 209, 210, 200]
        reports = [issue(n, "exit") for n in work["issues"]]
        reports[-1]["author"]["login"] = MAINTENANCE_LOOP.OWNER
        evidence = MAINTENANCE_LOOP.priority_evidence(work, reports, [reports[0]])
        self.assertEqual(evidence, {"open_threads": 4, "distinct_cases": 2, "distinct_issue_authors": 1, "pending_review": [208]})

    def test_context_contains_entire_priority_sheet_and_unassigned_intake(self):
        work = [self.work("online", 2, 123), self.work("graphics", 3, 193, "awaiting-device")]
        reports = [issue(123, "disconnect"), issue(193, "faces"), issue(999, "new crash")]
        context = MAINTENANCE_LOOP.priority_context(work, reports, [reports[-1]], work[0])
        self.assertIn("online", context)
        self.assertIn("graphics", context)
        self.assertIn("Accept when:", context)
        self.assertIn("#999", context)
        self.assertIn("Continue useful steps within this wake", context)

    def test_new_evidence_updates_counts_without_automatically_changing_order(self):
        work = self.work("graphics", 3, 193)
        before = copy.deepcopy(work)
        reported = issue(193, "faces")
        self.assertEqual(MAINTENANCE_LOOP.priority_evidence(work, [reported], [reported])["pending_review"], [193])
        self.assertEqual(work, before)

    def test_edited_old_reporter_comment_requires_review_after_owner_reply(self):
        reported = issue(193, "x", "Original", comments=[{"id": "old", "createdAt": "2026-09-10T00:00:00Z", "author": {"login": "reporter"}, "body": "still fails"}])
        state = {"_support_reviews": {"193": {"revision": MAINTENANCE_LOOP.reporter_revision(reported)}}}
        reported["comments"].append({"author": {"login": "chrissotraidis"}, "body": "reviewing", "createdAt": "2026-09-11T00:00:00Z"})
        self.assertEqual(MAINTENANCE_LOOP.support_queue([reported], state, NOW), [])
        reported["comments"][0]["body"] = "still fails, now also crashes at results"
        self.assertEqual(len(MAINTENANCE_LOOP.support_queue([reported], state, NOW)), 1)

    def test_edited_body_requires_review_without_creation_time_change(self):
        reported = issue(211, "faces", "device unknown")
        state = {"_support_reviews": {"211": {"revision": MAINTENANCE_LOOP.reporter_revision(reported)}}}
        reported["body"] = "S24 Ultra, same build still affected"
        self.assertEqual(len(MAINTENANCE_LOOP.support_queue([reported], state, NOW)), 1)

    def test_fresh_comment_does_not_rerun_same_contract(self):
        reported = issue(193, "faces", "new reporter evidence")
        rows = MAINTENANCE_LOOP.rank_issues([reported], NOW)
        state = {"193": {"fingerprint": "same", "command": rows[0]["plan"], "result": "pass"}}
        self.assertTrue(rows[0]["needs_response"])
        MAINTENANCE_LOOP.apply_repeat_guard(rows, state, {193: "same"})
        self.assertTrue(rows[0]["repeat_blocked"])

    def test_old_smaller_command_does_not_cover_larger_command_on_same_issue(self):
        rows = MAINTENANCE_LOOP.rank_issues([issue(193, "faces")], NOW)
        state = {"193": {"fingerprint": "same", "command": ["old-smaller-suite"], "result": "pass"}}
        MAINTENANCE_LOOP.apply_repeat_guard(rows, state, {193: "same"})
        self.assertFalse(rows[0]["repeat_blocked"])

    def test_platform_and_save_loss_classifications_are_preserved(self):
        expected = {101: "apple-display-projection", 169: "android-save-lifecycle", 192: "retro-pack-installation", 194: "retro-version-and-updater", 131: "android-cup-exit"}
        self.assertEqual({n: MAINTENANCE_LOOP.issue_family(n) for n in expected}, expected)
        self.assertIn("android-performance", MAINTENANCE_LOOP.RELATED_FAMILIES[169])

    def test_default_cycle_selects_work_without_running_tests(self):
        with tempfile.TemporaryDirectory() as directory:
            state_path = Path(directory) / "loop.json"
            with patch("sys.argv", ["maintenance-loop", "--state-file", str(state_path)]), patch.object(MAINTENANCE_LOOP, "load_open_issues", return_value=[issue(196, "crash")]), patch.object(MAINTENANCE_LOOP, "load_priorities", return_value=[self.work("ios", 1, 196)]), patch.object(MAINTENANCE_LOOP, "run_test") as run_test, redirect_stdout(io.StringIO()):
                self.assertEqual(MAINTENANCE_LOOP.main(), 0)
                run_test.assert_not_called()
            self.assertEqual(json.loads(state_path.read_text())["_active_work"]["id"], "ios")
            self.assertEqual(json.loads(state_path.read_text())["_meta"]["selected_work"], "ios")

    def test_preview_does_not_mutate_state(self):
        with tempfile.TemporaryDirectory() as directory:
            state_path = Path(directory) / "loop.json"
            with patch("sys.argv", ["maintenance-loop", "--preview", "--state-file", str(state_path)]), patch.object(MAINTENANCE_LOOP, "load_open_issues", return_value=[issue(196, "crash")]), patch.object(MAINTENANCE_LOOP, "load_priorities", return_value=[self.work("ios", 1, 196)]), redirect_stdout(io.StringIO()):
                self.assertEqual(MAINTENANCE_LOOP.main(), 0)
            self.assertFalse(state_path.exists())
            self.assertFalse((state_path.parent / "state.lock").exists())

    def test_automatic_test_sweep_is_rejected(self):
        with patch("sys.argv", ["maintenance-loop", "--execute-tests"]), redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as result:
            MAINTENANCE_LOOP.main()
        self.assertEqual(result.exception.code, 2)

    def test_corrupt_state_is_preserved_and_fails_visibly(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "loop.json"; path.write_text("{unfinished")
            with self.assertRaises(json.JSONDecodeError): MAINTENANCE_LOOP.load_loop_state(path)
            self.assertEqual(path.read_text(), "{unfinished")

    def test_external_state_requires_specific_owner_and_action(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "priorities.json"
            work = self.work("ios", 1, 196, "awaiting-device"); del work["dependency"]
            path.write_text(json.dumps({"schema": 1, "work": [work]}))
            with self.assertRaisesRegex(RuntimeError, "named owner"):
                MAINTENANCE_LOOP.load_priorities(path)


if __name__ == "__main__":
    unittest.main()
