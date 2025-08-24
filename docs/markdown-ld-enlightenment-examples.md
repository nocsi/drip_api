# Markdown-LD: True Enlightenment Examples

## Example 1: Dockerfile that Actually Builds

```markdown
<!-- 
{
  "@context": "https://kyozo.dev/schemas/markdown-ld/v1",
  "@id": "block:dockerfile",
  "@type": "kyozo:ExecutableBlock",
  "kyozo:executor": "docker",
  "kyozo:action": "build",
  "kyozo:tag": "myapp:latest"
}
-->
```dockerfile
FROM elixir:1.14-alpine

WORKDIR /app

# Install dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy and compile
COPY . .
RUN MIX_ENV=prod mix release

# Runtime
CMD ["_build/prod/rel/myapp/bin/myapp", "start"]
```

<!-- When you execute this block, it ACTUALLY runs: docker build -t myapp:latest . -->
```

## Example 2: Terraform that Actually Deploys

```markdown
<!--
{
  "@id": "block:infrastructure",
  "@type": "kyozo:ExecutableBlock", 
  "kyozo:executor": "terraform",
  "kyozo:action": "apply",
  "kyozo:autoApprove": false,
  "kyozo:workspace": "production"
}
-->
```hcl
resource "aws_lambda_function" "api" {
  filename         = "api.zip"
  function_name    = "kyozo-api"
  role            = aws_iam_role.lambda.arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  
  environment {
    variables = {
      DATABASE_URL = var.database_url
    }
  }
}
```

<!-- Executing this block runs: terraform apply -->
```

## Example 3: Database Migration that Actually Runs

```markdown
<!--
{
  "@id": "block:migration",
  "@type": "kyozo:ExecutableBlock",
  "kyozo:executor": "sql",
  "kyozo:database": {"@id": "db:production"},
  "kyozo:transaction": true,
  "kyozo:reversible": {
    "@id": "block:rollback"
  }
}
-->
```sql
-- Migration: Add user roles
CREATE TYPE user_role AS ENUM ('admin', 'editor', 'viewer');

ALTER TABLE users 
ADD COLUMN role user_role DEFAULT 'viewer';

CREATE INDEX idx_users_role ON users(role);
```

<!--
{
  "@id": "block:rollback",
  "@type": "kyozo:ExecutableBlock",
  "kyozo:executor": "sql",
  "kyozo:hidden": true
}
-->
```sql
-- Rollback
DROP INDEX idx_users_role;
ALTER TABLE users DROP COLUMN role;
DROP TYPE user_role;
```
```

## Example 4: Kubernetes Manifest that Actually Deploys

```markdown
<!--
{
  "@id": "block:k8s-deploy",
  "@type": "kyozo:ExecutableBlock",
  "kyozo:executor": "kubectl",
  "kyozo:action": "apply",
  "kyozo:namespace": "production",
  "kyozo:validates": {
    "@type": "kyozo:K8sManifest",
    "kyozo:apiVersion": "apps/v1"
  }
}
-->
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: myapp:latest
        ports:
        - containerPort: 4000
```

<!-- This actually runs: kubectl apply -f - -->
```

## Example 5: Multi-Stage Enlightenment

```markdown
<!--
{
  "@id": "doc:deployment-guide",
  "@type": "kyozo:EnlightenedDocument",
  "kyozo:enlightenment": {
    "stages": ["build", "test", "deploy"],
    "environment": "production"
  }
}
-->

# Production Deployment

This document will build, test, and deploy your application.

## Stage 1: Build

<!--
{
  "@id": "stage:build",
  "@type": "kyozo:ExecutableBlock",
  "kyozo:stage": "build",
  "kyozo:executor": "shell"
}
-->
```bash
#!/bin/bash
echo "Building application..."
mix deps.get
MIX_ENV=prod mix compile
MIX_ENV=prod mix release
```

## Stage 2: Test

<!--
{
  "@id": "stage:test",
  "@type": "kyozo:ExecutableBlock",
  "kyozo:stage": "test",
  "kyozo:dependsOn": ["stage:build"],
  "kyozo:continueOnError": false
}
-->
```bash
#!/bin/bash
echo "Running tests..."
mix test
mix credo --strict
mix dialyzer
```

## Stage 3: Deploy

<!--
{
  "@id": "stage:deploy",
  "@type": "kyozo:ExecutableBlock",
  "kyozo:stage": "deploy",
  "kyozo:dependsOn": ["stage:test"],
  "kyozo:requiresApproval": true,
  "kyozo:notifies": {
    "@type": "kyozo:Notification",
    "kyozo:channel": "slack",
    "kyozo:webhook": "${SLACK_WEBHOOK}"
  }
}
-->
```bash
#!/bin/bash
echo "Deploying to production..."
kubectl set image deployment/api api=myapp:${BUILD_ID}
kubectl rollout status deployment/api
```
```

## The Power of Enlightenment

With Markdown-LD enlightenment, your documentation becomes:

### 1. **Actually Executable**
```elixir
# This is how simple it is to execute
{:ok, doc} = MarkdownLD.parse(content)
{:ok, results} = MarkdownLD.execute(doc, %{
  environment: "production",
  dry_run: false
})
```

### 2. **Queryable**
```sparql
# Find all blocks that deploy to production
SELECT ?block ?content
WHERE {
  ?block a kyozo:ExecutableBlock ;
         kyozo:environment "production" ;
         kyozo:executor ?executor ;
         kyozo:content ?content .
}
```

### 3. **Composable**
```markdown
<!--
{
  "@id": "doc:full-deployment",
  "@type": "kyozo:CompositeDocument",
  "kyozo:imports": [
    "https://kyozo.dev/docs/standard-build",
    "https://github.com/myorg/deploy-templates/k8s"
  ],
  "kyozo:compose": {
    "strategy": "sequential",
    "stages": ["imported:build", "local:test", "imported:deploy"]
  }
}
-->
```

### 4. **Self-Describing**
```markdown
<!--
{
  "@type": "kyozo:ExecutableBlock",
  "kyozo:executor": "terraform",
  "kyozo:provides": {
    "@type": "kyozo:AWSInfrastructure",
    "kyozo:resources": ["aws_lambda_function", "aws_api_gateway"],
    "kyozo:outputs": {
      "api_url": {"@type": "xsd:anyURI"},
      "function_arn": {"@type": "aws:ARN"}
    }
  }
}
-->
```

## Real Implementation

```elixir
defmodule Kyozo.MarkdownLD.Executors.Docker do
  @behaviour Kyozo.MarkdownLD.Executor
  
  def execute(block, context) do
    dockerfile_content = block.content
    tag = block.properties["kyozo:tag"] || "latest"
    
    # Write Dockerfile to temp directory
    with {:ok, temp_dir} <- create_temp_dir(),
         :ok <- File.write!(Path.join(temp_dir, "Dockerfile"), dockerfile_content),
         {:ok, output} <- System.cmd("docker", ["build", "-t", tag, temp_dir]) do
      {:ok, %{
        output: output,
        image: tag,
        "@type" => "kyozo:DockerBuildResult"
      }}
    end
  end
end
```

## The Future: Even More Powerful

```markdown
<!--
{
  "@type": "kyozo:SmartContract",
  "kyozo:blockchain": "ethereum",
  "kyozo:deploy": {
    "network": "mainnet",
    "gas": "auto",
    "verify": true
  }
}
-->
```solidity
pragma solidity ^0.8.0;

contract MyToken {
    mapping(address => uint256) balances;
    
    function transfer(address to, uint256 amount) public {
        balances[msg.sender] -= amount;
        balances[to] += amount;
    }
}
```
<!-- This could actually deploy to Ethereum! -->
```

This is the power of Markdown-LD: **Your documentation doesn't just describe your infrastructure - it IS your infrastructure!**