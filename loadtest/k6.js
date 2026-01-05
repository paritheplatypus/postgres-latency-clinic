// loadtest/k6.js
import http from "k6/http";
import { check } from "k6";

export const options = {
  vus: 50,
  duration: "20s",
};

export default function () {
  const userId = Math.floor(Math.random() * 5000) + 1;
  const res = http.get(`http://localhost:8000/events/${userId}`);
  check(res, { "status is 200": (r) => r.status === 200 });
}
