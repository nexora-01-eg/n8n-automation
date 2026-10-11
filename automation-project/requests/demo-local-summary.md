# Automation Request: demo-local-summary

## Slug
demo-local-summary

## Goal
Local demo: build a small in-memory news list, remove duplicates, classify items, keep important ones, and shape a clear output. No external APIs, no credentials, manual trigger.

## Trigger
manual

## Schedule


## Feed URL


## Inputs
- Built-in sample items (generated inside the workflow)

## Steps
- Generate 4 sample news items (one duplicated link)
- Deduplicate by link, classify by keywords, mark important
- Route important items to output shaping

## Conditions
- Output only items with important=true

## External Services
-

## Outputs
List of items: title, link, category, important, processedAt

## Storage
- (in-memory only, no persistence)

## Notifications
-
