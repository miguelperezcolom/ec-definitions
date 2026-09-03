id: verify-booking-payment
name: Verify booking payment
version: 1
description: >-
  A human confirms a booking's payment; a real service then confirms or cancels the booking, and a 30-second deadline on
  the person cancels it for them.
steps:
  - id: start
    type: START
    name: Start
  - id: confirm-booking
    type: ACTION
    name: Confirm booking
    topic: booking
    preconditions:
      - stepId: start
  - id: end
    type: END
    name: End
    preconditions:
      - stepId: confirm-booking
