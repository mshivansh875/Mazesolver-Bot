# MazeSolver-Bot (FPGA — DE0-Nano)

**Control unit implemented on a DE0-Nano FPGA board using Quartus Prime.** This repository contains the Verilog source, Quartus project files and supporting resources for a maze-exploring robot that reads sensors and controls motors from an FPGA.

## Highlights
- FPGA-based control and sensor processing (no microcontroller required).
- Built and tested for DE0-Nano (Altera/Intel Cyclone IV) using Quartus Prime (20.1 recommended).
- Verilog-only implementation (100% Verilog).

---

## What the project does
The MazeSolver-Bot firmware reads multiple sensors (ultrasonic, DHT11, soil moisture/ADC, IR), communicates over UART/Bluetooth, and drives motors/servos through an L298 driver and PWM servos. The top-level controller (topmodule) coordinates sensor reads, path exploration logic (maze explorer), and motion control to autonomously explore and navigate a maze.

## Quick start — build & program
1. Install Quartus Prime 20.1 (project files were created/validated with 20.1).
2. Open the Quartus project file: `Maze Solver Bot/t2c_maze_explorer.qpf` in Quartus Prime.
3. Set the target device to the DE0-Nano board (Cyclone IV family) if not already set.
4. Compile the project (Quartus GUI: Processing → Start Compilation, or CLI: `quartus_sh --flow compile "t2c_maze_explorer"`).
5. Generate the programming file if needed (.jic is already included as `Maze Solver Bot/output_file.jic`).
6. Program the DE0‑Nano using the USB-Blaster / Quartus Programmer (quartus_pgm) or from the GUI. Example CLI:

```bash
# compile (example)
quartus_sh --flow compile "Maze Solver Bot/t2c_maze_explorer.qpf"
# program (example using generated .jic)
quartus_pgm -c USB-Blaster -m jtag -o "p;Maze Solver Bot/output_file.jic"
```

Notes:
- Clock domains used in the code include a 50 MHz clock for sensors and a 3.125 MHz-ish clock/divided clock for UART transmission (see uart_tx.v comments).
- Use the included .qsf to check pin assignments for your specific DE0‑Nano wiring.

## Repository layout
```
Demo Video.mp4               # Recorded demo of the assembled robot
README.md                    # This file (detailed README)
Maze Solver Bot/              # Quartus project and Verilog sources
  output_file.jic            # Generated programming file (JTAG Indirect Configuration)
  output_file.map            # Mapping report
  t2c_maze_explorer.qpf      # Quartus project file
  t2c_maze_explorer.qsf      # Quartus settings / pin assignments
  t2c_maze_explorer.qws      # Workspace file
  *.rpt                      # Reports and logs
  code/                      # Verilog source modules (core logic)
    topmodule.v              # Top-level FPGA module (connects peripherals and modules)
    t2c_maze_explorer.v      # Maze explorer / main control FSM
    move_controller.v        # Motion control and motor sequencing
    sensor_communication.v   # Sensor read/aggregation module
    adc_controller.v         # ADC controller (for analog sensors)
    t1b_ultrasonic.v         # HC-SR04 ultrasonic sensor module
    t2a_dht.v                # DHT11 temperature/humidity interface
    uart_tx.v / uart_rx.v    # UART transmitter / receiver
    l298_module.v            # Interface to L298 motor driver
    servo_motor.v            # Servo PWM driver
    centre_aligner.v         # Centering helper logic (line/IR based)
    u_filter.v               # Utility filter module (debounce/cleanup)
    bluetooth.v              # Bluetooth comms interface
Resources/                   # Datasheets and board manual
  de0_nano_manual.pdf
  DHT11-datasheet.pdf
  capacitive-soil-moisture-sensor-datasheet.pdf
```

How it fits together: the top-level `topmodule.v` instantiates sensor interfaces (ultrasonic, DHT11, ADC), communication peripherals (UART, Bluetooth), motion drivers (L298 interface, servo PWM) and the maze exploration FSM (`t2c_maze_explorer.v`). Sensor data flows into `sensor_communication.v` and decision outputs feed `move_controller.v` which drives the motor/servo interfaces.

## Key modules (what to look at)
- topmodule.v — system wiring, clock/reset handling, and top-level I/O.
- t2c_maze_explorer.v — the maze exploration finite-state machine (main algorithm and sequencing).
- move_controller.v — low-level motor/actuator commands and speed/direction handling.
- sensor_communication.v — gathers sensor readings and presents them to the controller.
- t1b_ultrasonic.v — HC-SR04 interface; outputs measured distance and presence flag.
- uart_tx.v / uart_rx.v — packetized UART routines (115200 bps target as commented in the source).
- adc_controller.v — bridge to any analog sensors (e.g., moisture sensor) using an ADC front-end.

Open these files to understand how inputs map to outputs and to adapt timings or pin assignments.

## Simulation & testing
- Create simple testbenches for individual modules and run them in ModelSim (or Questa/Modelsim-Altera) or use the Quartus NativeLink simulation flow.
- The Quartus project contains a NativeLink simulation report (`*.rpt`) indicating prior simulation runs; use that as a starting point.
- Focus simulation on `t1b_ultrasonic.v`, `uart_tx.v`, `move_controller.v` and the `topmodule.v` skeleton.

## Wiring & sensors (high-level)
The design expects a mobile robot platform equipped with:
- HC‑SR04 ultrasonic distance sensor (t1b_ultrasonic.v)
- DHT11 temperature/humidity sensor (t2a_dht.v)
- Capacitive soil moisture / other analog sensors routed via ADC (adc_controller.v)
- L298 motor driver controlling two DC motors (l298_module.v)
- Servos (servo_motor.v) for mechanical actuators/steering
- Optional Bluetooth module (bluetooth.v) and UART debug port (uart_tx/uart_rx)

Check `Maze Solver Bot/t2c_maze_explorer.qsf` for the exact FPGA pin mappings used during the project build.

## Demo
See `Demo Video.mp4` at the repository root for a recorded run of the assembled robot performing maze exploration.

## Resources & references
- DE0-Nano manual: Resources/de0_nano_manual.pdf
- DHT11 datasheet: Resources/DHT11-datasheet.pdf
- Capacitive soil moisture sensor datasheet: Resources/capacitive-soil-moisture-sensor-datasheet.pdf

## Contributing
Contributions are welcome. Typical improvements include:
- Adding or improving testbenches and simulation scripts.
- Updating pin assignments in the .qsf for other hardware revisions.
- Cleaning up or documenting state machines and packet formats.

If you want me to open any specific file and add inline documentation or a testbench, tell me which module and I'll prepare it.

## License
No license is included in this repository. If you want a permissive license, consider adding an MIT or Apache-2.0 LICENSE file. I can add one for you if you’d like.

---

If you'd like, I can now:
- Add this README to the repository (update applied), or
- Create a short CONTRIBUTING.md, or
- Add an MIT license and a minimal .gitignore for Quartus outputs.
