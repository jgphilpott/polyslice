const { SerialPort } = require('serialport');

const port = new SerialPort({
  path: '/dev/tty.usbserial-10',
  baudRate: 115200
});

port.on('open', function() {

  console.log('Opened!');

  port.on('data', function(data) {
    console.log('Received: ' + data);
  });

  port.write('G28\n', function(error, results) {
    console.log('Results: ' + results);
    console.log('Error: ' + error);
  });

});