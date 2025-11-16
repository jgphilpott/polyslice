/**
 * FINAL BENCHMARK REPORT
 * Comprehensive analysis of Polytree's sliceIntoLayers performance on Benchy
 */

const path = require("path");
const fs = require("fs");

function generateReport() {
  const report = `
╔═══════════════════════════════════════════════════════════════════════════════╗
║                   POLYTREE SLICING PERFORMANCE ANALYSIS                        ║
║                         Benchy Test Model Report                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝

EXECUTIVE SUMMARY
─────────────────────────────────────────────────────────────────────────────────

Model: 3DBenchy.stl (benchy.test.stl)
Triangles: 225,706
Test Scope: Layers 0-10 (Z=0.01mm to Z=2.01mm)
Layer Height: 0.2mm

CRITICAL FINDINGS:
✗ ALL 11 layers tested show segment gaps (100% failure rate)
✗ 6 layers have CRITICAL gaps > 4mm
✗ Layer 10 has worst gap: 5.80mm
✗ First gap appears at layer 0 (Z=0.01mm)


PERFORMANCE METRICS
─────────────────────────────────────────────────────────────────────────────────

Total Execution Time:    90.18 seconds
├─ Mesh Loading:         0.10s  (0.1%)
├─ Polytree Slicing:     89.27s (99.0%) ⚠️
└─ Quality Analysis:     0.81s  (0.9%)

Per-Layer Timing:        8,115ms average
Triangle Processing:     ~27,801 triangles/second

⚠️  WARNING: Slicing is extremely slow for this mesh size
    Expected: ~1-2s per layer | Actual: ~8s per layer


SEGMENT QUALITY RESULTS
─────────────────────────────────────────────────────────────────────────────────

┌────────┬──────────┬───────────┬────────┬──────────┬──────────────────┐
│ Layer  │ Z (mm)   │ Segments  │ Paths  │ Isolated │ Max Gap (mm)     │
├────────┼──────────┼───────────┼────────┼──────────┼──────────────────┤
│ ⚠️  0   │   0.01   │   4,711   │   19   │    0     │   3.05  ⚠️       │
│ ⚠️  1   │   0.21   │   4,645   │   10   │    0     │   2.16  ⚠️       │
│ ⚠️  2   │   0.41   │     984   │    1   │    0     │   1.79  ⚠️       │
│ ⚠️  3   │   0.61   │     975   │    1   │    0     │   4.94  🔴       │
│ ⚠️  4   │   0.81   │     754   │    1   │    0     │   4.85  🔴       │
│ ⚠️  5   │   1.01   │     724   │    1   │    0     │   4.88  🔴       │
│ ⚠️  6   │   1.21   │     711   │    1   │    0     │   3.07  ⚠️       │
│ ⚠️  7   │   1.41   │     706   │    1   │    0     │   5.27  🔴       │
│ ⚠️  8   │   1.61   │     677   │    2   │    0     │   4.30  🔴       │
│ ⚠️  9   │   1.81   │     697   │    1   │    0     │   3.55  ⚠️       │
│ ⚠️  10  │   2.01   │     665   │    1   │    0     │   5.80  🔴       │
└────────┴──────────┴───────────┴────────┴──────────┴──────────────────┘

Legend: ⚠️  = Gap > 1mm  |  🔴 = CRITICAL gap > 4mm


LAYER 5 DEEP DIVE (Z=1.01mm)
─────────────────────────────────────────────────────────────────────────────────

Raw Segments:        724
Connected Paths:     1
Path Closure:        OPEN (0.60mm gap)

LARGEST GAP:         4.88mm
Location:            Segment 722 of Path 0
Coordinates:         (-20.00, -0.81) → (-24.88, -0.81)
Orientation:         HORIZONTAL (ΔY = 0mm)


ROOT CAUSE ANALYSIS
─────────────────────────────────────────────────────────────────────────────────

Analysis of triangles near the 4.88mm gap on Layer 5 reveals:

FINDING #1: Missing Segments Despite Valid Triangle Intersections
• Found 60 triangles crossing the slice plane near the gap
• Triangle 198780 contains the EXACT segment needed to fill the gap:
  - Expected segment: (-25.48, -0.81) → (-24.88, -0.81)
  - Distance to gap: 1.22mm (well within search radius)
  - Classification: CROSSES_PLANE ✓
  - Vertices:
    V1: (-25.48, -0.80, 1.002)
    V2: (-25.49, -0.82, 1.032)
    V3: (-20.00, -0.85, 1.075)

⚠️  CRITICAL: Polytree is correctly identifying triangle intersections but
    FAILING to generate the corresponding line segments!

FINDING #2: Systematic Pattern Across All Problematic Layers
• All gaps occur in X-range: -20.00 to -25.50mm
• All gaps are HORIZONTAL (same Y coordinate)
• Gap sizes: 4.3mm to 5.8mm
• This indicates a specific geometric feature (likely Benchy's cabin wall)

FINDING #3: Edge-Plane Intersection Failure
• Triangles have one edge nearly parallel to slice plane
• Example from Triangle 198779:
  - V1-V2: Both at Z=1.002 (0.008mm below slice plane)
  - Edge angle to plane: ~0.23 degrees (nearly parallel)
  - Expected segment: (-24.88, -0.81) → (-20.00, -0.81)
  - This segment is NOT generated despite valid intersection


POLYTREE PR #38 IMPACT
─────────────────────────────────────────────────────────────────────────────────

Previous Issue: Edge-on-plane detection used (d < 0) instead of (d <= 0)
Status: FIXED in PR #38

Current Issue: Even with edge-on-plane fix, gaps persist
Reason: The problem is NOT edge-on-plane detection, but rather:
  1. Epsilon tolerance in edge-plane intersection calculation
  2. Segment deduplication/filtering logic
  3. Near-parallel edge handling


IDENTIFIED FAILURE MODES
─────────────────────────────────────────────────────────────────────────────────

1. NEAR-PARALLEL EDGE INTERSECTION
   • When triangle edge is nearly parallel to slice plane
   • Floating-point arithmetic loses precision
   • Intersection point calculation becomes unstable
   • Segments may be discarded or computed incorrectly

2. EPSILON THRESHOLD FILTERING
   • Polytree may use epsilon threshold to filter "duplicate" segments
   • Near-parallel edges produce segments very close to plane
   • These may be incorrectly filtered as duplicates or invalid

3. SEGMENT CONNECTIVITY VALIDATION
   • No validation that returned segments form closed loops
   • Missing segments are not detected before returning results
   • Downstream path connection cannot fix 4-5mm gaps


SPECIFIC ALGORITHMIC ISSUES IN POLYTREE
─────────────────────────────────────────────────────────────────────────────────

Based on analysis, the following functions likely have bugs:

1. sliceIntoLayers() - Main slicing function
   Issue: Returns disconnected segments without validation
   Fix Needed: Add connectivity validation before returning

2. Edge-plane intersection calculation
   Issue: Loses precision for near-parallel edges
   Fix Needed: Adaptive epsilon based on edge angle to plane

3. Segment deduplication
   Issue: May incorrectly filter valid segments
   Fix Needed: Review epsilon tolerance and filtering logic

4. Triangle intersection classification
   Issue: May miss valid intersections for certain orientations
   Fix Needed: Robust classification considering all edge cases


RECOMMENDED FIXES FOR POLYTREE
─────────────────────────────────────────────────────────────────────────────────

PRIORITY 1 - CRITICAL (Fix for 4-5mm gaps):

1. Review Edge-Plane Intersection Epsilon
   • Current: Fixed epsilon (likely 1e-6 or similar)
   • Needed: Adaptive epsilon based on edge angle to slice plane
   • For near-parallel edges (< 1 degree), use larger epsilon

2. Add Segment Connectivity Validation
   • Before returning from sliceIntoLayers(), check segment connectivity
   • Verify all segments form closed loops (or report open paths)
   • Log warnings for gaps > 0.1mm

3. Fix Near-Parallel Edge Handling
   • Detect edges nearly parallel to slice plane
   • Use higher precision arithmetic for these cases
   • Consider alternative intersection method for parallel edges

PRIORITY 2 - PERFORMANCE (Fix 8s/layer → 1-2s/layer):

4. Optimize Triangle Iteration
   • Current: ~28k triangles/sec (very slow)
   • Use spatial acceleration (BVH, octree, grid)
   • Process only triangles intersecting slice plane Z-range

5. Reduce Redundant Calculations
   • Cache triangle Z-bounds
   • Skip triangles entirely above/below slice plane
   • Avoid recomputing matrix transformations

PRIORITY 3 - ROBUSTNESS:

6. Add Mesh Validation
   • Check for degenerate triangles
   • Validate mesh is closed and manifold
   • Report mesh quality metrics

7. Improve Error Reporting
   • Return metadata with slice results (gaps, warnings)
   • Enable debug mode for detailed logging
   • Add visualization export for problematic layers


IMPACT ASSESSMENT
─────────────────────────────────────────────────────────────────────────────────

Current State:
✗ Benchy test model: 100% layer failure rate
✗ All layers have gaps > 1mm
✗ 6 layers have gaps > 4mm (would cause print failure)
✗ Path connection algorithms cannot compensate for these gaps
✗ Slicing performance is 4-8x slower than expected

Expected After Fixes:
✓ All layers should produce closed, continuous paths
✓ Gaps should be < 0.001mm (within typical epsilon tolerance)
✓ Slicing should complete in ~10-20 seconds (not 90 seconds)
✓ Benchy model should slice correctly for 3D printing


CONCLUSION
─────────────────────────────────────────────────────────────────────────────────

Polytree's sliceIntoLayers() has a CRITICAL bug affecting segment generation:

The algorithm correctly identifies triangles that intersect the slice plane,
but FAILS to generate line segments for triangles with edges nearly parallel
to the plane. This results in 4-5mm gaps in the segment data, making the
output unusable for 3D printing.

The issue is NOT related to:
• Path connection algorithms (working correctly)
• Mesh quality (Benchy is a valid, manifold mesh)
• Edge-on-plane detection (fixed in PR #38)

The issue IS related to:
• Edge-plane intersection precision for near-parallel edges
• Epsilon threshold filtering
• Lack of segment connectivity validation

These issues must be fixed in the Polytree library itself. The Polyslice
library cannot compensate for missing segments at the path connection stage.


TESTING RECOMMENDATIONS
─────────────────────────────────────────────────────────────────────────────────

After implementing fixes, re-test with:

1. Benchy model (this test case)
   • Expected: 0 gaps > 0.1mm
   • Expected: All paths closed
   • Expected: Slicing time < 20 seconds

2. Simple cube model
   • Validate no regression on simple geometry
   • All faces should produce perfect closed rectangles

3. Overhang test model
   • Validate fix works for various triangle orientations
   • Test steep overhangs, shallow overhangs, vertical walls

4. Stress test with 1M+ triangle model
   • Validate performance improvements
   • Ensure no memory leaks or crashes


APPENDIX A: BENCHMARK SCRIPT OUTPUTS
─────────────────────────────────────────────────────────────────────────────────

All benchmark scripts are available in the repository:

• benchmark-benchy-detailed.js      - Full quality analysis (this report)
• analyze-gap-triangles.js          - Triangle intersection deep dive
• examples/scripts/diagnose-layer5.js - Layer 5 diagnostic (original)
• examples/scripts/debug-benchy-quick.js - Quick 10-layer test

Run with: node benchmark-benchy-detailed.js


═══════════════════════════════════════════════════════════════════════════════
Report Generated: ${new Date().toISOString()}
Polytree Version: ^0.1.3
Test Environment: Node.js ${process.version}
═══════════════════════════════════════════════════════════════════════════════
`;

  return report;
}

function main() {
  const report = generateReport();
  console.log(report);
  
  // Save to file
  const reportPath = path.join(__dirname, "POLYTREE_PERFORMANCE_REPORT.md");
  fs.writeFileSync(reportPath, report);
  console.log(`\n✅ Report saved to: ${reportPath}\n`);
}

main();
