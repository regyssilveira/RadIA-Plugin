# Rad IA onboarding

Rad IA onboarding leads users to a useful first result without requiring them to understand
provider, model, executor, CLI, or MCP concepts first. The experience still presents the complete
platform and keeps every control available in the composer and settings.

It appears automatically once for each flow version and can be reopened from
**Tools > RadIA > Rad IA Getting Started**. Closing the window stops the guide without changing settings.
Opening it again from the menu resumes the last visited step.

## Experience principle

The flow follows three ideas:

1. **Start with the goal:** users describe what they want to understand, change, validate, debug,
   or create.
2. **Keep the power visible:** chat presents the effective mode, provider, model, and route, along
   with code, build, test, debugger, Form Designer, terminal, MCP, and skill capabilities.
3. **Go deeper on demand:** **More** opens executor, journey, and scope; **Settings** preserves the
   complete platform configuration.

## Steps

| Step | Expected result | Available action |
|---|---|---|
| Start with the goal | Open chat with work-oriented suggestions | **Start in Rad IA** |
| First result | Assess project health without changing files | **Understand this project** |
| Complete platform | Discover capabilities and applicable documentation | **Explore capabilities** |
| Full control | Access providers, agents, consent, CLI, MCP, and all other options | **Open full settings** |

The first result uses `/health`, combining IDE, compiler, build, test, and local knowledge state to
recommend the next action. Without an open project, the card explains the requirement while the
user can still chat or create a project from the same surface.

## Chat start screen

An empty conversation offers four starting points:

- **Understand this project:** prepares `/health`;
- **Fix a problem:** prepares an investigation, reviewed fix, and validation objective;
- **Create something:** starts a request for a project, form, unit, API, test, or feature;
- **Debug an application:** prepares a runtime diagnostic journey.

The buttons fill the composer and do not send automatically. Users can review or complete the
request before sending it. **Explore all capabilities** prepares `/help`.

## Control and security

Onboarding does not install CLIs, change MCP configuration, switch providers, or grant consent
automatically. The effective mode and route remain visible. Protected operations continue to use
preview, risk policy, and consent.

Users who prefer direct configuration can open **More**, **Settings**, `/scope`, `/doctor`, or
`/status` at any time. Simplification changes the presentation order, not platform capability or
control.
