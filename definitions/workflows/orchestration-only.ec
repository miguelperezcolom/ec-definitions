# Pure orchestration: what one orchestrator costs, with no worker in the way.
#
# Every step here is resolved by the engine itself — a JOIN with a single precondition is a
# pass-through, and START and END are engine transitions too. There is no ACTION, so no task is
# ever dispatched and no worker is involved at all.
#
# That is the whole point. Throughput on a workflow with ACTION steps measures the slowest of the
# engine, the worker and the queue between them; this one can only measure the engine. Twelve
# transitions per process, so processes/s x 12 is the orchestrator's transition rate.
id: orchestration-only
name: Orchestration only (benchmark)
version: 1
description: A chain of engine-resolved steps, for measuring orchestrator capacity with no worker.
steps:
  - id: start
    type: START
    name: Start
  - id: hop-1
    type: JOIN
    name: Hop 1
    joinType: AND
    preconditionStepIds: [start]
  - id: hop-2
    type: JOIN
    name: Hop 2
    joinType: AND
    preconditionStepIds: [hop-1]
  - id: hop-3
    type: JOIN
    name: Hop 3
    joinType: AND
    preconditionStepIds: [hop-2]
  - id: hop-4
    type: JOIN
    name: Hop 4
    joinType: AND
    preconditionStepIds: [hop-3]
  - id: hop-5
    type: JOIN
    name: Hop 5
    joinType: AND
    preconditionStepIds: [hop-4]
  - id: hop-6
    type: JOIN
    name: Hop 6
    joinType: AND
    preconditionStepIds: [hop-5]
  - id: hop-7
    type: JOIN
    name: Hop 7
    joinType: AND
    preconditionStepIds: [hop-6]
  - id: hop-8
    type: JOIN
    name: Hop 8
    joinType: AND
    preconditionStepIds: [hop-7]
  - id: hop-9
    type: JOIN
    name: Hop 9
    joinType: AND
    preconditionStepIds: [hop-8]
  - id: hop-10
    type: JOIN
    name: Hop 10
    joinType: AND
    preconditionStepIds: [hop-9]
  - id: end
    type: END
    name: Done
    preconditionStepId: hop-10
