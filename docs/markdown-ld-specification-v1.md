# Markdown-LD Specification v1.0

## Overview

Markdown-LD is **Markdown with Linked Data** - a format that embeds structured, semantic data within human-readable markdown documents. It's markdown that machines can understand deeply while remaining perfectly readable to humans.

## Core Concept: Linked Data in Markdown

Every piece of content can have semantic meaning and relationships:

```markdown
<!-- @context: https://kyozo.dev/schemas/markdown-ld/v1 -->
<!-- @type: ExecutableDocument -->
<!-- @id: doc:getting-started -->

# Getting Started Guide

<!-- @type: CodeBlock -->
<!-- @language: elixir -->
<!-- @executeOn: server -->
<!-- @dependsOn: #setup -->
```elixir
defmodule MyApp do
  def hello, do: "world"
end
```

<!-- @type: DataBlock -->
<!-- @format: json-ld -->
```json
{
  "@context": "https://schema.org/",
  "@type": "SoftwareApplication",
  "name": "MyApp",
  "version": "1.0.0",
  "author": {
    "@type": "Person",
    "name": "Alice Developer"
  }
}
```
```

## JSON-LD Integration

We use JSON-LD as our linked data format, embedded in HTML comments:

```markdown
<!-- 
{
  "@context": {
    "@vocab": "https://kyozo.dev/vocab/",
    "schema": "https://schema.org/",
    "kyozo": "https://kyozo.dev/schemas/",
    "code": "kyozo:CodeBlock",
    "executes": {
      "@id": "kyozo:executes",
      "@type": "@id"
    },
    "dependsOn": {
      "@id": "kyozo:dependsOn", 
      "@type": "@id"
    }
  },
  "@id": "cell:123",
  "@type": "code",
  "executes": "runtime:elixir",
  "dependsOn": ["cell:122"]
}
-->
```

## Semantic Vocabulary

### Document Types
- `kyozo:ExecutableDocument` - A document with executable code
- `kyozo:TutorialDocument` - An educational document
- `kyozo:APIDocument` - API documentation
- `kyozo:ConfigDocument` - Configuration documentation

### Block Types
- `kyozo:CodeBlock` - Executable code
- `kyozo:DataBlock` - Structured data (YAML/JSON/TOML)
- `kyozo:QueryBlock` - Database queries
- `kyozo:EnlightenmentBlock` - AI-enhanced content
- `kyozo:InjectionBlock` - Dynamic content injection

### Properties
- `kyozo:executes` - Links to execution runtime
- `kyozo:dependsOn` - Dependency relationships
- `kyozo:generates` - Output relationships
- `kyozo:enlightenedBy` - AI enhancement relationships
- `kyozo:validatedBy` - Schema validation relationships

## Full Example

```markdown
<!-- 
{
  "@context": "https://kyozo.dev/schemas/markdown-ld/v1",
  "@type": "kyozo:TutorialDocument",
  "@id": "tutorial:rest-api",
  "dc:title": "Building a REST API",
  "dc:creator": "Alice Developer",
  "kyozo:enlightenment": {
    "@type": "kyozo:EnlightenmentConfig",
    "kyozo:style": "beginner_friendly"
  }
}
-->

# Building a REST API

This tutorial teaches you how to build a REST API.

## Setup Dependencies

<!-- 
{
  "@id": "block:dependencies",
  "@type": "kyozo:CodeBlock",
  "kyozo:language": "elixir",
  "kyozo:executionContext": "setup"
}
-->
```elixir
Mix.install([
  {:plug_cowboy, "~> 2.0"},
  {:jason, "~> 1.4"}
])
```

## Configuration

<!--
{
  "@id": "block:config",
  "@type": "kyozo:DataBlock",
  "kyozo:format": "application/ld+json",
  "kyozo:validates": {
    "@id": "schema:APIConfig"
  }
}
-->
```json
{
  "@context": {
    "api": "https://kyozo.dev/vocab/api/"
  },
  "@type": "api:Configuration",
  "api:server": {
    "@type": "api:ServerConfig",
    "api:port": 4000,
    "api:host": "localhost"
  },
  "api:database": {
    "@type": "api:DatabaseConfig", 
    "api:url": "postgresql://localhost/myapp"
  }
}
```

## Define Router

<!--
{
  "@id": "block:router",
  "@type": "kyozo:CodeBlock",
  "kyozo:dependsOn": ["block:dependencies", "block:config"],
  "kyozo:generates": {
    "@type": "kyozo:Module",
    "kyozo:name": "MyAPI.Router"
  }
}
-->
```elixir
defmodule MyAPI.Router do
  use Plug.Router
  
  plug :match
  plug :dispatch
  
  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{
      "@context": "https://schema.org/",
      "@type": "HealthCheck",
      "status": "OK",
      "timestamp": DateTime.utc_now()
    }))
  end
end
```

## Query Example

<!--
{
  "@id": "block:user-query",
  "@type": "kyozo:QueryBlock",
  "kyozo:language": "sparql",
  "kyozo:endpoint": "https://kyozo.dev/sparql"
}
-->
```sparql
PREFIX kyozo: <https://kyozo.dev/vocab/>
PREFIX schema: <https://schema.org/>

SELECT ?user ?name ?email
WHERE {
  ?user a kyozo:User ;
        schema:name ?name ;
        schema:email ?email ;
        kyozo:createdAt ?date .
  FILTER(?date > "2024-01-01"^^xsd:date)
}
```
```

## Linked Data Benefits

### 1. Semantic Understanding
Machines understand not just the syntax but the meaning:
- What type of code block is this?
- What does it depend on?
- What does it generate?
- How should it be executed?

### 2. Knowledge Graph
Documents become nodes in a knowledge graph:
```turtle
@prefix kyozo: <https://kyozo.dev/vocab/> .
@prefix dc: <http://purl.org/dc/terms/> .

<tutorial:rest-api> a kyozo:TutorialDocument ;
    dc:title "Building a REST API" ;
    kyozo:hasBlock <block:dependencies> ;
    kyozo:hasBlock <block:router> .

<block:router> a kyozo:CodeBlock ;
    kyozo:dependsOn <block:dependencies> ;
    kyozo:generates <module:MyAPI.Router> .
```

### 3. Rich Queries
Query across documents with SPARQL:
```sparql
# Find all code blocks that generate API routes
SELECT ?doc ?block ?route
WHERE {
  ?doc kyozo:hasBlock ?block .
  ?block a kyozo:CodeBlock ;
         kyozo:generates ?module .
  ?module kyozo:definesRoute ?route .
}
```

### 4. Interoperability
Use standard vocabularies:
- Schema.org for common types
- Dublin Core for metadata  
- FOAF for people/organizations
- Custom Kyozo vocabulary for our domain

## Implementation

### Parser
```elixir
defmodule MarkdownLD.Parser do
  def parse(content) do
    # Extract JSON-LD blocks
    json_ld_blocks = extract_json_ld(content)
    
    # Build RDF graph
    graph = RDF.Graph.new()
    |> add_triples(json_ld_blocks)
    
    # Parse markdown with graph context
    document = parse_with_context(content, graph)
    
    {:ok, document}
  end
end
```

### Execution with Linked Data Context
```elixir
defmodule MarkdownLD.Executor do
  def execute(document, context) do
    # Query dependencies from graph
    deps = SPARQL.execute("""
      SELECT ?dep WHERE {
        <#{block_id}> kyozo:dependsOn ?dep .
      }
    """, document.graph)
    
    # Execute in dependency order
    execute_with_deps(block, deps, context)
  end
end
```

## File Extension

- **Primary**: `.mdld` (Markdown-LD)
- **Alternative**: `.md` with `<!-- @context -->` declaration

## MIME Type

`text/markdown+ld`

## Benefits of Markdown-LD

1. **Human Readable**: Still just markdown to humans
2. **Machine Understandable**: Rich semantic meaning for machines
3. **Queryable**: Can query across documents with SPARQL
4. **Extensible**: Add new vocabularies and meanings
5. **Standards-Based**: Built on W3C standards (JSON-LD, RDF)
6. **Interoperable**: Works with existing Linked Data tools

## Future: Federated Markdown-LD

Documents can reference and link to each other across the web:

```markdown
<!--
{
  "@context": "https://kyozo.dev/schemas/markdown-ld/v1",
  "@id": "https://mysite.com/docs/api",
  "owl:imports": "https://othersite.com/docs/shared-types"
}
-->

# My API Documentation

This document extends the types defined in the imported document.
```