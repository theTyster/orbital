/**
 * test_facts.pl — Example knowledge base for testing introspect.pl
 *
 * Models a software library ecosystem using plain Prolog facts.
 * No specific ontology — demonstrates that introspect.pl works
 * with arbitrary predicates.
 */
:- discontiguous module_type/2, depends_on/2, exports/2,
                  has_test/2, maintainer/2, license/2.

%% ============================================================
%% Module types
%% ============================================================

module_type(web_framework, framework).
module_type(auth_lib, library).
module_type(db_adapter, library).
module_type(cache_lib, library).
module_type(logging, library).
module_type(cli_tool, application).
module_type(test_runner, tool).

%% ============================================================
%% Dependencies
%% ============================================================

depends_on(web_framework, auth_lib).
depends_on(web_framework, logging).
depends_on(web_framework, db_adapter).
depends_on(auth_lib, db_adapter).
depends_on(auth_lib, cache_lib).
depends_on(db_adapter, logging).
depends_on(cache_lib, logging).
depends_on(cli_tool, web_framework).
depends_on(cli_tool, logging).
depends_on(test_runner, logging).

%% ============================================================
%% Exports (what each module provides)
%% ============================================================

exports(web_framework, handle_request).
exports(web_framework, route).
exports(web_framework, middleware).
exports(auth_lib, authenticate).
exports(auth_lib, authorize).
exports(db_adapter, query).
exports(db_adapter, transaction).
exports(cache_lib, get_cached).
exports(cache_lib, invalidate).
exports(logging, log_info).
exports(logging, log_error).

%% ============================================================
%% Test coverage
%% ============================================================

has_test(web_framework, true).
has_test(auth_lib, true).
has_test(db_adapter, false).
has_test(cache_lib, true).
has_test(logging, false).
has_test(cli_tool, false).
has_test(test_runner, true).

%% ============================================================
%% Maintainers
%% ============================================================

maintainer(web_framework, alice).
maintainer(auth_lib, alice).
maintainer(db_adapter, bob).
maintainer(cache_lib, bob).
maintainer(logging, charlie).
maintainer(cli_tool, charlie).
maintainer(test_runner, alice).

%% ============================================================
%% Licenses
%% ============================================================

license(web_framework, mit).
license(auth_lib, mit).
license(db_adapter, apache2).
license(cache_lib, mit).
license(logging, bsd3).
license(cli_tool, gpl3).
license(test_runner, mit).
