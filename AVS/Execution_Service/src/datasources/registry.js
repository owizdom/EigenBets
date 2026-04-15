/**
 * Plugin registry for data sources.
 *
 * Usage:
 *   const registry = require('./registry');
 *   const ds = registry.get('twitter');  // returns a datasource instance
 *   const all = registry.getAll();        // returns list of registered types
 */
const BaseDatasource = require('./base.datasource');

const _registry = new Map();

/**
 * Register a datasource class (auto-called on require).
 * @param {typeof BaseDatasource} DatasourceClass
 */
function register(DatasourceClass) {
  if (!DatasourceClass || typeof DatasourceClass.type !== 'string') {
    throw new Error('Datasource must define a static "type" getter that returns a string');
  }
  if (_registry.has(DatasourceClass.type)) {
    console.warn(`[datasource-registry] overwriting existing plugin: ${DatasourceClass.type}`);
  }
  _registry.set(DatasourceClass.type, DatasourceClass);
}

/**
 * Get a datasource instance by type.
 * @param {string} type
 * @returns {BaseDatasource}
 */
function get(type) {
  const DS = _registry.get(type);
  if (!DS) {
    throw new Error(`Unknown data source type: "${type}". Available: ${getAll().join(', ')}`);
  }
  return new DS();
}

/**
 * List all registered datasource types.
 * @returns {string[]}
 */
function getAll() {
  return Array.from(_registry.keys());
}

/**
 * Run health checks on every registered plugin.
 * @returns {Promise<Record<string, {ok: boolean, reason?: string}>>}
 */
async function healthCheckAll() {
  const results = {};
  for (const type of getAll()) {
    try {
      const ds = get(type);
      results[type] = await ds.healthCheck();
    } catch (err) {
      results[type] = { ok: false, reason: err.message };
    }
  }
  return results;
}

// ============ Auto-register built-in plugins ============
// Each require() below triggers the plugin file's own registration call.
// Keep this list in sync with the files in this directory.
try { register(require('./twitter.datasource')); } catch (e) { console.warn('[registry] twitter plugin not loaded:', e.message); }
try { register(require('./news.datasource')); } catch (e) { console.warn('[registry] news plugin not loaded:', e.message); }
try { register(require('./financial.datasource')); } catch (e) { console.warn('[registry] financial plugin not loaded:', e.message); }
try { register(require('./sports.datasource')); } catch (e) { console.warn('[registry] sports plugin not loaded:', e.message); }
try { register(require('./weather.datasource')); } catch (e) { console.warn('[registry] weather plugin not loaded:', e.message); }
try { register(require('./onchain.datasource')); } catch (e) { console.warn('[registry] onchain plugin not loaded:', e.message); }

module.exports = { register, get, getAll, healthCheckAll };
