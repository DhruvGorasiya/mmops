.PHONY: help install dev test lint format clean docker-build docker-up docker-down

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install dependencies
	pip install -r requirements.txt
	npm install
	go mod tidy

env-setup: ## Set up environment files
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "Created .env from .env.example - please edit with your values"; \
	fi
	@if command -v direnv >/dev/null 2>&1; then \
		direnv allow; \
		echo "Environment loaded with direnv"; \
	else \
		echo "direnv not found - install it for automatic env loading"; \
	fi

security-setup: ## Set up security tools and pre-commit hooks
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit install; \
		echo "Pre-commit hooks installed"; \
	else \
		echo "pre-commit not found - install it first: brew install pre-commit"; \
	fi
	@if command -v gitleaks >/dev/null 2>&1; then \
		echo "gitleaks is installed"; \
	else \
		echo "gitleaks not found - install it: brew install gitleaks"; \
	fi

security-test: ## Test secret detection with a dummy secret
	@echo "Creating test file with fake secret..."
	@echo "API_KEY=sk_live_1234567890abcdef" > test_secret.env
	@echo "Adding to git and attempting commit (should fail)..."
	@git add test_secret.env
	@git commit -m "test secret detection" || echo "✅ Secret detection working - commit blocked as expected"
	@git reset HEAD test_secret.env
	@rm test_secret.env
	@echo "Test completed - secret file cleaned up"

dev: ## Start development environment
	docker-compose up -d db
	uvicorn main:app --reload --host 0.0.0.0 --port 8000

test: ## Run tests
	pytest
	npm test

lint: ## Run linters
	flake8 .
	mypy .
	npm run lint

format: ## Format code
	black .
	isort .
	npm run format

clean: ## Clean up
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	rm -rf .pytest_cache
	rm -rf dist
	rm -rf build

docker-build: ## Build Docker image
	docker build -t mmops .

docker-up: ## Start Docker services
	docker-compose up -d

docker-down: ## Stop Docker services
	docker-compose down
