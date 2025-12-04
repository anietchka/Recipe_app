# Deployment Guide - Fly.io

This guide explains how to deploy the Recipe App to Fly.io.

## Prerequisites

1. **Fly.io Account:**
   - Create an account at [fly.io](https://fly.io)
   - Install the Fly CLI: `curl -L https://fly.io/install.sh | sh`
   - Login: `fly auth login`

2. **Domain (Optional):**
   - You can use Fly.io's free `.fly.dev` subdomain
   - Or configure your custom domain

## Step 1: Configure Fly.io

### Initialize Fly.io App

```bash
# Initialize Fly.io (this will create fly.toml if it doesn't exist)
fly launch

# Follow the prompts:
# - App name: recipe-app (or your preferred name)
# - Region: Choose closest to your users (e.g., cdg for Paris, ord for Chicago)
# - PostgreSQL: Yes (we'll create it)
# - Redis: No (not needed for this app)
```

This will create a `fly.toml` configuration file.

### Update `fly.toml`

Ensure your `fly.toml` includes:

```toml
app = "recipe-app"
primary_region = "cdg"  # Your preferred region

[env]
  RAILS_ENV = "production"
  SOLID_QUEUE_IN_PUMA = "true"
  PORT = "8080"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 1

  [[http_service.checks]]
    grace_period = "10s"
    interval = "30s"
    method = "GET"
    timeout = "5s"
    path = "/up"
```

## Step 2: Create PostgreSQL Database

Fly.io provides managed PostgreSQL databases:

```bash
# Create a PostgreSQL database
fly postgres create --name recipe-app-db --region cdg --vm-size shared-cpu-1x --volume-size 10

# Attach the database to your app
fly postgres attach --app recipe-app recipe-app-db
```

This will automatically set the `DATABASE_URL` environment variable.

### Manual Database Configuration (Alternative)

If you prefer to configure manually:

```bash
# Create database
fly postgres create --name recipe-app-db

# Get connection string
fly postgres connect -a recipe-app-db

# Set secrets manually
fly secrets set DATABASE_URL="postgres://user:password@host:5432/dbname"
fly secrets set RECIPE_APP_DATABASE_PASSWORD="your-password"
```

## Step 3: Set Secrets

Set your Rails master key and other secrets:

```bash
# Get your Rails master key
cat config/master.key

# Set secrets
fly secrets set RAILS_MASTER_KEY="your-master-key-from-config-master-key"

# Set database password (if not using DATABASE_URL)
fly secrets set RECIPE_APP_DATABASE_PASSWORD="your-database-password"
```

**Important:** Never commit `config/master.key` to git!

## Step 4: Update Database Configuration

The `config/database.yml` is already configured to use `DATABASE_URL` from Fly.io. If you need to customize, update the production section:

```yaml
production:
  <<: *default
  url: <%= ENV["DATABASE_URL"] %>
```

Fly.io automatically provides `DATABASE_URL` when you attach a PostgreSQL database.

## Step 5: Update Production Configuration

Update `config/environments/production.rb`:

```ruby
# SSL is already enabled
config.assume_ssl = true
config.force_ssl = true

# Update mailer host with your Fly.io domain
config.action_mailer.default_url_options = { host: "recipe-app.fly.dev" }
# Or with custom domain:
# config.action_mailer.default_url_options = { host: "your-domain.com" }
```

## Step 6: Deploy

### First Deployment

```bash
# Deploy the application
fly deploy

# This will:
# - Build the Docker image
# - Push to Fly.io
# - Run migrations automatically (via docker-entrypoint)
# - Start the application
```

### Verify Deployment

```bash
# Check app status
fly status

# View logs
fly logs

# Open in browser
fly open
```

## Step 7: Import Recipes

After deployment, import the recipes:

```bash
# Download recipes file
fly ssh console -C "cd /rails && bin/rails recipes:download"

# Import recipes
fly ssh console -C "cd /rails && bin/rails recipes:import"
```

Or use the Rails console:

```bash
# Open Rails console
fly ssh console
# Then:
cd /rails
bin/rails console
# In console:
system("rails recipes:download")
system("rails recipes:import")
exit
```

## Step 8: Configure Custom Domain (Optional)

If you have a custom domain:

```bash
# Add your domain
fly certs add your-domain.com

# Follow DNS instructions to add CNAME record
# Fly.io will provide the DNS target (e.g., recipe-app.fly.dev)

# Update production.rb with your domain
# config.action_mailer.default_url_options = { host: "your-domain.com" }
```

## Useful Fly.io Commands

```bash
# View app status
fly status

# View logs
fly logs
fly logs -a recipe-app

# Open Rails console
fly ssh console
# Then: cd /rails && bin/rails console

# Run migrations manually
fly ssh console -C "cd /rails && bin/rails db:migrate"

# Scale the application
fly scale count 2  # Run 2 instances
fly scale vm shared-cpu-2x  # Use 2 CPUs

# View secrets
fly secrets list

# Set a secret
fly secrets set KEY="value"

# Remove a secret
fly secrets unset KEY

# SSH into the machine
fly ssh console

# View app info
fly info

# Restart the app
fly apps restart recipe-app
```

## Troubleshooting

### Build Failures

```bash
# Check build logs
fly logs

# Build locally to test
docker build -t recipe-app .
```

### Database Connection Issues

```bash
# Check database status
fly postgres status -a recipe-app-db

# Connect to database
fly postgres connect -a recipe-app-db

# Check DATABASE_URL is set
fly ssh console -C "echo \$DATABASE_URL"
```

### Application Crashes

```bash
# View logs
fly logs

# Check app status
fly status

# View machine details
fly machine list
```

### Memory Issues

If you encounter memory issues, scale up:

```bash
fly scale vm shared-cpu-2x --memory 1024
```

## Monitoring

### View Metrics

```bash
# View app metrics
fly metrics

# View database metrics
fly postgres metrics -a recipe-app-db
```

### Health Checks

The app includes a health check endpoint at `/up` which Fly.io uses automatically.

## Backup Strategy

### Database Backups

Fly.io PostgreSQL databases include automatic daily backups. To create manual backups:

```bash
# Create backup
fly postgres backup create -a recipe-app-db

# List backups
fly postgres backup list -a recipe-app-db

# Restore from backup
fly postgres backup restore <backup-id> -a recipe-app-db
```

## Scaling

### Scale Vertically (More Resources)

```bash
# Scale to 2 CPUs and 1GB RAM
fly scale vm shared-cpu-2x --memory 1024
```

### Scale Horizontally (More Instances)

```bash
# Run 2 instances
fly scale count 2
```

## Maintenance

### Update Application

```bash
# Pull latest code
git pull

# Deploy
fly deploy
```

### Run Migrations Manually

```bash
fly ssh console -C "cd /rails && bin/rails db:migrate"
```

### Update Dependencies

After updating Gemfile:

```bash
fly deploy
```

## Cost Optimization

Fly.io offers a free tier with:
- 3 shared-cpu-1x VMs with 256MB RAM
- 3GB persistent volume storage
- 160GB outbound data transfer

For this app, you'll likely need:
- 1 VM for the app (shared-cpu-1x, 512MB RAM recommended)
- 1 PostgreSQL database (shared-cpu-1x, included in free tier)

Monitor usage: `fly dashboard`

## Next Steps

- Set up monitoring (e.g., Sentry for error tracking)
- Configure automated backups
- Set up CI/CD for automated deployments
- Configure email service for production
- Set up log aggregation

