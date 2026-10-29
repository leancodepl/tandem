"""What the scripted model plays in place of a real model: Waypoint's demo.

Like a real model it decides only from the request, so it keeps no count of runs. On the trip, the
workshop in Berlin moves to Friday, the hotel and the flight home follow, and the traveller approves
the booking. On the booking form, it reads a hotel's confirmation e-mail.
"""

import json
import re
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date, datetime
from typing import Any

from waypoint_agent.instruction import Screen

TRIP_REPLY = "This is a scripted assistant: it knows that the workshop in Berlin moves to Friday."
BOOKING_REPLY = "This e-mail has no hotel booking."
# What the app notes when the traveller's change voided an approval.
REASK = "changed the trip on the screen"
_SUMMARY = (
    "Moved the workshop to Friday, added a night at Spree Loft and put you on the 18:05 home. "
    "Book both?"
)


@dataclass(frozen=True)
class Call:
    name: str
    args: dict[str, Any]


@dataclass(frozen=True)
class Answer:
    name: str
    result: Any


Part = str | Call | Answer
Message = Sequence[Part]


def play(screen: Screen, messages: Sequence[Message], instruction: str) -> list[str | Call]:
    """The next turn of the model, oldest message first. The last message holds the user's text
    or the answers the model waits for. The instruction holds the screen and the app's notes."""
    last = messages[-1]
    answers = {part.name: part.result for part in last if isinstance(part, Answer)}
    text = " ".join(part for part in last if isinstance(part, str))
    match screen:
        case Screen.TRIP:
            # A wake-up of the app says only to read its notes, which are in the instruction.
            woken = text.startswith("The app sent this")
            return _trip(answers, "\n".join(_new_notes(instruction)) if woken else text)
        case Screen.BOOKING:
            return _booking(answers, text)
        case Screen.PLAN:
            return _plan(last, text, instruction)
        case Screen.EXPENSES:
            return _expenses(last, instruction)
        case Screen.ARRIVAL:
            return _arrival(last, text, instruction)


def _trip(answers: dict[str, Any], text: str) -> list[str | Call]:
    match answers:
        case {"book_changes": {"confirmation": confirmation}}:
            return [f"Booked. Your confirmation is {confirmation}."]
        case {"book_changes": {"status": "rejected_by_user"}}:
            return ["OK, I won't book them."]
        case {"find_flights": flights}:
            return [_home_after_the_workshop(flights)]
        case {"set_homebound_flight": _}:
            return [_SUMMARY, Call("book_changes", {})]
    if REASK in text:
        return ["The trip changed. Book the changes as they are now?", Call("book_changes", {})]
    if "workshop" in text.lower():
        return [
            Call("move_meeting", {"meetingId": "workshop", "start": "2026-10-30T10:00:00"}),
            Call("set_hotel_nights", {"nights": 2}),
            Call("find_flights", {"origin": "BER", "destination": "WAW", "date": "2026-10-30"}),
        ]
    return [TRIP_REPLY]


def _new_notes(instruction: str) -> list[str]:
    """The app's new notes, from the `app_notes` line of the screen in the instruction."""
    found = re.search(r"^- app_notes: .*?(\{.*\})$", instruction, re.MULTILINE)
    if found is None:
        return []
    return [note.get("note", "") for note in json.loads(found[1]).get("new", [])]


def _home_after_the_workshop(flights: list[dict]) -> Call:
    """The first flight home that the app does not rule out."""
    flight = next(flight for flight in flights if not flight.get("unavailable"))
    # As find_flights gives it: "Fri 2026-10-30 18:05".
    day = date.fromisoformat(flight["departs"].split()[1])
    return Call("set_homebound_flight", {"number": flight["number"], "date": day.isoformat()})


def _booking(answers: dict[str, Any], text: str) -> list[str | Call]:
    if answers:
        return ["Filled in from the confirmation."]
    return _fill(text) or [BOOKING_REPLY]


def _fill(email: str) -> list[str | Call]:
    """One call per field of a confirmation e-mail, in the form the demo's hotels write them."""

    def line(label: str) -> str | None:
        found = re.search(rf"^{label}: (.+)$", email, re.MULTILINE)
        return found[1] if found else None

    if (confirmation := line("Confirmation number")) is None:
        return []
    calls: list[str | Call] = []
    if hotel := re.search(r"^From: (.+?) <", email, re.MULTILINE):
        calls.append(Call("set_hotel", {"name": hotel[1]}))
    # A hotel signs with its name and its address, the last line.
    calls.append(Call("set_address", {"address": email.strip().splitlines()[-1].strip()}))
    if check_in := _date(line("Check-in")):
        at = re.search(r"\d{2}:\d{2}", line("Check-in") or "")
        calls.append(Call("set_check_in", {"at": f"{check_in}T{at[0] if at else '15:00'}:00"}))
    if check_out := _date(line("Check-out")):
        calls.append(Call("set_check_out", {"day": check_out}))
    if total := re.search(r"EUR (\d+)", line("Total") or ""):
        calls.append(Call("set_total_price", {"euros": int(total[1])}))
    calls.append(Call("set_confirmation", {"number": confirmation}))
    return calls


def _date(text: str | None) -> str | None:
    """ "Wednesday, 18 November 2026, from 15:00" as 2026-11-18."""
    found = re.search(r"(\d{1,2}) (\w+) (\d{4})", text or "")
    if found is None:
        return None
    return datetime.strptime(f"{found[1]} {found[2]} {found[3]}", "%d %B %Y").date().isoformat()


def _plan(last: Message, text: str, instruction: str) -> list[str | Call]:
    answers = [part for part in last if isinstance(part, Answer)]
    if not answers:
        if "Vienna" in text or "Alpenlicht" in text:
            return _READ_THE_INVITATION
        return [PLAN_REPLY]
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


def _choose_flight(flights: list[dict], tool: str, afternoon: bool = False) -> Call | None:
    """The first flight the policy allows, after noon when `afternoon`."""
    for flight in flights:
        if flight.get("unavailable"):
            continue
        # As the app writes it: "Tue 2026-12-08 17:40".
        _, day, time = flight["departs"].split()
        if afternoon and int(time.split(":")[0]) < 12:
            continue
        return Call(tool, {"number": flight["number"], "date": day})
    return None


def _closest_hotel(hotels: list[dict]) -> Call | None:
    allowed = [hotel for hotel in hotels if not hotel.get("unavailable")]
    if not allowed:
        return None
    closest = min(allowed, key=lambda hotel: hotel["walkMinutes"])
    return Call("set_hotel", {"hotelId": closest["id"]})


def _plan_summary(instruction: str) -> str:
    found = re.search(r"^- plan: .*?(\{.*\})$", instruction, re.MULTILINE)
    plan = json.loads(found[1]) if found else {}
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


def _expenses(last: Message, instruction: str) -> list[str | Call]:
    found = re.search(r"^- report: .*?(\{.*\})$", instruction, re.MULTILINE)
    report = json.loads(found[1]) if found else {}
    missing = [receipt for receipt in report.get("receipts", []) if receipt.get("claimed") is None]
    answers = [part for part in last if isinstance(part, Answer)]
    if not answers:
        if missing:
            return [
                Call("add_expense", {"receiptId": receipt["id"], "claimed": receipt["paid"]})
                for receipt in missing
            ]
        return _ask_to_submit(report)
    if answers[-1].name == "submit_report":
        match answers[-1].result:
            case {"confirmation": confirmation, "total": total}:
                return [f"Submitted as {confirmation}. €{total} comes back with your next salary."]
            case _:
                return ["OK, the report stays unsubmitted. Submit it when you're ready."]
    # A meal over the daily limit: the app says what is left for that day.
    for answer in answers:
        if not isinstance(answer.result, dict) or answer.result.get("status") != "refused":
            continue
        left = re.search(r"€(\d+) is left", answer.result.get("reason", ""))
        meals = [receipt for receipt in missing if receipt["category"] == "meal"]
        if left and meals and left[1] != "0":
            return [Call("add_expense", {"receiptId": meals[0]["id"], "claimed": int(left[1])})]
    return _ask_to_submit(report)


def _ask_to_submit(report: dict) -> list[str | Call]:
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
    summary = (
        f"All receipts are in: €{report.get('total', 0)} paid back. The dinner went over the "
        "policy's €60 a day for meals, so only what was left for that day is paid back. "
        "Submit the report?"
    )
    return [summary, Call("submit_report", {})]


def _arrival(last: Message, text: str, instruction: str) -> list[str | Call]:
    notes = _new_notes_raw(instruction)
    if notes and "pressed" in notes[-1]:
        return [_answer_press(notes[-1])]
    answers = [part for part in last if isinstance(part, Answer)]
    if answers:
        match answers[-1].result:
            case {"status": "refused", "reason": reason}:
                return [
                    f"I can't book the taxi: {reason}. The S-Bahn is booked from the view in one tap."
                ]
            case _:
                return ["Done."]
    if "taxi" in text.lower() and "app_notes" not in text:
        return [Call("book_ride", {"rideId": "taxi"})]
    return [Call("tandem_show_view", {"components": json.dumps(_DAY_VIEW)}), _ARRIVAL_SUMMARY]


def _new_notes_raw(instruction: str) -> list[dict]:
    found = re.search(r"^- app_notes: .*?(\{.*\})$", instruction, re.MULTILINE)
    return json.loads(found[1]).get("new", []) if found else []


def _answer_press(note: dict) -> str:
    match note:
        case {"status": "refused", "reason": reason}:
            return f"That did not go through: {reason}."
        case {"status": "rejected_by_user"}:
            return "OK, I left it."
        case {"pressed": "book_ride", "result": booking}:
            return f"Booked: {booking}. I can text Lena that you are on your way."
        case {"pressed": "message_host", "result": message}:
            return f'Texted Lena: "{message}"'
        case {"pressed": "request_early_check_in"}:
            return "The hotel will have your room ready at 13:00, so you can drop your bags."
    return "Done."


def _action(tool: str, context: dict | None = None) -> dict:
    event: dict = {"name": tool}
    if context:
        event["context"] = context
    return {"action": {"event": event}}


_ARRIVAL_SUMMARY = (
    "You land at 08:40. The S-Bahn gets you to Studio Kraft by 09:42, in good time for the "
    "kickoff at 11:00."
)

# The arrival day in the app's components, as `ArrivalCatalog` lists them.
_DAY_VIEW = [
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
