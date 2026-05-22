# Routing Check Summary

Source report: `routing_violations.rpt` converted into a sanitized summary.

## Route Verification

| Metric | Value |
|---|---:|
| Total nets checked | 1532 |
| Open nets | 0 |
| Nets with errors | 0 |
| Total DRC violations | 0 |
| Total wire length | 50591 µm |
| Total routed wire length | 50402 µm |
| Total contacts | 8847 |
| Total wires | 9014 |
| Total routed wires | 8801 |

## Layer Usage

| Layer/Via | Count / Length |
|---|---:|
| M1 wire length | 1430 µm |
| M2 wire length | 26693 µm |
| M3 wire length | 22279 µm |
| TOP_M wire length | 0 µm |
| VIA12A | 4290 |
| VIA12A rotated | 238 |
| VIA23 | 4319 |

## Important Limitation

The route check reported zero open nets and zero DRC violations. However, antenna analysis was skipped because no antenna rules were defined in the available setup. Therefore, this should be treated as a routing-clean check, not complete foundry signoff.
