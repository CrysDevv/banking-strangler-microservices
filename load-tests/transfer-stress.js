import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '20s', target: 10 },
    { duration: '40s', target: 30 },
    { duration: '20s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<600'],
    http_req_failed: ['rate<0.02'],
  },
};

const BASE_URL = 'http://localhost:8088/api/v1/bff';

export default function () {
  const url = `${BASE_URL}/transferencias`;
  const payload = JSON.stringify({
    idempotencyKey: `idem-${Date.now()}-${Math.floor(Math.random() * 1000000)}`,
    cuentaOrigen: '11222333',
    cuentaDestino: '99888777',
    monto: 500.00,
    glosa: 'k6 stress transfer'
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'X-Correlation-ID': `k6-corr-${Date.now()}`,
      'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LXVzZXIifQ.dummy'
    },
  };

  const res = http.post(url, payload, params);
  check(res, {
    'status es 200 o 400 (negocio)': (r) => r.status === 200 || r.status === 400,
  });
  sleep(1);
}
