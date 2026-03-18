# HEARTBEAT.md

## Morning Brief (once daily, ~9:00 AM)
When it's morning (first heartbeat after 9:00 AM) and no morning brief has been sent today:

1. **Weather** -- Current weather and forecast for the user's location
2. **AI News** -- Top 3-5 stories in AI/LLM/agents space
3. **Industry News** -- Top 3-5 stories relevant to the user's work
4. **Reminders** -- Check memory/YYYY-MM-DD.md for any pending reminders

Keep it concise but informative. Track in memory/heartbeat-state.json so you don't send it twice.

## Nightly Reflection Loop (3:00 AM)
When it's 3 AM (after all daily activity complete):

### Data Gathering:
1. Review today's memory/YYYY-MM-DD.md
2. Check learning events -- mistakes made, rules added
3. Review any system issues

### Analysis:
1. What went well? -- successful patterns, wins
2. What went wrong? -- failures, mistakes, blockers
3. What patterns emerge? -- recurring issues, automation opportunities
4. What needs follow-up? -- incomplete tasks, pending decisions

### Memory Consolidation:
- Compress daily logs into essential insights
- Remove redundant information
- Cross-reference patterns with previous learnings

### Output:
Write to `knowledge/reflections/YYYY-MM-DD.md`:
```
# Reflection -- YYYY-MM-DD

## Summary
(3-5 sentences)

## Went Well
- (what worked and why)

## Went Wrong
- (what failed and why)

## Lessons
- (distilled principle, not the event)

## Action Items
- [ ] (concrete next step)
```

Silent unless urgent issues detected.

## System Health Check (once daily, quiet)
- Check for OpenClaw updates (`openclaw status`)
- Only notify if:
  - Critical security update
  - Major version with breaking changes
  - Significant improvements worth knowing about
- Don't notify for minor patches

## Reminders
- Check memory/YYYY-MM-DD.md for any reminders set
- Deliver at the right time, then remove from pending

## Rules
- Quiet hours: 01:00-09:00 unless urgent
- If nothing needs attention: HEARTBEAT_OK
- If something matters: message directly
