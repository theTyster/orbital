/**
 * test_facts.pl — Example facts for validating the ontology modules
 *
 * Models a hypothetical full-stack app to exercise all predicates.
 * This file doubles as a template showing the expected format
 * for generated facts files.
 */
:- discontiguous context/2, container/3, component/4,
                  file_mapping/3, depends_on/2.

%% ============================================================
%% C1: System Contexts
%% ============================================================

context(webapp, 'Full-stack web application with API and SPA frontend').
context(shared_infra, 'Shared infrastructure services (auth, logging)').

%% ============================================================
%% C2: Containers
%% ============================================================

container(webapp, frontend, 'React/TypeScript').
container(webapp, api_server, 'Node.js/Express').
container(webapp, postgres, 'PostgreSQL 16').
container(webapp, redis_cache, 'Redis 7').

container(shared_infra, auth_service, 'Go').
container(shared_infra, log_collector, 'Fluentd').

%% ============================================================
%% C3: Components
%% ============================================================

% Frontend components
component(webapp, frontend, app_shell, 'Root layout and routing').
component(webapp, frontend, auth_ui, 'Login/signup forms').
component(webapp, frontend, dashboard, 'Main user dashboard').
component(webapp, frontend, api_client, 'HTTP client wrapper').

% API server components
component(webapp, api_server, auth_middleware, 'JWT validation middleware').
component(webapp, api_server, user_controller, 'User CRUD endpoints').
component(webapp, api_server, order_controller, 'Order management endpoints').
component(webapp, api_server, db_pool, 'Database connection pool').
component(webapp, api_server, cache_layer, 'Redis caching abstraction').

% Shared infra components
component(shared_infra, auth_service, token_issuer, 'JWT token generation').
component(shared_infra, auth_service, user_store, 'User credential storage').
component(shared_infra, log_collector, log_parser, 'Structured log parsing').

%% ============================================================
%% Dependencies
%% ============================================================

% Frontend deps
depends_on(auth_ui, api_client).
depends_on(dashboard, api_client).
depends_on(app_shell, auth_ui).
depends_on(app_shell, dashboard).

% API server deps
depends_on(user_controller, auth_middleware).
depends_on(user_controller, db_pool).
depends_on(order_controller, auth_middleware).
depends_on(order_controller, db_pool).
depends_on(order_controller, cache_layer).
depends_on(auth_middleware, token_issuer).

% Cross-system deps
depends_on(api_client, auth_middleware).
depends_on(cache_layer, db_pool).

%% ============================================================
%% File Mappings
%% ============================================================

% Context roots
file_mapping(context, webapp, '/project').
file_mapping(context, shared_infra, '/infra').

% Container paths
file_mapping(container, frontend, '/project/frontend/src').
file_mapping(container, api_server, '/project/api/src').
file_mapping(container, postgres, '/project/db').
file_mapping(container, redis_cache, '/project/config/redis').
file_mapping(container, auth_service, '/infra/auth').
file_mapping(container, log_collector, '/infra/logging').

% Component files
file_mapping(component, app_shell, '/project/frontend/src/App.tsx').
file_mapping(component, auth_ui, '/project/frontend/src/components/Auth.tsx').
file_mapping(component, dashboard, '/project/frontend/src/components/Dashboard.tsx').
file_mapping(component, api_client, '/project/frontend/src/lib/api.ts').

file_mapping(component, auth_middleware, '/project/api/src/middleware/auth.ts').
file_mapping(component, user_controller, '/project/api/src/controllers/user.ts').
file_mapping(component, order_controller, '/project/api/src/controllers/order.ts').
file_mapping(component, db_pool, '/project/api/src/db/pool.ts').
file_mapping(component, cache_layer, '/project/api/src/cache/redis.ts').

file_mapping(component, token_issuer, '/infra/auth/issuer.go').
file_mapping(component, user_store, '/infra/auth/store.go').
file_mapping(component, log_parser, '/infra/logging/parser.conf').
