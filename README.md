# GitHub Issue Importer

A simple bash script to bulk import issues into any GitHub repository from a CSV file. Automatically creates labels and milestones if they don't already exist.

Built for personal use to run projects in a lightweight agile style — backlog in a CSV, one command to get everything into GitHub Projects.

---

## Requirements

- **bash** — already on macOS/Linux
- **jq** — for JSON handling
- **python3** — for reliable CSV parsing (pre-installed on macOS)
- A **GitHub Personal Access Token** with `repo` scope

### Install jq

**macOS (Homebrew):**
```bash
brew install jq
```

**Linux (apt):**
```bash
sudo apt install jq
```

---

## Setup

**1. Clone or download the script**
```bash
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/import_issues.sh
chmod +x import_issues.sh
```

**2. Generate a GitHub Personal Access Token**

Go to: `GitHub → Settings → Developer Settings → Personal Access Tokens → Generate New Token`

Required scope: `repo`

**3. Fill in the config block at the top of the script**
```bash
GITHUB_TOKEN="ghp_yourtoken"
REPO_OWNER="your-username"
REPO_NAME="your-repo-name"
CSV_FILE="your_issues.csv"
```

---

## CSV Format

The script expects a CSV with the following columns in this exact order:

| Column | Description | Example |
|---|---|---|
| `title` | Issue title | `Implement preamble detector` |
| `body` | Issue body — supports markdown | `## Description\nDo the thing...` |
| `labels` | Comma-separated label names | `signal-processing,setup` |
| `milestone` | Milestone (epic) name | `Signal Processing` |

The first row must be the header row:
```
title,body,labels,milestone
```

### Example Row
```csv
"Set up CMake project","## Description\nSet up the build system.\n\n## Acceptance Criteria\n- [ ] Builds cleanly","setup","Hardware Interface"
```

> **Tip:** Wrap fields in double quotes if they contain commas or newlines. Use `\n` for line breaks inside the body field.

---

## Usage

Place `import_issues.sh` and your CSV file in the same directory, then run:

```bash
./import_issues.sh
```

### Example Output
```
🏷️  Setting up labels...
  🏷️  Created label: hardware-interface
  🏷️  Created label: signal-processing

📋 Importing issues from adsb_tracker_issues.csv...

  🪨  Created milestone: Hardware Interface (#1)
  ✅  #1 — Set up CMake project structure with librtlsdr dependency
       https://github.com/you/your-repo/issues/1
  ✅  #2 — Implement RTL-SDR device init and sample streaming
       https://github.com/you/your-repo/issues/2
  ...

─────────────────────────────────────────────
✅ Created:  20 issues
🔗 View your board: https://github.com/you/your-repo/issues
─────────────────────────────────────────────
```

---

## Behavior

- **Labels** — created automatically if they don't exist on the repo, skipped if they already do
- **Milestones** — created automatically if they don't exist, reused if they do
- **Rate limiting** — a 0.5s delay between requests keeps you well within GitHub's API limits
- **Duplicates** — the script does not check for duplicate issues, so running it twice will create duplicates. Make sure you only run it once per CSV.

---

## Reusing for Future Projects

This script is intentionally generic. To reuse it for a new project:

1. Create a new CSV with your issues following the format above
2. Update the config block with your new repo details
3. Run the script

The labels and milestones in the CSV are whatever you want them to be — they are created fresh for each repo.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `jq: command not found` | Run `brew install jq` |
| `401 Unauthorized` | Check your token is correct and has `repo` scope |
| `404 Not Found` | Check `REPO_OWNER` and `REPO_NAME` are spelled correctly |
| Issues created but no milestone | Make sure the milestone name in the CSV exactly matches across all rows |
| Body text looks wrong | Make sure multiline body fields are wrapped in double quotes in the CSV |

---

## License

MIT — do whatever you want with it.
