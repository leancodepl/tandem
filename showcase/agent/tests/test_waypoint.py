import json

from tandem_thread import Run, Thread

# The app's tools as `trip_cubit.g.dart` and `booking_cubit.g.dart` declare them, with the
# descriptions left out: the scripted model does not read them.
TRIP_TOOLS = [
    {"name": name, "description": "", "parameters": {"type": "object", "properties": {}}}
    for name in [
        "find_flights",
        "move_meeting",
        "set_homebound_flight",
        "set_hotel_nights",
        "book_changes",
    ]
]
BOOKING_TOOLS = [
    {"name": name, "description": "", "parameters": {"type": "object", "properties": {}}}
    for name in [
        "set_hotel",
        "set_address",
        "set_check_in",
        "set_check_out",
        "set_total_price",
        "set_confirmation",
    ]
]
WAKE = (
    "The app sent this, not the user. Something happened in the app: read app_notes in your "
    "context and act on it if it needs you."
)
# As in showcase/packages/waypoint_travel/lib/src/inbox.dart.
CONFIRMATION = """From: Havnegade Loft <stay@havnegadeloft.example>
Subject: Your booking is confirmed: 55120873

Confirmation number: 55120873
Check-in: Wednesday, 18 November 2026, from 15:00
Check-out: Thursday, 19 November 2026, by 11:00
Total: EUR 168.00, paid at the hotel

Havnegade Loft
Havnegade 44, 1058 Copenhagen"""
TRIP = {"homebound": {"number": "WA 388", "departs": "Thu 2026-10-29 18:05"}}
ASK = "The workshop moved to Friday. Can you fix the rest of the trip?"
# What find_flights answers for Friday, as `TripCubit.findFlights` writes it.
FRIDAY_FLIGHTS = [
    {"number": "WA 382", "departs": "Fri 2026-10-30 07:05", "unavailable": "Too early"},
    {"number": "WA 386", "departs": "Fri 2026-10-30 12:50", "unavailable": "Too early"},
    {"number": "WA 388", "departs": "Fri 2026-10-30 18:05"},
    {"number": "WA 390", "departs": "Fri 2026-10-30 20:45"},
]


def trip(agent_url: str) -> Thread:
    return Thread(f"{agent_url}/agent", "trip: The trip as the traveller sees it", TRIP_TOOLS)


def calls(run: Run) -> list[tuple[str, dict]]:
    return [(call.name, call.args) for call in run.app_calls]


def answer(run: Run, results: dict[str, object]) -> dict[str, str]:
    """The app's answers to the calls of `run`, by tool name; null for a tool not given."""
    return {call.id: json.dumps(results.get(call.name)) for call in run.app_calls}


def test_a_moved_workshop_moves_the_meeting_and_looks_up_flights(agent_url: str) -> None:
    run = trip(agent_url).run(TRIP, ASK)

    assert "RUN_ERROR" not in run.types
    assert calls(run) == [
        ("move_meeting", {"meetingId": "workshop", "start": "2026-10-30T10:00:00"}),
        ("set_hotel_nights", {"nights": 2}),
        ("find_flights", {"origin": "BER", "destination": "WAW", "date": "2026-10-30"}),
    ]


def test_the_flight_home_is_the_first_one_the_app_allows(agent_url: str) -> None:
    thread = trip(agent_url)
    first = thread.run(TRIP, ASK)

    run = thread.run(TRIP, answers=answer(first, {"find_flights": FRIDAY_FLIGHTS}))

    assert calls(run) == [("set_homebound_flight", {"number": "WA 388", "date": "2026-10-30"})]


def test_the_agent_asks_to_book_and_reports_the_confirmation(agent_url: str) -> None:
    thread = trip(agent_url)
    first = thread.run(TRIP, ASK)
    flight = thread.run(TRIP, answers=answer(first, {"find_flights": FRIDAY_FLIGHTS}))

    ask = thread.run(TRIP, answers=answer(flight, {}))
    booked = thread.run(
        TRIP, answers=answer(ask, {"book_changes": {"confirmation": "WP-48243", "charged": 189}})
    )

    assert calls(ask) == [("book_changes", {})]
    assert ask.text.endswith("Book both?")
    assert booked.text == "Booked. Your confirmation is WP-48243."


def test_an_e_mail_that_moves_the_workshop_wakes_the_agent_to_fix_the_trip(
    agent_url: str,
) -> None:
    note = "The traveller forwarded an e-mail from Jonas Weber: it moves Design workshop to Fri."

    run = trip(agent_url).run(TRIP, WAKE, notes=[note])

    assert [name for name, _ in calls(run)] == ["move_meeting", "set_hotel_nights", "find_flights"]


def test_a_hotel_confirmation_fills_every_field_of_the_booking(agent_url: str) -> None:
    thread = Thread(f"{agent_url}/agent/booking", "draft: The hotel booking", BOOKING_TOOLS)

    run = thread.run({}, f"Fill in the hotel booking from this e-mail:\n\n{CONFIRMATION}")

    assert calls(run) == [
        ("set_hotel", {"name": "Havnegade Loft"}),
        ("set_address", {"address": "Havnegade 44, 1058 Copenhagen"}),
        ("set_check_in", {"at": "2026-11-18T15:00:00"}),
        ("set_check_out", {"day": "2026-11-19"}),
        ("set_total_price", {"euros": 168}),
        ("set_confirmation", {"number": "55120873"}),
    ]


PLAN_TOOLS = [
    {"name": name, "description": "", "parameters": {"type": "object", "properties": {}}}
    for name in [
        "set_city",
        "set_purpose",
        "add_meeting",
        "find_flights",
        "set_outbound_flight",
        "set_homebound_flight",
        "find_hotels",
        "set_hotel",
    ]
]
# What the app answers for Vienna, as `PlanTripCubit` writes it.
TUESDAY_THERE = [
    {"number": "WA 511", "departs": "Tue 2026-12-08 07:05"},
    {"number": "WA 517", "departs": "Tue 2026-12-08 17:40"},
    {"number": "WA 519", "departs": "Tue 2026-12-08 20:10"},
]
THURSDAY_HOME = [
    {"number": "WA 512", "departs": "Thu 2026-12-10 10:30", "unavailable": "Too early"},
    {"number": "WA 518", "departs": "Thu 2026-12-10 18:45"},
]
VIENNA_HOTELS = [
    {"id": "ringstrasse-grand", "walkMinutes": 4, "unavailable": "Over the policy"},
    {"id": "spittelberg", "walkMinutes": 8},
    {"id": "naschmarkt-rooms", "walkMinutes": 22},
]


def test_an_invitation_is_planned_within_the_policy(agent_url: str) -> None:
    thread = Thread(f"{agent_url}/agent/plan", "plan: The new trip", PLAN_TOOLS)
    read = thread.run({}, "Plan the trip for this invitation: Vienna, Alpenlicht")
    flights = iter([TUESDAY_THERE, THURSDAY_HOME])

    def result(name: str) -> object:
        if name == "find_flights":
            return next(flights)
        return VIENNA_HOTELS if name == "find_hotels" else None

    answers = {call.id: json.dumps(result(call.name)) for call in read.app_calls}

    chosen = thread.run({}, answers=answers)

    assert [name for name, _ in calls(read)][-3:] == ["find_flights", "find_flights", "find_hotels"]
    assert calls(chosen) == [
        ("set_outbound_flight", {"number": "WA 517", "date": "2026-12-08"}),
        ("set_homebound_flight", {"number": "WA 518", "date": "2026-12-10"}),
        ("set_hotel", {"hotelId": "spittelberg"}),
    ]


EXPENSE_TOOLS = [
    {"name": name, "description": "", "parameters": {"type": "object", "properties": {}}}
    for name in ["add_expense", "remove_expense", "submit_report"]
]
PARIS_RECEIPTS = [
    {"id": "R-0915-2", "category": "meal", "paid": 18, "claimed": 18},
    {"id": "R-0915-3", "category": "meal", "paid": 71, "claimed": None},
]
OVER_THE_LIMIT = {
    "status": "refused",
    "reason": "Meals are paid back up to €60 a day, and €42 is left for that day.",
}


def test_a_meal_over_the_limit_is_claimed_as_far_as_the_policy_allows(agent_url: str) -> None:
    thread = Thread(f"{agent_url}/agent/expenses", "report: The expense report", EXPENSE_TOOLS)
    report = {"receipts": PARIS_RECEIPTS, "total": 18}
    added = thread.run(report, WAKE)

    retried = thread.run(
        report, answers={call.id: json.dumps(OVER_THE_LIMIT) for call in added.app_calls}
    )

    assert calls(added) == [("add_expense", {"receiptId": "R-0915-3", "claimed": 71})]
    assert calls(retried) == [("add_expense", {"receiptId": "R-0915-3", "claimed": 42})]


def test_a_claim_with_a_problem_is_not_submitted(agent_url: str) -> None:
    thread = Thread(f"{agent_url}/agent/expenses", "report: The expense report", EXPENSE_TOOLS)
    taxi = {
        "id": "R-0914-1",
        "merchant": "G7 Taxi",
        "category": "taxi",
        "paid": 58,
        "claimed": 99,
        "problem": "Claim between €1 and the €58 paid",
    }

    run = thread.run({"receipts": [taxi], "total": 99}, WAKE)

    assert calls(run) == []
    assert "G7 Taxi: Claim between €1 and the €58 paid" in run.text


ARRIVAL_TOOLS = [
    {"name": name, "description": "", "parameters": {"type": "object", "properties": {}}}
    for name in ["tandem_show_view", "book_ride", "message_host", "request_early_check_in"]
]


def test_the_arrival_day_is_drawn_with_the_app_components(agent_url: str) -> None:
    thread = Thread(f"{agent_url}/agent/arrival", "arrival: The arrival day", ARRIVAL_TOOLS)

    run = thread.run({}, WAKE, notes=["The traveller opened their arrival day."])

    [(name, args)] = calls(run)
    components = {component["component"] for component in json.loads(args["components"])}
    assert name == "tandem_show_view"
    assert components == {
        "ArrivalCard",
        "NextStop",
        "ArrivalColumn",
        "RideOption",
        "HostNote",
        "HotelNote",
    }
