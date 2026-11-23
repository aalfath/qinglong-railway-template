// Railway reports the host's CPU count to Node, not the service's share.
// Qinglong sizes its task queues from os.cpus(), so cap the list to
// QL_CPU_LIMIT (set by railway-start.sh from the cgroup quota).
const os = require('os');
const limit = parseInt(process.env.QL_CPU_LIMIT || '0', 10);
if (limit > 0) {
  const original = os.cpus;
  os.cpus = function cpus() {
    const list = original.call(os);
    return list.length > limit ? list.slice(0, limit) : list;
  };
}
