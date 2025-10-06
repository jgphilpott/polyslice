// Warp speed star field animation
class WarpSpeed {
  constructor() {
    this.canvas = document.getElementById('warp-canvas');
    this.ctx = this.canvas.getContext('2d');
    this.stars = [];
    this.numStars = 200;
    this.centerX = 0;
    this.centerY = 0;

    this.init();
    this.animate();

    // Handle window resize
    window.addEventListener('resize', () => this.init());
  }

  init() {
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
    this.centerX = this.canvas.width / 2;
    this.centerY = this.canvas.height / 2;

    // Clear canvas completely on init
    this.ctx.fillStyle = 'rgba(0, 0, 0, 1)';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    // Create stars
    this.stars = [];
    for (let i = 0; i < this.numStars; i++) {
      this.stars.push(this.createStar());
    }
  }

  createStar() {
    const angle = Math.random() * Math.PI * 2;
    const distance =
      (Math.random() * Math.max(this.canvas.width, this.canvas.height)) / 2;

    return {
      x: this.centerX + Math.cos(angle) * distance,
      y: this.centerY + Math.sin(angle) * distance,
      z: Math.random() * this.canvas.width,
      prevX: this.centerX,
      prevY: this.centerY,
      speed: Math.random() * 0.5 + 0.5,
    };
  }

  updateStar(star) {
    star.prevX = star.x;
    star.prevY = star.y;

    // Calculate position relative to center
    const dx = star.x - this.centerX;
    const dy = star.y - this.centerY;

    // Move star outward from center
    star.z -= star.speed * 8;

    // If star is too close, reset it
    if (star.z <= 0) {
      const angle = Math.random() * Math.PI * 2;
      const distance = Math.random() * 50 + 10;
      star.x = this.centerX + Math.cos(angle) * distance;
      star.y = this.centerY + Math.sin(angle) * distance;
      star.z = this.canvas.width;
      star.prevX = star.x;
      star.prevY = star.y;
    }

    // Calculate perspective projection
    const k = 128.0 / star.z;
    star.x = this.centerX + dx * k;
    star.y = this.centerY + dy * k;
  }

  drawStar(star) {
    // Calculate size based on depth
    const size = (1 - star.z / this.canvas.width) * 3;

    // Calculate opacity based on depth
    const opacity = 1 - star.z / this.canvas.width;

    // Draw star trail
    this.ctx.beginPath();
    this.ctx.lineWidth = size;
    this.ctx.strokeStyle = `rgba(255, 255, 255, ${opacity})`;
    this.ctx.moveTo(star.prevX, star.prevY);
    this.ctx.lineTo(star.x, star.y);
    this.ctx.stroke();

    // Draw star point
    this.ctx.beginPath();
    this.ctx.fillStyle = `rgba(255, 200, 100, ${opacity})`;
    this.ctx.arc(star.x, star.y, size, 0, Math.PI * 2);
    this.ctx.fill();
  }

  animate() {
    // Don't clear canvas - let streaks persist
    // this.ctx.fillStyle = 'rgba(0, 0, 0, 0.2)';
    // this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    // Update and draw stars
    this.stars.forEach(star => {
      this.updateStar(star);
      this.drawStar(star);
    });

    requestAnimationFrame(() => this.animate());
  }
}

// Initialize warp speed effect when page loads
document.addEventListener('DOMContentLoaded', () => {
  new WarpSpeed();
});
