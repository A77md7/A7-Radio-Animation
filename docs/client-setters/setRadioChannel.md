## setRadioChannel | addPlayerToRadio | SetCallChannel

## Description

Sets the local players radio channel.

## Parameters

* **radioChannel**: the radio channel to join

## NOTE: If the player fails the server side radio channel check they will be reset to no channel. 

```lua
-- Joins radio channel 1
exports['A7-voice']:setRadioChannel(1)

-- This will remove the player from all radio channels
exports ['A7-voice']:setRadioChannel(0)
```

addPlayerToRadio is provided as a 'easier to read' alternative to setRadioChannel.

```lua
-- Joins radio channel 1
exports['A7-voice']:addPlayerToRadio(1)
```
