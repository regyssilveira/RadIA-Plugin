# User Guide: Editor Integration & Code Generation

This guide details how to use **Rad IA** features integrated within the Embarcadero Delphi code editor, as well as automatic DTO, documentation, and full-project generation tools.

---

## 1. Context-Aware Editor Actions

Rad IA connects natively to the Delphi code editor using the Open Tools API (OTA). You can trigger artificial intelligence analyses for specific code snippets directly inside the editor.

### How to Use:
1. In the IDE code editor, **select** the code block you want to analyze or modify.
2. **Right-click** the selection.
3. At the top of the pop-up menu, open the **Rad IA** category and choose one of the following actions:
   * **Explain Selected Code (`/explain`):** Pedagogically analyzes the logic, explaining the execution flow and the purpose of complex algorithms.
   * **Optimize/Refactor (`/refactor`):** Rewrites code aiming for performance, readability, and compliance with Clean Code and SOLID principles.
   * **Find Bugs (`/bugs`):** Scans the code for memory leaks (missing try..finally blocks), unhandled exceptions, and logic flaws.
   * **Generate Unit Tests (`/test`):** Automatically generates structured test classes and methods using the DUnitX framework.
   * **Create Implementation from Comment:** With the cursor inside an empty method that contains a
     natural-language comment, directly generates the bounded implementation.

Implementation creation is an explicit editor action. It waits for chat loading to finish, sends the
request directly to the configured provider, and neither creates nor requests approval for an agent plan,
even when Agent mode is enabled. Applying the generated code remains subject to user review.

> The **Rad IA** submenu is inserted at the top of the editor context menu after the IDE builds its native items, preserving compatibility with Delphi 12/13 and menus added by other plugins.

---

## 2. Smart Visual Diff (Smart Diff)

When you request refactorings or code optimizations, Rad IA does not modify your original file immediately. Instead, it presents the suggested changes side-by-side in a premium comparison window.

<p align="center">
  <img src="images/radia_diff_ui_mockup.png" alt="Rad IA Smart Diff UI" width="90%" />
</p>

### Workflow and How it Works:
* **Side-by-Side View**: The Smart Diff window displays the original code on the left (highlighted in red for deletions) and the suggested AI code on the right (highlighted in green for additions).
* **Per-block review**: Each changed block has **Accept** and **Reject** actions. The counter shows
  how many blocks are included in the version that will be applied.
* **Navigation**: **Previous** and **Next** move between changed blocks.
* **[Apply Selected] Button**: Applies only the accepted combination to the Delphi editor. It stays
  disabled when every block is rejected.
* **Safety**: If you decide to discard the changes, simply close the Diff panel. Your original file remains untouched.

Smart Diff starts with every block accepted. Reject unwanted blocks, review the composed result,
and then apply it. If the original content changes while the window is open, Rad IA interrupts the
operation to prevent overwrite or duplication.

---

## 3. Automatic XML Documentation Generation

Rad IA allows you to document classes and methods using the standard Delphi XML format, directly feeding the IDE's **Help Insight** feature (which displays documentation tooltips when hovering over methods).

### How to Use:
1. Hover your cursor over a method or property declaration (either in the interface or implementation section).
2. Right-click and choose **Rad IA -> Automatic XML Documentation** (or type `/doc` in the chat sidebar).
3. The AI will generate the XML structure and Rad IA will insert it right above the targeted method.

### Output Example:
```pascal
/// <summary>
///   Calculates the period sales total by applying discounts and local taxes.
/// </summary>
/// <param name="AStartDate">Apuration start date</param>
/// <param name="AEndDate">Apuration end date</param>
/// <returns>Total calculated amount in current currency</returns>
function CalculatePeriodTotal(const AStartDate, AEndDate: TDateTime): Currency;
```

---

## 4. DTO and Model Converter

Writing Data Transfer Objects (DTOs) or ORM mappings manually from JSON payloads or database tables takes significant time. Rad IA automates this.

### How to Use:
1. Paste the JSON payload or SQL DDL script into the chat sidebar.
2. Use the `/dto [format]` slash command (e.g., `/dto vanilla` or `/dto dext`).
3. Supported Formats:
   * **Vanilla Delphi**: Pure Pascal classes with standard getters/setters and properties.
   * **DEXT ORM**: Entity models decorated with attributes ready for the DEXT ORM persistence framework.
   * **TMS Aurelius**: Classes mapped using attributes specific to the TMS Aurelius framework.
   * **REST.Json**: Classes annotated with attributes compatible with Delphi's native JSON serialization framework.

---

## 5. Full-Project Generation via Prompts

One of Rad IA's most powerful capabilities is structuring and saving a complete Delphi project from scratch using a simple informal chat prompt.

### How to use

This workflow also works when Delphi starts without an open project. A natural request such as
**“make a basic calculator”** or **“create a VCL calculator with basic operations”** automatically
starts the guided creation journey. RadIA asks only for missing information — name, destination,
and platform — before showing the approval plan.

1. In the Rad IA sidebar chat, request a new project. Example:
   > *"Generate a console project that consumes a weather API and saves the data in local JSON files."*
   *(You can also use the `/createproject` or `/createprojectarch` slash commands for templates adhering to Clean Architecture).*
2. The AI processes the request and returns the complete file set (project `.dpr`, configuration
   `.dproj`, logic units `.pas`, and UI forms `.dfm`). For VCL calculators, the native composer
   provides a functional display, keypad, and basic operations.
   If the request mentions history, the specification includes that feature explicitly and the project
   receives an ordered operation list and a **Clear history** action.
3. Rad IA will display a glassmorphism-styled panel showing the list of generated files.
4. **Saving Workflow**:
   * Click **Criar Projeto e Abrir na IDE** (Create Project and Open in IDE) in the chat UI.
   * A native Windows folder selection dialog will open.

> [!IMPORTANT]
> **Safe Project Generation:**
> For security reasons and to avoid accidentally overwriting existing code, the selected folder for project generation **must be completely empty**. Rad IA will block the physical saving process if the chosen directory contains any files.

5. **IDE loading and validation**: after writing the files, RadIA opens the `.dproj`, structurally checks
   the requirements, builds it through Delphi, and repairs errors within the approved boundaries. The
   application starts only when the user explicitly requests execution or functional validation.
   Completion distinguishes creation, build, and any runtime result.

The external CLI does not need to find `msbuild` on `PATH` for this workflow. RadIA's native tools
perform project creation, build, and optional execution. When a CLI assists the analysis, the chat displays
an expandable activity card with its current stage, elapsed time, and technical output.

Project links open in the IDE. Web links open in the default browser and never replace the main chat
surface, so users cannot become trapped on a page without a Back control.

When navigating to a symbol, RadIA queries the structural project index first, including other units and
inherited members. If the index is unavailable or does not find the name, navigation returns to the
bounded active-unit scanner. The operation remains confined to projects loaded in the IDE.
