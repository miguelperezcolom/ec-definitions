id: uc02-cancellation-saga
name: UC02 Cancellation Saga
version: 1
steps:
  - id: start
    type: START
    name: Start
  - id: updateReservationStatus
    type: ACTION
    name: Updates reservation status to CANCELLING
    preconditionStepIds:
      - start
    retries: 0
    compensable: true
    compensationStepId: restoreReservation
  - id: validateCancellation
    type: ACTION
    name: Check if cancellation is allowed
    preconditionStepIds:
      - updateReservationStatus
  - id: registerPenalty
    type: ACTION
    name: Register penalty if applicable
    preconditions:
      - stepId: validateCancellation
        expression: cancellable && ratePlan == 'NON_REFUNDABLE'
  - id: chargePenalty
    type: ACTION
    name: Charge penalty if applicable
    preconditionStepIds:
      - registerPenalty
    compensable: true
    compensationStepId: deletePenalty
  - id: cancelReservation
    type: ACTION
    name: Cancel reservation
    compensable: true
    retries: 0
    compensationStepId: cancelError
    preconditions:
      - stepId: step-ykuj21
  - id: updateLoyaltyPoints
    type: ACTION
    name: Update loyalty points
    retries: 5
    timeout: 5000
    preconditions:
      - stepId: cancelReservation
  - id: sendNotification
    type: ACTION
    name: Send reservation confirmed notification
    retries: 0
    timeout: 5000
    preconditions:
      - stepId: updateLoyaltyPoints
  - id: confirmCancellation
    type: ACTION
    name: Confirm cancellation
    preconditionStepIds:
      - sendNotification
    retries: 0
    timeout: 5000
  - id: end
    type: END
    name: Done
    preconditionStepIds:
      - confirmCancellation
  - id: cancelError
    type: ACTION
    name: Cancel reservation error
    retries: 0
  - id: deletePenalty
    type: ACTION
    name: Delete cancellation penalty
    retries: 0
  - id: restoreReservation
    type: ACTION
    name: Fail the cancellation
  - id: rejectCancellation
    type: ACTION
    name: Reject Cancellation
    preconditions:
      - stepId: validateCancellation
        expression: '!cancellable'
  - id: end2
    type: END
    name: Failed
    preconditions:
      - stepId: rejectCancellation
  - id: step-ykuj21
    type: JOIN
    name: Cancellation Join
    preconditions:
      - stepId: chargePenalty
      - stepId: validateCancellation
        expression: cancellable && ratePlan == 'FLEXIBLE'
    joinType: XOR
limitConcurrentExecutions: false
