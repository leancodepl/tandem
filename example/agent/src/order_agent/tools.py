import re

from order_agent.data import CUSTOMERS, ORDER_HISTORY


def find_customer(query: str) -> list[dict]:
    """Finds customers by the company name, a contact's name or an e-mail address.

    Args:
      query: For example the signature of an e-mail, such as "Marta, Acme Office Supply".

    Returns:
      The matching customers, the best match first; empty when none matches.
    """
    words = _words(query)

    def score(customer: dict) -> int:
        return len(words & _words(" ".join(customer.values())))

    return sorted(filter(score, CUSTOMERS), key=score, reverse=True)


def get_order_history(customer_id: str) -> list[dict]:
    """Lists the customer's past orders with their lines, newest first.

    Args:
      customer_id: The id from find_customer, such as "acme".
    """
    return ORDER_HISTORY.get(customer_id, [])


def _words(text: str) -> set[str]:
    # Shorter words ("Sp.", "z", "o") would match every company.
    return set(re.findall(r"\w{3,}", text.lower()))
