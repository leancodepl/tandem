# Waypoint

Waypoint helps a traveller plan business trips, change bookings and report
expenses under their company's policy.

## Language

**Flight number**:
The airline's designation of a scheduled flight. A particular departure also
has a date and time.

**Airport code**:
A three-letter designation of an airport. An airport's code does not mean
Waypoint serves it.

**Origin**:
The airport a flight departs from.
_Avoid_: from

**Destination**:
The airport a flight arrives at.
_Avoid_: to

**Travel time**:
A civil date and time in Central Europe (`Europe/Warsaw`, CET/CEST), shared
by the demo's destinations. An input with an explicit UTC offset denotes an
instant and is converted to this zone; an input without one already denotes
the travel clock time. The in-memory domain keeps these civil clock fields,
not distinct instants for repeated hours at the autumn DST transition.
If the device's time zone cannot represent a converted clock time because
its own clock skips it, the conversion refuses that input instead of shifting
it. Parsing a raw time without an offset can already normalize a local DST
gap before this conversion; this civil model does not validate that raw input.

**Money**:
An amount in a currency. A booking change can have a negative amount when it
reduces the cost. Waypoint currently uses whole currency units.

**Currency**:
The denomination of a money amount. Waypoint currently uses euros (EUR).

**Night count**:
The positive number of nights in a hotel stay. A trip without a hotel stay can
last a single day.

**Stay total**:
The agreed price of the whole hotel stay. Importing a confirmation preserves
this amount exactly.

**Nightly quote**:
A provider's price for one night, used to price a change in the stay's length.
A confirmation's total alone does not establish a nightly quote.

**Booking reference**:
The identifier a provider assigns to a booking. Its spelling belongs to the
provider.
_Avoid_: confirmation number
