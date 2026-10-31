import pytest

from waypoint_agent.instruction import Screen
from waypoint_agent.script import Call, play


@pytest.mark.parametrize(
    "check_in",
    [
        "Wednesday, 18 Unknown 2026, from 15:00",
        "Wednesday, 31 February 2026, from 15:00",
        "Wednesday, 0 November 2026, from 15:00",
        "Wednesday, 18 November 0000, from 15:00",
        "Wednesday, 18 November 2026, from 25:00",
        "Wednesday, 18 November 2026, from 15:61",
        "Wednesday, 18 November 2026",
    ],
)
def test_invalid_check_in_is_skipped_while_valid_fields_are_filled(check_in: str) -> None:
    email = _CONFIRMATION.replace("Wednesday, 18 November 2026, from 15:00", check_in)

    calls = [part for part in play(Screen.BOOKING, [[email]], "") if isinstance(part, Call)]

    assert "set_check_in" not in [call.name for call in calls]
    assert Call("set_check_out", {"day": "2026-11-19"}) in calls
    assert Call("set_confirmation", {"number": "55120873"}) in calls


@pytest.mark.parametrize("total", ["EUR 168.50", "EUR 168.001", "EUR 0.00", "USD 168.00"])
def test_nonwhole_euro_total_is_not_truncated(total: str) -> None:
    email = _CONFIRMATION.replace("EUR 168.00, paid at the hotel", total)

    calls = [part for part in play(Screen.BOOKING, [[email]], "") if isinstance(part, Call)]

    assert "set_total_price" not in [call.name for call in calls]
    assert Call("set_check_in", {"at": "2026-11-18T15:00:00"}) in calls


def test_a_reference_alone_does_not_fabricate_other_fields() -> None:
    assert play(Screen.BOOKING, [["Confirmation number: 55120873"]], "") == [
        Call("set_confirmation", {"number": "55120873"})
    ]
    assert play(Screen.BOOKING, [["Confirmation number:  "]], "") == [
        "This e-mail has no hotel booking."
    ]


_CONFIRMATION = """From: Havnegade Loft <stay@havnegadeloft.example>
Confirmation number: 55120873
Check-in: Wednesday, 18 November 2026, from 15:00
Check-out: Thursday, 19 November 2026, by 11:00
Total: EUR 168.00, paid at the hotel

Havnegade Loft
Havnegade 44, 1058 Copenhagen"""
