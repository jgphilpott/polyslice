/**
 * TypeScript definitions for Polyslice
 */

export interface PolysliceOptions {
  autohome?: boolean;
  workspacePlane?: 'XY' | 'XZ' | 'YZ';
  timeUnit?: 'milliseconds' | 'seconds';
  lengthUnit?: 'millimeters' | 'inches';
  temperatureUnit?: 'celsius' | 'fahrenheit' | 'kelvin';
  nozzleTemperature?: number;
  bedTemperature?: number;
  fanSpeed?: number;
}

export interface BezierControlPoint {
  x: number;
  y: number;
  extrude?: number;
  feedrate?: number;
  power?: number;
  xOffsetStart?: number;
  yOffsetStart?: number;
  xOffsetEnd: number;
  yOffsetEnd: number;
}

export declare class Polyslice {
  constructor(options?: PolysliceOptions);
  
  // Getters
  getAutohome(): boolean;
  getWorkspacePlane(): string;
  getTimeUnit(): string;
  getLengthUnit(): string;
  getTemperatureUnit(): string;
  getNozzleTemperature(): number;
  getBedTemperature(): number;
  getFanSpeed(): number;

  // Setters
  setAutohome(autohome?: boolean): Polyslice;
  setWorkspacePlane(plane?: string): Polyslice;
  setTimeUnit(unit?: string): Polyslice;
  setLengthUnit(unit?: string): Polyslice;
  setTemperatureUnit(unit?: string): Polyslice;
  setNozzleTemperature(temp?: number): Polyslice;
  setBedTemperature(temp?: number): Polyslice;
  setFanSpeed(speed?: number): Polyslice;

  // G-code generation methods
  codeAutohome(x?: boolean, y?: boolean, z?: boolean, skip?: boolean, raise?: number, leveling?: boolean): string;
  codeWorkspacePlane(plane?: string): string;
  codeLengthUnit(unit?: string): string;
  codeTemperatureUnit(unit?: string): string;
  codeMovement(x?: number, y?: number, z?: number, extrude?: number, feedrate?: number, power?: number): string;
  codeLinearMovement(x?: number, y?: number, z?: number, extrude?: number, feedrate?: number, power?: number): string;
  codeArcMovement(
    direction?: 'clockwise' | 'counterclockwise',
    x?: number,
    y?: number,
    z?: number,
    extrude?: number,
    feedrate?: number,
    power?: number,
    xOffset?: number,
    yOffset?: number,
    radius?: number,
    circles?: number
  ): string;
  codeBézierMovement(controlPoints?: BezierControlPoint[]): string;
  codePositionReport(auto?: boolean, interval?: number, real?: boolean, detail?: boolean, extruder?: boolean): string;
  codeNozzleTemperature(temp?: number, wait?: boolean, index?: number): string;
  codeBedTemperature(temp?: number, wait?: boolean, time?: number): string;
  codeTemperatureReport(auto?: boolean, interval?: number, index?: number, sensor?: boolean): string;
  codeFanSpeed(speed?: number, index?: number): string;
  codeFanReport(auto?: boolean, interval?: number): string;
  codeDwell(time?: number, interruptible?: boolean, message?: string): string;
  codeInterrupt(): string;
  codeWait(): string;
  codeTone(duration?: number, frequency?: number): string;
  codeMessage(message?: string): string;
  codeShutdown(): string;
  codeFirmwareReport(): string;
  codeSDReport(auto?: boolean, interval?: number, name?: boolean): string;
  codeProgressReport(percent?: number, time?: number): string;

  // Main slicing method
  slice(scene?: object): string;
}

export default Polyslice;