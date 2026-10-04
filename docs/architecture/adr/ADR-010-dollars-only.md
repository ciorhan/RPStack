# ADR-010: Dollars only for RPStack money paths

Date: 2026-10-04
Status: Accepted

## Decision

RPStack money paths (treasuries, transfers, ledger) handle VORP currency `0` (dollars) only, as positive whole-dollar integers. VORP gold (`1`) and rol (`2`) are out of scope.

## Reasoning

One currency keeps the ledger, journal, and validation simple. VORP stores money as `double(11,2)`; whole-dollar integers are stored exactly and avoid floating-point drift.

## Consequences

Easier: simple validation and accounting.
Harder: gold-denominated features need a later ADR and a schema extension.
