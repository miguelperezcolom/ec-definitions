id: uc01-reservation-saga
name: UC01 Reservation Saga
version: 1
steps:
  - id: start
    type: START
    name: Start
  - id: createReservation
    type: ACTION
    name: Create the reservation
    preconditionStepIds:
      - start
    retries: 0
    compensable: true
    compensationStepId: errorReservation
  - id: holdInventory
    type: ACTION
    name: Reserve the inventory
    preconditionStepIds:
      - createReservation
    compensable: true
    retries: 0
    compensationStepId: cancelReservation
  - id: createPaymentIntent
    type: ACTION
    name: Creates the payment intent
    preconditionStepIds:
      - holdInventory
    compensable: true
    retries: 0
    compensationStepId: releaseInventory
  - id: sendNotification
    type: ACTION
    name: Send reservation confirmed notification
    preconditionStepIds:
      - createPaymentIntent
    retries: 0
    timeout: 0
  - id: waitForPayment
    type: WAIT_FOR_MESSAGE
    name: Wait for payment confirmation
    messageName: payment-captured
    correlationExpression: businessKey
    preconditionStepIds:
      - sendNotification
    timeout: 60000
    compensable: false
    compensationStepId: cancelPaymentIntent
    onTimeoutStepId: cancelPaymentIntent
  - id: confirmReservation
    type: ACTION
    name: Confirm the reservation
    preconditionStepIds:
      - waitForPayment
  - id: end
    type: END
    name: Done
    preconditionStepIds:
      - confirmReservation
  - id: cancelReservation
    type: ACTION
    name: Cancel the reservation
    retries: 0
  - id: releaseInventory
    type: ACTION
    name: Release the inventory
    retries: 0
  - id: cancelPaymentIntent
    type: ACTION
    name: Cancel the payment intent
    retries: 0
  - id: errorReservation
    type: ACTION
    name: Fail the reservation
limitConcurrentExecutions: false
