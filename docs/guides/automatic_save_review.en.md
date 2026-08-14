# Automatic review on save

Enable **Tools > RadIA > Review automatically on save** for the current IDE session. After each save of the
active unit, RadIA analyzes up to 20 objective findings in the background, including lines over 120 characters,
trailing whitespace, and TODO/FIXME markers. Findings appear in inline review and can be reviewed or dismissed.

The flow is opt-in, does not block saving, and never changes code automatically. Disable the same menu item to
stop new analyses.
