const { SerialPort } = require('serialport');
const { ReadlineParser } = require('@serialport/parser-readline');

const port = new SerialPort({ path: 'COM3', baudRate: 115200 });
const parser = port.pipe(new ReadlineParser({ delimiter: '\n' }));

function sendToFPGA(payload) {
  return new Promise((resolve) => {
    port.write(JSON.stringify(payload) + "\n");
    parser.once('data', data => resolve(JSON.parse(data)));
  });
}

module.exports = sendToFPGA;
