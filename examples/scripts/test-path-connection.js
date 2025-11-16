const helpers = require('../../src/slicer/geometry/helpers.js');

// Test with a simple square
const segments = [
  { start: { x: 0, y: 0 }, end: { x: 10, y: 0 } },
  { start: { x: 10, y: 0 }, end: { x: 10, y: 10 } },
  { start: { x: 10, y: 10 }, end: { x: 0, y: 10 } },
  { start: { x: 0, y: 10 }, end: { x: 0, y: 0 } }
];

console.log("Testing with simple square:");
console.log("Input segments:", segments.length);

const paths = helpers.connectSegmentsToPaths(segments);

console.log("Output paths:", paths.length);
paths.forEach((path, i) => {
  console.log(`Path ${i}: ${path.length} points`);
  console.log("  First 3 points:", path.slice(0, 3));
  console.log("  Last 3 points:", path.slice(-3));
});

// Test with segments in random order
const shuffledSegments = [
  { start: { x: 10, y: 10 }, end: { x: 0, y: 10 } },
  { start: { x: 0, y: 0 }, end: { x: 10, y: 0 } },
  { start: { x: 0, y: 10 }, end: { x: 0, y: 0 } },
  { start: { x: 10, y: 0 }, end: { x: 10, y: 10 } }
];

console.log("\nTesting with shuffled square:");
console.log("Input segments:", shuffledSegments.length);

const shuffledPaths = helpers.connectSegmentsToPaths(shuffledSegments);

console.log("Output paths:", shuffledPaths.length);
shuffledPaths.forEach((path, i) => {
  console.log(`Path ${i}: ${path.length} points`);
  console.log("  First 3 points:", path.slice(0, 3));
  console.log("  Last 3 points:", path.slice(-3));
});

// Calculate signed area to check winding order
function signedArea(path) {
  let area = 0;
  for (let i = 0; i < path.length; i++) {
    const j = (i + 1) % path.length;
    area += path[i].x * path[j].y - path[j].x * path[i].y;
  }
  return area / 2;
}

console.log("\nPath winding check:");
console.log("Original path signed area:", signedArea(paths[0]));
console.log("Shuffled path signed area:", signedArea(shuffledPaths[0]));
console.log("(Positive = CCW, Negative = CW)");
