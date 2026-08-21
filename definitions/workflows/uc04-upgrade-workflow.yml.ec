id: uc04-upgrade-saga
name: UC04 Upgrade Saga
version: 1
steps:
  - id: start
    type: START
    name: Start
  - id: getReservation
    type: ACTION
    name: Get reservation
    preconditionStepIds:
      - start
  - id: setReservationUpgradingStatus
    type: ACTION
    name: Updates reservation status to UPGRADE_IN_PROGRESS
    preconditionStepIds:
      - getReservation
    retries: 0
    compensable: true
    compensationStepId: restoreReservation
  - id: checkAvailability
    type: ACTION
    name: Check upgrade availability
    preconditionStepIds:
      - setReservationUpgradingStatus
  - id: rejectUpgrade
    type: ACTION
    name: Reject upgrade and restore reservation
    preconditions:
      - stepId: checkAvailability
        expression: '!upgradeAvailable'
  - id: end1
    type: END
    name: Failed
    preconditionStepIds:
      - rejectUpgrade
  - id: chargeAdditionalAmount
    type: ACTION
    name: Charge additional amount
    preconditions:
      - stepId: checkAvailability
        expression: upgradeAvailable
    compensable: true
    compensationStepId: cancelAdditionalCharge
  - id: updateReservationInPms
    type: ACTION
    name: Update PMS reservation
    preconditions:
      - stepId: chargeAdditionalAmount
    compensable: true
    compensationStepId: restoreReservationInPms
  - id: sendUpgradeNotification
    type: ACTION
    name: Send reservation upgraded notification
    retries: 0
    timeout: 5000
    preconditions:
      - stepId: updateReservationInPms
  - id: confirmUpgrade
    type: ACTION
    name: Confirm upgrade
    preconditionStepIds:
      - sendUpgradeNotification
    retries: 0
    timeout: 5000
  - id: end2
    type: END
    name: Done
    preconditionStepIds:
      - confirmUpgrade
  - id: cancelAdditionalCharge
    type: ACTION
    name: Cancel additional charge
    retries: 0
  - id: restoreReservationInPms
    type: ACTION
    name: Restore reservation status in PMS
    retries: 0
  - id: restoreReservation
    type: ACTION
    name: Fail the upgrading process
limitConcurrentExecutions: false
