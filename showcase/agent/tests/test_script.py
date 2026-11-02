import json

from waypoint_agent.instruction import Screen
from waypoint_agent.script import play
from waypoint_agent.script_message import Answer, Call


def test_trip_uses_current_changes_and_never_books_after_a_failed_change() -> None:
    instruction = _context("trip", {"unbookedChanges": [{}, {}, {}], "unbookedCost": 215})
    tools = frozenset({"book_changes"})
    for status in ("refused", "failed"):
        reply = play(
            Screen.TRIP,
            [[Answer("set_homebound_flight", {"status": status, "reason": "Not confirmed."})]],
            instruction,
            tools,
        )
        assert reply == ["I could not confirm the flight change. Not confirmed."]
    reply = play(Screen.TRIP, [[Answer("set_homebound_flight", None)]], instruction, tools)
    assert reply == [
        "The flight home is updated. Book 3 changes for €215?",
        Call("book_changes", {}),
    ]
    assert not any(
        isinstance(part, Call)
        for part in play(Screen.TRIP, [[Answer("set_homebound_flight", None)]], instruction)
    )


def test_trip_skips_malformed_and_unavailable_flights_and_handles_an_empty_search() -> None:
    malformed = [
        {"number": "WA 388", "departs": "Fri 2026-10-30 18"},
        {"number": "WA 388", "departs": "Fri 2026-02-30 18:05"},
        {"number": "WA 388", "departs": "Fri 2026-10-30 18:05", "unavailable": "Too early"},
    ]
    assert play(Screen.TRIP, [[Answer("find_flights", malformed)]], "") == [
        "No flight home fits after the workshop."
    ]
    valid = {"number": "WA 390", "departs": "Fri 2026-10-30 20:45"}
    assert play(Screen.TRIP, [[Answer("find_flights", [*malformed, valid])]], "") == [
        Call("set_homebound_flight", {"number": "WA 390", "date": "2026-10-30"})
    ]


def test_arrival_uses_the_current_meeting_and_only_offered_actions() -> None:
    instruction = _context("arrival", _ARRIVAL)
    reply = play(
        Screen.ARRIVAL, [["Show my arrival"]], instruction, frozenset({"tandem_show_view"})
    )
    view, summary = reply
    assert isinstance(view, Call)
    components = json.loads(view.args["components"])
    assert all(
        key not in component
        for component in components
        for key in ("onBook", "onText", "onEarlyCheckIn")
    )
    assert summary == "The train gets you there by 12:42 for Review at 14:00."
    assert play(Screen.ARRIVAL, [["Book a taxi"]], instruction) == [
        "Ride booking is not available right now. Check the current screen."
    ]


def test_arrival_reports_action_results_without_promising_failed_early_check_in() -> None:
    failed = {
        "pressed": "request_early_check_in",
        "status": "failed",
        "error": "Hotel unavailable.",
    }
    instruction = _context("arrival", _ARRIVAL) + "\n" + _context("app_notes", {"new": [failed]})
    assert play(Screen.ARRIVAL, [["The app sent this"]], instruction) == [
        "I could not confirm that action. Hotel unavailable."
    ]
    instruction = _context("arrival", _ARRIVAL)
    assert play(Screen.ARRIVAL, [[Answer("message_host", "On my way")]], instruction) == [
        'Texted Mira: "On my way"'
    ]
    assert play(Screen.ARRIVAL, [[Answer("request_early_check_in", None)]], instruction) == [
        "The hotel reports your room ready at 12:30."
    ]


def test_failed_expense_changes_do_not_trigger_submission_or_claim_success() -> None:
    instruction = _context("report", {"receipts": [], "total": 12})
    reply = play(
        Screen.EXPENSES,
        [[Answer("add_expense", {"status": "failed", "error": "The change may have happened."})]],
        instruction,
        frozenset({"submit_report"}),
    )
    assert reply == ["I could not confirm the expense change. The change may have happened."]


def test_submission_describes_actual_claims_and_waits_for_missing_receipts() -> None:
    receipt = {"id": "train", "category": "transport", "paid": 12, "claimed": None}
    report = {"receipts": [receipt], "total": 0}
    tools = frozenset({"submit_report"})
    assert play(
        Screen.EXPENSES, [[Answer("add_expense", None)]], _context("report", report), tools
    ) == ["Some receipts are not in the report. Review them before submitting."]
    report = {"receipts": [{**receipt, "claimed": 12}], "total": 12}
    assert play(
        Screen.EXPENSES, [[Answer("add_expense", None)]], _context("report", report), tools
    ) == [
        "The report claims €12. Submit the report?",
        Call("submit_report", {}),
    ]
    assert play(Screen.EXPENSES, [[Answer("add_expense", None)]], _context("report", report)) == [
        "The report cannot be submitted right now. Check the current screen."
    ]


def test_an_uncertain_submission_does_not_claim_that_nothing_was_submitted() -> None:
    reply = play(
        Screen.EXPENSES,
        [
            [
                Answer(
                    "submit_report",
                    {"status": "failed", "error": "No acknowledgement was received."},
                )
            ]
        ],
        "",
    )
    assert reply == [
        "I could not confirm whether the report was submitted. No acknowledgement was received."
    ]


def test_a_refused_meal_is_not_guessed_from_multiple_missing_receipts() -> None:
    report = {
        "receipts": [
            {"id": "first", "category": "meal", "paid": 71, "claimed": None},
            {"id": "second", "category": "meal", "paid": 71, "claimed": None},
        ],
        "total": 0,
    }
    reason = "Meals are paid back up to €60 a day, and €42 is left for that day."
    reply = play(
        Screen.EXPENSES,
        [[Answer("add_expense", {"status": "refused", "reason": reason})]],
        _context("report", report),
        frozenset({"add_expense", "submit_report"}),
    )
    assert reply == [f"The expense was not added: {reason}"]


def test_a_manual_invalid_claim_is_explained_without_trying_to_add_its_receipt() -> None:
    report = {
        "receipts": [
            {
                "id": "taxi",
                "merchant": "Taxi",
                "category": "taxi",
                "paid": 58,
                "claimed": None,
                "problem": "Claim between €1 and the €58 paid",
            }
        ],
        "total": 0,
    }
    reply = play(
        Screen.EXPENSES,
        [["Check the report"]],
        _context("report", report),
        frozenset({"add_expense", "submit_report"}),
    )
    assert len(reply) == 1
    assert isinstance(reply[0], str)
    assert "Taxi: Claim between €1 and the €58 paid" in reply[0]


def test_a_total_only_hotel_stays_unchanged_while_flight_approval_names_its_warning() -> None:
    warning = "No hotel for the night of Thu 29 Oct"
    instruction = _context(
        "trip",
        {
            "hotel": {"name": "Self-booked hotel", "nights": 1, "total": 245, "nightly": None},
            "warnings": [warning],
            "unbookedChanges": [{"what": "Flight home WA 388"}],
            "unbookedCost": 52,
        },
    )
    tools = frozenset({"move_meeting", "find_flights", "set_homebound_flight", "book_changes"})

    moved = play(Screen.TRIP, [["The workshop moved to Friday"]], instruction, tools)
    assert [part.name for part in moved if isinstance(part, Call)] == [
        "move_meeting",
        "find_flights",
    ]
    assert "needs a nightly quote" in str(moved[-1])

    asking = play(Screen.TRIP, [[Answer("set_homebound_flight", None)]], instruction, tools)
    assert asking[-1] == Call("book_changes", {})
    assert warning in str(asking[0])
    assert "needs a nightly quote" in str(asking[0])
    assert "Book 1 change for €52?" in str(asking[0])

    booked = play(
        Screen.TRIP, [[Answer("book_changes", {"confirmation": "flight-only"})]], instruction, tools
    )
    assert "Your confirmation is flight-only." in str(booked[0])
    assert warning in str(booked[0])
    assert "hotel is updated" not in str(booked[0])


def _context(name: str, value: object) -> str:
    return f"- {name}: current app state {json.dumps(value)}"


_ARRIVAL = {
    "meeting": {"title": "Review", "start": "2026-10-29T14:00:00", "host": "Mira"},
    "rides": [
        {"mode": "taxi", "arrives": "2026-10-29T12:10:00", "overPolicy": True},
        {"mode": "train", "arrives": "2026-10-29T12:42:00", "overPolicy": False},
    ],
    "hotel": {"roomReady": "2026-10-29T12:30:00"},
}
