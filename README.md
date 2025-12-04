# Recipe App

A Ruby on Rails application that helps users find the most relevant recipes based on what they have in their pantry, then automatically decrements their stocks when they cook a recipe.

## 📘 User Stories

1. **As a user**, I want to add ingredients to my pantry so that the application can suggest recipes I can cook.

2. **As a user**, I want the application to prioritize showing me recipes for which I have the most available ingredients.

3. **As a user**, when I cook a recipe, I want my stocks to be automatically decremented and the recipe to appear in my history.

4. **As a user**, I can see the latest recipes I have cooked.

## 🎯 Features

- **Pantry Management** : Manage your ingredients with quantities, fractions, and units
- **Recipe Search** : Find recipes based on your available ingredients
- **Filters** : Filter recipes by minimum rating, prep time, and cook time
- **History** : View your cooking history
- **Automatic Decrement** : Stocks are automatically updated when cooking

## 🔍 Recipe Matching Algorithm

The recipe matching algorithm compares the canonicalized ingredients of each recipe with the user's pantry. Ingredients are normalized using a canonicalization process that:
- Converts to lowercase and removes non-alphabetic characters
- Removes parasitic words (e.g., "large", "chopped", "fresh")
- Extracts the root word and applies simple singularization

Recipes are ranked by:
- **Number of matched ingredients** (descending) - recipes with more available ingredients appear first
- **Number of missing ingredients** (ascending) - among recipes with the same match count, those requiring fewer additional ingredients are prioritized
- **Recipe ID** (ascending) - for stable ordering

This ensures users see the most relevant recipes based on what they already have in their pantry.

## 🚫 Out of Scope

Out of scope for this technical test:

- **Full NLP ingredient parsing** - The current implementation uses simple pattern matching and canonicalization rather than advanced natural language processing
- **User authentication beyond a simple demo user** - The application uses a single demo user (`demo@example.com`) without a full authentication system
- **Responsive or production-ready design** - The UI is functional and minimal, focusing on business logic rather than polished design
- **Background jobs** - All operations are synchronous; no job queue is used despite Solid Queue being available
- **Advanced unit conversions** - Basic conversions are supported, but complex conversions between incompatible units are not handled
- **Recipe recommendations based on user preferences** - The matching is purely based on ingredient availability, not user history or preferences

## 🛠️ Development Tools

This project was developed using **Cursor** (an AI-powered code editor) for:
- **CSS generation** - Initial styling and layout assistance
- **JavaScript generation** - Client-side interactivity (autocomplete, modals)
- **HTML/ERB templates** - Initial view structure (subsequently refactored to use presenters to keep Ruby logic out of views)
- **SQL queries** - Complex SQL query construction for recipe matching and ingredient counting
- **Regex patterns** - Complex pattern matching for ingredient parsing
- **Fraction handling** - Mathematical operations and conversions for fractional quantities
- **Test dictation** - Writing test cases following TDD practices
- **Tab completion** - Code suggestions and autocompletion during development

All generated code has been reviewed, refactored, and integrated following Rails best practices and the project's architectural decisions (e.g., using presenters to separate concerns).

## 📋 Prerequisites

### Option 1: Using Dev Containers (Recommended)

The project is configured to work with **Dev Containers**, which provides a fully containerized development environment. This is the easiest way to get started as it handles all dependencies automatically.

**Requirements:**
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) or Docker Engine
- [VS Code](https://code.visualstudio.com/) or [Cursor](https://cursor.sh/) with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### Option 2: Local Installation

If you prefer to run the application locally without containers:

- **Ruby** : Version 3.3 or higher
- **Rails** : Version 8.1.1
- **PostgreSQL** : Version 9.3 or higher
- **Node.js** : For assets (optional, depending on your setup)

## 🚀 Installation

### Using Dev Containers (Recommended)

1. **Open the project in VS Code/Cursor**
   - Open VS Code or Cursor
   - Open the project folder

2. **Reopen in Container**
   - Press `F1` (or `Cmd+Shift+P` on Mac / `Ctrl+Shift+P` on Windows/Linux)
   - Type "Dev Containers: Reopen in Container"
   - Select the option and wait for the container to build

3. **Wait for setup to complete**
   - The container will automatically run `bin/setup --skip-server` which:
     - Installs all Ruby gems
     - Sets up the database
     - Runs migrations
     - Seeds the database

4. **Start the Rails server**
   ```bash
   rails server
   ```
   The application will be available at `http://localhost:3000`

**What's included in the Dev Container:**
- Ruby 3.4.7 with Rails 8.1.1
- PostgreSQL 16.1 (automatically configured)
- Selenium for system tests
- All required system dependencies
- GitHub CLI and other development tools

**Port forwarding:**
- Port `3000` : Rails application
- Port `5432` : PostgreSQL (if needed for external tools)

**Note:** The database is automatically configured to use the PostgreSQL container. No additional database setup is required when using Dev Containers.

### Local Installation

#### 1. Clone the repository

```bash
git clone <repository-url>
cd recipe_app
```

#### 2. Install dependencies

```bash
bundle install
```

#### 3. Set up the database

Create and configure your PostgreSQL database:

```bash
# Create databases
rails db:create

# Run migrations
rails db:migrate

# Load seed data (creates demo user)
rails db:seed
```

#### 4. Download and import recipes

The application requires a recipe data file that is not versioned in Git (too large).

##### Download the recipe file

```bash
rails recipes:download
```

This command automatically downloads the `recipes-en.json` file from S3 and decompresses it into `db/data/`.

##### Verify the file is present

```bash
rails recipes:check_file
```

##### Import recipes

```bash
rails recipes:import
```

This command imports all recipes, ingredients, and associations into the database.

## 🏃 Running the application

### Development mode

```bash
rails server
# or
bin/dev
```

The application will be available at `http://localhost:3000`

### Demo user

The application uses a single demo user:
- **Email** : `demo@example.com`

This user is automatically created when running `rails db:seed`.

## 🧪 Testing

The application uses Minitest as the testing framework.

### Run all tests

```bash
rails test
```

### Run specific tests

```bash
# Model tests
rails test test/models

# Controller tests
rails test test/controllers

# Service tests
rails test test/services

# Specific file
rails test test/models/recipe_test.rb
```

## 📁 Application structure

```
app/
├── controllers/          # Controllers (pantry_items, recipes, cooked_recipes)
├── models/              # Models (User, Recipe, Ingredient, PantryItem, CookedRecipe)
├── services/            # Business services (Recipes::Finder, Recipes::ImportFromJson)
├── presenters/          # Presenters for data presentation
└── views/               # ERB views

db/
├── migrate/             # Database migrations
├── data/                # JSON data (recipes-en.json)
└── seeds.rb             # Seeds to initialize data

test/                    # Tests (Minitest)
lib/tasks/               # Custom Rake tasks
```

## 🎨 Technologies used

- **Rails 8.1** : Web framework
- **PostgreSQL** : Database
- **Propshaft** : Asset pipeline
- **Hotwire (Turbo + Stimulus)** : For interactivity
- **Minitest** : Testing framework

## 📝 Available Rake tasks

### Recipes

```bash
# Download recipe file from S3
rails recipes:download

# Check if file exists
rails recipes:check_file

# Import recipes from JSON file
rails recipes:import

# Import from specific file
rails recipes:import[path/to/file.json]

# Delete all recipes and unused ingredients
rails recipes:clean
```

## 🔧 Configuration

### Database

Database configuration is located in `config/database.yml`.

By default, the application uses:
- **Development** : `recipe_app_development`
- **Test** : `recipe_app_test`
- **Production** : `recipe_app_production`

### Environment variables

For production, you can configure:
- `DB_HOST` : Database host
- `RAILS_MAX_THREADS` : Maximum number of threads (default: 5)
- `RECIPE_APP_DATABASE_PASSWORD` : Database password (production)

## 🎯 Usage

### 1. Add ingredients to pantry

Go to the home page (Pantry) and add your ingredients with their quantities.

### 2. Find recipes

Click on "Find Recipes" or navigate to "Recipes" in the navbar. The application displays recipes sorted by relevance (number of available ingredients).

### 3. Filter recipes

Use the filters at the top of the recipes page to:
- Filter by minimum rating
- Filter by maximum prep time
- Filter by maximum cook time

### 4. Cook a recipe

On a recipe detail page, click "Cook this recipe". The application will:
- Automatically decrement quantities in your pantry
- Record the recipe in your history

### 5. View history

Navigate to "History" in the navbar to see all recipes you've cooked.

## 🐛 Troubleshooting

### Database connection issues

Check that PostgreSQL is running:

```bash
# macOS (Homebrew)
brew services start postgresql

# Linux
sudo systemctl start postgresql

# Docker
docker-compose up -d postgres
```

### Missing recipes-en.json file

Download it with:

```bash
rails recipes:download
```

### Import errors

If import fails, verify that the JSON file is valid:

```bash
rails recipes:check_file
```

You can also clean and re-import:

```bash
rails recipes:clean
rails recipes:import
```

## 📚 Additional documentation

- **Recipe Import** : See [docs/RECIPES_DATA_SETUP.md](docs/RECIPES_DATA_SETUP.md) for details on importing recipes
- **Deployment** : See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for a complete guide on deploying to production with Kamal

## 🚀 Deployment

The application is configured for deployment with **Kamal** (formerly MRSK). For detailed deployment instructions, see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

### Quick Start for OVH Deployment

1. **Prepare your server:**
   - Install Docker on your OVH server
   - Configure firewall (ports 22, 80, 443)
   - Point your domain to the server IP

2. **Configure Kamal:**
   - Copy `config/deploy.yml.example` to `config/deploy.yml`
   - Update with your server IP, domain, and Docker Hub credentials
   - Copy `.kamal/secrets.example` to `.kamal/secrets`
   - Fill in your secrets (RAILS_MASTER_KEY, database passwords, etc.)

3. **Deploy:**
   ```bash
   kamal build
   kamal app setup
   kamal deploy
   ```

4. **Import recipes:**
   ```bash
   kamal console
   # Then: system("rails recipes:download && rails recipes:import")
   ```

For complete deployment instructions, troubleshooting, and best practices, see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

## 🤝 Contributing

This project is a technical test. For any questions or suggestions, feel free to open an issue.

## 📄 License

This project is a technical test for Pennylane.
