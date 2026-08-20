name: New Workflow
steps:
  - id: step-wox762
    type: START
    name: New Start
  - id: step-vqeg6c
    type: ACTION
    name: New Action
    preconditions:
      - stepId: step-wox762
    compensable: true
    compensationStepId: step-onswhp
    onTimeoutStepId: step-g59eji
    timeout: 30000
  - id: step-g59eji
    type: ACTION
    name: New Action
    preconditions:
      - stepId: step-21dls4
  - id: step-21dls4
    type: ACTION
    name: New Action
    preconditions:
      - stepId: step-wox762
  - id: step-onswhp
    type: ACTION
    name: New Action
  - id: step-jrqieo
    type: END
    name: New End
    preconditions:
      - stepId: step-onswhp
      - stepId: step-g59eji
  - id: step-2mbgdk
    type: ACTION
    name: New Action
    preconditions:
      - stepId: step-wox762
