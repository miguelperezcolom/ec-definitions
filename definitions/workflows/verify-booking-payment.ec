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
  - id: verify-payment
    type: USER_TASK
    name: Verify payment received
    formId: verify-payment
    topic: forms
    preconditionStepId: start
    timeout: 300000
    onTimeoutStepId: cancel-booking
  - id: confirm-booking
    type: ACTION
    name: Confirm booking
    topic: booking
    preconditions:
      - stepId: verify-payment
        expression: paymentReceived == 'true'
  - id: cancel-booking
    type: ACTION
    name: Cancel booking
    topic: booking
    preconditions:
      - stepId: verify-payment
        expression: paymentReceived == 'false'
  - id: done
    type: JOIN
    name: Done
    joinType: XOR
    preconditionStepIds:
      - confirm-booking
      - cancel-booking
  - id: end
    type: END
    name: End
    preconditionStepId: done
