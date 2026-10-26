# Recipe App

A Ruby on Rails application that helps users find recipes based on the ingredients they already have at home.

Users can manage their pantry, discover recipes ranked by how closely they match their available ingredients, see what is missing, cook a recipe, and automatically update their pantry.

## User stories

- As a user, I want to manage the ingredients I have at home so that the application knows what I can cook.
- As a user, I want to see recipes ranked by how well they match my pantry so that I can quickly decide what to cook.
- As a user, I want to see which ingredients are missing from a recipe so that I know what I would need before cooking it.

## Features

- Manage pantry ingredients with optional quantities and units
- Find recipes based on available pantry ingredients
- Rank recipes by pantry coverage
- See available and missing ingredients for each recipe
- Filter recipes by rating, preparation time, and cooking time
- Automatically update pantry quantities when cooking
- Keep a history of cooked recipes
- Handle compatible unit conversions

## Technical overview

The application is built with Ruby on Rails and PostgreSQL.

The main business operations are separated into dedicated services:

- `Recipes::Finder` handles recipe filtering, matching, and ranking.
- `Recipes::Cook` handles cooking and pantry updates.
- `Recipes::ImportFromJson` handles recipe dataset import and normalization.

The application uses presenters for display-specific logic and Minitest for automated testing.

## Setup

### Requirements

The easiest way to run the application is with the included Dev Container.

You will need:

- Docker
- VS Code or Cursor with the Dev Containers extension

Alternatively, the application can be run locally with Ruby, Rails, and PostgreSQL.

### Dev Container

Open the project and select:

```text
Dev Containers: Reopen in Container
```

Then start the application:

```bash
bin/rails server
```

The application is available at:

```text
http://localhost:3000
```

### Local installation

Install dependencies:

```bash
bundle install
```

Set up the database:

```bash
bin/rails db:prepare
```

The application uses the following demo user:

```text
demo@example.com
```

## Recipe dataset

The recipe JSON file is not committed to the repository.

Download it with:

```bash
bin/rails recipes:download
```

Check that it is available:

```bash
bin/rails recipes:check_file
```

Import the recipes:

```bash
bin/rails recipes:import
```

## Tests and code quality

Run the test suite:

```bash
bin/rails test
```

Run RuboCop:

```bash
bin/rubocop
```

The CI pipeline runs the test suite, RuboCop, Brakeman, dependency security auditing, and importmap auditing.

## AI tools

I used AI tools as development assistants during this case study.

### Claude Code

I mainly used Claude Code for:

- generating and refining CSS and frontend code;
- helping with regular expressions and text parsing;
- generating additional test cases and edge cases;
- reviewing code quality and suggesting potential improvements;
- assisting with documentation and commit messages.

AI-generated code was reviewed before being kept. I validated changes by checking their behavior, adapting them when necessary, and running the relevant tests.

For changes affecting business logic or performance, I also added regression tests where appropriate.

## Main technologies

- Ruby on Rails
- PostgreSQL
- Hotwire / Turbo / Stimulus
- Minitest
- Propshaft