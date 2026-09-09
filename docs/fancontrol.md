# Fan control 

The `fancontrol` role provides 2 features: 

- TUI dashboard over HDMI to monitor host temperatures
- Fan control of PWM fans using a PWM-compatible GPIO pin on the controller host

The configuration of these pins is highly specific to different SBC models. 
With the Radxa Rock Pi 4+ SBC I use, the device tree overlay has to be set up first to enable this board's PWM pin. 
The overlay defaults in `defaults/main.yml` need to be changed for different boards to work!

This role is only helpful if you want to control fans using the controller host; in most cases, it will be better to have bare-metal hosts drive their own fans. 

The fan control daemon exposes host temperatures to a `rich` TUI dashboard. Connect the controller to a HDMI display to render the dashboard. For the controller to have access to the temperatures of other hosts, it uses Node Exporter. 

Run the `monitoring.yml` and `deploy_fancontrol.yml` playbooks to enable the fan control features. 

## Caveats

It is very unlikely that the fan control implementation will work on hardware setups that are not identical to mine. Implementing the fan control solution was not straightforward and took a lot of troubleshooting; I mostly included this in case anyone else runs into similar problems. 
