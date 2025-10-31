/**
 * Test the distance calculation with simple circular paths
 */

const helpers = require('../../src/slicer/geometry/helpers');

// Create two concentric circular paths
function createCircle(centerX, centerY, radius, numPoints) {
  const points = [];
  for (let i = 0; i < numPoints; i++) {
    const angle = (i / numPoints) * Math.PI * 2;
    points.push({
      x: centerX + radius * Math.cos(angle),
      y: centerY + radius * Math.sin(angle),
      z: 0
    });
  }
  return points;
}

// Create two circles with known radii
const circle1 = createCircle(0, 0, 4.85, 32);  // Inner circle
const circle2 = createCircle(0, 0, 5.15, 32);  // Outer circle

console.log('Testing distance calculation between two circles:');
console.log(`Circle 1: radius 4.85mm, ${circle1.length} points`);
console.log(`Circle 2: radius 5.15mm, ${circle2.length} points`);
console.log(`Expected distance: ${(5.15 - 4.85).toFixed(3)}mm`);

const distance = helpers.calculateMinimumDistanceBetweenPaths(circle1, circle2);
console.log(`Calculated distance: ${distance.toFixed(3)}mm`);

if (Math.abs(distance - 0.3) < 0.05) {
  console.log('✅ Distance calculation is correct!');
} else {
  console.log('❌ Distance calculation may be incorrect');
}
