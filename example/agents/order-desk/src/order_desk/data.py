"""Customers and their past orders. The catalog and the price lists live in the app."""

CUSTOMERS = [
    {
        "id": "acme",
        "name": "Acme Office Supply Sp. z o.o.",
        "contact": "Marta Nowak",
        "email": "marta.nowak@acme-office.example",
        "usualDeliveryAddress": "Magazynowa 5, 61-001 Poznań",
    },
    {
        "id": "northline",
        "name": "Northline Logistics S.A.",
        "contact": "Piotr Zieliński",
    },
    {
        "id": "kowalscy",
        "name": "Kowalscy i Wspólnicy Sp. j.",
        "contact": "Ewa Kowalska",
    },
]

ORDER_HISTORY = {
    "acme": [
        {
            "orderId": "ORD-0987",
            "date": "2026-09-14",
            "lines": [
                {"sku": "VM-27Q", "quantity": 10},
                {"sku": "VC-HDMI-2M", "quantity": 20},
            ],
        },
    ],
}
