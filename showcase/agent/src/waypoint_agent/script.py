"""Scripted turns depend only on the request, never a saved run counter."""

import json
import re
from collections.abc import Iterator, Sequence
from dataclasses import dataclass
from datetime import date, datetime
from typing import Any

from waypoint_agent.instruction import Screen
from waypoint_agent.script_message import Answer, Call, Message

TRIP_REPLY = "This is a scripted assistant: it knows that the workshop in Berlin moves to Friday."
BOOKING_REPLY = "This e-mail has no hotel booking."
# What the app notes when the traveller's change voided an approval.
REASK = "changed the trip on the screen"


def play(
    screen: Screen,
    messages: Sequence[Message],
    instruction: str,
    offered_tools: frozenset[str] = frozenset(),
    *,
    user_request: str | None = None,
) -> list[str | Call]:
    """Messages are oldest first; the instruction contains screen state and app notes."""
    last = messages[-1] if messages else ()
    answers = {part.name: part.result for part in last if isinstance(part, Answer)}
    text = " ".join(part for part in last if isinstance(part, str))
    match screen:
        case Screen.TRIP:
            # A wake-up of the app says only to read its notes, which are in the instruction.
            woken = text.startswith("The app sent this")
            return _trip(
                answers,
                "\n".join(_new_notes(instruction)) if woken else text,
                _context(instruction, "trip"),
                offered_tools,
            )
        case Screen.BOOKING:
            return _booking(answers, text)
        case Screen.PLAN:
            return _plan(last, text, instruction)
        case Screen.EXPENSES:
            return _expenses(
                last,
                instruction,
                offered_tools,
                user_request if user_request is not None else text,
            )
        case Screen.ARRIVAL:
            return _arrival(last, text, instruction, offered_tools)


def _trip(
    answers: dict[str, Any], text: str, trip: dict[str, Any], offered_tools: frozenset[str]
) -> list[str | Call]:
    match answers:
        case {"book_changes": {"confirmation": str(confirmation)}}:
            return [_with_trip_warnings(trip, f"Booked. Your confirmation is {confirmation}.")]
        case {"book_changes": {"status": "rejected_by_user"}}:
            return ["OK, I won't book them."]
        case {"book_changes": result} if _tool_problem(result):
            return [f"I could not confirm the booking. {_tool_problem(result)}"]
        case {"move_meeting": result} if _tool_problem(result):
            return [f"I could not confirm the meeting change. {_tool_problem(result)}"]
        case {"find_flights": flights}:
            return [
                _choose_flight(flights, "set_homebound_flight")
                or "No flight home fits after the workshop."
            ]
        case {"move_meeting": _}:
            return _fit_trip(trip, offered_tools)
        case {"set_homebound_flight": result} if _tool_problem(result):
            return [f"I could not confirm the flight change. {_tool_problem(result)}"]
        case {"set_homebound_flight": _}:
            return _ask_to_book(trip, offered_tools, "The flight home is updated.")
    if REASK in text:
        return _ask_to_book(trip, offered_tools, "The trip changed.")
    if "workshop" in text.lower():
        return [
            Call("move_meeting", {"meetingId": "workshop", "start": "2026-10-30T10:00:00"}),
        ]
    return [TRIP_REPLY]


def _fit_trip(trip: dict[str, Any], offered_tools: frozenset[str]) -> list[str | Call]:
    steps: list[str | Call] = []
    if "set_hotel_nights" in offered_tools:
        steps.append(Call("set_hotel_nights", {"nights": 2}))
    steps.append(
        Call(
            "find_flights",
            {"origin": "BER", "destination": "WAW", "date": "2026-10-30"},
        )
    )
    if notice := _hotel_notice(trip):
        steps.append(notice)
    return steps


def _ask_to_book(
    trip: dict[str, Any], offered_tools: frozenset[str], lead: str
) -> list[str | Call]:
    summary = _with_trip_warnings(trip, lead)
    match trip:
        case {"unbookedChanges": list(changes), "unbookedCost": int(cost)} if (
            changes and "book_changes" in offered_tools
        ):
            label = "change" if len(changes) == 1 else "changes"
            return [f"{summary} Book {len(changes)} {label} for €{cost}?", Call("book_changes", {})]
    return [f"{summary} Check the current trip before booking."]


def _with_trip_warnings(trip: dict[str, Any], lead: str) -> str:
    parts = [lead]
    if notice := _hotel_notice(trip):
        parts.append(notice)
    if isinstance(warnings := trip.get("warnings"), list):
        text = "; ".join(warning for warning in warnings if isinstance(warning, str))
        if text:
            parts.append(f"Check the trip: {text}.")
    return " ".join(parts)


def _hotel_notice(trip: dict[str, Any]) -> str | None:
    match trip:
        case {"hotel": {"nightly": None}}:
            return "Changing the hotel nights still needs a nightly quote."
        case {"hotel": None}:
            return "There is no hotel booking to extend."
    return None


def _context(instruction: str, name: str) -> dict[str, Any]:
    found = re.search(rf"^- {re.escape(name)}: .*?(\{{.*\}})$", instruction, re.MULTILINE)
    if found is None:
        return {}
    try:
        value = json.loads(found[1])
    except json.JSONDecodeError:
        return {}
    return value if isinstance(value, dict) else {}


def _new_notes(instruction: str) -> list[str]:
    return [
        text for note in _new_notes_raw(instruction) if isinstance(text := note.get("note"), str)
    ]


@dataclass(frozen=True)
class _FlightChoice:
    number: str
    departs: datetime


def _allowed_flights(value: object) -> Iterator[_FlightChoice]:
    if not isinstance(value, list):
        return
    for flight in value:
        match flight:
            case {"number": str(number), "departs": str(departure)} if (
                flight.get("unavailable") is None and number.strip()
            ):
                parts = departure.split(" ")
                if len(parts) != 3:
                    continue
                _, day, time = parts
                try:
                    at = datetime.fromisoformat(f"{day}T{time}")
                except ValueError:
                    continue
                if at.isoformat(timespec="minutes") == f"{day}T{time}":
                    yield _FlightChoice(number, at)


def _booking(answers: dict[str, Any], text: str) -> list[str | Call]:
    if answers:
        problems = [problem for answer in answers.values() if (problem := _tool_problem(answer))]
        if problems:
            return [f"Some booking fields could not be filled in. {' '.join(problems)}"]
        return ["Filled in from the confirmation."]
    return _fill(text) or [BOOKING_REPLY]


def _tool_problem(answer: Any) -> str | None:
    match answer:
        case {"status": str(status)} if status != "returned":
            match answer:
                case {"reason": str(reason)}:
                    return reason
                case {"error": str(error)}:
                    return error
                case _:
                    return "Check the fields on the form."
    return None


def _fill(email: str) -> list[str | Call]:
    lines = email.splitlines()

    def line(label: str) -> str | None:
        prefix = f"{label}:"
        return (
            next((text[len(prefix) :].strip() for text in lines if text.startswith(prefix)), None)
            or None
        )

    if (confirmation := line("Confirmation number")) is None:
        return []
    calls: list[str | Call] = []
    sender = re.match(r"^(.+?)\s*<", line("From") or "")
    hotel = sender[1].strip() if sender else None
    if hotel:
        calls.append(Call("set_hotel", {"name": hotel}))
    signature = [text.strip() for text in lines if text.strip()]
    if hotel and len(signature) >= 2 and signature[-2] == hotel:
        calls.append(Call("set_address", {"address": signature[-1]}))
    if check_in := _check_in(line("Check-in")):
        calls.append(Call("set_check_in", {"at": check_in.isoformat(timespec="seconds")}))
    if check_out := _date(line("Check-out")):
        calls.append(Call("set_check_out", {"day": check_out.isoformat()}))
    if total := _whole_euros(line("Total")):
        calls.append(Call("set_total_price", {"euros": total}))
    calls.append(Call("set_confirmation", {"number": confirmation}))
    return calls


def _date(text: str | None) -> date | None:
    found = re.fullmatch(
        r"(?:[A-Za-z]+, )?([0-9]{1,2}) ([A-Za-z]+) ([0-9]{4})(?:, .*)?", text or ""
    )
    if found is None:
        return None
    try:
        return datetime.strptime(f"{found[1]} {found[2]} {found[3]}", "%d %B %Y").date()
    except ValueError:
        return None


def _check_in(text: str | None) -> datetime | None:
    day = _date(text)
    at = re.search(r", from ([0-9]{2}):([0-9]{2})$", text or "")
    if day is None or at is None:
        return None
    try:
        return datetime(day.year, day.month, day.day, int(at[1]), int(at[2]))
    except ValueError:
        return None


def _whole_euros(text: str | None) -> int | None:
    found = re.fullmatch(r"EUR ([0-9]+)(?:\.00)?(?:, .*)?", text or "")
    if found is None:
        return None
    try:
        euros = int(found[1])
    except ValueError:
        return None
    return euros if euros > 0 else None


def _plan(last: Message, text: str, instruction: str) -> list[str | Call]:
    answers = [part for part in last if isinstance(part, Answer)]
    if not answers:
        if "Vienna" in text or "Alpenlicht" in text:
            return _READ_THE_INVITATION
        return [PLAN_REPLY]
    for answer in answers:
        if answer.name in ("find_flights", "find_hotels") and (
            problem := _tool_problem(answer.result)
        ):
            return [f"I could not finish planning. {problem}"]
    flights = [answer.result for answer in answers if answer.name == "find_flights"]
    hotels = [answer.result for answer in answers if answer.name == "find_hotels"]
    if len(flights) == 2 and len(hotels) == 1:
        there, home = flights
        chosen = [
            _choose_flight(there, "set_outbound_flight", afternoon=True),
            _choose_flight(home, "set_homebound_flight"),
            _closest_hotel(hotels[0]),
        ]
        return [call for call in chosen if call]
    return [_plan_summary(instruction)]


PLAN_REPLY = (
    "This is a scripted assistant: it plans the trip to Vienna from Alpenlicht's invitation."
)
_MEETING_PLACE = "Alpenlicht, Mariahilfer Str. 88"
_READ_THE_INVITATION: list[str | Call] = [
    Call("set_city", {"city": "Vienna"}),
    Call("set_purpose", {"purpose": "Discovery · Alpenlicht"}),
    Call(
        "add_meeting",
        {
            "title": "Discovery workshop",
            "place": _MEETING_PLACE,
            "start": "2026-12-09T09:30:00",
            "end": "2026-12-09T17:00:00",
        },
    ),
    Call(
        "add_meeting",
        {
            "title": "Roadmap session",
            "place": _MEETING_PLACE,
            "start": "2026-12-10T09:00:00",
            "end": "2026-12-10T12:00:00",
        },
    ),
    # The workshop starts at 09:30, so the policy wants the evening before.
    Call("find_flights", {"origin": "WAW", "destination": "VIE", "date": "2026-12-08"}),
    Call("find_flights", {"origin": "VIE", "destination": "WAW", "date": "2026-12-10"}),
    Call("find_hotels", {"city": "Vienna"}),
]


def _choose_flight(flights: object, tool: str, afternoon: bool = False) -> Call | None:
    for flight in _allowed_flights(flights):
        if afternoon and flight.departs.hour < 12:
            continue
        return Call(tool, {"number": flight.number, "date": flight.departs.date().isoformat()})
    return None


def _closest_hotel(hotels: list[dict]) -> Call | None:
    allowed = [hotel for hotel in hotels if not hotel.get("unavailable")]
    if not allowed:
        return None
    closest = min(allowed, key=lambda hotel: hotel["walkMinutes"])
    return Call("set_hotel", {"hotelId": closest["id"]})


def _plan_summary(instruction: str) -> str:
    plan = _context(instruction, "plan")
    if plan.get("missing") or not plan.get("hotel"):
        return "I could not plan all of it within the policy. Check what is missing."
    there = plan["outbound"]["departs"].split()[-1]
    home = plan["homebound"]["departs"].split()[-1]
    hotel = plan["hotel"]
    return (
        f"Planned from Mira's invitation: the {there} on Tuesday, {hotel['nights']} nights at "
        f"{hotel['name']}, the closest hotel within the policy, and the {home} home on Thursday. "
        f"€{plan['total']} in all; book it below."
    )


def _expenses(
    last: Message, instruction: str, offered_tools: frozenset[str], user_request: str
) -> list[str | Call]:
    submit_requested = re.search(r"\bsubmit\b", user_request, re.IGNORECASE) is not None
    report = _context(instruction, "report")
    missing = [
        receipt
        for receipt in report.get("receipts", [])
        if receipt.get("claimed") is None and receipt.get("problem") is None
    ]
    answers = [part for part in last if isinstance(part, Answer)]
    if not answers:
        if any(receipt.get("problem") for receipt in report.get("receipts", [])):
            return _report_reply(report, offered_tools, submit_requested=submit_requested)
        if missing:
            if "add_expense" in offered_tools:
                return [
                    Call("add_expense", {"receiptId": receipt["id"], "claimed": receipt["paid"]})
                    for receipt in missing
                ]
            return ["Expenses cannot be added right now. Check the current screen."]
        return _report_reply(report, offered_tools, submit_requested=submit_requested)
    if answers[-1].name == "submit_report":
        match answers[-1].result:
            case {"confirmation": confirmation, "total": total}:
                return [f"Submitted as {confirmation}. €{total} comes back with your next salary."]
            case {"status": "rejected_by_user"}:
                return ["OK, the report stays unsubmitted. Submit it when you're ready."]
            case {"reason": str(reason)}:
                return [f"The report was not submitted: {reason}"]
            case {"error": str(error)}:
                return [f"I could not confirm whether the report was submitted. {error}"]
            case _:
                return [
                    "I could not confirm whether the report was submitted. Check the current screen."
                ]
    # A meal over the daily limit: the app says what is left for that day.
    for answer in answers:
        match answer.result:
            case {"status": "refused", "reason": str(reason)}:
                left = re.search(r"€(\d+) is left", reason)
                meals = [receipt for receipt in missing if receipt["category"] == "meal"]
                if left and left[1] != "0" and len(meals) == 1 and "add_expense" in offered_tools:
                    return [
                        Call(
                            "add_expense",
                            {
                                "receiptId": meals[0]["id"],
                                "claimed": int(left[1]),
                            },
                        )
                    ]
                return [f"The expense was not added: {reason}"]
        if problem := _tool_problem(answer.result):
            return [f"I could not confirm the expense change. {problem}"]
    return _report_reply(report, offered_tools, submit_requested=submit_requested)


def _report_reply(
    report: dict[str, Any], offered_tools: frozenset[str], *, submit_requested: bool
) -> list[str | Call]:
    if report.get("submitted"):
        return ["The report is submitted already."]
    problems = [
        f"{receipt.get('merchant', receipt['id'])}: {receipt['problem']}"
        for receipt in report.get("receipts", [])
        if receipt.get("problem")
    ]
    if problems:
        wrong = ". ".join(problems)
        return [
            f"Some claims are wrong. {wrong}. Change them on the screen, then submit the report."
        ]
    if any(receipt.get("claimed") is None for receipt in report.get("receipts", [])):
        return ["Some receipts are not in the report. Review them before submitting."]
    if submit_requested and "submit_report" not in offered_tools:
        return ["The report cannot be submitted right now. Check the current screen."]
    match report:
        case {"total": int(total)}:
            if submit_requested:
                return [
                    f"The report claims €{total}. Submit the report?",
                    Call("submit_report", {}),
                ]
            return [f"The report claims €{total}."]
    return ["Check the current report before submitting."]


def _arrival(
    last: Message, text: str, instruction: str, offered_tools: frozenset[str]
) -> list[str | Call]:
    arrival = _context(instruction, "arrival")
    notes = _new_notes_raw(instruction)
    if notes:
        match notes[-1]:
            case {"pressed": str(tool), "status": str(status)} as note:
                return [_arrival_answer(tool, status, note, arrival, offered_tools)]
    answers = [part for part in last if isinstance(part, Answer)]
    if answers:
        answer = answers[-1]
        note = answer.result if isinstance(answer.result, dict) else {"result": answer.result}
        status = note.get("status", "returned")
        return [_arrival_answer(answer.name, status, note, arrival, offered_tools)]
    if "taxi" in text.lower() and "app_notes" not in text:
        if "book_ride" in offered_tools:
            match arrival:
                case {"rides": list(rides)} if any(
                    isinstance(ride, dict)
                    and ride.get("id") == "taxi"
                    and ride.get("overPolicy") is True
                    for ride in rides
                ):
                    return ["This taxi is outside the company policy. Choose an allowed route."]
            return [Call("book_ride", {"rideId": "taxi"})]
        return ["Ride booking is not available right now. Check the current screen."]
    reply: list[str | Call] = []
    if "tandem_show_view" in offered_tools:
        reply.append(Call("tandem_show_view", {"components": json.dumps(_day_view(offered_tools))}))
    reply.append(_arrival_summary(arrival))
    return reply


def _new_notes_raw(instruction: str) -> list[dict[str, Any]]:
    notes = _context(instruction, "app_notes").get("new", [])
    return [note for note in notes if isinstance(note, dict)] if isinstance(notes, list) else []


def _arrival_answer(
    tool: str,
    status: str,
    note: dict[str, Any],
    arrival: dict[str, Any],
    offered_tools: frozenset[str],
) -> str:
    if status == "rejected_by_user":
        return "OK, I left it."
    if status == "refused" and isinstance(reason := note.get("reason"), str):
        return f"That did not go through: {reason}"
    if tool == "tandem_show_view" and status == "shown":
        return "The arrival day is on the screen."
    if status != "returned":
        detail = note.get("reason") or note.get("error") or "Check the current screen."
        return f"I could not confirm that action. {detail}"
    host = None
    match arrival:
        case {"meeting": {"host": str(name)}}:
            host = name
    match (tool, note.get("result")):
        case ("book_ride", str(booking)):
            offer = (
                f" I can text {host} that you are on your way."
                if host and "message_host" in offered_tools
                else ""
            )
            return f"Booked: {booking}.{offer}"
        case ("message_host", str(message)):
            return f'{f"Texted {host}" if host else "Sent"}: "{message}"'
        case ("request_early_check_in", _):
            match arrival:
                case {"hotel": {"roomReady": str(ready)}}:
                    if at := _arrival_datetime(ready):
                        return f"The hotel reports your room ready at {at:%H:%M}."
            return "The early check-in was requested."
    return "Done."


def _arrival_summary(arrival: dict[str, Any]) -> str:
    match arrival:
        case {"meeting": {"title": str(title), "start": str(start)}, "rides": list(rides)}:
            meeting = _arrival_datetime(start)
            if meeting is not None:
                for ride in rides:
                    match ride:
                        case {"mode": str(mode), "arrives": str(arrives), "overPolicy": False}:
                            at = _arrival_datetime(arrives)
                            if at is None or (at.tzinfo is None) != (meeting.tzinfo is None):
                                continue
                            if at <= meeting:
                                return (
                                    f"The {mode} gets you there by {at:%H:%M} for {title} "
                                    f"at {meeting:%H:%M}."
                                )
                return f"{title} starts at {meeting:%H:%M}. Check the available routes below."
    return "Check the meeting and route options on the arrival day."


def _arrival_datetime(value: str) -> datetime | None:
    if "T" not in value:
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def _action(tool: str, context: dict[str, Any] | None = None) -> dict[str, Any]:
    event: dict[str, Any] = {"name": tool}
    if context:
        event["context"] = context
    return {"action": {"event": event}}


def _day_view(offered_tools: frozenset[str]) -> list[dict[str, Any]]:
    actions = {
        "onBook": "book_ride",
        "onText": "message_host",
        "onEarlyCheckIn": "request_early_check_in",
    }
    return [
        {
            key: value
            for key, value in component.items()
            if key not in actions or actions[key] in offered_tools
        }
        for component in _DAY_VIEW
    ]


_DAY_VIEW: list[dict[str, Any]] = [
    {
        "id": "root",
        "component": "ArrivalCard",
        "title": "After you land",
        "children": ["next", "rides", "host", "hotel"],
    },
    {
        "id": "next",
        "component": "NextStop",
        "title": {"path": "/arrival/meeting/title"},
        "place": {"path": "/arrival/meeting/place"},
        "start": {"path": "/arrival/meeting/start"},
    },
    {
        "id": "rides",
        "component": "ArrivalColumn",
        "children": {"componentId": "ride", "path": "/arrival/rides"},
    },
    {
        "id": "ride",
        "component": "RideOption",
        "mode": {"path": "mode"},
        "minutes": {"path": "minutes"},
        "fare": {"path": "fare"},
        "arrives": {"path": "arrives"},
        "booked": {"path": "booked"},
        "overPolicy": {"path": "overPolicy"},
        "onBook": _action("book_ride", {"rideId": {"path": "id"}}),
    },
    {
        "id": "host",
        "component": "HostNote",
        "name": {"path": "/arrival/meeting/host"},
        "told": {"path": "/arrival/meeting/hostTold"},
        "onText": _action("message_host"),
    },
    {
        "id": "hotel",
        "component": "HotelNote",
        "name": {"path": "/arrival/hotel/name"},
        "checkIn": {"path": "/arrival/hotel/checkIn"},
        "roomReady": {"path": "/arrival/hotel/roomReady"},
        "onEarlyCheckIn": _action("request_early_check_in"),
    },
]
