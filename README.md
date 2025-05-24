# Zif - Zsh Interface Framework

**Version: 0.0.1 (Pre-alpha)**

Zif is a Textual User Interface (TUI) framework for Zsh, designed to simplify the creation of interactive command-line applications. It emphasizes a functional programming paradigm, modularity, and configurability.

## Current Status

This framework is in the very early stages of development. The core structure is being established, and basic functionalities are being implemented. Expect frequent changes and incomplete features.

## Core Principles

*   **Functional Programming:** Favoring immutability and pure functions where practical.
*   **Modularity:** Breaking down components into manageable and reusable Zsh modules.
*   **Event-Driven:** Using an event loop to handle user input and UI updates.
*   **Configurability:** Aiming for user-configurable keybindings, themes, and behaviors.
*   **Zsh Native:** Leveraging `zsh/curses` for TUI rendering and interaction.

## Implemented Features (So Far)

*   Basic directory structure.
*   `zsh/curses` initialization and cleanup.
*   Simple event loop.
*   Core state management.
*   Basic keybinding handling (for 'quit').
*   Basic rendering engine (boxes, text).
*   Top bar layout with a static title and '[X]' quit button.
*   Logging functionality.

## Getting Started (Development)

Currently, to run the basic TUI:
```bash
zsh src/main.zsh
```
Press 'q' to quit. Log output can be found in `~/.cache/zif_framework/app.log`.

## Contributing

Contributions are welcome, but please be aware of the early development stage. It's best to discuss potential changes or features via issues first.

## License

MIT License (To be formally added)
