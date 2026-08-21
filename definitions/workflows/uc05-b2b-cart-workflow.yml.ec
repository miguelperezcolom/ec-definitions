id: uc05-b2b-cart-saga
name: UC05 B2B Cart Saga
version: 1
steps:
  - id: start
    type: START
    name: Start
  - id: createB2BCart
    type: ACTION
    name: Create B2B Cart
    preconditionStepIds:
      - start
    compensable: true
    compensationStepId: cancelB2BCart
  - id: b2bCartHumanDecision
    type: USER_TASK
    name: B2B Cart human decision
    formId: b2b-cart-form
    preconditionStepIds:
      - createB2BCart
  - id: rejectB2BCart
    type: ACTION
    name: Reject B2B cart
    preconditions:
      - stepId: b2bCartHumanDecision
        expression: decision == 'REJECT'
  - id: end2
    type: END
    name: Aborted
    preconditionStepIds:
      - rejectB2BCart
  - id: chargeB2BCart
    type: ACTION
    name: Charge B2B cart
    retries: 0
    compensable: true
    compensationStepId: refundB2BCart
    preconditions:
      - stepId: b2bCartHumanDecision
        expression: decision == 'APPROVE'
  - id: doB2BCartFulfillment
    type: ACTION
    name: Fulfill B2B Cart
    preconditionStepIds:
      - chargeB2BCart
    retries: 0
    compensable: true
    compensationStepId: releaseB2BCartFulfillment
  - id: sendB2BCartNotification
    type: ACTION
    name: Send B2B cart confirmed notification
    retries: 0
    timeout: 5000
    preconditions:
      - stepId: doB2BCartFulfillment
  - id: confirmB2BCart
    type: ACTION
    name: Confirm B2B cart
    preconditionStepIds:
      - sendB2BCartNotification
    retries: 0
    timeout: 5000
  - id: end1
    type: END
    name: Done
    preconditionStepIds:
      - confirmB2BCart
  - id: cancelB2BCart
    type: ACTION
    name: Cancel B2B Cart
    retries: 0
  - id: releaseB2BCartFulfillment
    type: ACTION
    name: Release B2B cart fulfillment
    retries: 0
  - id: refundB2BCart
    type: ACTION
    name: Refund B2B cart
    retries: 0
limitConcurrentExecutions: false
