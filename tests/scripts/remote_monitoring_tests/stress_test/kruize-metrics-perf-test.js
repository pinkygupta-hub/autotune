import http from 'k6/http';
import { check, sleep } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

// ================= CLI CONFIG =================
// k6 run -e BASE_URL=http://192.168.49.2:30841 -e USERS=5 kruize-metrics-perf-test.js

const BASE_URL = __ENV.BASE_URL || 'http://192.168.49.2:30841';
const USERS = Number(__ENV.USERS) || 3;

// ================= k6 OPTIONS =================
export const options = {
  scenarios: {
    kruize_multi_experiment: {
      executor: 'per-vu-iterations',
      vus: USERS,       // 👈 from CLI
      iterations: 1,
    },
  },
};

export default function () {
  const vuId = __VU;

  const experimentName =
    `default|default|deployment|tfb-qrh-deployment-vu-${vuId}-${uuidv4()}`;

  // 1️⃣ Create Kruize Experiment
  const payload = JSON.stringify([
    {
      version: 'v2.0',
      experiment_name: experimentName,
      cluster_name: 'default',
      performance_profile: 'resource-optimization-local-monitoring',
      metadata_profile: 'cluster-metadata-local-monitoring',
      mode: 'monitor',
      target_cluster: 'local',
      kubernetes_objects: [
        {
          type: 'deployment',
          name: 'tfb-qrh-deployment',
          namespace: 'default',
          containers: [
            {
              container_image_name: 'kruize/tfb-db:1.15',
              container_name: 'tfb-server-0',
            },
            {
              container_image_name: 'kruize/tfb-qrh:1.13.2.F_et17',
              container_name: 'tfb-server-1',
            },
          ],
        },
      ],
      trial_settings: {
        measurement_duration: '15min',
      },
      recommendation_settings: {
        threshold: '0.1',
      },
      datasource: 'prometheus-1',
    },
  ]);

  const params = {
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
  };

  const createRes = http.post(
    `${BASE_URL}/createExperiment`,
    payload,
    params
  );

  check(createRes, {
    'createExperiment executed': (r) => r.status < 500,
  });

  // 2️⃣ Validate via listExperiments
  const listRes = http.get(`${BASE_URL}/listExperiments`);

  check(listRes, {
    'listExperiments OK': (r) => r.status === 200,
    'experiment listed': (r) => r.body.includes(experimentName),
  });

  sleep(1);
}
