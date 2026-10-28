import json

import pytest
from tandem_thread import Run, Thread

EMAIL = (
    "Hi, could you send us 40 HDMI cables (2 m) and 12 of the 27-inch monitors like last time? "
    "Delivery to Magazynowa 5, Poznań by Friday please. Thanks, Marta, Acme Office Supply"
)
NORTHLINE_EMAIL = "Hi, 40 HDMI cables (2 m) and 12 monitors please. Thanks, Piotr, Northline"
ACME = {
    "id": "acme",
    "name": "Acme Office Supply Sp. z o.o.",
    "contact": "Marta Nowak",
    "priceList": "Acme 2026",
}
# A customer the agent has no usual delivery address for.
NORTHLINE = {"id": "northline", "name": "Northline Logistics S.A.", "contact": "Piotr Zieliński"}
DELIVERY = {"address": "Magazynowa 5, 61-001 Poznań", "date": "2026-10-23T00:00:00.000"}
CABLES = {
    "sku": "VC-HDMI-2M",
    "name": "HDMI 2.1 cable, 2 m",
    "description": "Braided cable for 8K video",
    "price": 29,
}
PROVIEW_27Q = {
    "sku": "VM-27Q",
    "name": 'Voltra ProView 27Q, 27" QHD monitor',
    "description": "27-inch QHD monitor, 2560 x 1440, IPS",
    "price": 1249,
}
PROVIEW_27U = {
    "sku": "VM-27U",
    "name": 'Voltra ProView 27U, 27" 4K monitor',
    "description": "27-inch 4K monitor, 3840 x 2160, IPS",
    "price": 1699,
}
# The 4K model comes first, so the last order and not the order of the results decides.
FOUND = {"HDMI cable 2 m": [CABLES], "27-inch monitor": [PROVIEW_27U, PROVIEW_27Q]}
EMPTY = {"customer": None, "lines": [], "delivery": None, "total": "0.00 PLN"}
REJECTED = '{"status":"rejected_by_user"}'
INVALIDATED = '{"status":"invalidated"}'
WAKE = (
    "The app sent this, not the user. Something happened in the app: read app_notes in your "
    "context and act on it if it needs you."
)
TIER = "You changed the monitors to 15, which unlocks Acme's 15+ tier (17 % off monitors)."


def screen(monitors: int, total: str) -> dict:
    return {
        "customer": ACME,
        "lines": [
            {"sku": "VC-HDMI-2M", "name": CABLES["name"], "quantity": 40},
            {"sku": "VM-27Q", "name": PROVIEW_27Q["name"], "quantity": monitors},
        ],
        "delivery": DELIVERY,
        "total": total,
    }


def answers(run: Run) -> dict[str, str]:
    return {
        call.id: json.dumps(FOUND[call.args["query"]] if call.name == "search_catalog" else None)
        for call in run.app_calls
    }


def calls(run: Run) -> list[tuple[str, dict]]:
    return [(call.name, call.args) for call in run.app_calls]


@pytest.fixture
def asked_to_place(agent_url: str) -> Thread:
    thread = Thread(agent_url)
    first = thread.run(EMPTY, EMAIL)
    second = thread.run({**EMPTY, "customer": ACME}, answers=answers(first))
    thread.run(screen(12, "14 349.44 PLN"), answers=answers(second))
    return thread


def test_the_email_turn_ends_with_the_app_calls(agent_url: str) -> None:
    run = Thread(agent_url).run(EMPTY, EMAIL)

    assert "RUN_ERROR" not in run.types
    assert [call.name for call in run.calls] == [
        "find_customer",
        "get_order_history",
        "set_customer",
        "search_catalog",
        "search_catalog",
    ]
    assert calls(run) == [
        ("set_customer", {"customerId": "acme"}),
        ("search_catalog", {"query": "HDMI cable 2 m"}),
        ("search_catalog", {"query": "27-inch monitor"}),
    ]


def test_the_agent_picks_the_monitor_from_the_last_order(agent_url: str) -> None:
    thread = Thread(agent_url)
    first = thread.run(EMPTY, EMAIL)

    run = thread.run({**EMPTY, "customer": ACME}, answers=answers(first))

    assert run.text == "I assumed the ProView 27Q, as in your September order ORD-0987."
    assert calls(run) == [
        ("set_quantity", {"sku": "VC-HDMI-2M", "quantity": 40}),
        ("set_quantity", {"sku": "VM-27Q", "quantity": 12}),
        ("set_delivery", {"address": "Magazynowa 5, 61-001 Poznań", "date": "2026-10-23"}),
    ]


def test_the_agent_reads_the_total_from_the_screen(agent_url: str) -> None:
    thread = Thread(agent_url)
    first = thread.run(EMPTY, EMAIL)
    second = thread.run({**EMPTY, "customer": ACME}, answers=answers(first))

    run = thread.run(screen(12, "14 349.44 PLN"), answers=answers(second))

    assert run.text == (
        "40 HDMI cables and 12 ProView 27Q monitors, delivered on 23 Oct. "
        "Total 14 349.44 PLN. Shall I place it?"
    )
    assert run.app_calls == []


def test_the_agent_names_the_tier_the_user_reached(asked_to_place: Thread) -> None:
    run = asked_to_place.run(screen(15, "16 710.05 PLN"), "Looks good, place it")

    assert run.text == TIER
    assert calls(run) == [("place_order", {})]


def test_the_agent_places_the_order_without_comment_below_the_tier(asked_to_place: Thread) -> None:
    run = asked_to_place.run(screen(12, "14 349.44 PLN"), "Place it")

    assert run.text == ""
    assert calls(run) == [("place_order", {})]


def test_the_agent_reports_the_order_id(asked_to_place: Thread) -> None:
    placing = asked_to_place.run(screen(15, "16 710.05 PLN"), "Looks good, place it")

    # The desk keeps the placed order on the screen, read-only.
    run = asked_to_place.run(
        screen(15, "16 710.05 PLN"),
        answers={placing.app_calls[0].id: '"ORD-1042"'},
        placed=True,
    )

    assert run.text == "Order ORD-1042 placed for 23 Oct."


def test_the_agent_accepts_a_rejection(asked_to_place: Thread) -> None:
    placing = asked_to_place.run(screen(15, "16 710.05 PLN"), "Looks good, place it")

    run = asked_to_place.run(
        screen(15, "16 710.05 PLN"), answers={placing.app_calls[0].id: REJECTED}
    )

    assert run.text == "OK, I won't place it."
    assert run.app_calls == []


def test_the_agent_asks_again_once_the_app_wakes_it_after_an_edit(asked_to_place: Thread) -> None:
    placing = asked_to_place.run(screen(12, "14 349.44 PLN"), "Place it")

    run = asked_to_place.run(
        screen(15, "16 710.05 PLN"), WAKE, answers={placing.app_calls[0].id: INVALIDATED}
    )

    assert run.text == TIER
    assert calls(run) == [("place_order", {})]


def test_the_agent_reports_an_order_it_did_not_fill(agent_url: str) -> None:
    thread = Thread(agent_url)
    placing = thread.run(screen(12, "14 349.44 PLN"), "place it")

    run = thread.run(
        screen(12, "14 349.44 PLN"),
        answers={placing.app_calls[0].id: '"ORD-1042"'},
        placed=True,
    )

    assert run.text == "Order ORD-1042 placed."


def test_the_agent_does_not_place_an_order_without_delivery(agent_url: str) -> None:
    # The desk lists place_order only once the order has a delivery.
    run = Thread(agent_url).run({**screen(12, "14 349.44 PLN"), "delivery": None}, "place it")

    assert run.text == "Paste a customer's e-mail, or ask me to place the order."
    assert run.calls == []


def test_the_agent_asks_for_the_address_of_a_customer_without_one(agent_url: str) -> None:
    thread = Thread(agent_url)
    first = thread.run(EMPTY, NORTHLINE_EMAIL)

    run = thread.run({**EMPTY, "customer": NORTHLINE}, answers=answers(first))

    assert run.text == "Which address should I deliver to?"
    assert run.app_calls == []


def test_the_agent_says_when_the_catalog_has_no_match(agent_url: str) -> None:
    thread = Thread(agent_url)
    first = thread.run(EMPTY, EMAIL)
    nothing = {call.id: "[]" for call in first.app_calls}

    run = thread.run({**EMPTY, "customer": ACME}, answers=nothing)

    assert run.text == 'I could not find "HDMI cable 2 m" in the catalog.'
    assert run.app_calls == []


def test_anything_else_gets_a_neutral_reply(agent_url: str) -> None:
    run = Thread(agent_url).run(EMPTY, "Hello")

    assert run.text == "Paste a customer's e-mail, or ask me to place the order."
    assert run.calls == []
