# Implementation Plan

- [x] 1. Create core format infrastructure





  - Implement OutputFormat enum with Markdown as preferred default
  - Create base ContentProcessor interface for format-specific processing
  - Add format field to AppConfig model with Hive serialization
  - _Requirements: 1.2, 4.3_

- [x] 2. Implement Markdown content processor





  - Create MarkdownProcessor class that extracts content between @@@START@@@ and @@@END@@@ markers
  - Implement validation to ensure clean Markdown without HTML remnants
  - Add error handling for malformed escape markers or missing content
  - Write unit tests for various input scenarios and edge cases
  - _Requirements: 2.1, 2.2, 3.2, 3.3_

- [x] 3. Enhance LLM service with format-aware generation




  - Modify generateTZ method to accept OutputFormat parameter
  - Implement buildMarkdownSystemPrompt method with escape marker requirements
  - Update buildConfluenceSystemPrompt method to maintain existing HTML functionality
  - Add format-specific prompt validation and error handling
  - _Requirements: 3.1, 3.4, 4.1, 4.2_

- [x] 4. Create format selection UI component





  - Implement FormatSelector widget with radio buttons for Markdown and Confluence options
  - Set Markdown as preselected default format in widget initialization
  - Add proper state management and change callbacks
  - Style component to match existing application design
  - _Requirements: 1.1, 1.2_

- [x] 5. Integrate format selection into main screen





  - Add FormatSelector widget to MainScreen layout
  - Update _generateTZ method to use selected format parameter 
  - Implement format-specific content processing using appropriate processor
  - Add format preference persistence across application sessions
  - _Requirements: 1.3, 4.4_

- [x] 6. Update file export functionality





  - Modify FileService to handle format-specific file extensions (.md for Markdown, .html for Confluence)
  - Update file naming to include format identifier
  - Ensure exported content maintains proper format structure
  - Add validation for export content based on selected format
  - Validate Markdown file export compatibility with third-party editors (e.g., VSCode preview, Obsidian)
  - _Requirements: 2.5_

- [x] 7. Enhance generation history tracking
  - Add format field to GenerationHistory model
  - Update history display to show format used for each generation
  - Implement format-specific history item rendering
  - Ensure history items maintain format context when restored
  - _Requirements: 1.3, 4.4_

- [x] 8. Add comprehensive error handling and validation
  - Implement format-specific error messages for processing failures
  - Add validation for LLM responses with missing or malformed escape markers
  - Create fallback mechanisms for content extraction failures
  - Add user-friendly error notifications with recovery suggestions
  - _Requirements: 2.2, 3.3, 3.4_

- [x] 9. Write comprehensive tests for new functionality


  - Create unit tests for MarkdownProcessor with various input scenarios
  - Write widget tests for FormatSelector component interactions
  - Implement integration tests for end-to-end format selection and generation
  - Add tests for format persistence and session management
  - _Requirements: 1.1, 1.2, 2.1, 2.2, 3.2_

- [x] 10. Update configuration management





  - Modify ConfigService to handle format preference storage and retrieval
  - Add migration logic for existing configurations without format preference
  - Implement format preference validation and default fallback
  - Update setup screen to include format preference selection
  - _Requirements: 1.3, 4.3_