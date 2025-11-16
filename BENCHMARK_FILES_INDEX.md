# Polytree Benchmark Files Index

This directory contains comprehensive benchmarking scripts and reports analyzing Polytree's sliceIntoLayers performance on the Benchy test model.

## Quick Start

Run the comprehensive benchmark:
```bash
node benchmark-benchy-detailed.js
```

View results:
```bash
cat BENCHMARK_SUMMARY.md
cat POLYTREE_PERFORMANCE_REPORT.md
```

## Files Created

### Analysis Scripts

1. **benchmark-benchy-detailed.js** (15KB)
   - Comprehensive slicing benchmark for layers 0-10
   - Analyzes segment quality, gaps, connectivity
   - Reports timing and performance metrics
   - Run time: ~90 seconds

2. **analyze-gap-triangles.js** (13KB)
   - Deep dive into triangle intersections near gaps
   - Identifies missing segments in Polytree output
   - Classifies triangle-plane intersections
   - Shows which triangles should fill gaps but don't
   - Run time: ~90 seconds

3. **visualize-gap-pattern.js** (6KB)
   - Generates visual charts of gap distribution
   - Shows gap severity across layers
   - Statistical summary and trends
   - Run time: instant

4. **generate-final-report.js** (15KB)
   - Generates the comprehensive technical report
   - Consolidates all findings
   - Produces POLYTREE_PERFORMANCE_REPORT.md
   - Run time: instant

### Reports

5. **BENCHMARK_SUMMARY.md** (8KB)
   - Executive summary of findings
   - Key metrics and results tables
   - Root cause analysis
   - Recommended fixes
   - **READ THIS FIRST**

6. **POLYTREE_PERFORMANCE_REPORT.md** (15KB)
   - Detailed technical report
   - Complete analysis and evidence
   - Algorithmic issues identified
   - Testing recommendations
   - Impact assessment

7. **BENCHMARK_FILES_INDEX.md** (this file)
   - Index of all benchmark files
   - Quick start guide
   - File descriptions

### Existing Diagnostic Scripts

8. **examples/scripts/diagnose-layer5.js**
   - Original diagnostic for Layer 5
   - Analyzes path connectivity
   - Reports gap locations

9. **examples/scripts/debug-benchy-quick.js**
   - Quick 10-layer diagnostic
   - Faster iteration for debugging
   - Basic path analysis

10. **examples/scripts/test-benchy-layer5.js**
    - Simple Layer 5 test
    - Compares layers 4 and 5

## Key Findings Summary

- **100% failure rate**: All 11 layers tested have gaps > 1mm
- **6 critical layers**: Gaps > 4mm (layers 3, 4, 5, 7, 8, 10)
- **Worst gap**: 5.80mm on layer 10
- **Root cause**: Polytree fails to generate segments for triangles with near-parallel edges
- **Performance**: 8s/layer (4-8x slower than expected)

## Evidence

The analysis conclusively shows:

1. **Triangle 198780** on Layer 5 should produce segment (-25.48, -0.81) → (-24.88, -0.81)
2. This segment would fill the gap
3. The triangle intersects the slice plane correctly
4. **But Polytree does not generate this segment**

This proves the bug is in Polytree's segment generation, not path connection.

## Recommended Actions

1. Report findings to Polytree maintainers
2. Implement fixes for near-parallel edge handling
3. Add segment connectivity validation
4. Optimize triangle iteration performance
5. Re-test with fixed version

## Running All Tests

```bash
# Comprehensive benchmark (90s)
node benchmark-benchy-detailed.js > benchmark_output.txt

# Triangle analysis (90s)
node analyze-gap-triangles.js > triangle_analysis.txt

# Visualization (instant)
node visualize-gap-pattern.js

# Generate report (instant)
node generate-final-report.js

# Original diagnostics (90s each)
node examples/scripts/diagnose-layer5.js
node examples/scripts/debug-benchy-quick.js
```

## Test Environment

- Node.js: v20.19.5
- Polytree: ^0.1.3
- Model: 3DBenchy (225,706 triangles)
- Test date: 2025-11-16

## Contact

For questions about these benchmarks, refer to the detailed reports or the original Polytree issue report (POLYTREE_ISSUE_REPORT.md).

---
*Benchmarks completed by Slice Benchmarks Agent*
