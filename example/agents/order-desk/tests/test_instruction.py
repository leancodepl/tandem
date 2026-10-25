from datetime import date

from order_desk.instruction import instruction


def test_the_instruction_tells_the_model_the_weekday_of_today() -> None:
    assert "Today is Friday, 16 October 2026." in instruction(date(2026, 10, 16), [])
