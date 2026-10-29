# ADR-0015 — Graph as a computed projection, centered native view

- Status: accepted
- Date: 2026-10-11
- Spec references: v1.4 sec. 3.17 (FR-160…165), 10.5; addendum H.15

## Context
The graph view (phase 3) shows relations between projects, items, people, organizations, topics, tags and decisions. All these relations already exist in the model's tables.

## Decision
No dedicated table: the graph is a projection computed in `IAGOIntelligence` (models `GraphNode`/`GraphEdge` in `IAGOCore`) from `item`, `project`, `item_tag`, `item_entity`, `item_link`, `decision`, `decision_entity`, `decision_tag`, `note`. Native SwiftUI view; default mode centered on the selected item with depth 1. Candidate library Grape (license, maintenance and performance to be evaluated); alternative, our own force-directed layout with `Canvas`.

## Consequences
- No data duplication and no synchronization issues between the graph and the model.
- Performance depends on the queries: grouping is mandatory beyond 500 visible nodes.
