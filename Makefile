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
