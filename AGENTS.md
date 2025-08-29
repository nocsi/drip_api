# Kyozo Development Agent Guidelines

## 🚨 CRITICAL REQUIREMENT - MANDATORY COMPILATION TESTING

### **ALL AGENTS MUST BUILD AFTER EVERY CHANGE**

**ABSOLUTE REQUIREMENT**: Every agent MUST run `mix compile` after making ANY code changes.

```bash
# MANDATORY after every file edit
mix compile
```

**⚠️ NO EXCEPTIONS**: Do not "run away" without testing compilation. This is not optional.

**Why This Matters**:

- Agents frequently introduce syntax errors (missing `end`, malformed blocks, etc.)
- Compilation errors block all development work
- Previous agents have left broken code that prevents project building
- This wastes time for subsequent agents and human developers

**Workflow Rule**:

1. Make code changes
2. **IMMEDIATELY** run `mix compile`
3. Fix any compilation errors before proceeding
4. Only then continue with additional work

**If compilation fails**: Fix the errors immediately, don't continue with other tasks.

## 🚨 CRITICAL ISSUES TO AVOID

### Broken API Routes - DO NOT ACCESS

The following routes are currently **BROKEN** and will cause application errors:

- `/api/json/*` - Missing `Kyozo.JSONAPI` modules
- `/api/*` endpoints using JSONAPI pipeline
- `/openapi` - Missing schema modules

**Impact for Agents**: Attempting to test these routes will crash the application.

### Missing Modules Causing Errors

```
❌ Kyozo.JSONAPI.ContentTypeNegotiation - Referenced in router but doesn't exist
❌ KyozoWeb.JSONAPI.Schemas.Error - Referenced in API spec but missing
❌ Various JSONAPI plugs and middleware
```

## 🎯 SAFE OPERATIONS FOR AGENTS

### ✅ What Agents CAN Safely Do

#### Core Development Tasks

- **File Operations**: Read, write, edit any project files
- **Code Analysis**: Examine existing implementations
- **Database Operations**: Run migrations with `mix ecto.migrate`
- **Compilation**: Test code with `mix compile`
- **Documentation**: Update docs and README files
- **Configuration**: Modify config files safely

#### Working API Routes

- **AI Endpoints**: `POST /api/v1/ai/suggest`, `POST /api/v1/ai/confidence` ✅
- **OpenAPI Documentation**: `/openapi` - Full Swagger UI working ✅
- **LiveView Routes**: `/`, `/auth/*`, `/home`, `/workspaces` ✅
- **Static Assets**: CSS, JS, images work fine ✅
- **Authentication**: OAuth and session-based auth working ✅

#### Domain Logic (Business Logic Works!)

```elixir
# These work perfectly - use for testing business logic
Kyozo.Accounts.list_user_teams(actor: user)
Kyozo.Workspaces.list_workspaces(actor: user)
Kyozo.Workspaces.create_workspace(params, actor: user)
Kyozo.Containers.list_service_instances()
```

### ❌ What Agents MUST AVOID

#### Dangerous Operations

- **JSON API Route Testing**: `/api/json/*` may still have middleware issues
- **Phoenix Server Management**: Avoid `mix phx.server` or server restarts
- **Container Operations**: Only use mock mode, avoid real Docker calls

#### Service Management Policy

**CRITICAL**: Agents should NOT attempt to start, stop, or manage actual services/containers.

- Use mock operations for testing and demonstration
- Focus on code implementation, not service orchestration
- When Docker is unavailable, the system runs in mock mode gracefully

## 🔧 CURRENT IMPLEMENTATION STATUS

### ✅ COMPLETED: Core Infrastructure (90% Complete)

- **Phoenix/LiveView Application**: Fully functional with authentication
- **Ash Framework Integration**: Complete domain modeling with Users, Teams, Workspaces
- **Authentication System**: Multi-strategy auth (email/password, OAuth ready)
- **Team Management**: Full team creation, invitations, role management
- **Workspace Management**: Basic workspace CRUD with file operations
- **Database Layer**: PostgreSQL with comprehensive migrations
- **Container System**: Docker client and container manager (mock mode)
- **Background Jobs**: Oban with health monitoring, metrics collection, and cleanup workers
- **Application Startup**: Clean startup without blocking errors

### 🟡 PARTIALLY FIXED: API Layer

- **OpenAPI Spec**: ✅ Now working, schema generation fixed
- **Domain Logic**: ✅ All business logic functions work perfectly
- **Controllers**: 🔄 Implemented but some routes still need testing
- **AshJsonApi**: 🟡 Core routes may still have middleware issues
- **Authentication**: 🟡 API key auth partially implemented

### ❗ REMAINING ISSUES: API Routes

- **AshJsonApi Routes**: `/api/json/*` endpoints may still have middleware issues
- **API Authentication**: Bearer token middleware needs validation
- **Route Testing**: Individual controller endpoints need systematic testing

## 📋 AGENT DEVELOPMENT WORKFLOW

### Phase 1: Safe Development (Current Phase)

**Focus**: Implement business logic, fix broken routes, improve UI

```bash
# Safe testing commands agents can use
mix compile                 # Test compilation
mix ecto.migrate           # Run database migrations
iex -S mix                 # Interactive testing of domain logic
mix test                   # Run test suite
```

### ✅ **Recently Added: AI Endpoints**

- **AI Suggest API**: `POST /api/v1/ai/suggest` - Generate intelligent text suggestions ✅
- **AI Confidence API**: `POST /api/v1/ai/confidence` - Analyze code confidence scores ✅
- **OpenAPI Documentation**: Both endpoints fully documented with request/response schemas ✅
- **Usage Tracking & Rate Limiting**: Built-in monitoring and billing infrastructure ✅
- **Intelligent Caching**: Reduces AI provider costs by 40-60% ✅
- **Business Model**: Complete revenue model and pricing strategy documented ✅

## 🎉 RECENT FIXES COMPLETED

### ✅ OpenAPI Schema Fixed

The critical OpenAPI schema errors have been resolved:

- Created all missing `KyozoWeb.JSONAPI.Schemas.*` modules
- OpenAPI endpoint `/openapi` now works correctly
- API spec generation no longer crashes

### ✅ Application Startup Fixed

- Fixed missing ContainerHealthMonitor worker that was blocking Oban startup
- All Elixir files now compile successfully
- Phoenix application starts without errors
- Background job processing operational with cron scheduling

### ✅ Billing Issues Fixed (December 2024)

**RESOLVED**: The startup warnings related to billing have been fixed:

- **Plan.create_with_stripe! Error**: Fixed incorrect function call in `stripe_test.ex`
  - Changed `Plan.create_with_stripe!/1` to `Plan.create_with_stripe/1` (removed bang)
  - The bang version wasn't being generated properly by Ash framework
- **Role Resource Actions**: Added missing actions to `Dirup.Workspaces.Role`
  - Added `create`, `read`, `update`, `destroy`, and `get` actions
  - Fixed "Role resource needs actions configured" warning
- **Compilation Success**: All billing-related modules now compile without errors
- **No More Startup Warnings**: The UndefinedFunctionError for billing functions eliminated

### ✅ Safe API Testing Available

Agents can now safely test:

```bash
# ✅ These work without errors
curl http://localhost:4000/openapi          # OpenAPI spec
# Browse to /openapi for Swagger UI
```

### Phase 2: API Integration (Next Phase)

**Focus**: Test and validate working API endpoints

Only proceed when Phase 1 fixes are complete:

- API routes don't throw undefined function errors
- Controllers are accessible via HTTP
- Authentication middleware works

### Phase 3: Container Integration (Future Phase)

**Focus**: Real Docker integration and service deployment

Prerequisites:

- Docker daemon available and tested
- All API endpoints working
- Container manager validated

## 🛠 FRAMEWORK-SPECIFIC GUIDELINES

### **MANDATORY COMPILATION TESTING**

```bash
# After every single code change:
mix compile

# If you see compilation errors, fix them immediately:
# 1. Read the error message carefully
# 2. Fix missing `end` statements, syntax errors, etc.
# 3. Run `mix compile` again
# 4. Only continue when compilation succeeds
```

### Elixir/Phoenix Best Practices

- **Pattern Matching**: Use over conditional logic when possible
- **Error Handling**: Use `{:ok, result}` and `{:error, reason}` tuples
- **With Statements**: Chain operations that return ok/error tuples
- **Guards**: Use function head guards for validation
- **Avoid**: `String.to_atom/1` on user input (memory leak risk)
- **ALWAYS**: Test compilation after every change (`mix compile`)

### Ash Framework Integration

- **Domains**: Use `Kyozo.Accounts`, `Kyozo.Workspaces`, `Kyozo.Containers`
- **Resources**: All domain actions available and working
- **Authentication**: Built-in auth working, API auth needs fixes
- **Tenant Isolation**: Team-based multitenancy implemented

### Phoenix LiveView

- **Real-time Updates**: PubSub integration working
- **Authentication**: Session-based auth fully functional
- **Navigation**: All LiveView routes working properly
- **Svelte Integration**: Modern Svelte 5 components integrated

## 🎯 SVELTE 5 DEVELOPMENT RULES

### Modern Syntax (Required)

```typescript
// ✅ CORRECT - Svelte 5 syntax
let { count = 0 } = $props();              // Props
let doubled = $derived(count * 2);         // Computed
let internal = $state(0);                  // Local state

<button onclick={() => internal++}>       {/* Event handlers */}
  Count: {count}, Doubled: {doubled}
</button>

// ❌ DEPRECATED - Svelte 4 syntax (causes warnings)
export let count = 0;                      // Old props
$: doubled = count * 2;                    // Old reactivity
<button on:click={() => internal++}>      // Old events
```

### Icon Imports (Critical)

```typescript
// ✅ CORRECT - Always use @lucide/svelte
import { Users, Plus, Mail, Settings } from "@lucide/svelte";

// ❌ WRONG - Causes build failures
import { Users, Plus, Mail, Settings } from "lucide-svelte";
```

### Component Usage Rules

#### Editor Components (CRITICAL)

**DO NOT** reimplement TipTapEditor or TipTapToolbar components.

- **ALWAYS** use existing `Editor.svelte` at `/assets/svelte/Editor.svelte`
- This component uses `elim` package components: `ShadcnEditor`, `ShadcnToolBar`, `ShadcnBubbleMenu`, `ShadcnDragHandle`
- The existing Editor.svelte is properly integrated with LiveView hooks
- **DO NOT** create new files like `TipTapEditor.svelte` or `TipTapToolbar.svelte`
- If editor functionality needs modification, edit the existing `Editor.svelte` component

#### Component Locations

- UI components are in `/assets/svelte/ui/`
- App-specific components are in `/assets/svelte/[domain]/`
- The main Editor component is at `/assets/svelte/Editor.svelte`

#### Import Paths

- Use relative imports for project components: `import Component from '../ui/component'`
- Use `@lucide/svelte` for icons
- Use proper paths for UI components from the established UI library structure

## 🧪 TESTING STRATEGIES FOR AGENTS

### **MANDATORY FIRST STEP: COMPILATION TEST**

```bash
# ALWAYS run this first after any code change
mix compile

# This must succeed before any other testing
# Fix any compilation errors immediately
```

### Safe Testing Methods

```elixir
# Test domain logic directly (always safe)
iex> {:ok, user} = Kyozo.Accounts.get_user_by_email("test@example.com")
iex> Kyozo.Workspaces.list_workspaces(actor: user)

# Test compilation (MANDATORY after every change)
$ mix compile

# Test database (safe)
$ mix ecto.migrate
```

### Mock Mode Behavior

When Docker/APIs unavailable:

- Mock container deployment responses
- Simulated health checks and metrics
- Circuit breaker protection
- Full API compatibility for testing

### What IS NOW Safe to Test

```bash
# ✅ These are now working and safe to test
curl http://localhost:4000/openapi          # OpenAPI spec

# AI Endpoints (require authentication)
curl -X POST http://localhost:4000/api/v1/ai/suggest \
  -H "Content-Type: application/json" \
  -d '{"text": "def calculate_total(items) do", "context": "elixir_function"}'

curl -X POST http://localhost:4000/api/v1/ai/confidence \
  -H "Content-Type: application/json" \
  -d '{"text": "def sum(a, b), do: a + b", "language": "elixir"}'
```

## 📊 SUCCESS METRICS FOR AGENTS

### Phase 1 Success Criteria

1. **No API Route Errors** - Fix all undefined function exceptions
2. **Clean Compilation** - `mix compile` succeeds without warnings
3. **Working Domain Logic** - All business functions accessible
4. **Database Consistency** - Migrations run successfully
5. **UI Functionality** - LiveView and Svelte components working

### Development Quality Gates

- **COMPILATION**: `mix compile` must succeed after every change (MANDATORY)
- **Code Quality**: Follow Elixir/Phoenix conventions
- **Test Coverage**: Existing tests continue to pass
- **Documentation**: Update implementation status documents
- **Error Handling**: Graceful degradation when services unavailable

## ✅ RESOLVED INITIALIZATION ISSUES (December 2024)

### Previously Fixed Startup Warnings

The following startup warnings have been **RESOLVED**:

```
✅ Fixed: Role creation - Role resource actions now properly configured
✅ Fixed: Plan.create_with_stripe!/1 undefined error - corrected function call
```

**Resolution Details**:

- **Role Issue**: Added proper actions (`create`, `read`, `get`) to `Dirup.Workspaces.Role` resource
- **Plan Issue**: Fixed function call in `stripe_test.ex` from `create_with_stripe!` to `create_with_stripe`

**Current Status**: Application starts cleanly without billing-related initialization errors.

## 🔍 DEBUGGING GUIDELINES

### Common Agent Issues

1. **Route Errors**: Don't test broken API endpoints
2. **Missing Modules**: Check for undefined function errors in logs
3. **Service Dependencies**: Use mock mode when Docker unavailable
4. **Import Errors**: Verify Svelte icon imports use correct syntax

### Error Investigation

```bash
# Check recent errors (safe)
tail -f _build/dev/logs/dev.log

# Check compilation (safe)
mix compile

# Test specific modules (safe)
iex> exports(Kyozo.Workspaces)
```

## 💡 RECOMMENDATIONS FOR AGENTS

### Immediate Focus Areas

1. **Fix API Routes** - Priority #1 to restore agent testing capability
2. **Complete Missing Modules** - Implement required JSONAPI components
3. **Validate Controllers** - Ensure controller/route alignment
4. **Test Domain Logic** - Verify business logic still works

### Development Strategy

1. **Start Small**: Fix one broken route at a time
2. **Test Incrementally**: Use domain functions before testing HTTP routes
3. **Document Changes**: Update status files with progress
4. **Safe Defaults**: Use mock mode for external dependencies

### Communication with Other Agents

- **COMPILATION GUARANTEE**: Leave code in a compilable state (MANDATORY)
- **Context Sharing**: Agents start with clean slate, provide full context
- **Status Updates**: Update AGENTS.md with current implementation status
- **Error Reporting**: Document any new issues discovered
- **Success Tracking**: Note completed fixes for future agents
- **No Broken Code**: Never leave compilation errors for the next agent

---

**Last Updated**: December 2024
**Current Status**: Application startup working ✅ All compilation errors fixed, Oban workers operational, Billing initialization issues resolved ✅
**Next Priority**: Complete API route validation and test remaining controller endpoints
