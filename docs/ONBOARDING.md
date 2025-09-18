# MMOps Onboarding Guide

## Prerequisites

- Git
- Docker Desktop
- Make/Just
- Go 1.22+
- Python 3.11+
- Node 18+
- direnv (for environment management)
- pre-commit (for security scanning)
- gitleaks (for secret detection)

## Recommended Tools

- asdf or pyenv/nvm for version management
- VS Code with extensions: Docker, YAML, Prettier, Go, Python, ESLint

## Setup Instructions

### 1. Clone the Repository
```bash
git clone <repository-url>
cd mmops
```

### 2. Install Security Tools
```bash
# macOS (with Homebrew)
brew install direnv pre-commit gitleaks

# Linux
curl -sfL https://direnv.net/install.sh | bash
pip install pre-commit
# Download gitleaks from releases page

# Add direnv to your shell profile (.bashrc, .zshrc, etc.)
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
# or for zsh:
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
```

### 3. Set Up Environment
```bash
# Copy environment template
cp .env.example .env

# Edit .env with your local values
# (Update database credentials, API keys, etc.)

# Allow direnv to load the .env file
direnv allow
```

### 4. Install Dependencies & Security
```bash
# Install all dependencies
make install

# Set up security tools and pre-commit hooks
make security-setup

# Test secret detection (optional)
make security-test
```

### 5. Start Development Environment
```bash
# Start database and services
make docker-up

# Start development server
make dev
```

## Environment Management

This project uses **direnv** for automatic environment loading:

- `.env` files are automatically loaded when you enter the directory
- No need to manually source environment variables
- Environment is automatically unloaded when you leave the directory
- Run `direnv allow` after creating/modifying `.env` files

## Development Workflow

```bash
# Run tests
make test

# Format code
make format

# Run linters
make lint

# Clean up
make clean
```

## Troubleshooting

- If environment variables aren't loading, run `direnv allow`
- If direnv isn't working, check your shell configuration
- For database issues, ensure Docker is running and `make docker-up` completed successfully
