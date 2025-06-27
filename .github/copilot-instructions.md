<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# AI Requirements Generator - Copilot Instructions

## Project Overview
This is a cross-platform desktop application built with Wails (Go backend + web frontend) that generates technical requirements from raw user inputs using OpenAI API.

## Architecture
- **Backend (Go):** Configuration management, OpenAI API integration, local data storage
- **Frontend (JavaScript + CSS):** Modern UI with multiple screens, API interaction through Wails bindings
- **Platform:** Cross-platform desktop application (Windows, macOS, Linux)

## Key Technologies
- **Framework:** Wails v2
- **Backend Language:** Go 1.19+
- **Frontend:** Vanilla JavaScript, CSS3
- **API:** OpenAI/Compatible APIs
- **Storage:** Local JSON configuration files

## Code Structure
- `app.go` - Main Wails application with exported methods for frontend
- `config.go` - Configuration management and cross-platform file storage
- `openai.go` - OpenAI API client and model management
- `frontend/src/main.js` - Frontend application logic and UI management
- `frontend/src/style.css` - Modern CSS styling with CSS variables

## Coding Guidelines
1. **Go Code:**
   - Use proper error handling with wrapped errors
   - Follow Go naming conventions
   - Comment all exported functions in Russian (target audience)
   - Use struct methods for organized code

2. **JavaScript Code:**
   - Use async/await for API calls
   - Implement proper error handling and user feedback
   - Follow modern ES6+ practices
   - Use semantic HTML and accessible UI patterns

3. **Configuration:**
   - Use cross-platform file paths (`%APPDATA%`, `~/Library/Application Support`, `~/.config`)
   - Store sensitive data securely (future enhancement)
   - Validate all user inputs

## Current Features
- ✅ Cross-platform configuration storage
- ✅ OpenAI API integration and validation
- ✅ Model selection and management
- ✅ Modern UI with multiple screens
- ✅ Error handling and user feedback
- 🚧 Requirements generation (planned)

## When adding new features:
- Export Go functions that need frontend access in `app.go`
- Add corresponding JavaScript calls in `main.js`
- Update UI screens and styling as needed
- Maintain error handling consistency
- Update documentation files

## Security Considerations
- API keys stored in plain text (MVP limitation)
- Local file system access for configuration
- Network requests to AI API endpoints
- Consider encryption for production use

## Build Process
- Use `wails build` for production builds
- Use `wails dev` for development with hot-reload
- Bindings auto-generate during build process
- Cross-platform compilation supported
