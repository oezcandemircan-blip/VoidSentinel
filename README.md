# VoidSentinel

*"The devil whispered in my ear: 'You are not strong enough to withstand the storm.' But I am the storm."*

---

## Overview
**VoidSentinel** is a modular dashboard for real-time monitoring of honeypot logs. It utilizes `tmux` to visualize various data streams within a professional command center environment.

## How It Works
The script is organized into three logical layers:

1.  **Log-Colorizer (`/tmp/cyber_colorizer.sh`):** An intelligent stream parser that filters log outputs in real-time and applies ANSI colors for enhanced readability.
2.  **Stats-Panel (`/tmp/cyber_stats.sh`):** The core engine. It reads Docker logs from `cowrie`, `honeytrap`, and `krawl`, calculates statistics (attack frequency, IP ranking), and generates the "Live Threat Feed."
3.  **Tmux-Orchestrator:** The main script launches a `tmux` session and splits the terminal into four panes to display live logs and the statistical dashboard simultaneously.

## Flexibility for Users
VoidSentinel is designed to be **easily adaptable to individual needs**:
*   **Different Honeypots?** You can simply replace the `docker logs` commands in the `STATS` section with other log sources or file paths.
*   **Design Customization:** All ANSI color variables are defined at the beginning. You can modify the entire color scheme (neon aesthetic) with just a few adjustments.
*   **Modularity:** Since the dashboard and the colorizer are independent scripts, you can utilize them separately in other projects.

## Requirements
*   `tmux` (for the multi-pane layout)
*   `docker` (as the data source)
*   `curl` (for WAN IP lookup)

## Installation
1. Ensure `tmux`, `docker`, and `curl` are installed.
2. Clone the repository: `git clone https://github.com/oezcandemircan-blip/VoidSentinel.git`
3. Make the script executable: `chmod +x voidsentinel.sh`
4. Launch the void: `./voidsentinel.sh`

## Security Note
This tool is intended for ethical security research and honeypot visualization. Always ensure your local log paths are correctly configured and that no sensitive information is exposed.

---
*Developed by oezcandemircan | Hobby Project – Security & Systems Engineering*
