# Packet Tracer: how to work in it

Read this file for any task in Cisco Packet Tracer.

## Devices

- The user places the devices themselves. Do not add, move or delete any device.
- Configure each device through its **CLI** tab: click the device, open the CLI tab, click in the console.
  Write the commands in a file in the current folder (one command file per device) and type it with `ecrire-fichier`.
- Check the result with `show` commands (`show running-config`, `show ip interface brief`, `show vlan brief`...).
- For a PC: Desktop tab > IP Configuration.
- Open a device with **one** `clic`, never `doubleclic`: a second click on the device closes the window that the
  first one opened. If the window does not show yet, wait (`attendre 1000`) and look again before clicking.
- Fill in address fields with `remplacer`, not `ecrire`: Packet Tracer fills the subnet mask in by itself once the
  IP address is entered, so typing a mask after it gives it twice. An incomplete address opens an "Error" box:
  click OK, then fix the field.

## Cabling

- Only cable if the task or the user's instruction asks you to connect devices. Otherwise leave the cables as they are.
- Click the **Connections** icon (lightning bolt) in the bottom-left device bar, then the cable type.
- With a precise cable (straight-through, crossover, serial, console...): click the first device, pick the port
  in the list that opens, click the second device, pick its port.
- Never guess where a port will be in the list: its place and its length change with the device and with the
  ports already used. Click the device, end the call, read the list on the screenshot, then click the port.
  A click that misses the list lands on the workspace or on a device: it drops the cable, and the next click
  on a device opens its window instead of cabling it.
- If a device window opens while you are cabling, the cable tool is no longer selected: close the window,
  look at the screen, and select the cable again.
- With "Automatically Choose Connection Type": `relier X1 Y1 X2 Y2` does both clicks.
- Take a screenshot to check that the link is there, then press `esc` to put the cable tool away.
