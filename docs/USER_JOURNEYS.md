# ARIA User Journeys

## Overview

This document maps the five primary user journeys in ARIA. Each journey shows
the full flow from trigger to resolution, including UI state, system actions,
and failure modes.

---

## Journey 1 — Onboarding

**Trigger:** User downloads ARIA for the first time.

### Steps

| # | User Action | System Action | UI State |
|---|-------------|---------------|----------|
| 1 | Opens app | Load splash animation | Animated ARIA logo, gradient background |
| 2 | Taps "Get Started" | Navigate to step 1 | Welcome page with progress bar (1/5) |
| 3 | Reads welcome | — | Feature highlights: Memory · Events · Privacy |
| 4 | Taps "Continue" | Advance to name selection | Page 2/5: preset name chips |
| 5 | Taps "ARIA" (or custom name) | Preview card updates in real time | Selected chip highlighted, preview card shows chosen name |
| 6 | Taps "Continue" | Navigate to calendar | Page 3/5 |
| 7 | Toggles Google Calendar ON | Request OAuth permission | System permission dialog |
| 8 | Grants permission | Token stored encrypted | Toggle shows green, card border glows |
| 9 | Taps "Continue" | Navigate to comms | Page 4/5 |
| 10 | Toggles Email ON | — | Email tile highlights |
| 11 | Taps "Continue" | Navigate to privacy | Page 5/5 |
| 12 | Reads privacy promises | — | 5 privacy items with icons |
| 13 | Taps "Get Started" | Call `completeOnboarding()` + `updateAssistantName()` | Loading spinner briefly, then dashboard |
| 14 | Arrives at Dashboard | Generate first daily briefing | Greeting card: "Good morning! Here's your day." |

### Success Criteria
- User completes onboarding in under 3 minutes
- At least one integration connected
- First daily briefing displayed

### Failure States
- OAuth permission denied → show "You can connect later in Settings" and continue
- Network error on token save → queue for retry, don't block onboarding

---

## Journey 2 — Meeting Detection (WhatsApp → Calendar)

**Trigger:** User receives WhatsApp message: "Let's meet tomorrow at 3 PM."

### Steps

| # | User Action | System Action | UI State |
|---|-------------|---------------|----------|
| 1 | — | WhatsApp integration detects new message | Background service running |
| 2 | — | Text sent to AI service: `detect_intent(text)` | Processing (invisible to user) |
| 3 | — | Claude returns: `{type: meeting, person: John, date: tomorrow, time: 15:00, confidence: 0.92}` | — |
| 4 | — | Confidence ≥ threshold (70%) → create pending Event in DB | Event status = `pending` |
| 5 | — | Firebase FCM push sent: "📅 Meeting detected — John, tomorrow 3 PM" | Lock screen notification |
| 6 | User taps notification | App opens to Dashboard | Pending suggestions section visible |
| 7 | User sees suggestion card | — | Card shows: Person · Date · Time · Source · 92% confidence badge |
| 8 | User taps "Approve" | `POST /events/{id}/approve` called | Loading indicator on button |
| 9 | — | Backend calls Google Calendar API to create event | — |
| 10 | — | Event created in calendar, status updated to `approved` | Success toast: "Added to Calendar ✓" |
| 11 | — | Suggestion card removed from Dashboard | Smooth animated removal |

### AI Reasoning Shown to User
> "Detected from WhatsApp: 'Let's meet tomorrow at 3 PM.' — John is in your contacts."

### Failure States
- Calendar API fails → show retry option, keep event as `pending`
- User taps "Ignore" → event marked `rejected`, never shown again
- Confidence below threshold → event stored but not surfaced

---

## Journey 3 — Daily Briefing

**Trigger:** 7:00 AM — configured briefing time.

### Steps

| # | User Action | System Action | UI State |
|---|-------------|---------------|----------|
| 1 | — | Celery task fires at 7:00 AM for each user | Background worker |
| 2 | — | `generate_daily_briefing(user_id)` called | — |
| 3 | — | Claude synthesizes: calendar events + pending tasks + pending suggestions | — |
| 4 | — | Briefing stored, FCM push sent | Lock screen: "Good morning! 3 meetings, 2 tasks today." |
| 5 | User taps notification | App opens to Dashboard | Dashboard loads with briefing card |
| 6 | User reads briefing card | — | Card shows: greeting + stats (meetings / tasks / pending) |
| 7 | User scrolls down | — | "Needs Your Approval" section with pending suggestions |
| 8 | User taps "Approve" on meeting suggestion | API call to approve | Event added to calendar |
| 9 | User taps "Ignore" on travel suggestion | API call to reject | Card removed |
| 10 | User scrolls to "Today's Schedule" | — | Timeline of all events for today |
| 11 | User taps ARIA chat FAB | Navigate to ChatScreen | ARIA opens with context: "Anything you want to prep for your 10 AM call?" |

### Briefing Content Structure
```
Good morning, Vidhi.

You have 3 meetings today:
  • 10:00 AM — Team Standup (30 min)
  • 2:00  PM — Client Call with Raj (1 hr)
  • 4:30  PM — Product Review (1 hr)

2 tasks due today:
  • Send proposal to Raj  [HIGH]
  • Review Q4 budget      [MEDIUM]

2 items need your approval.
```

### Failure States
- No events or tasks → "Looks like a clear day! Enjoy the breathing room."
- AI generation fails → show static calendar view without AI summary
- User has no connected calendar → prompt to connect one

---

## Journey 4 — Travel Detection (Flight Email → Full Pack)

**Trigger:** Gmail receives IndiGo flight booking confirmation.

### Steps

| # | User Action | System Action | UI State |
|---|-------------|---------------|----------|
| 1 | — | Email integration receives new email from IndiGo | Background polling |
| 2 | — | `travel_service.detect_from_email(email_body)` called | — |
| 3 | — | Claude extracts: airline, flight number, DEL→BOM, Jan 17 7:00 AM, booking ref IND7X3 | — |
| 4 | — | TravelBooking created in DB, confidence = 0.97 | — |
| 5 | — | FCM push: "✈️ Flight detected — Delhi to Mumbai, tomorrow 7 AM" | Lock screen |
| 6 | User opens app | Navigate to Travel screen | Flight card displayed at top |
| 7 | — | ARIA generates 4 contextual suggestions | Suggestion list below flight card |
| 8 | User sees "Add to Calendar?" | — | Suggestion card with Approve/Ignore |
| 9 | User taps "Yes" | Create calendar event for flight | Calendar updated |
| 10 | User sees "Set Wake-Up Alarm?" | — | "4:30 AM suggested" |
| 11 | User taps "Yes" | Open native alarm intent | System alarm dialog |
| 12 | User sees "Book Airport Cab?" | — | Cab booking suggestion |
| 13 | User taps "Yes" | Deep-link to Uber/Ola | App opens with pre-filled destination |
| 14 | User sees "Check Weather?" | — | Weather card: "Mumbai: 28°C, partly cloudy" |
| 15 | User sees "Start Packing Checklist?" | — | "2-night trip — generate?" |
| 16 | User taps "Yes" | Claude generates packing list | Modal with 12-item checklist |

### Key Principle
**Every action requires explicit user approval.** ARIA never books a cab, sets an alarm, or creates an event without the user tapping "Yes."

### Failure States
- Email parsing fails → still create basic booking record with raw text
- Calendar creation fails → retry with backoff
- User dismisses all suggestions → log preference, adjust future suggestions

---

## Journey 5 — Voice Command

**Trigger:** User says "Hey ARIA, remind me to call Raj tomorrow at 11."

### Steps

| # | User Action | System Action | UI State |
|---|-------------|---------------|----------|
| 1 | Says "Hey ARIA" | Wake word detected by on-device model | Waveform animation appears |
| 2 | Speaks full command | Audio captured (16kHz, 16-bit PCM) | Recording indicator pulses |
| 3 | Stops speaking | Audio sent to Whisper STT endpoint | "Listening..." changes to "Processing..." |
| 4 | — | Whisper returns: "remind me to call Raj tomorrow at 11" | — |
| 5 | — | Claude parses intent: `{action: create_reminder, person: Raj, time: tomorrow_11am}` | — |
| 6 | — | Confirmation card generated | Card appears in ChatScreen |
| 7 | User sees card | — | Card: "Create reminder: Call Raj — tomorrow, 11:00 AM?" |
| 8 | User says "Yes" OR taps "Approve" | `POST /tasks` with due_date, source=voice | Loading |
| 9 | — | Task created, reminder scheduled via FCM | — |
| 10 | — | TTS response: "Done! I'll remind you to call Raj tomorrow at 11 AM." | Audio plays, text shown |

### Alternative Commands Handled

| Command | Intent | Action |
|---------|--------|--------|
| "What do I have today?" | query_schedule | Show today's events |
| "When am I meeting Sarah?" | query_person_event | Search events for Sarah |
| "Don't let me forget my dentist" | create_reminder | Create reminder from vague input |
| "Cancel my 3 PM meeting" | cancel_event | Surface event, ask to confirm cancel |
| "What did I promise Raj?" | query_memory | Search memory store for Raj |

### Voice Pipeline
```
Audio Input
    ↓
On-Device Wake Word (Porcupine)
    ↓
Audio Buffer (2–30 seconds)
    ↓
Whisper STT (API or on-device)
    ↓
Text → Claude Intent Detection
    ↓
Structured Intent
    ↓
Confirmation Card (never auto-execute)
    ↓
User Approval
    ↓
Execute + TTS Confirmation
```

### Failure States
- Wake word false positive → user can tap the mic button instead
- STT fails → show "I couldn't hear that. Try typing instead."
- Ambiguous command → ARIA asks clarifying question before creating card
- No internet → queue command, process when reconnected (offline tasks only)

---

## Design Principles Across All Journeys

1. **Observe → Understand → Suggest → Confirm → Execute**  
   ARIA never skips the "Confirm" step.

2. **Transparency**  
   Every suggestion shows its source, confidence, and reasoning.

3. **Graceful degradation**  
   Failed integrations never break the core experience.

4. **Minimal interruption**  
   Focus Mode suppresses non-urgent notifications during meetings.

5. **One-tap recovery**  
   Any dismissed suggestion can be found in History within 24 hours.
