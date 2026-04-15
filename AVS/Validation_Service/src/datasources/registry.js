/**
 * Plugin registry for data sources (Validation Service side).
 *
 * Mirrors Execution_Service/src/datasources/registry.js so the validator can
 * independently re-fetch data from the same sources.
 */
const BaseDatasource = require('./base.datasource');

const _registry = new Map();

function register(DatasourceClass) {
  if (!DatasourceClass || typeof DatasourceClass.type !== 'string') {
    throw new Error('Datasource must define a static "type" getter');
  }
  if (_registry.has(DatasourceClass.type)) {
    console.warn(`[datasource-registry] overwriting: ${DatasourceClass.type}`);
  }
  _registry.set(DatasourceClass.type, DatasourceClass);
}

function get(type) {
  const DS = _registry.get(type);
  if (!DS) {
    throw new Error(`Unknown data source type: "${type}". Available: ${getAll().join(', ')}`);
  }
  return new DS();
}

function getAll() {
  return Array.from(_registry.keys());
}

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

// Auto-register
try { register(require('./twitter.datasource')); } catch (e) { console.warn('[registry] twitter plugin not loaded:', e.message); }
try { register(require('./news.datasource')); } catch (e) { console.warn('[registry] news plugin not loaded:', e.message); }
try { register(require('./financial.datasource')); } catch (e) { console.warn('[registry] financial plugin not loaded:', e.message); }
try { register(require('./sports.datasource')); } catch (e) { console.warn('[registry] sports plugin not loaded:', e.message); }
try { register(require('./weather.datasource')); } catch (e) { console.warn('[registry] weather plugin not loaded:', e.message); }
try { register(require('./onchain.datasource')); } catch (e) { console.warn('[registry] onchain plugin not loaded:', e.message); }

module.exports = { register, get, getAll, healthCheckAll };
