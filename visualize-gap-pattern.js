/**
 * Visual gap pattern chart generator
 */

function generateGapVisualization() {
  const layers = [
    { layer: 0, z: 0.01, gap: 3.05, segments: 4711, paths: 19 },
    { layer: 1, z: 0.21, gap: 2.16, segments: 4645, paths: 10 },
    { layer: 2, z: 0.41, gap: 1.79, segments: 984, paths: 1 },
    { layer: 3, z: 0.61, gap: 4.94, segments: 975, paths: 1 },
    { layer: 4, z: 0.81, gap: 4.85, segments: 754, paths: 1 },
    { layer: 5, z: 1.01, gap: 4.88, segments: 724, paths: 1 },
    { layer: 6, z: 1.21, gap: 3.07, segments: 711, paths: 1 },
    { layer: 7, z: 1.41, gap: 5.27, segments: 706, paths: 1 },
    { layer: 8, z: 1.61, gap: 4.30, segments: 677, paths: 2 },
    { layer: 9, z: 1.81, gap: 3.55, segments: 697, paths: 1 },
    { layer: 10, z: 2.01, gap: 5.80, segments: 665, paths: 1 }
  ];

  console.log("\n╔══════════════════════════════════════════════════════════════════════════╗");
  console.log("║              BENCHY GAP PATTERN VISUALIZATION                            ║");
  console.log("╚══════════════════════════════════════════════════════════════════════════╝\n");

  console.log("Gap Size Distribution Across Layers:");
  console.log("─────────────────────────────────────────────────────────────────────────────\n");

  const maxGap = 6.0;
  const barWidth = 50;

  layers.forEach(l => {
    const barLength = Math.floor((l.gap / maxGap) * barWidth);
    const isCritical = l.gap > 4.0;
    const bar = (isCritical ? "█" : "▓").repeat(barLength);
    const marker = isCritical ? "🔴" : "⚠️ ";
    
    console.log(`Layer ${l.layer.toString().padStart(2)} (Z=${l.z.toFixed(2)}mm) ${marker}`);
    console.log(`${l.gap.toFixed(2)}mm │${bar}${' '.repeat(Math.max(0, barWidth - barLength))}│ ${l.segments} segments`);
    console.log();
  });

  console.log("\n┌─────────────────────────────────────────────────────────────────────────┐");
  console.log("│  Scale: 0mm ─────────────────────────────── 6mm                         │");
  console.log("│  Legend: ⚠️  = Gap > 1mm  |  🔴 = CRITICAL gap > 4mm                    │");
  console.log("└─────────────────────────────────────────────────────────────────────────┘\n");

  // Statistical summary
  const avgGap = layers.reduce((sum, l) => sum + l.gap, 0) / layers.length;
  const maxGapLayer = layers.reduce((max, l) => l.gap > max.gap ? l : max);
  const minGapLayer = layers.reduce((min, l) => l.gap < min.gap ? l : min);
  const criticalCount = layers.filter(l => l.gap > 4.0).length;

  console.log("Statistical Summary:");
  console.log("─────────────────────────────────────────────────────────────────────────────");
  console.log(`Layers analyzed:          ${layers.length}`);
  console.log(`Average gap size:         ${avgGap.toFixed(2)}mm`);
  console.log(`Minimum gap:              ${minGapLayer.gap.toFixed(2)}mm (Layer ${minGapLayer.layer})`);
  console.log(`Maximum gap:              ${maxGapLayer.gap.toFixed(2)}mm (Layer ${maxGapLayer.layer})`);
  console.log(`Critical layers (>4mm):   ${criticalCount}/${layers.length} (${Math.round(criticalCount/layers.length*100)}%)`);
  console.log(`All layers affected:      ${layers.length}/${layers.length} (100%)`);

  // Segment count trend
  console.log("\n\nSegment Count Trend:");
  console.log("─────────────────────────────────────────────────────────────────────────────");
  console.log("Note: Sharp drop from Layer 1 → Layer 2 suggests completion of bottom layers\n");

  const maxSegments = 5000;
  const segBarWidth = 40;

  layers.forEach(l => {
    const barLength = Math.floor((l.segments / maxSegments) * segBarWidth);
    const bar = "▓".repeat(barLength);
    console.log(`Layer ${l.layer.toString().padStart(2)}: ${bar} ${l.segments}`);
  });

  console.log("\n┌─────────────────────────────────────────────────────────────────────────┐");
  console.log("│  Observation: Segment count drops 80% from Layer 1 to Layer 2           │");
  console.log("│  This is normal - bottom layers have infill, upper layers are shells     │");
  console.log("└─────────────────────────────────────────────────────────────────────────┘\n");

  // Gap location pattern
  console.log("\nGap Location Pattern:");
  console.log("─────────────────────────────────────────────────────────────────────────────");
  console.log("All major gaps occur in X-range: -20.00mm to -25.50mm");
  console.log("This corresponds to Benchy's cabin wall area");
  console.log("\nGap coordinates (Layer 5 example):");
  console.log("  From: (-20.00, -0.81)");
  console.log("  To:   (-24.88, -0.81)");
  console.log("  Type: HORIZONTAL (ΔY = 0mm)");
  console.log("\nPattern suggests near-horizontal triangles with edges parallel to slice plane");

  // Timeline
  console.log("\n\n╔══════════════════════════════════════════════════════════════════════════╗");
  console.log("║                     GAP SEVERITY TIMELINE                                ║");
  console.log("╚══════════════════════════════════════════════════════════════════════════╝\n");

  console.log("Z-Height vs Gap Size:\n");
  
  const zRange = 2.1;
  const timelineHeight = 15;
  
  for (let row = timelineHeight; row >= 0; row--) {
    const z = (row / timelineHeight) * zRange;
    let line = `${z.toFixed(2).padStart(4)}mm │`;
    
    for (let i = 0; i < layers.length; i++) {
      const layer = layers[i];
      const layerZ = layer.z;
      
      if (Math.abs(layerZ - z) < 0.15) {
        const marker = layer.gap > 4.0 ? "🔴" : layer.gap > 2.5 ? "⚠️ " : "• ";
        line += marker;
      } else {
        line += "   ";
      }
    }
    
    console.log(line);
  }
  
  console.log("       └" + "───".repeat(layers.length));
  console.log("         " + layers.map(l => l.layer.toString().padStart(2)).join(" "));
  console.log("                                Layer Number\n");

  console.log("Conclusion: Gaps persist throughout all tested heights (0.01mm - 2.01mm)");
  console.log("           This indicates a systemic issue, not a model-specific artifact\n");
}

generateGapVisualization();
