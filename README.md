# MazeSolver-Bot (FPGA — DE0‑Nano)

**Control unit implemented on a DE0‑Nano FPGA board using Quartus Prime.** The design runs entirely on the FPGA (no microcontroller). Verilog sources, Quartus project files, and hardware resources are included to build, simulate and program a maze‑exploring robot that also samples environmental sensors at specific measuring points and reports them to a user.

## Highlights
- FPGA-based robot control + sensor acquisition (DE0‑Nano, Cyclone IV).
- Implemented and tested with Quartus Prime 20.1.
- Verilog (100%) — modular design: sensor interfaces, motion control, FSM explorer, comms.

---

## What the project does (detailed)
This project implements an autonomous maze explorer with environmental sampling.

Runtime sequence (how it behaves on the robot):
1. The maze exploration FSM (t2c_maze_explorer.v) and motion controller (move_controller.v) drive the robot through the maze using ultrasonic/IR sensor feedback.
2. When the robot reaches a measuring point (detected by IR sensors plus wall/ultrasonic conditions), the move controller asserts an mpi signal and stops the motors (see move_controller.v, state CHECK_MPI → WAIT_CAPTURE).
3. Once in the measuring point, the servo dips a moisture probe into the soil and the ADC reads soil moisture. This is implemented by the moisture_sensor module which instantiates the servo and the adc_controller; the module provides an mm_done/stable_data indication when the measurement is ready.
4. At (approximately) the same time the DHT11 interface (t2a_dht.v) samples temperature and humidity.
5. The measured values (moisture, temperature, humidity — plus any other telemetry) are packaged and sent to the user via the Bluetooth/UART interface (bluetooth.v and uart_tx.v / uart_rx.v).

In short: the bot navigates the maze, detects measuring points with IR/wall sensors, mechanically samples soil moisture with a servo+dipped probe, reads DHT11 for environment data, and sends results to the user over wireless/serial links.

You can see this behavior in the demo video: https://youtu.be/hfJg5jYmMrU?si=1RFYLNTxfjBVxnvM


## Repository layout
```
Demo Video.mp4               # Demo of the assembled robot
README.md                    # This file (detailed README)
Maze Solver Bot/              # Quartus project and Verilog sources
  output_file.jic            # Generated programming file (JTAG Indirect Configuration)
  t2c_maze_explorer.qpf      # Quartus project file
  t2c_maze_explorer.qsf      # Quartus settings / pin assignments
  code/                      # Verilog modules (core logic)
    topmodule.v              # Top-level FPGA module (connects modules and I/O)
    t2c_maze_explorer.v      # Maze exploration FSM / sequencing
    move_controller.v        # Motion controller, measuring point detection (mpi), encoders
    sensor_communication.v   # Sensor aggregation (wiring helper for multiple sensors)
    adc_controller.v         # ADC controller for analog sensors (moisture probe)
    moisture_sensor.v        # Dips the probe via servo + ADC read (mm_done)
    t2a_dht.v                # DHT11 temperature & humidity interface
    t1b_ultrasonic.v         # HC‑SR04 ultrasonic timing & distance (distance_out, op)
    uart_tx.v / uart_rx.v    # UART transmit/receive (telemetry / debugging)
    bluetooth.v              # Bluetooth comms interface (user telemetry)
    l298_module.v            # L298 motor driver interface
    servo_motor.v            # Servo PWM driver (used to dip probe)
    centre_aligner.v         # Alignment helper to keep robot centered between walls
    u_filter.v               # Utility filters
Resources/                   # Datasheets and board manual
  de0_nano_manual.pdf
  DHT11-datasheet.pdf
  capacitive-soil-moisture-sensor-datasheet.pdf
```

**Signal & module connections (important names to look for in code):**
- move_controller.v: CHECK_MPI state asserts `mpi` when ir_in==0, wall_l && wall_r && front wall condition; then waits for `stable_data` before resuming (see WAIT_CAPTURE).
- moisture_sensor.v: combines a servo_motor instance and adc_controller; provides `mm_done` / `is_moisture` outputs and a `start_measure` input to trigger the servo/measurement cycle.
- t2a_dht.v: drives the DHT11 bidirectional pin and produces T_integral/T_decimal and RH_integral/RH_decimal plus a data_valid flag.
- t1b_ultrasonic.v: measures distance from HC‑SR04 and provides distance_out (mm) and an object present flag `op` used by motion control.
- uart_tx.v / bluetooth.v: used to transmit telemetry (moisture, temp, humidity, position/state) to the user.


## How it fits together (runtime shape)
- topmodule.v ties everything: sensors → sensor_communication → t2c_maze_explorer FMS → move_controller. When move_controller detects a measuring point it raises mpi; topmodule wires mpi to the moisture sampling path which starts the servo dip and ADC capture. DHT sampling runs under its own interface block and its results are read when available. When measurement modules assert their "done" signals (mm_done / data_valid), the top module or comms module packages the values and sends them over Bluetooth/UART to the user.


## Quick start — build & program
1. Install Quartus Prime 20.1 (project files were created/validated with 20.1).
2. Open `Maze Solver Bot/t2c_maze_explorer.qpf` in Quartus and confirm the target device is the DE0‑Nano (Cyclone IV).
3. Compile and program the board (GUI or CLI):

```bash
quartus_sh --flow compile "t2c_maze_explorer"
quartus_pgm -c USB-Blaster -m jtag -o "p;Maze Solver Bot/output_file.jic"
```

Notes:
- Clocks: sensor modules assume a 50 MHz clock; uart_tx expects a slower derived clock (around 3.125 MHz domain in the comments).
- Inspect `t2c_maze_explorer.qsf` for pin mappings for your wiring (sensors, L298, servos, UART/Bluetooth pins).


## Simulation & testing
- Create testbenches and run simulations in ModelSim/Questa or Quartus NativeLink.
- Prioritize timing‑sensitive modules: t1b_ultrasonic.v (edge/timing capture), uart_tx.v (baud timing), move_controller.v (state transitions and encoder counting), t2a_dht.v (bit timing), and moisture_sensor.v (servo timing + ADC handshake).


## Demo
Demo (recorded run): Demo Video.mp4
YouTube: https://youtu.be/hfJg5jYmMrU?si=1RFYLNTxfjBVxnvM — shows the robot navigating the maze, stopping at measuring points, dipping the moisture probe, reading DHT11, and sending data to the user.


## Next steps I can help with
- Produce a PINOUT / HARDWARE.md by extracting the main pin names from `t2c_maze_explorer.qsf` into a readable table.
- Add a small testbench template for `moisture_sensor.v` or `t2a_dht.v`.
- Add inline module documentation headers for `topmodule.v` or `move_controller.v` to make the signal flows clearer.

If you want, I will now update README.md in the repository with this content.
