# Contributing to Mermaider.nvim

Thank you for considering contributing to Mermaider.nvim! This document provides guidelines for contributing to the project.

## Getting Started

### Development Setup

1. Fork and clone the repository
2. Install dependencies:
   - Neovim 0.8+
   - Node.js and npm
   - ImageMagick
   - image.nvim plugin

3. Set up your development environment:
   ```bash
   # Clone your fork
   git clone https://github.com/yourusername/mermaider.nvim.git
   cd mermaider.nvim
   
   # Test the plugin locally
   nvim -u NONE -c "set rtp+=." examples/test.mmd
   ```

### Project Structure

```
mermaider.nvim/
├── lua/
│   └── mermaider/
│       ├── init.lua           # Main entry point
│       ├── config.lua         # Configuration management
│       ├── render.lua         # Core rendering logic
│       ├── cache.lua          # Content-based caching
│       ├── image_integration.lua # image.nvim integration
│       ├── markdown.lua       # Markdown support
│       ├── commands.lua       # CLI command handling
│       ├── files.lua          # File operations
│       ├── ui.lua             # UI components
│       ├── status.lua         # Render status tracking
│       ├── utils.lua          # Utility functions
│       └── types.lua          # Type definitions
├── examples/                  # Sample files
├── test/                      # Test files
└── docs/                      # Documentation
```

## Types of Contributions

### Bug Reports

When reporting bugs, please include:
- Neovim version (`nvim --version`)
- Plugin configuration
- Steps to reproduce
- Expected vs actual behavior
- Error messages or logs
- Sample mermaid file that demonstrates the issue

### Feature Requests

For new features:
- Describe the use case
- Explain why it would benefit users
- Consider backwards compatibility
- Provide mockups or examples if applicable

### Code Contributions

1. **Create an issue first** to discuss the change
2. **Follow the coding style** used in the project
3. **Add tests** for new functionality
4. **Update documentation** as needed
5. **Keep commits focused** - one logical change per commit

## Development Guidelines

### Code Style

- Use 2 spaces for indentation
- Follow Lua best practices
- Use meaningful variable and function names
- Add comments for complex logic
- Prefer explicit over implicit

### Error Handling

- Use `pcall()` for operations that might fail
- Provide helpful error messages to users
- Log debug information for troubleshooting
- Fail gracefully - don't crash Neovim

### Testing

Manual testing workflow:
1. Test with different file types (`.mmd`, `.md`)
2. Test both inline and split rendering modes
3. Test error conditions (invalid syntax, missing CLI)
4. Test performance with large files
5. Test cache behavior

### Documentation

- Update README.md for user-facing changes
- Add docstrings to public functions
- Update configuration examples
- Add examples for new features

## Architecture Guidelines

### Key Principles

1. **Async by default** - Use `vim.uv` for non-blocking operations
2. **Resource cleanup** - Always clean up jobs, files, and images
3. **Error recovery** - Handle failures gracefully
4. **Performance** - Cache aggressively, avoid redundant work
5. **User experience** - Provide clear feedback and helpful errors

### Module Responsibilities

- **init.lua** - Plugin lifecycle, commands, autocmds
- **render.lua** - Async rendering orchestration
- **cache.lua** - Content-based caching logic
- **image_integration.lua** - image.nvim abstraction
- **markdown.lua** - Markdown-specific functionality
- **commands.lua** - CLI command building and execution

### Adding New Features

1. **Consider the scope** - Does it belong in core or as an extension?
2. **Design the API** - How will users interact with it?
3. **Plan the implementation** - Which modules need changes?
4. **Consider backwards compatibility** - Will it break existing setups?
5. **Think about configuration** - What options should be configurable?

## Pull Request Process

1. **Fork** the repository
2. **Create a feature branch** from main
3. **Make your changes** following the guidelines above
4. **Test thoroughly** with different configurations
5. **Update documentation** as needed
6. **Submit a pull request** with:
   - Clear description of changes
   - Motivation for the change
   - Testing performed
   - Breaking changes (if any)

### PR Checklist

- [ ] Code follows project style guidelines
- [ ] Changes are backwards compatible (or breaking changes are documented)
- [ ] Documentation is updated
- [ ] Manual testing performed
- [ ] Commit messages are clear and descriptive

## Getting Help

- **Issues** - For bugs and feature requests
- **Discussions** - For questions and general discussion
- **Code review** - Maintainers will review PRs and provide feedback

## Recognition

Contributors will be recognized in:
- Git commit history
- Release notes for significant contributions
- README acknowledgments for major features

Thank you for contributing to Mermaider.nvim!