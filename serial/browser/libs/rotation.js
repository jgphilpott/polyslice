// Rotate any jQuery selected element.
// Credit: https://gist.github.com/hoandang/5989980
// Credit: https://stackoverflow.com/a/15191130/1544937
$.fn.rotate = function(degree = 0, duration = 1000) {
    var element, rotation;
    element = $(this);
    rotation = function() {
      var matrix;
      matrix = element.css("-webkit-transform" || element.css("-moz-transform" || element.css("-ms-transform" || element.css("-o-transform" || element.css("transform")))));
      if (matrix !== "none") {
        matrix = matrix.split("(")[1].split(")")[0].split(",");
        return Math.round(Math.atan2(matrix[1], matrix[0]) * (180 / Math.PI));
      } else {
        return 0;
      }
    };
    rotation = rotation();
    if (rotation !== degree) {
      return $({
        "deg": rotation
      }).animate({
        "deg": degree
      }, {
        "duration": duration,
        "step": (now) => {
          return element.css({
            "transform": "rotate(" + now + "deg)"
          });
        }
      });
    }
};