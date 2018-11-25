# Time tracker for busy consultants!

## Data types
- Timesheet
  - id -> string
  - start -> timestamp
  - end -> timestamp
  - company -> String
- Timesheet Input
  - start -> timestamp
  - end -> timestamp
  - company -> String

## Operations needing support
- Add timesheet
- Display timesheets with pagination
- Delete timesheet
- Edit timesheet
- Export timesheets
  - By time
  - By company
  - Configurable time

## Settings
- Quiet hours
- Pop up frequency
- Snooze pop ups for duration


## Future fancy
- Add timesheets
  - Create timeslots and populate modal based on non-filled timeslots for the day
    - Add ability to mark timeslot as "non-invoiceable"? <-- v2 feature
- Settings
  - Show settings page

## TODO
- Menu cleanup
- DevTools removal
- Correct db locations
- Test builder
- Taskbard icon
- Minimization/closing
