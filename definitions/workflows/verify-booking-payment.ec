# Verify booking payment — the one process here whose ACTIONs are answered by a real service.
#
# Every other definition in this repository is served by the test worker, which does no work and
# plays back whatever TEST_CONFIG tells it. The two ACTIONs below are not: `topic: booking` routes
# them to the booking service, which loads the booking, changes its status and replies. The
# process is what makes a row in a database change.
#
# Shape-wise this is payment-review with a service behind it: a person confirms the payment, a
# 30-second deadline cancels if they do not, and a JOIN·XOR ends on whichever branch wins.
#
# Two things it needs that the others do not:
#
#   • **A `bookingId` process variable.** The booking service reads it off the task to know which
#     booking to act on, and rejects the task outright without it. Start the process with it:
#
#         {"variables": [{"name": "bookingId", "value": "<an existing booking id>"}]}
#
#     The id has to exist — create one from Booking → Bookings in the console, or ask the chat
#     agent to ("crea una reserva para Ana"), which is the same MCP tool.
#
#   • **The booking service deployed and consuming `booking`.** Without it these two steps are
#     dispatched to a topic nobody reads and the process stops at whichever one it reached. That
#     is a stuck process, not an error: check the Groups tab of the Redpanda console before
#     concluding the engine lost the message.
id: verify-booking-payment
name: Verify booking payment
version: 1
description: >-
  A human confirms a booking's payment; a real service then confirms or cancels the booking,
  and a 30-second deadline on the person cancels it for them.
steps:

  - id: start
    type: START
    name: Start

  # No topic, deliberately, and for the same reason as payment-review's: with none this goes to
  # `downstream`, where the test worker answers it from TEST_CONFIG. That is what keeps the
  # 30-second deadline testable —
  #
  #     {"tasks": {"verify-payment": {"outcome": "NO_REPLY"}}}
  #
  # is a reviewer who never answered, on demand, which no real person can be asked to be. Hand it
  # the decision the same way:
  #
  #     {"tasks": {"verify-payment": {"variables": [{"name": "paymentReceived", "value": "true"}]}}}
  #
  # Add `topic: forms` to make it a real human task instead, answered from Forms → My tasks.
  - id: verify-payment
    type: USER_TASK
    name: Verify payment received
    formId: verify-payment
    preconditionStepId: start
    timeout: PT30S
    onTimeoutStepId: cancel-booking

  # The step ids of these two are a contract, not a label: the booking service switches on the
  # stepId it is handed to decide which status to write, so renaming one here without renaming it
  # there leaves a task that is dispatched, received and silently ignored.
  #
  # They are the same two ids payment-review uses, which is safe only because that definition
  # names no topic and its tasks therefore never reach this service. Routing it here would send
  # tasks the service recognises from a process with no `bookingId` — every one of them rejected.
  - id: confirm-booking
    type: ACTION
    name: Confirm booking
    topic: booking
    preconditions:
      - stepId: verify-payment
        expression: "paymentReceived == 'true'"

  # Reached by an explicit rejection, or by the timeout above.
  - id: cancel-booking
    type: ACTION
    name: Cancel booking
    topic: booking
    preconditions:
      - stepId: verify-payment
        expression: "paymentReceived == 'false'"

  # XOR: whichever outcome completes first ends the process, and END cancels the loser's pending
  # step — which matters here, because the loser is a task sitting in another service's queue.
  - id: done
    type: JOIN
    name: Done
    joinType: XOR
    preconditionStepIds: [confirm-booking, cancel-booking]

  - id: end
    type: END
    name: End
    preconditionStepId: done
