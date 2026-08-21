id: uc03-overbooking-saga
name: UC03 Overbooking Saga
version: 1
steps:
  - id: start
    type: START
    name: Start
  - id: setReservationOverbookingStatus
    type: ACTION
    name: Updates reservation status to OVERBOOKING_IN_PROGRESS
    preconditionStepIds:
      - start
    retries: 0
    compensable: true
    compensationStepId: restoreReservation
  - id: registerIncidence
    type: ACTION
    name: Register incidence in CRM
    preconditionStepIds:
      - setReservationOverbookingStatus
    compensable: true
    compensationStepId: cancelIncidence
  - id: overbookingHumanDecision
    type: USER_TASK
    name: Overbooking human decision
    formId: overbooking-form
    preconditionStepIds:
      - registerIncidence
    timeout: 90000
    onTimeoutStepId: cancelIncidence
  - id: rejectOverbooking
    type: ACTION
    name: Reject overbooking and restore reservation
    preconditions:
      - stepId: overbookingHumanDecision
        expression: decision == 'REJECT'
  - id: end3
    type: END
    name: Aborted
    preconditionStepIds:
      - rejectOverbooking
  - id: refundReservation
    type: ACTION
    name: Refund reservation
    compensable: true
    retries: 0
    compensationStepId: cancelRefund
    preconditions:
      - stepId: overbookingHumanDecision
        expression: decision == 'REFUND'
  - id: registerRefund
    type: ACTION
    name: Register refund in accountability system
    preconditions:
      - stepId: refundReservation
  - id: sendRefundNotification
    type: ACTION
    name: Send reservation refunded notification
    retries: 0
    timeout: 5000
    preconditions:
      - stepId: registerRefund
  - id: confirmRefund
    type: ACTION
    name: Confirm refund
    preconditionStepIds:
      - sendRefundNotification
    retries: 0
    timeout: 5000
  - id: end1
    type: END
    name: Done
    preconditionStepIds:
      - confirmRefund
  - id: doWalk
    type: ACTION
    name: Walk on alternative room
    compensable: true
    retries: 0
    compensationStepId: cancelAlternativeReservation
    preconditions:
      - stepId: overbookingHumanDecision
        expression: decision == 'WALK'
  - id: adjustReservation
    type: ACTION
    name: Perform economic adjustment
    preconditions:
      - stepId: doWalk
    compensable: true
    compensationStepId: revertReservationAdjustment
  - id: registerWalk
    type: ACTION
    name: Register walk in accountability system
    preconditions:
      - stepId: adjustReservation
  - id: sendWalkNotification
    type: ACTION
    name: Send reservation updated notification
    retries: 0
    timeout: 5000
    preconditions:
      - stepId: registerWalk
  - id: confirmWalk
    type: ACTION
    name: Confirm walk
    preconditionStepIds:
      - sendWalkNotification
    retries: 0
    timeout: 5000
  - id: end2
    type: END
    name: Done
    preconditionStepIds:
      - confirmWalk
  - id: cancelRefund
    type: ACTION
    name: Cancel reservation refund
    retries: 0
  - id: cancelAlternativeReservation
    type: ACTION
    name: Walk reservation error
    retries: 0
  - id: revertReservationAdjustment
    type: ACTION
    name: Revert reservation adjustment
    retries: 0
  - id: cancelIncidence
    type: ACTION
    name: Cancel incidence in CRM
    retries: 0
  - id: restoreReservation
    type: ACTION
    name: Fail the overbooking process
limitConcurrentExecutions: false
